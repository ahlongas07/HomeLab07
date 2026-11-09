# Caddy

## Purpose

Caddy is the HomeLab07 shared reverse proxy. It publishes platform services
over HTTPS with automatic certificates, from a version-controlled Caddyfile.
It was introduced in Sprint 017 and is the only platform reverse proxy.

## Responsibilities

Caddy is responsible for:

- reverse proxy and HTTPS termination;
- automatic Let's Encrypt certificates (HTTP-01);
- HTTP to HTTPS redirection and HSTS;
- origin protection: Cloudflare-proxied routes and plain HTTP accept only
  Cloudflare sources;
- the LAN-only administration site, which serves the Keycloak administration
  console to private sources with a certificate from Caddy's internal CA;
- sanitized access logs for the observability layer.

Caddy is **not** responsible for identity, authentication, application
configuration or secrets.

## Technology

| Component | Technology |
|---|---|
| Reverse proxy | Caddy 2.11.9, official image pinned by digest |
| Configuration | Caddyfile, snippets and sites in this directory |
| Certificates | Let's Encrypt, HTTP-01; Caddy internal CA for the LAN administration site |
| Runtime | Docker Compose, non-root, read-only root filesystem |

No database, Docker socket or custom build is required.

## Directory Structure

```text
services/caddy/
├── compose.yaml
├── Caddyfile                 # global options and imports
├── cloudflare-ranges.env     # public Cloudflare ranges (versioned)
├── snippets/
│   └── cloudflare-proxied.caddy
├── sites/
│   ├── homelab07.caddy       # HomeLab07 routes
│   ├── admin-lan.caddy       # LAN-only administration site (port 9443)
│   ├── juanchoai.caddy       # approved external application (JuanchoAI API)
│   └── rates-mock.caddy      # approved external application (JuanchoAI rates mock)
├── .env.example
└── README.md
```

Private, outside Git: `HomeLab07.private/env/caddy.env` (domains, ACME
contact, UID/GID, data root, LAN administration address).

## Configuration

Create the private environment from the example and set the domains, the ACME
contact and a non-root UID/GID:

```bash
cp services/caddy/.env.example ../HomeLab07.private/env/caddy.env
chmod 600 ../HomeLab07.private/env/caddy.env
```

Pre-create the persistent directories owned by `CADDY_UID:CADDY_GID`:

```bash
install -d -m 0700 -o <uid> -g <gid> <data-root>/caddy/data <data-root>/caddy/config
install -d -m 0755 -o <uid> -g <gid> <data-root>/caddy/logs
```

### Routes

Every route imports the `cloudflare_proxied` snippet with its upstream:

```caddy
{$CADDY_EXAMPLE_DOMAIN} {
	import cloudflare_proxied homelab07-example:8080
}
```

The snippet:

- returns `403` to any source outside the Cloudflare ranges, matching on the
  connecting address (`remote_ip`);
- sets HSTS `max-age=63072000; preload` without subdomains;
- limits request bodies to 2000 MB;
- forwards headers: Cloudflare is a trusted proxy, so `X-Forwarded-For` keeps
  the visitor and appends Cloudflare, and
  `X-Forwarded-Proto` keeps Cloudflare's value. `X-Real-IP` carries the visitor
  address, read from `CF-Connecting-IP` (`client_ip_headers`), which
  Cloudflare always sets; Apache's `remoteip` in the Nextcloud image takes the
  client from it. `X-Forwarded-Scheme` is set, and Caddy also sends
  `X-Forwarded-Host`, equal to `Host`, and `Via`.

### Plain HTTP

Automatic HTTP to HTTPS redirects are disabled (`auto_https
disable_redirects`). A catch-all `http://` block in the `Caddyfile` instead
redirects with `308` to HTTPS only when the connecting address is in the
Cloudflare ranges, and returns `403` to any other source. ACME HTTP-01
challenges are answered by Caddy before that block, so issuance and renewal
are unaffected.

Every route lives in `sites/`, and its domain is a variable in `caddy.env`:
HomeLab07 services in `homelab07.caddy`, and each external application
approved by the platform owner in its own file (`juanchoai.caddy`,
`rates-mock.caddy`). To add a
route, add the site block, add its `CADDY_<NAME>_DOMAIN` variable to
`compose.yaml`, `.env.example` and the private `caddy.env`, then recreate
Caddy. Applications never publish their own routes.

### Cloudflare ranges

`cloudflare-ranges.env` holds the published Cloudflare ranges, used both as
trusted proxies and as the origin allowlist. Check them regularly:

```bash
./operation/cloudflare-ranges-check.sh
```

A difference is fixed through a reviewed change, followed by
`./operation/compose.sh caddy up -d` so the new environment applies.

### Authenticated Origin Pulls

The Cloudflare ranges are shared by every Cloudflare customer, so the range
check alone cannot tell this zone from another account pointing a hostname at
the origin. Zone-level Authenticated Origin Pulls closes that gap: Cloudflare
presents a client certificate uploaded to this zone, and Caddy verifies it
against a private CA (`client_auth` in the shared snippet).

The CA and client certificate live in
`HomeLab07.private/certs/cloudflare-aop/` (`ca.key` and `client.key` mode
`0600`); only `ca.pem` is mounted into Caddy. Upload `client.pem` and
`client.key` to the zone (Cloudflare API, `origin_tls_client_auth`) and enable
the zone's Authenticated Origin Pulls setting.

Rollout and rotation use `mode verify_if_given` first: access log entries then
carry `request.tls.client_common_name`, which must show the zone certificate
on every request before the mode changes to `require_and_verify`. An expired
client certificate makes every route fail, so `security-audit.sh` fails 60
days before expiry. To rotate, issue a new client certificate from the same
CA, upload it, confirm it is active, then delete the old one in Cloudflare.

### LAN administration site

`sites/admin-lan.caddy` serves `https://<CADDY_ADMIN_LAN_ADDRESS>:9443`. The
port is bound only to that private address and is never forwarded by the
router; any source outside the private ranges receives `403`. Port 8443 is
not used because the NAS management interface listens on it on every host
address. It proxies the
Keycloak administration console and Admin REST API, which the public identity
route denies with `403` under `/admin`.

The certificate comes from Caddy's internal CA and is renewed automatically
(it lasts hours, by design). Browsers send no SNI to an IP address, so
`default_sni` selects it; Cloudflare always sends SNI, so public routes are
unaffected. `skip_install_trust` keeps Caddy from installing the root in the
container. Trust the root once on each administration device:

```bash
docker exec homelab07-caddy cat /data/caddy/pki/authorities/local/root.crt > homelab07-caddy-root.crt
openssl x509 -in homelab07-caddy-root.crt -noout -fingerprint -sha256
```

Compare the fingerprint before trusting the file. The root lives in
`caddy/data` and is included in the platform backup; a restore keeps it.

## Deployment

```bash
./operation/compose.sh caddy config --quiet
./operation/compose.sh caddy up -d
```

Caddy owns the `homelab07-proxy` network. Published services join it as an
external network and never publish host ports.

Configuration changes that do not touch `compose.yaml` or
`cloudflare-ranges.env` are applied without dropping connections:

```bash
docker exec homelab07-caddy caddy validate --config /etc/caddy/Caddyfile
docker exec homelab07-caddy caddy reload --config /etc/caddy/Caddyfile
```

An invalid configuration is rejected and the running one stays active.

## Validation

- `docker exec homelab07-caddy caddy validate --config /etc/caddy/Caddyfile`
- Each route answers through Cloudflare with a valid certificate.
- A direct origin request from a non-Cloudflare address returns `403`.
- Plain HTTP through Cloudflare redirects to HTTPS with `308`; a direct plain
  HTTP request from a non-Cloudflare address returns `403`. HTTPS responses
  carry HSTS.
- The administration API (`localhost:2019`) is unreachable from other
  containers.
- The LAN administration site answers from an approved LAN with a certificate
  that verifies against the internal root; `/admin/` on the public identity
  route returns `403`.
- `./operation/security-audit.sh` and `./operation/cloudflare-ranges-check.sh`
  pass.

## Backup

`<data-root>/caddy/data` (certificates and ACME account) and
`<data-root>/caddy/config` are included in the platform backup. Logs are not
backed up. Certificates can always be reissued; the backup avoids issuance
rate limits during a restore.

## Restore

Restore `caddy/data` and `caddy/config` with their ownership, restore the
private `caddy.env` and route files, then start Caddy. Missing certificates
are issued again automatically.

## Security

- Non-root UID/GID, read-only root filesystem, `no-new-privileges`, all
  capabilities dropped except `NET_BIND_SERVICE` for ports 80 and 443.
- Only ports 80 and 443 are published publicly. Port 9443 is bound to the
  private LAN address and serves only private sources. The Caddy administration
  API listens on the container loopback only.
- The internal CA root is private state under `caddy/data`; only its
  certificate leaves the host, never its key.
- Access logs replace request targets with `[REDACTED_TARGET]` and omit
  request and response headers. They are world-readable so the log shipper can
  read them without capabilities; certificates stay under `caddy/data`.
- Cloudflare-proxied routes verify the zone's Authenticated Origin Pulls
  client certificate; once required, other Cloudflare accounts cannot reach
  the origin.
- No domain, address, credential or certificate is committed.

## Related Sprint

- [Sprint 017 — Reverse Proxy Migration to Caddy](../../sprints/SPRINT-017.md)
- [Sprint 018 — Origin Trust Hardening](../../sprints/SPRINT-018.md)

# Caddy

## Purpose

Caddy is the HomeLab07 shared reverse proxy. It publishes platform services
over HTTPS with automatic certificates, from a version-controlled Caddyfile.
It replaces Nginx Proxy Manager (Sprint 017).

## Responsibilities

Caddy is responsible for:

- reverse proxy and HTTPS termination;
- automatic Let's Encrypt certificates (HTTP-01);
- HTTP to HTTPS redirection and HSTS;
- origin protection: Cloudflare-proxied routes accept only Cloudflare
  sources;
- sanitized access logs for the observability layer.

Caddy is **not** responsible for identity, authentication, application
configuration or secrets.

## Technology

| Component | Technology |
|---|---|
| Reverse proxy | Caddy 2.11.7, official image pinned by digest |
| Configuration | Caddyfile, snippets and sites in this directory |
| Certificates | Let's Encrypt, HTTP-01 |
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
│   └── juanchoai.caddy       # approved external application (JuanchoAI API)
├── .env.example
└── README.md
```

Private, outside Git: `HomeLab07.private/env/caddy.env` (domains, ACME
contact, UID/GID, data root).

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
- forwards headers as Nginx Proxy Manager did: Cloudflare is a trusted proxy,
  so `X-Forwarded-For` keeps the visitor and appends Cloudflare,
  `X-Forwarded-Proto` keeps Cloudflare's value, and `X-Real-IP` and
  `X-Forwarded-Scheme` are set. Caddy also sends `X-Forwarded-Host`, equal to
  `Host`, and `Via`.

Every route lives in `sites/`, and its domain is a variable in `caddy.env`:
HomeLab07 services in `homelab07.caddy`, and each external application
approved by the platform owner in its own file (`juanchoai.caddy`). To add a
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
- Plain HTTP redirects to HTTPS, and HTTPS responses carry HSTS.
- The administration API (`localhost:2019`) is unreachable from other
  containers.
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
- Only ports 80 and 443 are published. The administration API listens on the
  container loopback only.
- Access logs replace request targets with `[REDACTED_TARGET]` and omit
  request and response headers. They are world-readable so the log shipper can
  read them without capabilities; certificates stay under `caddy/data`.
- No domain, address or credential is committed.

## Related Sprint

- [Sprint 017 — Reverse Proxy Migration to Caddy](../../sprints/SPRINT-017.md)

# SPRINT-017 — Reverse Proxy Migration to Caddy

**Status:** Cut over 2026-10-28 — soak until 2026-11-11, then decommission

**Classification:** Platform Enhancement

**Phase:** Phase 2 — Shared Platform Capabilities

**Depends On:** Nginx Proxy Manager baseline (Sprint 004), Cloudflare edge
policy, Sprint 016 security scan targets

## Objective

Replace Nginx Proxy Manager with Caddy configured from a version-controlled
Caddyfile, so the shared reverse proxy is reproducible from the repository and
has no web administration plane, no database and no rendered state to audit.

## Background

Keeping Nginx Proxy Manager requires a growing set of compensating controls:

- Upstream issue #5919 can render a host without its access rules or SSL while
  the UI shows them as applied; `npm-access-audit.sh` must run after every
  change until a fix ships.
- The administration UI and API (ports `81` and `3000`) answer from every
  container on `homelab07-proxy`, bypassing the LAN-only boundary. Closing it
  needs host bridge filtering and `DOCKER-USER` rules.
- The proxy configuration lives in MariaDB and is edited through a GUI, so the
  repository is not its source of truth.

Read-only inventory of the NPM database on 2026-10-28 (identifiers only):

| Item | State |
|---|---|
| Proxy hosts | 6, one domain each: landing page, collaboration, documents, media, identity and one external application |
| Access lists | 1, used by all 6 hosts: 22 Cloudflare ranges, allow-only, implicit deny |
| Certificates | 6 Let's Encrypt HTTP-01; no DNS challenge |
| Advanced configuration, custom locations, redirections, streams, 404 hosts | None |
| Force SSL, HTTP/2, HSTS (without subdomains) | 5 hosts; the identity host has none of them |
| Block common exploits | 5 hosts |
| WebSocket upgrade | documents and media |
| Asset caching | collaboration |

Caddy covers every feature in use with its official image. The
administration API listens only on the container loopback, so no other
container can reach it.

## Decisions

| Decision | Outcome | Rationale |
|---|---|---|
| Configuration model | **Plain Caddy with a versioned Caddyfile.** | No Docker socket, and no application can publish its own route. caddy-docker-proxy was rejected for needing socket access and route governance. |
| Media route access | **Migrate the current state: proxied by Cloudflare, Cloudflare-only list.** | A public DNS check on 2026-10-28 showed every route, including media, resolving to Cloudflare. `EDGE_POLICY.md` still describes media as DNS-only and is corrected by this Sprint. A return to DNS-only, originally chosen because Cloudflare could restrict streaming traffic, is evaluated separately after the soak period (see Residual work). |
| Identity route HTTP behavior | **Align with the other hosts: forced HTTPS and HSTS without subdomains.** | Closes plain-HTTP access to the identity provider at the origin. The original reason for the exception is unknown, so an OIDC login for every client application is an acceptance criterion and the rehearsal checks for redirect loops. |
| Block common exploits | **Drop.** | It is a coarse regex filter; Cloudflare's managed WAF covers every proxied route. |
| Collaboration asset caching | **Drop.** | The application sets its own cache headers. |
| HTTP/3 at the origin | **Not enabled.** | Clients reach Cloudflare, which already speaks HTTP/3. |

## Scope

### Included

- `services/caddy/`: Compose file with the official Caddy image pinned by tag
  and digest, `Caddyfile`, snippets, `.env.example`, README following the
  service standard, and implementation notes.
- Domains and upstream choices come from the private environment through
  Caddyfile environment placeholders; no domain enters Git.
- A `cloudflare-only` snippet: a `remote_ip` matcher over the published
  Cloudflare ranges and `403` for every other source, imported by each route
  that uses the list today.
- Global `trusted_proxies` set to the Cloudflare ranges, so forwarded headers
  keep NPM's semantics: `X-Forwarded-For` keeps the visitor address and
  appends Cloudflare, and Cloudflare's `X-Forwarded-Proto` is preserved.
- Forced HTTPS and HSTS without subdomains on all six hosts, including the
  identity route, which has neither today; WebSocket and range requests use
  Caddy's native proxy behavior.
- `operation/cloudflare-ranges-check.sh`: read-only comparison of the
  versioned ranges with the provider's published lists.
- Persistent Caddy data (certificates, ACME account) on the platform data
  root and included in backup and restore.
- Caddy joins only `homelab07-proxy`; it needs no database and no internal
  network.
- Platform integration: `lib.sh` lifecycle order, `security-audit.sh` controls
  (published ports, LAN-only exposure, Caddyfile validation, certificate
  expiry), `backup.sh`, `restore-test.sh`, `platform-metrics.sh`, observability
  probes and dashboards, security scan exceptions.
- Documentation: edge policy (including the media route correction),
  incident response, validation, and the proxy sections of every published
  service README.

### Excluded

- Changes to Cloudflare, DNS or router configuration.
- New routes or applications.
- Authentication at the proxy (forward auth).
- Removal of NPM data, its database and its service directory: a follow-up
  decommission change after the soak period.

## Migration plan

1. **Recovery point.** Run a backup that includes NPM data, certificates and
   its database.
2. **Rehearsal.** Run Caddy on alternate LAN-only ports with an internal CA.
   Verify each route with `curl --connect-to`, the `403` for non-Cloudflare
   sources, and header parity against NPM using a temporary echo upstream.
3. **Cutover window.** Stop NPM, start Caddy, let it issue six HTTP-01
   certificates (Let's Encrypt staging first, then production), then run the
   validation below. NPM data and database remain untouched.
4. **Rollback.** Stop Caddy and start NPM; it resumes with its existing
   configuration and certificates within minutes.
5. **Soak.** Keep NPM stopped but intact for 14 days.
6. **Decommission (follow-up).** Remove the NPM service, its database and user
   after a final backup, `npm-access-audit.sh` and NPM scan exceptions.

## Cutover runbook

Private preparation, by the owner, before the window:

1. Create `HomeLab07.private/env/caddy.env` from `services/caddy/.env.example`
   (mode `0600`): the six current domains, an ACME contact, and the operator
   UID/GID.
2. Create `<data-root>/caddy/data` and `<data-root>/caddy/config` (`0700`) and
   `<data-root>/caddy/logs` (`0755`), owned by that UID/GID.
3. Create `HomeLab07.private/caddy/sites/` with one file per external
   application route, using the `cloudflare_proxied` snippet.
4. In `observability.env`, replace `HOMELAB07_NPM_LOG_ROOT` with
   `HOMELAB07_PROXY_LOG_ROOT=<data-root>/caddy/logs`.

Window:

5. Recovery point on the current revision: `./operation/backup.sh` (as root).
6. Update the platform checkout to the Sprint 017 revision.
7. `./operation/compose.sh caddy config --quiet` and
   `./operation/compose.sh caddy pull`.
8. `./operation/compose.sh nginx-proxy-manager stop`
9. `./operation/compose.sh caddy up -d`; follow
   `./operation/compose.sh caddy logs -f` until the six certificates are
   obtained.
10. `./operation/compose.sh observability up -d` so Alloy reads the new log
    root.
11. Validate the acceptance criteria below, `./operation/security-audit.sh`
    and the endpoint probes.

Rollback: `./operation/compose.sh caddy stop`, then
`./operation/compose.sh nginx-proxy-manager start`; restore the previous
`observability.env` value and revert the Sprint 017 commits before the next
platform start.

## Requirements and acceptance criteria

- **Given** Caddy serves the platform, **when** each route is requested
  through Cloudflare, **then** it answers over HTTPS with a valid certificate
  and the same application behavior as before.
- **Given** a route that uses the Cloudflare-only list today, **when** it is
  requested directly at the origin from a non-Cloudflare address, **then** it
  returns `403`.
- **Given** the documents application, **when** a user logs in, **then**
  login succeeds and rate limiting sees the visitor address with the existing
  trusted proxy count.
- **Given** the identity provider, **when** an OIDC login runs for each
  client application, **then** redirects and issuer URLs are correct and no
  redirect loop occurs.
- **Given** any route, **when** it is requested over plain HTTP at the origin,
  **then** it redirects to HTTPS, and every HTTPS response carries HSTS
  without subdomains.
- **Given** the collaboration and media applications, **when** desktop or
  mobile clients sync or play media, **then** uploads, WebSockets, range
  requests and resume work.
- **Given** any container on the shared networks, **when** it tries to reach
  the proxy administration API, **then** the connection fails.
- **Given** the Caddyfile changes, **when** it is validated and reloaded,
  **then** an invalid configuration is rejected without dropping traffic.
- **Given** Cloudflare publishes new ranges, **when** the range check runs,
  **then** it reports the difference.
- **Given** a failure after cutover, **when** rollback runs, **then** NPM
  serves all routes again with its previous certificates.

## Architecture and security contracts

- Caddy is the only service publishing `80` and `443`. It has no
  administration port, Docker socket or database.
- The Caddyfile and snippets are the source of truth; changes ship as
  reviewed commits and a validated reload.
- Domains, upstream overrides and private values stay in the private
  environment. The Cloudflare ranges are public and versioned.
- The image is pinned by tag and digest and covered by the security scan.
- Certificates and the ACME account live on private persistent storage
  included in backup.

## Validation

- `docker compose config`, `caddy validate`, `caddy fmt --diff`, ShellCheck on
  new scripts, and `security-audit.sh`.
- Rehearsal evidence: per-route response, `403` for non-Cloudflare sources,
  header parity table (sanitized).
- Cutover evidence: certificate issuance, endpoint probes, and per-application
  functional checks listed above.
- The first security scan after cutover includes the Caddy image.

## Rollback

Stop Caddy and start Nginx Proxy Manager with `./operation/compose.sh`. NPM
data, certificates and database are not modified until the decommission
change, so rollback needs no restore during the soak period.

## Residual work

- Disable the TLS-ALPN challenge, which cannot succeed behind Cloudflare, so
  failed attempts do not count against issuance limits.
- Media route evaluation, after the soak period: rehearse DNS-only playback
  (remote clients, transcoding, long sessions) against the Cloudflare-proxied
  route, then decide and update the edge policy. Changing the route requires
  removing the Cloudflare-only list for it in the same change.
- Decommission NPM, as described in the migration plan.

## Closure record

### Rehearsal (2026-10-28)

Caddy 2.11.7 ran on the platform host in a disposable sandbox on alternate
LAN-only ports, with an internal CA, the real routes and upstreams, and the
same runtime restrictions as the Compose definition. Production traffic stayed
on Nginx Proxy Manager. The sandbox, its containers and a temporary echo
upstream were removed afterwards.

- With only the Cloudflare ranges, all six routes returned `403` to direct
  requests from the NAS and from a LAN client.
- With test sources temporarily allowed: the landing page, Paperless and
  Jellyfin returned `200`; Nextcloud reported installed and not in maintenance;
  the external application returned `401` (token required); Keycloak's issuer
  matched production exactly.
- Header parity with Nginx Proxy Manager: `Host`, `X-Forwarded-For` (visitor,
  then proxy), `X-Forwarded-Proto` preserved, `X-Real-IP` overwritten with the
  connecting address, `X-Forwarded-Scheme`; Caddy adds `X-Forwarded-Host`
  (equal to `Host`) and `Via`.
- HTTP redirected with `308`; HSTS matched; WebSocket upgrade `101`; range
  request `206`; hot reload without errors; the administration API was
  unreachable from another container.
- Access log entries contained `[REDACTED_TARGET]` and no request or response
  headers, and were readable by a capability-less root reader, as Alloy runs.
- `caddy validate`, `caddy fmt`, `docker compose config` (Caddy and
  observability), `bash -n` and ShellCheck on changed scripts passed;
  ShellCheck reports only pre-existing findings.

### Production cutover (2026-10-28)

Private configuration was prepared on a dedicated `homelab07-caddy` share,
after a recovery point on the previous revision. Nginx Proxy Manager was
stopped and Caddy started at 15:39; Alloy was recreated for the new log root.

- Caddy obtained the six Let's Encrypt certificates within ten seconds through
  HTTP-01. TLS-ALPN attempts failed first, as expected behind Cloudflare.
- Through Cloudflare, every route answered. The landing page returned `200`,
  the application routes redirected to their login, and the external
  application returned `401` from its own API.
- A direct request to the origin returned `403` on all six routes.
- Plain HTTP on the identity route redirected with `308` to HTTPS.
- Keycloak's issuer matched the public HTTPS host, and Nextcloud reported
  installed and not in maintenance. The Paperless login page and Jellyfin
  public information returned `200`.
- Loki received Caddy access logs and both endpoint probes were up.
- `security-audit.sh`: 32 pass, 0 failures. Nginx Proxy Manager is retired and
  not running, and Caddy runs non-root with exactly 80 and 443 and a valid
  configuration.

Owner checks pending during the soak: OIDC login for every client
application, Paperless login, Nextcloud desktop and mobile synchronization,
Jellyfin remote playback and an authenticated external application request.

### External application route in the repository (2026-10-28)

At the owner's request, the JuanchoAI route moved from the private
`caddy/sites/` directory to `services/caddy/sites/juanchoai.caddy`, with its
domain in `caddy.env` like the other routes. The private directory remains for
routes that must stay out of Git.

### Deviations

- Caddy runs as a non-root UID/GID. The official binary carries the
  `cap_net_bind_service` file capability, so `NET_BIND_SERVICE` stays in the
  bounding set (with all other capabilities dropped); without it the binary
  cannot execute.
- Access logs use a dedicated `caddy/logs` volume, world-readable like the
  former proxy logs, so certificates under `caddy/data` stay private.
- The Cloudflare ranges are passed as an environment variable from a
  versioned file: Caddy's `remote_ip` matcher accepts no block, so the same
  list cannot be shared through an import.
- Caddy is not stopped during backup; its state is plain files.
- Caddy state lives on a dedicated `homelab07-caddy` share instead of the
  former proxy share, which stays untouched until the decommission.

### Findings outside scope

- Nextcloud's `trusted_proxies` does not contain the proxy network, so it
  does not see visitor addresses (behavior unchanged by the migration). Brute
  force protection therefore counts every visitor as the proxy. Correct the
  private value to the `homelab07-proxy` subnet in a separate change.
- Jellyfin has no Known Proxy configured, with the same effect for its logs
  and network classification.
- The origin HSTS header keeps Nginx Proxy Manager's `preload` token for
  parity, while the edge policy stages HSTS without preload. Align them in a
  separate change.

Record outcome, sanitized validation summary, deviations and residual work here.
Detailed private evidence remains in its approved private location.
Update the affected living specification under `/specs` before marking this
Sprint complete.

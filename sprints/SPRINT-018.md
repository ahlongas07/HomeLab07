# SPRINT-018 — Origin Trust Hardening

**Status:** Implementation complete — rollout in progress

**Classification:** Platform Enhancement

**Phase:** Phase 2 — Shared Platform Capabilities

**Depends On:** Sprint 017 Caddy reverse proxy, Cloudflare edge policy

## Objective

Make the origin trust only this zone's Cloudflare traffic, and let
applications see the real visitor address, so edge controls cannot be bypassed
and per-visitor protections work.

## Scope

### Included

- Zone-level Authenticated Origin Pulls: a private CA and client certificate,
  uploaded to the zone, verified by Caddy's shared route snippet; staged
  rollout from `verify_if_given` to `require_and_verify`.
- Security audit controls: the origin pull client certificate must be valid
  beyond 60 days, and a warning while certificates are not yet required.
- Disable the TLS-ALPN challenge, which cannot succeed behind Cloudflare.
- Nextcloud visitor address: `trusted_proxies` set to the current proxy
  network and `forwarded_for_headers` set to `HTTP_CF_CONNECTING_IP`.
- Documentation: Caddy and Nextcloud READMEs, edge policy, reverse proxy
  specification.

### Excluded

- Cloudflare Tunnel, custom Caddy images and DNS-01.
- Visitor address handling in other applications.

## Requirements and acceptance criteria

- **Given** `verify_if_given`, **when** requests arrive through Cloudflare
  after the zone certificate is enabled, **then** every access log entry
  carries the zone certificate's common name.
- **Given** `require_and_verify`, **when** a route is requested through this
  zone, **then** it works; **when** a connection presents no zone certificate,
  **then** the TLS handshake fails.
- **Given** Nextcloud behind Caddy, **when** a visitor logs in, **then**
  Nextcloud records the visitor address, not a proxy address.
- **Given** the origin pull client certificate is within 60 days of expiry,
  **when** the security audit runs, **then** it fails.

## Rollout

1. Recreate Nextcloud so the corrected `TRUSTED_PROXIES` applies.
2. Upload the client certificate to the zone and enable zone-level
   Authenticated Origin Pulls.
3. Deploy Caddy with `verify_if_given` and confirm the certificate in the
   access logs.
4. Change the mode to `require_and_verify` and deploy.

Rollback: set the mode back to `verify_if_given` (or remove `client_auth`) and
recreate Caddy; disabling the zone setting alone does not break the origin
while the mode is `verify_if_given`.

## Closure record

Record outcome, sanitized validation summary, deviations and residual work here.
Detailed private evidence remains in its approved private location.

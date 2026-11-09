# Reverse Proxy Capability

**Status:** Implemented in Sprint 017 (Caddy); in production since
2026-10-28. Nginx Proxy Manager was decommissioned on 2026-11-09

## Required behavior

- Publish platform and approved external applications over HTTPS from a
  version-controlled configuration; the running proxy holds no configuration
  state outside the repository and private environment.
- Obtain and renew certificates automatically, redirect HTTP to HTTPS and send
  HSTS without subdomains on every route.
- Accept origin requests on Cloudflare-proxied routes only from the published
  Cloudflare ranges, matched on the connecting address, and trust only those
  ranges for forwarded headers. Require the zone's Authenticated Origin Pulls
  client certificate, so other Cloudflare accounts cannot reach the origin.
- Redirect plain HTTP to HTTPS only for Cloudflare sources, matched on the
  connecting address; any other plain HTTP source receives `403`.
- Forward `Host`, `X-Forwarded-For` (visitor, then Cloudflare),
  `X-Forwarded-Proto` (Cloudflare's value), `X-Real-IP` (the visitor, from
  `CF-Connecting-IP`) and `X-Forwarded-Scheme` with the semantics applications
  were validated against.
- Reject an invalid configuration on reload without dropping traffic.
- Write access logs without request targets or headers, readable by the
  observability layer.
- Serve administration interfaces only on a LAN administration site bound to
  the private LAN address on port 8443, to private sources only, with a
  certificate from the proxy's internal CA; the public route of such a service
  denies its administration paths.

## Boundaries

The proxy publishes only ports 80 and 443 publicly, plus port 8443 bound to the
private LAN address; it runs as a non-root user with no capability other than
binding those ports, and its own administration API is not reachable outside
its container. It has no database and no Docker socket.
Applications never publish their own routes: HomeLab07 and approved external
application routes are versioned in the repository, with their domains in the
private environment. Domains, addresses and credentials stay outside Git.
Authentication at the proxy is not provided.

## Operational references

- [Caddy service](../services/caddy/README.md)
- [Edge security policy](../docs/security/EDGE_POLICY.md)
- [Security validation](../docs/security/VALIDATION.md)
- [Sprint 017 scope, decisions and evidence](../sprints/SPRINT-017.md)

# Reverse Proxy Capability

**Status:** Implemented in Sprint 017 (Caddy); validated in a target-host
rehearsal; production cutover pending

## Required behavior

- Publish platform and approved external applications over HTTPS from a
  version-controlled configuration; the running proxy holds no configuration
  state outside the repository and private environment.
- Obtain and renew certificates automatically, redirect HTTP to HTTPS and send
  HSTS without subdomains on every route.
- Accept origin requests on Cloudflare-proxied routes only from the published
  Cloudflare ranges, matched on the connecting address, and trust only those
  ranges for forwarded headers.
- Forward `Host`, `X-Forwarded-For` (visitor, then Cloudflare),
  `X-Forwarded-Proto` (Cloudflare's value), `X-Real-IP` and
  `X-Forwarded-Scheme` with the semantics applications were validated against.
- Reject an invalid configuration on reload without dropping traffic.
- Write access logs without request targets or headers, readable by the
  observability layer.

## Boundaries

The proxy publishes only ports 80 and 443, runs as a non-root user with no
capability other than binding those ports, and has no administration listener
reachable outside its container. It has no database and no Docker socket.
Applications never publish their own routes: HomeLab07 routes are versioned in
the repository and external application routes are private files reviewed by
the platform owner. Domains, addresses and credentials stay outside Git.
Authentication at the proxy is not provided.

## Operational references

- [Caddy service](../services/caddy/README.md)
- [Edge security policy](../docs/security/EDGE_POLICY.md)
- [Security validation](../docs/security/VALIDATION.md)
- [Sprint 017 scope, decisions and evidence](../sprints/SPRINT-017.md)

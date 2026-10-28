# Edge Security Policy

## Purpose

This document defines the desired public-exposure and edge-security state for
HomeLab07. Provider dashboards implement the policy manually; this repository
remains the source of truth. Real hostnames, addresses, account identifiers,
rule identifiers and credentials belong outside Git.

## Exposure Classes

| Class | Path | Policy |
|---|---|---|
| Proxied web application | Cloudflare → Caddy → application | Managed WAF, narrow rate limiting, response headers and direct-origin denial |
| Proxied media application | Cloudflare → Caddy → application | Same as proxied web applications; rate limits exclude media paths |
| LAN integration | Approved LAN → Homebridge host listeners | No public DNS or reverse-proxy publication |
| Internal data service | Internal Docker network | No host ports and no public route |
| Outbound automation | Service → provider API | No inbound listener |
| Read-only API client | Client with its own User-Agent → Cloudflare → Caddy → application API | Token of a read-only account; no Cloudflare exception; see [Medical Agent Access](MEDICAL_AGENT_ACCESS.md) |

Only approved public gateway forwards are retained. Caddy is the only service
that declares public gateway ports, and only 80 and 443. It has no
administration listener: its configuration is the version-controlled
Caddyfile, and its API listens only on the container loopback. Exact firewall
and network parameters remain in private operational configuration and
evidence.

Every public route is currently proxied by Cloudflare, including media
(verified 2026-10-28; Sprint 017). Returning media to DNS-only, originally
chosen because Cloudflare could restrict streaming, requires the evaluation
recorded in Sprint 017 and removing the Cloudflare-only restriction for that
route in the same change.

## Cloudflare Baseline

- SSL/TLS mode: Full (strict).
- Managed WAF: enabled for proxied hostnames.
- Custom WAF rules: retained only when a demonstrated threat or false-positive
  exception has an owner and rollback procedure.
- Rate limiting: narrowly scoped IP-based rules protect authentication
  endpoints without affecting synchronization, API, media or static traffic.
- Response headers use **Set static**, not Add, to avoid duplicate policies:
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: strict-origin-when-cross-origin`
- HSTS is staged with a limited lifetime, without `includeSubDomains` and
  without preload.
- Global CSP, framing policy and browser capability restrictions are deferred
  because they require application-specific compatibility validation.

Rate-limit rules intentionally exclude upload, synchronization, WebDAV, API,
static-resource and media paths. Exact matches, thresholds and block windows
remain in private provider evidence. DNS-only routes never receive Cloudflare
WAF, rate-limit, transform or HSTS controls.

## Origin Policy

Routes that use Cloudflare must accept origin requests only from current
Cloudflare IPv4 and IPv6 ranges. Caddy's `cloudflare_proxied` snippet returns
`403` to any connecting address outside the published ranges in
`services/caddy/cloudflare-ranges.env`, and trusts only those ranges for
forwarded headers. `operation/cloudflare-ranges-check.sh` compares the
versioned list with the provider's; changes are reviewed before the list is
updated.

A DNS-only service must not use the `cloudflare_proxied` snippet. It remains
protected by HTTPS, Caddy routing, application authentication and the
router/host boundary.

## Zero Trust Decision

Cloudflare Access remains a future option for browser-only administrative
interfaces. Sprint 009 does not deploy Tunnel, WARP or an identity dependency.
Native clients, WebDAV, media playback, HomeKit discovery and recovery access
must be proven compatible in a bounded future proof of concept before adoption.

## Ownership And Review Triggers

The platform owner reviews this policy after:

- a provider plan or ruleset change;
- a new public hostname or application protocol;
- a Cloudflare IP-range change;
- an authentication-path change;
- a certificate, proxy or router change;
- an edge false positive or suspected origin bypass;
- each security-focused Sprint or major platform release.

Related validation and rollback procedures are defined in
[`VALIDATION.md`](VALIDATION.md) and [`INCIDENT_RESPONSE.md`](INCIDENT_RESPONSE.md).

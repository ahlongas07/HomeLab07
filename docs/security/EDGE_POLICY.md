# Edge Security Policy

## Purpose

This document defines the desired public-exposure and edge-security state for
HomeLab07. Provider dashboards implement the policy manually; this repository
remains the source of truth. Real hostnames, addresses, account identifiers,
rule identifiers and credentials belong outside Git.

## Exposure Classes

| Class | Path | Policy |
|---|---|---|
| Proxied web application | Cloudflare → Nginx Proxy Manager → application | Managed WAF, narrow rate limiting, response headers and direct-origin denial |
| DNS-only media application | Nginx Proxy Manager → application | HTTPS through the shared gateway; no claim of Cloudflare HTTP protection |
| Management | Approved management network → proxy administration | Denied from WAN and untrusted networks |
| LAN integration | Approved LAN → Homebridge host listeners | No public DNS or reverse-proxy publication |
| Internal data service | Internal Docker network | No host ports and no public route |
| Outbound automation | Service → provider API | No inbound listener |

Only approved public gateway forwards are retained. Nginx Proxy Manager is the
only service that declares public gateway ports. Its administration listener
is bound by Docker only to an explicitly configured LAN address and must be
denied outside approved management sources. Exact listener, firewall and
network parameters remain in private operational configuration and evidence.

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

Proxy hosts that use Cloudflare must accept origin requests only from current
Cloudflare IPv4 and IPv6 ranges. The Nginx Proxy Manager access list uses all
published Cloudflare ranges followed by a deny-all rule. Provider range changes
must be reviewed before the list is updated.

DNS-only services must not use the Cloudflare-only access list. They remain
protected by HTTPS, Nginx Proxy Manager routing, application authentication and
the router/host boundary.

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

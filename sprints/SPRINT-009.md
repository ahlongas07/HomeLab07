# Sprint 009 — Platform Operations

**Status:** Planned — technical design complete; implementation required

**Classification:** Platform Enhancement

**Primary Focus:** Security hardening and operational assurance

**Last Reviewed:** 2026-07-28

---

# Objective

Harden the existing HomeLab07 platform by making its exposure boundaries,
edge-security policies, management access and recurring security validation
explicit, reproducible and operationally testable.

Sprint 009 must improve the platform already delivered through Sprints 001–008.
It does not deploy another reverse proxy, identity provider, VPN, SIEM,
monitoring stack or security appliance.

The Sprint must preserve application compatibility. A security control is not
accepted merely because it blocks traffic; it must reduce a demonstrated risk
without breaking approved browser, mobile, synchronization, streaming,
automation or recovery workflows.

---

# Decision Context

HomeLab07 currently provides:

- Nginx Proxy Manager as the only public origin gateway;
- Cloudflare Dynamic DNS and optional proxied DNS records;
- HTTPS certificates through Nginx Proxy Manager;
- shared internal and proxy Docker networks;
- public Nextcloud, Paperless-ngx, Jellyfin and Landing Page routes;
- LAN-only Homebridge using a service-specific host-networking exception;
- MariaDB and Valkey without published host ports;
- lifecycle operations through the HomeLab07 Operation Layer;
- environment-specific values and secrets through `HomeLab07.private/`.

The current Nginx Proxy Manager definition publishes `80`, `443` and its
administration port `81` on all host interfaces. Router policy may prevent WAN
access to port `81`, but Compose alone does not prove the administration
boundary. Sprint 009 must make that boundary explicit and validate it
negatively from unapproved networks.

Cloudflare controls protect only traffic that traverses proxied records. A
DNS-only hostname or direct origin request does not consume Cloudflare WAF,
rate limiting or response-transform controls. Sprint evidence must therefore
distinguish edge protection from origin protection.

```text
Proxied public hostname
    → Cloudflare edge controls
    → router and host boundary
    → Nginx Proxy Manager
    → approved published service

DNS-only public hostname
    → router and host boundary
    → Nginx Proxy Manager
    → approved published service

Approved management LAN
    → Nginx Proxy Manager administration

Approved HomeKit LAN
    → Homebridge host-networking listeners

Unapproved and external networks
    → denied unless an explicit public route exists
```

---

# Architecture

## Security Control Layers

Sprint 009 uses defense in depth without duplicating ownership.

| Layer | Responsibility | Owner |
|---|---|---|
| Cloudflare edge | Proxied-host WAF, rate limiting and optional header transforms | Cloudflare configuration under HomeLab07 policy |
| Router and host | WAN forwarding, management-network access and direct-origin policy | Network infrastructure |
| Nginx Proxy Manager | TLS termination, host routing and origin-facing security headers | Nginx Proxy Manager |
| Docker | Service network membership and host-port publication | HomeLab07 Compose definitions |
| Application | Authentication, authorization, sessions and application-specific request policy | Individual service |
| Operation Layer | Sanitized inventory and repeatable security validation | HomeLab07 |
| Rockstor | Persistent application and gateway state | Storage platform |

No layer may be described as providing protection that was not observed on the
actual traffic path.

## Exposure Classes

Every service and listener must belong to exactly one class.

| Class | Definition | Baseline examples |
|---|---|---|
| Public proxied | Public hostname traverses Cloudflare and Nginx Proxy Manager | Determine from target DNS inventory |
| Public DNS-only | Public hostname reaches Nginx Proxy Manager without Cloudflare HTTP proxying | Determine from target DNS inventory |
| LAN management | Administrative endpoint restricted to approved management networks | Nginx Proxy Manager port `81` |
| LAN application | Application requires direct approved-LAN reachability | Homebridge UI, HAP and mDNS |
| Container internal | Reachable only on `homelab07-internal` | MariaDB and Valkey |
| Proxy internal | Reachable only from Nginx Proxy Manager on `homelab07-proxy` | Published application container ports |
| Outbound only | Initiates outbound traffic and accepts no inbound application traffic | Cloudflare Dynamic DNS |

Unknown exposure is a Sprint blocker. “Private IP” and “LAN” are not security
classifications without an approved source-network policy.

## Origin Protection Decision Boundary

Cloudflare recommends allowing its published IP ranges and blocking other
sources at an origin used exclusively by proxied hostnames. HomeLab07 must not
apply that policy blindly to a shared `443` listener while an approved DNS-only
service also requires direct clients.

Implementation must first choose and document one of these outcomes:

1. all approved public hostnames are proxied and origin `80`/`443` may be
   limited to current Cloudflare source ranges plus explicitly documented
   recovery access; or
2. at least one approved hostname remains DNS-only, so the shared origin must
   retain direct access and rely on Nginx Proxy Manager, host firewall and
   application controls instead of claiming Cloudflare-only origin isolation.

Separating listeners, adding a second gateway or introducing a tunnel is not
approved by this Sprint merely to obtain Cloudflare-only origin access.

Official reference:

- [Cloudflare origin-server protection](https://developers.cloudflare.com/fundamentals/security/protect-your-origin-server/)

---

# Public Exposure Inventory

Before changing controls, create a sanitized inventory containing:

- every host TCP and UDP listener relevant to HomeLab07;
- every Compose `ports` entry and `network_mode: host` service;
- router WAN-forwarded ports;
- Cloudflare DNS record proxy mode by service classification;
- Nginx Proxy Manager Proxy Hosts, Redirection Hosts and Streams;
- certificate host coverage and expiry;
- each application's Docker networks;
- management interfaces and their approved source networks;
- Homebridge UI, HAP, child-bridge and mDNS listeners;
- unexpected or undocumented listeners.

Real domains, addresses, certificate contents, tokens and household metadata
must not enter Git. Repository evidence records classifications and sanitized
counts only.

Expected baseline:

- only Nginx Proxy Manager publishes public HTTP and HTTPS gateway ports;
- Nginx Proxy Manager administration is not reachable from WAN or unapproved
  LANs;
- no application publishes a direct public host port;
- MariaDB and Valkey remain internal;
- Cloudflare Dynamic DNS accepts no inbound port;
- Homebridge is the only host-networking container and remains LAN-only;
- no Docker socket or privileged container exists.

---

# Nginx Proxy Manager Administration Boundary

Port `81` is a management endpoint, not a public platform service.

Sprint 009 must select the simplest target-host control that provides an
explicit boundary:

- bind port `81` to a private management address supplied only through
  `HomeLab07.private`; or
- enforce an equivalent host-firewall and router rule limited to approved
  management sources.

Binding to a private address is preferred when the target Docker host and
network topology support it reliably. The repository must use a placeholder
or required private variable and must never encode the real address.

Acceptance requires:

- successful administration from an approved management client;
- denial from guest, visitor and untrusted IoT networks;
- denial from an external source;
- no effect on public ports `80` and `443`;
- documented local recovery access;
- changed default credentials and protected administrative credentials;
- session and authentication behavior validated after hardening.

Cloudflare Access or a Tunnel must not be used to publish port `81` merely to
avoid defining the LAN management boundary.

---

# Cloudflare WAF

## Capability Boundary

Cloudflare custom WAF rules are available across plans, with rule counts and
expression features varying by plan. The Free Managed Ruleset provides a
limited managed baseline on the Free plan. Implementation must inventory the
actual zone entitlement before promising a ruleset or action.

Official references:

- [Cloudflare WAF](https://developers.cloudflare.com/waf/)
- [Cloudflare custom-rule availability](https://developers.cloudflare.com/waf/custom-rules/)
- [Cloudflare WAF getting started](https://developers.cloudflare.com/waf/get-started/)

## Policy

WAF rollout must be application-aware and reversible.

1. Record the current proxied hostname set and available rule entitlement.
2. Enable the applicable managed ruleset with default-safe behavior.
3. Review sampled Security Events before adding custom enforcement.
4. Introduce narrowly scoped rules for demonstrated abuse or exposure.
5. Prefer Managed Challenge during initial tuning when available and suitable.
6. Record every exception with hostname, path class, reason and review trigger.
7. Validate uploads, synchronization, WebDAV, APIs, streaming and WebSockets.
8. Roll back any rule that creates unexplained application failure.

Custom WAF rules must not contain real private addresses, user identifiers,
tokens or credentials in repository documentation.

WAF acceptance is not defined by a high block count. It is defined by a known
policy producing expected challenge or denial behavior without disrupting
approved workflows.

---

# Rate Limiting

Cloudflare rate-limiting capabilities vary by plan. The current Free baseline
provides one rule with IP-based counting and a ten-second period; higher plans
provide additional expression fields, periods and rule counts. Actual
entitlement must be captured before selecting syntax or thresholds.

Official references:

- [Cloudflare rate-limiting rules](https://developers.cloudflare.com/waf/rate-limiting-rules/)
- [Cloudflare rate-limiting parameters](https://developers.cloudflare.com/waf/rate-limiting-rules/parameters/)

Implementation must:

- select a narrowly scoped authentication or abuse-sensitive request class;
- measure representative normal behavior before setting a threshold;
- account for multiple users behind one NAT address;
- validate challenge or block behavior from a disposable test client;
- confirm recovery after the mitigation period;
- review Security Events for false positives;
- document why the chosen rule has greater platform value than competing
  candidates when the plan permits only one rule.

Do not apply blanket rate limiting to:

- Nextcloud WebDAV, synchronization, upload or download traffic;
- Paperless document upload or background polling paths;
- Jellyfin playback, range requests or WebSockets;
- static assets required by login flows;
- Homebridge, which does not traverse Cloudflare.

Thresholds must not be guessed in this planning document. They are
implementation evidence derived from target traffic and plan capabilities.

---

# Security Headers And TLS

## Ownership

Each header must have one documented owner. Do not set the same header in
Cloudflare, Nginx Proxy Manager and the application unless a tested reason
requires layered behavior.

Safe baseline candidates include:

- `X-Content-Type-Options: nosniff`;
- `Referrer-Policy: strict-origin-when-cross-origin`;
- removal of unnecessary origin-identifying response headers where supported.

Application-specific controls require compatibility evidence:

- Content Security Policy;
- `frame-ancestors` or `X-Frame-Options`;
- Permissions Policy;
- cross-origin isolation headers;
- cache-policy overrides.

A global Content Security Policy is not approved. Nextcloud, Paperless-ngx,
Jellyfin and Nginx Proxy Manager have different scripts, workers, media,
WebSocket and framing behavior.

Cloudflare response-header transform rules can set, add or remove supported
response headers. If used, the repository must record the matching hostname
class, intended value and rollback procedure.

Official reference:

- [Cloudflare response-header transform rules](https://developers.cloudflare.com/rules/transform/response-header-modification/)

## HSTS

HSTS is accepted only after HTTPS, renewal and recovery paths work for every
covered hostname. Initial rollout must use a reversible, limited `max-age`.
`includeSubDomains` and preload remain disabled until every affected subdomain
has a durable HTTPS commitment and explicit approval.

Official reference:

- [Cloudflare HSTS requirements](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/http-strict-transport-security/)

TLS validation must cover:

- HTTP-to-HTTPS redirection;
- valid certificate chain and hostname coverage;
- certificate expiry and renewal state;
- supported protocol baseline;
- direct-origin behavior appropriate to the selected proxy mode;
- local recovery access before strict controls are retained.

---

# Cloudflare Zero Trust Evaluation

Sprint 009 evaluates Zero Trust; it does not deploy Cloudflare Tunnel, the
Cloudflare One Client, private routing or a new identity dependency.

The evaluation must consider:

| Candidate | Evaluation concern |
|---|---|
| Nginx Proxy Manager administration | Must remain LAN management; publishing it to add Access is not approved |
| Nextcloud browser UI | Access redirect may conflict with desktop/mobile clients and WebDAV |
| Paperless-ngx | Browser and API/consumer compatibility must be separated |
| Jellyfin | Native and TV clients may not support an Access login flow |
| Landing Page | Public content gains little from identity enforcement |
| Homebridge | Non-HTTP HomeKit behavior and LAN-only policy exclude it |
| Future administrator access | May justify a later private-access design after identity requirements are defined |

Cloudflare self-hosted Access applications can protect public hostnames or
private applications, but private routing normally introduces Tunnel or Mesh
connectivity and a client path. Those are new operational dependencies and
require a future implementation decision.

Official references:

- [Cloudflare Zero Trust setup](https://developers.cloudflare.com/cloudflare-one/setup/)
- [Cloudflare self-hosted application types](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/choose-application-type/)

Required output:

- evaluated use cases;
- client and protocol compatibility matrix;
- identity and recovery dependencies;
- operational cost and failure modes;
- recommended decision: adopt later, reject or perform a bounded PoC;
- explicit confirmation that evaluation alone creates no public route.

Identity-provider deployment remains Sprint 011. Sprint 009 must not preempt
that platform decision.

---

# Container And Host Hardening Review

Review every service for:

- exact image tag and digest evidence;
- mutable-tag exposure and update policy;
- effective user and filesystem permissions;
- `no-new-privileges` compatibility;
- dropped capabilities and read-only filesystem feasibility;
- required mounts and read-only mount opportunities;
- Docker socket and privileged-mode absence;
- published ports and Docker network membership;
- restart and healthcheck behavior;
- sensitive environment variables and secret-file permissions;
- log content that may expose tokens, URLs, identities or household metadata;
- resource limits only where target evidence demonstrates value.

Sprint 009 may harden existing Compose definitions when compatibility is
validated. It must not upgrade application major versions, change application
topology or introduce an automated update controller.

Homebridge host networking remains an approved exception. The review may
strengthen its host, router and VLAN rules but must not move unrelated services
to host networking.

The stable-major `favonia/cloudflare-ddns:1` and other tag-only images must be
assessed for immutable deployment references. Image changes remain controlled,
reviewed and rollback-capable.

---

# Operation Layer Integration

Sprint 009 is expected to add a read-only security audit command:

```text
operation/security-audit.sh
```

Expected operator interface:

```bash
./operation/security-audit.sh
./operation/status.sh
./operation/compose.sh nginx-proxy-manager ps
./operation/compose.sh nginx-proxy-manager logs
```

The audit must report sanitized pass, warning or failure results for:

- Compose host-port declarations;
- running container port mappings;
- host-networking containers;
- privileged containers and Docker socket mounts;
- expected Docker network membership;
- mutable image references;
- container health and restart state;
- missing private configuration file permissions where safely testable;
- Nginx Proxy Manager administration bind policy;
- certificate expiry metadata without certificate or hostname disclosure;
- known exceptions with an explicit identifier.

The audit must not:

- modify firewall, router, Cloudflare or container state;
- print secrets, real domains, addresses, tokens or certificate contents;
- inspect application data;
- claim WAN denial based only on local configuration;
- replace external positive and negative network tests.

Exit behavior must distinguish a failed required control from an approved
documented exception.

---

# Reproducible Edge Policy

Cloudflare and Nginx Proxy Manager contain provider-managed state that cannot
remain an undocumented production-only configuration.

Sprint 009 must add placeholder-based desired-state documentation for:

- hostname exposure class and proxy mode;
- WAF managed and custom rule intent;
- rate-limiting match class, threshold evidence and action;
- response-header ownership;
- TLS and HSTS policy;
- Nginx Proxy Manager management boundary;
- router and host-firewall intent;
- exceptions, validation and rollback.

Real zone IDs, account IDs, rule IDs, domains, addresses and API tokens remain
private. Terraform, provider API automation and broader Infrastructure as Code
are not introduced by this Sprint. A future automation enhancement may consume
the desired-state policy after its operational cost is justified.

Manual dashboard configuration is a controlled implementation mechanism, not
the source of truth. Every retained manual setting must map to repository
policy and validation evidence.

---

# Incident And Maintenance Procedures

Document concise procedures for:

- disabling a WAF or rate-limit rule that blocks legitimate traffic;
- restoring Nginx Proxy Manager administrative access;
- responding to an unexpected public listener;
- revoking and replacing the Cloudflare DNS API token;
- handling certificate expiry or failed renewal;
- isolating a compromised published application without stopping unrelated
  platform services;
- preserving sanitized logs and timestamps for diagnosis;
- returning to the last validated edge policy.

Procedures must use the Operation Layer where applicable and must not require
deleting persistent application data.

---

# Repository Impact

Implementation is expected to add:

```text
docs/security/
├── EDGE_POLICY.md
├── INCIDENT_RESPONSE.md
└── VALIDATION.md

operation/
└── security-audit.sh
```

Implementation is expected to update:

```text
services/nginx-proxy-manager/
├── .env.example
├── README.md
└── compose.yaml

services/cloudflare-ddns/README.md
operation/lib.sh
README.md
ROADMAP.md
CHANGELOG.md
```

The exact file set may be narrowed during implementation. This planning change
adds none of those runtime or operational files.

---

# Implementation Plan

## Phase 1 — Baseline And Entitlement Discovery

1. Freeze edge, proxy and firewall changes.
2. Capture the sanitized exposure inventory.
3. Record Cloudflare zone plan and available WAF/rate-limit features.
4. Classify every public record as proxied or DNS-only.
5. Inventory Nginx Proxy Manager routes, streams, certificates and listeners.
6. Confirm router, host firewall and LAN management rules.
7. Record normal application workflows and representative request rates.

## Phase 2 — Management And Origin Boundary

1. Protect and test Nginx Proxy Manager administration access.
2. Confirm only approved WAN forwards exist.
3. Decide the proxied versus mixed-origin policy.
4. Remove or document unexpected listeners.
5. Validate recovery access before retaining restrictions.

## Phase 3 — Edge Controls

1. Enable the entitlement-appropriate managed WAF baseline.
2. Observe Security Events and tune application-specific exceptions.
3. Implement the highest-value narrow rate-limit rule.
4. Add safe shared response headers with one documented owner.
5. Stage HSTS with a limited reversible policy where requirements are met.
6. Validate all published application workflows after each control.

## Phase 4 — Runtime Hardening And Audit

1. Review image, privilege, mount, secret and network posture for every service.
2. Apply only compatible Compose hardening changes.
3. Implement the read-only security audit command.
4. Validate known exceptions and failure exit behavior.
5. Document incident and maintenance procedures.

## Phase 5 — Zero Trust Decision And Closure

1. Complete the client and protocol compatibility matrix.
2. Record the Zero Trust recommendation without deploying new connectivity.
3. Repeat public, LAN, container and external negative tests.
4. Exercise WAF, rate-limit and management-access rollback.
5. Record sanitized evidence and close the Sprint.

---

# Validation Plan

## Static Validation

- All Compose files render with placeholder-only examples.
- Shell scripts pass `bash -n` and ShellCheck when available.
- Only documented services declare host ports or host networking.
- No Docker socket or privileged mode exists.
- Edge-policy documentation contains no real environment value.
- Every exception maps to an owner, reason, validation and review trigger.
- Desired state matches the active roadmap and service documentation.

## Public Path Validation

- Every approved public hostname redirects HTTP to HTTPS.
- Certificate chain, hostname and expiry are valid.
- Proxied hostnames demonstrably traverse Cloudflare.
- DNS-only hostnames are not credited with Cloudflare WAF protection.
- Direct application container ports are unreachable externally.
- Unknown hostnames do not route to an application default backend.
- Direct-origin behavior matches the approved mixed or proxied-only decision.

## WAF And Rate-Limit Validation

- A controlled synthetic request triggers the expected WAF action.
- Normal browser login and logout remain functional.
- Nextcloud browser, desktop/mobile sync, WebDAV and representative transfer
  workflows remain functional.
- Paperless login, upload, consumption status and document viewing work.
- Jellyfin login, navigation, range requests, WebSockets and playback work.
- Rate-limit threshold, action and recovery period match the documented rule.
- Approved clients behind a representative NAT are not unintentionally denied.
- Rollback restores normal behavior.

## Header And TLS Validation

- Intended headers appear once with the approved value.
- CSP or framing changes, if any, are application-specific and tested.
- HSTS applies only to explicitly approved hostname scope.
- HTTPS remains available throughout the selected HSTS `max-age` commitment.
- Certificate renewal and local recovery paths remain functional.

## Management And LAN Validation

- Nginx Proxy Manager administration works from approved management networks.
- Port `81` is denied from external, guest, visitor and untrusted IoT sources.
- Homebridge remains reachable only from approved local networks.
- HomeKit discovery, cameras and representative automations remain functional.
- No other service moved to host networking.

## Runtime Audit Validation

- The audit reports the expected Nginx Proxy Manager public gateway ports.
- The audit reports Homebridge as an approved host-network exception.
- An injected disposable invalid definition produces a non-zero result.
- Sanitized output contains no real address, domain, token or credential.
- Container state remains unchanged before and after the audit.

---

# Risks

| Risk | Impact | Mitigation |
|---|---|---|
| WAF false positive | Upload, sync, API or playback failure | Stage rules, inspect events, validate workflows and retain rollback |
| Blanket rate limit | NAT users or background clients are blocked | Scope narrowly and measure normal behavior first |
| Port `81` remains broadly reachable | Administrative compromise | Bind or firewall to approved management networks and test denial |
| Cloudflare protection is assumed for DNS-only traffic | Direct origin bypass | Inventory proxy mode and document control path per hostname |
| Cloudflare-only origin allowlist blocks DNS-only service | Public outage | Decide mixed-origin policy before firewall changes |
| HSTS is enabled too broadly | Hostnames become inaccessible | Short staged `max-age`; exclude subdomains and preload initially |
| Global CSP breaks applications | UI, workers, media or WebSockets fail | Keep CSP application-specific and evidence-driven |
| Manual edge configuration drifts | Production becomes undocumented source of truth | Maintain desired-state policy and repeatable audit evidence |
| Security audit leaks environment data | Infrastructure information exposure | Emit classifications and sanitized counts only |
| Zero Trust adds incompatible authentication | Native clients and recovery paths fail | Evaluation only; require bounded future PoC |
| Hardening changes runtime behavior | Service outage | One reversible control per change with workflow validation |
| Security work expands into observability platform | Sprint delay and new operational burden | Exclude centralized logging, SIEM and monitoring deployment |

---

# Explicit Non-Goals

- Cloudflare Tunnel deployment.
- Cloudflare One Client or WARP deployment.
- Public Nginx Proxy Manager administration.
- Identity-provider or SSO deployment.
- Replacing Nginx Proxy Manager.
- A second reverse proxy, API gateway or firewall appliance.
- VPN deployment or replacement.
- Centralized logging, SIEM, IDS or IPS platform.
- General monitoring or alerting platform.
- Automated vulnerability-scanning service.
- Automatic image or application updates.
- Terraform or broad Cloudflare API automation.
- Application major-version upgrades.
- Network-wide VLAN redesign.
- Moving services to host networking.
- Homebridge topology or plugin redesign.
- Backup automation, which belongs to Sprint 010.
- Identity Platform implementation, which belongs to Sprint 011.

---

# Acceptance Criteria

Sprint 009 is complete only when:

- every service and listener has a documented exposure class;
- only approved public gateway ports are reachable from WAN;
- Nginx Proxy Manager administration is restricted to approved management
  sources and denied from unapproved and external networks;
- Cloudflare proxy mode and effective security path are recorded per public
  service without committing real hostnames;
- the entitlement-appropriate WAF baseline is enabled and validated;
- a narrowly scoped rate-limit rule is validated without disrupting approved
  clients;
- security-header ownership and values are documented and tested;
- HSTS is either safely staged or explicitly deferred with evidence;
- public browser, synchronization, upload, API, WebSocket and streaming
  workflows remain operational;
- Homebridge remains LAN-only and is the sole host-networking exception;
- MariaDB, Valkey and application container ports remain non-public;
- no privileged container or Docker socket mount exists;
- container and secret posture has a documented review result;
- the read-only security audit executes through the Operation Layer and emits
  sanitized actionable results;
- WAF, rate-limit and management-boundary rollback procedures succeed;
- the Zero Trust evaluation produces an explicit recommendation without
  creating a new public route or dependency;
- incident and maintenance procedures are documented;
- no secret or environment-specific value exists in Git;
- all applicable static, runtime, LAN and external negative tests pass.

---

# Definition of Done

Sprint 009 is done when HomeLab07 has a documented and validated exposure
model, its public edge and administrative interfaces enforce approved
boundaries, and operators can detect security drift through a reproducible,
read-only workflow.

The platform must remain compatible, recoverable and simpler to audit after
hardening. Controls that cannot be validated safely must be documented as
deferred decisions rather than represented as active protection.

---

# Engineering Principles

Sprint 009 introduces no new application or shared data service.

Security controls follow actual traffic paths and demonstrated risks. A
provider feature is not a platform control until it is configured, owned,
tested and recoverable.

Application compatibility and recovery access are part of security. A control
that creates an unexplained outage is not accepted hardening.

The repository records desired state and validation procedures while secrets,
provider identifiers and environment-specific values remain private.

Manual configuration is temporary operational execution, not architectural
truth. Retained settings must remain reviewable from repository documentation.

---

# Completion Notes

This section will be completed after implementation.

It must summarize:

- final exposure inventory and retained exceptions;
- Nginx Proxy Manager administration boundary;
- origin-access decision for proxied and DNS-only services;
- WAF entitlement, ruleset and compatibility results;
- rate-limit target, threshold evidence and false-positive validation;
- security headers and HSTS decision;
- public application regression results;
- container and secret hardening changes;
- security-audit implementation and findings;
- Zero Trust recommendation;
- negative network and direct-origin tests;
- rollback and incident-procedure validation;
- deferred work and review triggers.

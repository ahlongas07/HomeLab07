# Identity Platform Research — Authentik Candidate

**Status:** Deferred — retained as candidate research for Sprint 010

**Classification:** Platform Capability

**Phase:** Phase 3 — Platform Operations

**Primary Technology Under Evaluation:** Authentik

**First Planned Consumer:** Nextcloud

**Last Reviewed:** 2026-07-22

---

# Objective

Design a reusable identity platform for HomeLab07 using Authentik as the
candidate identity provider.

The identity platform must provide one central authentication authority that
applications consume through standard protocols. Nextcloud is the first
planned consumer, but neither the deployment nor its configuration may make
identity a Nextcloud-owned capability.

This research produces an implementation-ready Authentik candidate plan only. It does not deploy
Authentik, PostgreSQL, an identity integration, or production SSO. Runtime
implementation and evidence belong to a future PoC. The final Sprint 010
technology decision must compare this design with the capabilities then
available in Authelia and Keycloak.

---

# Decision Context

HomeLab07 already provides reusable capabilities for:

- container execution through Docker Compose;
- internal and proxy networking;
- relational storage through MariaDB;
- transient state through Valkey;
- HTTPS termination through Nginx Proxy Manager;
- public DNS updates through Cloudflare Dynamic DNS;
- environment-specific configuration through `HomeLab07.private/`;
- NAS-backed persistence through Rockstor;
- lifecycle management through the operation layer.

POC-001 established Nextcloud as the active collaboration service and a
consumer of those shared capabilities. Identity must follow the same model:

```text
Applications consume Identity.
Applications do not own Identity.
```

Authentik is evaluated because it provides OAuth2/OpenID Connect, SAML and
other provider types from one platform. Its documented Docker Compose model is
appropriate for test and small production deployments, matching HomeLab07's
single-host architecture.

## Sprint Deferral

Identity Platform is deferred to Sprint 010 so that Paperless-ngx, Media
Platform, Platform Operations and Backup & Recovery can first demonstrate the
platform's actual authentication requirements. This document is retained on
the `identity` branch as Authentik-specific research; it is not an approved
technology decision or active implementation plan.

---

# Research Findings

## Authentik Deployment Model

The official container architecture has three required runtime roles:

- **server:** handles the web interface, API, authentication flows, protocol
  endpoints, static assets and the embedded outpost;
- **worker:** executes background tasks, event notifications and email work;
- **PostgreSQL:** stores Authentik configuration and application state.

The server and worker use the same Authentik image with different commands.
PostgreSQL is not an optional cache or convenience dependency. Authentik uses
it for application data, configuration, sessions and background-task
coordination.

Official references:

- [Authentik Docker Compose installation](https://docs.goauthentik.io/install-config/install/docker-compose/)
- [Authentik architecture](https://docs.goauthentik.io/core/architecture)
- [Authentik configuration](https://docs.goauthentik.io/install-config/configuration/)

## Official Containers And Version Selection

The candidate application image for the future PoC is:

```text
ghcr.io/goauthentik/server:2026.5.4
```

The server and worker must use the same exact tag and digest. Version 2026.5.4
is the latest documented stable patch reviewed on 2026-07-21. The future PoC
must revalidate the supported stable patch and record its multi-architecture
digest immediately before implementation.

`latest`, beta, release candidate and rolling tags are prohibited.

The official documentation currently supports PostgreSQL 14 through 18. The
candidate HomeLab07 baseline is the PostgreSQL 17 release line because it is
within the supported range and has been used by recent upstream deployment
defaults. The exact patch tag and digest must be selected and pinned during PoC
entry validation rather than guessed in this planning document.

Official references:

- [Authentik 2026.5 release notes](https://docs.goauthentik.io/releases/2026.5/)
- [Authentik releases](https://docs.goauthentik.io/releases)
- [Authentik security support policy](https://docs.goauthentik.io/security/policy)

## MariaDB Decision

MariaDB cannot be reused for Authentik.

Authentik explicitly requires PostgreSQL. Attempting to force Authentik onto
MariaDB would be unsupported and would violate reliability, reproducibility
and upgrade guidance.

The new PostgreSQL dependency is therefore technically required. To preserve
the HomeLab07 shared-service architecture, PostgreSQL must be introduced as an
application-agnostic platform capability rather than hidden inside the
Authentik service definition.

MariaDB remains unchanged and continues serving applications that support it.
PostgreSQL does not replace MariaDB platform-wide.

## Valkey Decision

Authentik must not consume shared Valkey.

Authentik removed Redis entirely in release 2025.10. Caching, task
coordination, embedded-outpost sessions and WebSockets now use PostgreSQL.
Redis-related settings were removed.

Consequences for HomeLab07:

- do not attach Authentik to Valkey;
- do not deploy a dedicated Redis or Valkey instance;
- do not add Authentik-specific state to shared Valkey;
- keep Valkey unchanged for Nextcloud and future compatible consumers;
- include PostgreSQL connection capacity in PoC validation because Authentik
  expects more database connections after Redis removal.

Official reference:

- [Authentik 2025.10 Redis removal](https://docs.goauthentik.io/releases/2025.10)

## Resource Baseline

The official Compose installation requires at least:

- two CPU cores;
- 2 GB RAM;
- Docker Compose v2.

These are entry requirements, not HomeLab07 sizing conclusions. The future PoC
must observe actual server, worker and PostgreSQL consumption alongside the
existing platform before production approval.

---

# Protocol Decision

## OpenID Connect

OpenID Connect is the preferred HomeLab07 application integration protocol.

OIDC adds an identity layer to OAuth2 and provides standard ID tokens, claims,
discovery metadata, user information and signed-token verification. Authentik
supports OIDC as an OpenID Provider and exposes per-application discovery and
JWKS endpoints.

The baseline interactive flow is:

```text
OIDC Authorization Code
Confidential client
Strict redirect URIs
Signed ID tokens
Scopes: openid profile email
Stable subject: Authentik user UUID
```

PKCE should be enabled when the consumer supports it. Implicit, password and
hybrid grants are not approved for the baseline. Refresh tokens and
`offline_access` are enabled only when a consumer has a documented session or
token-refresh requirement.

Each consumer receives its own Authentik application/provider pair, client ID,
client secret, strict redirect URI set and authorization policy. Credentials
must never be shared between applications.

Official reference:

- [Authentik OAuth2/OIDC provider](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/)

## OAuth2

OAuth2 is an authorization framework, not by itself a complete authentication
protocol. HomeLab07 must not infer user identity from a generic access token
when the consumer supports OIDC.

OAuth2 remains useful for future machine-to-machine or delegated API access,
but those uses require separate clients, scopes and threat analysis. They are
outside this Sprint.

## SAML

Authentik and Nextcloud support SAML. SAML remains an approved fallback for a
consumer that lacks a reliable OIDC implementation or has a documented SAML
requirement.

SAML is not preferred for the HomeLab07 baseline because it introduces more
XML metadata, signing-certificate and assertion-mapping operations without a
demonstrated benefit for Nextcloud or the evaluated future services. Using
OIDC consistently reduces per-application onboarding work.

## Preferred Protocol

| Protocol | Identity capability | HomeLab07 decision | Rationale |
|---|---|---|---|
| OIDC Authorization Code | Authentication and claims over OAuth2 | Preferred | Discovery, signed tokens, broad consumer support and simpler onboarding |
| OAuth2 without OIDC | Delegated authorization | Not an authentication baseline | Does not standardize identity by itself |
| SAML 2.0 | Federated authentication | Supported fallback | Useful for SAML-only consumers but operationally heavier |
| LDAP | Directory protocol | Out of scope | Requires an outpost and is explicitly excluded from this Sprint |

---

# Architecture

## Logical Architecture

```text
Internet
    │
    ▼
Cloudflare Dynamic DNS
    │
    ▼
Nginx Proxy Manager
    │
    ▼
Authentik Server
    ├── Authentik Worker
    ├── Shared PostgreSQL Platform
    └── NAS-backed Authentik media
             │
             ▼
      OIDC Authorization Code
             │
      ┌──────┴──────────────┐
      │                     │
      ▼                     ▼
  Nextcloud          Future Consumers
                          ├── Jellyfin
                          ├── Gitea
                          ├── Grafana
                          ├── Paperless-ngx
                          └── Immich
```

## Ownership Boundaries

Authentik owns:

- identities created directly in Authentik;
- groups and application-access policy;
- authentication flows;
- provider configuration;
- OIDC signing keys, grants and sessions;
- identity audit events.

PostgreSQL owns durable relational storage as a platform capability. The
Authentik database and role remain application-specific state inside that
shared service.

Consumers own:

- their local application accounts and authorization state;
- client-side OIDC configuration;
- mapping Authentik claims to application roles;
- their local break-glass administrative access;
- application sessions after token exchange.

Nginx Proxy Manager owns TLS termination and publication. Cloudflare Dynamic
DNS owns the public record update. Neither owns authentication policy.

## Availability Boundary

Identity is a dependency for new federated logins. An Authentik outage must not
corrupt consumer data, but it can prevent new OIDC sessions and token refresh.

The first PoC must preserve local break-glass access in both Authentik and
Nextcloud. Automatic redirection and disabling local login are prohibited until
recovery and bypass procedures are validated.

---

# Technology Stack

| Capability | Planned selection | Decision |
|---|---|---|
| Identity server | `ghcr.io/goauthentik/server:2026.5.4` | Candidate pin; revalidate tag and digest at PoC entry |
| Background processing | Same Authentik image with worker command | Required official architecture |
| Relational database | Shared PostgreSQL 17 release line | New required platform capability; exact patch pin pending PoC entry |
| In-memory service | None | Authentik no longer uses Redis/Valkey |
| Protocol | OIDC Authorization Code | Preferred reusable application integration |
| Reverse proxy | Existing Nginx Proxy Manager | Reuse shared publication capability |
| DNS | Existing Cloudflare Dynamic DNS | Reuse shared DNS capability |
| Persistence | Rockstor-backed PostgreSQL and Authentik data roots | Reuse Storage First architecture |
| Operations | Existing HomeLab07 operation layer | Required public lifecycle interface |

Not approved:

- `latest` or prerelease images;
- MariaDB for Authentik;
- dedicated Redis or Valkey;
- direct host ports for Authentik or PostgreSQL;
- Kubernetes or multi-node deployment;
- external managed databases;
- Docker socket access;
- a separate proxy, LDAP or RADIUS outpost;
- disabling all local administrator access;
- application-shared client secrets.

---

# Repository Impact

## Source Control Strategy

Implementation must be developed in a dedicated branch created from the
current `main` baseline:

```text
identity
```

PostgreSQL does not require a separate feature branch. Although it is a new
shared platform capability, its introduction is a technically required and
reviewable part of the Identity Platform scope. Keeping PostgreSQL and
Authentik in the same Sprint branch preserves end-to-end validation while
separate logical commits keep the dependency independently reviewable.

The planned commit boundaries are:

1. identity platform planning and roadmap reconciliation;
2. shared PostgreSQL platform service and operations integration;
3. Authentik server and worker deployment;
4. Nextcloud OIDC consumer integration;
5. validation evidence and final Sprint documentation.

The branch must not be merged into `main` until the future PoC satisfies its
acceptance criteria. `main` remains the stable implementation baseline, and
the repository owner retains responsibility for commits, pushes, merges, tags
and releases.

The future PoC is expected to add:

```text
services/
├── postgresql/
│   ├── .env.example
│   ├── README.md
│   └── compose.yaml
└── authentik/
    ├── .env.example
    ├── README.md
    ├── IMPLEMENTATION_NOTES.md
    ├── compose.yaml
    └── blueprints/
        └── homelab07-nextcloud.yaml

operation/
├── authentik-db-create.sh
├── authentik-db-drop.sh
└── authentik-storage-check.sh
```

The future PoC is expected to update:

```text
operation/start.sh
operation/stop.sh
operation/status.sh
README.md
ROADMAP.md
CHANGELOG.md
services/nextcloud/README.md
```

This planning Sprint creates none of those implementation files.

## Reuse Map

| Existing capability | Decision | Planned use |
|---|---|---|
| MariaDB | Preserve, not consumed | Unsupported by Authentik |
| Valkey | Preserve, not consumed | Removed from current Authentik architecture |
| `homelab07-internal` | Reuse | Authentik server/worker to PostgreSQL; consumer back-channel connectivity |
| `homelab07-proxy` | Reuse | Nginx Proxy Manager to Authentik server |
| Operation layer | Extend | PostgreSQL and Authentik lifecycle/status integration |
| `HomeLab07.private` | Reuse | Database credentials, secret key, domains and client secrets |
| Nginx Proxy Manager | Reuse | HTTPS termination and WebSocket-capable proxying |
| Cloudflare Dynamic DNS | Reuse | Dedicated Authentik hostname record |
| Rockstor | Reuse | PostgreSQL database files and Authentik media |

---

# Persistent Storage

## PostgreSQL

PostgreSQL is the primary persistence boundary and must use NAS-backed storage:

```text
${HOMELAB07_DATA_ROOT}/postgresql -> /var/lib/postgresql/data
```

The final internal path must match the pinned official PostgreSQL image. The
PoC must not silently change `PGDATA` or mount a parent directory that obscures
the actual database boundary.

PostgreSQL is shared infrastructure. Its service definition initializes only
the PostgreSQL platform administrator. Authentik database, role, password and
minimum privileges are provisioned explicitly by Authentik-owned operation
commands.

## Authentik Media

Authentik uses `/data` for uploaded application icons, flow backgrounds, files
and CSV reports. The planned mount is:

```text
${AUTHENTIK_DATA_ROOT}/data -> /data
```

Server and worker mounts must follow the pinned upstream Compose requirements.
The PoC must validate actual UID/GID ownership and whether both roles require
the same mount.

No filesystem certificate persistence is planned because TLS terminates at
Nginx Proxy Manager and Authentik stores imported certificates in PostgreSQL.
No custom template mount is planned because UI customization is not required.

## Storage Principles

- PostgreSQL and `/data` must have distinct, documented backup boundaries.
- Database files must never be copied live as the only backup method.
- Identity data must not share a directory with Nextcloud state.
- Runtime containers must be replaceable without losing identity state.
- Environment-specific host paths belong only in `HomeLab07.private/`.

---

# Docker Architecture

## Planned Services

```text
homelab07-postgresql
homelab07-authentik-server
homelab07-authentik-worker
```

### PostgreSQL

- uses a pinned PostgreSQL 17 patch image and digest;
- joins only `homelab07-internal`;
- publishes no host ports;
- persists `/var/lib/postgresql/data` on Rockstor;
- exposes a native readiness healthcheck;
- contains no Authentik-specific configuration in its Compose definition.

### Authentik Server

- uses the exact pinned Authentik image;
- runs the server role;
- joins `homelab07-internal` and `homelab07-proxy`;
- publishes no host ports;
- receives PostgreSQL and Authentik secrets through private configuration;
- mounts only required persistent and blueprint paths;
- exposes a healthcheck validated against the pinned image.

### Authentik Worker

- uses the same exact image and digest as the server;
- runs the worker role;
- joins only `homelab07-internal`;
- receives the same core database and secret-key configuration;
- publishes no ports;
- has no Docker socket mount;
- mounts only paths required by worker behavior and blueprints.

## Docker Socket Decision

The official Compose example mounts `/var/run/docker.sock` into the worker for
automatic outpost management. HomeLab07 does not require an external outpost
for OIDC or SAML in this Sprint.

The mount is prohibited because it grants high-impact control over the Docker
host without providing baseline identity value. If a future Sprint requires an
outpost, it must separately evaluate manual deployment or a restricted Docker
socket proxy.

## Time Configuration

Authentik performs internal operations in UTC. The containers must not mount
host `/etc/timezone` or `/etc/localtime`; upstream warns these mounts can break
OAuth and SAML behavior. User-facing localization remains an application
function.

---

# Reverse Proxy Integration

Authentik receives a dedicated public hostname stored only in private
configuration.

Traffic path:

```text
Internet
    ↓
Cloudflare
    ↓
Nginx Proxy Manager
    ↓ HTTP on homelab07-proxy
homelab07-authentik-server:9000
```

Planned Nginx Proxy Manager settings:

| Setting | Planned value |
|---|---|
| Domain | `<authentik-public-domain>` |
| Scheme | `http` |
| Forward host | `homelab07-authentik-server` |
| Forward port | `9000` |
| WebSocket support | enabled |
| Force SSL | enabled after certificate issuance |
| HTTP/2 | enabled |
| HSTS | enabled only after HTTPS and recovery validation |

The proxy must preserve:

- `Host`;
- `X-Forwarded-Proto`;
- `X-Forwarded-For`;
- `Upgrade` and `Connection` for WebSockets.

`AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS` must contain the exact private proxy
network CIDR from target-environment configuration. Broad defaults must not be
accepted without validation.

Official reference:

- [Authentik reverse proxy requirements](https://docs.goauthentik.io/install-config/reverse-proxy/)

## Cloudflare

Cloudflare Dynamic DNS remains the DNS update mechanism. The implementation
must add or select a dedicated record through private configuration without
placing the real hostname in Git.

Initial certificate validation should use the existing HomeLab07 publication
procedure. Cloudflare proxying, if enabled, must preserve WebSockets and
original HTTPS headers.

---

# Database Design

## Shared PostgreSQL Platform

PostgreSQL is introduced as a reusable platform capability because it is a
hard Authentik requirement and is likely reusable by future services. It must
remain application agnostic.

The PostgreSQL service must not bootstrap an Authentik schema or embed
Authentik credentials. Application provisioning belongs to Authentik-specific
operation commands.

## Authentik Database

Candidate private identifiers:

```dotenv
AUTHENTIK_POSTGRESQL__HOST=homelab07-postgresql
AUTHENTIK_POSTGRESQL__PORT=5432
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__PASSWORD=replace-with-a-strong-password
```

The database must:

- use UTF-8 encoding;
- be owned by or grant minimum required privileges to the Authentik role;
- accept connections only over `homelab07-internal`;
- reject empty or malformed private values;
- be created idempotently;
- be dropped only through an explicit destructive command requiring exact
  confirmation;
- never print credentials;
- remain independent from Nextcloud and Nginx Proxy Manager databases.

The final locale, encoding and owner commands must be validated against the
pinned PostgreSQL image before provisioning.

## Connection Capacity

Because modern Authentik coordinates sessions and tasks through PostgreSQL and
no longer uses Redis, the PoC must measure active and peak connections from
both server and worker. Connection limits must be based on observed behavior,
not copied from a multi-node example.

---

# Private Configuration

Expected private files:

```text
HomeLab07.private/env/postgresql.env
HomeLab07.private/env/authentik.env
HomeLab07.private/env/nextcloud.env
```

Candidate PostgreSQL private values:

```dotenv
HOMELAB07_DATA_ROOT=/path/to/homelab07-data
POSTGRES_ADMIN_USER=replace-with-platform-admin
POSTGRES_ADMIN_PASSWORD=replace-with-a-strong-password
```

Candidate Authentik private values:

```dotenv
AUTHENTIK_DATA_ROOT=/path/to/homelab07-authentik
AUTHENTIK_SECRET_KEY=replace-with-a-long-random-secret
AUTHENTIK_POSTGRESQL__HOST=homelab07-postgresql
AUTHENTIK_POSTGRESQL__PORT=5432
AUTHENTIK_POSTGRESQL__NAME=authentik
AUTHENTIK_POSTGRESQL__USER=authentik
AUTHENTIK_POSTGRESQL__PASSWORD=replace-with-a-strong-password
AUTHENTIK_PUBLIC_DOMAIN=auth.example.com
AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS=replace-with-proxy-network-cidr
AUTHENTIK_NEXTCLOUD_CLIENT_ID=replace-with-client-id
AUTHENTIK_NEXTCLOUD_CLIENT_SECRET=replace-with-client-secret
```

`AUTHENTIK_PUBLIC_DOMAIN` is a proposed HomeLab07 publication/blueprint input,
not an upstream Authentik configuration key. The implementation must pass only
documented upstream keys to the containers and use HomeLab07 helper values only
where the Compose or blueprint definition explicitly consumes them.

The Authentik secret key, PostgreSQL credentials, bootstrap credential hash,
OIDC client secrets, real URLs and CIDRs are secrets or environment-specific
values and must not enter Git.

## Bootstrap Administrator

The future PoC should use a pre-hashed `AUTHENTIK_BOOTSTRAP_PASSWORD_HASH`
rather than plaintext bootstrap password configuration. It is consumed only on
first startup and must be stored in private configuration with correct Compose
escaping.

The bootstrap administrator remains the local break-glass account. It must not
be used as a normal application identity.

Official reference:

- [Authentik automated install](https://docs.goauthentik.io/install-config/automated-install)

## Blueprints

The future PoC should evaluate a minimal version-controlled blueprint for the
Nextcloud application/provider pair and reusable claim mappings. Blueprint
secrets must resolve from environment variables using Authentik's `!Env` tag;
they must never be committed.

The blueprint must not create production users, MFA stages, LDAP sources or
future application integrations. If blueprint reconciliation proves less
predictable than API-driven provisioning, the PoC must record that finding and
retain an auditable, documented provisioning sequence.

Official reference:

- [Authentik blueprint YAML tags](https://docs.goauthentik.io/customize/blueprints/v1/tags)

---

# Network Integration

| Component | Internal network | Proxy network | Host ports |
|---|---:|---:|---:|
| PostgreSQL | yes | no | none |
| Authentik server | yes | yes | none |
| Authentik worker | yes | no | none |
| Nextcloud | yes | yes | none |
| Nginx Proxy Manager | as currently defined | yes | existing gateway ports only |

Required network flows:

```text
Authentik server ──TCP 5432──> PostgreSQL
Authentik worker ──TCP 5432──> PostgreSQL
Nginx Proxy Manager ──TCP 9000──> Authentik server
Nextcloud ──HTTPS──> Authentik discovery/token/JWKS endpoints
Browser ──HTTPS──> Authentik authorization endpoint
```

PostgreSQL must not join `homelab07-proxy`. The worker must not be directly
reachable from the proxy. Nextcloud and Authentik may communicate through the
internal network where the selected integration supports an internal endpoint,
but the OIDC issuer must remain the stable public HTTPS URL seen by clients.

---

# Nextcloud Integration Design

## Provider Model

Nextcloud receives one dedicated confidential OAuth2/OIDC provider in
Authentik.

Planned settings:

```text
Application: Nextcloud
Provider type: OAuth2/OIDC
Client type: Confidential
Flow: Authorization Code
Redirect URI: https://<nextcloud-domain>/apps/user_oidc/code
Issuer mode: Per-provider
Subject mode: Authentik user UUID
Scopes: openid profile email
Signing key: Explicit Authentik signing certificate
```

Redirect URIs must be strict literal values. Regex or first-use learning is not
approved for the baseline.

Nextcloud uses its OpenID Connect user backend and the per-provider discovery
document:

```text
https://<authentik-domain>/application/o/<nextcloud-slug>/.well-known/openid-configuration
```

Official reference:

- [Authentik Nextcloud integration](https://docs.goauthentik.io/integrations/services/nextcloud/)

## Identity Mapping

The OIDC `sub` claim must be based on the immutable Authentik user UUID.
Mutable usernames are not approved as the primary subject.

Baseline claims:

- `sub` for stable identity;
- `preferred_username` for display and optional local mapping;
- `name` for display name;
- `email` for contact identity;
- `groups` only after group-provisioning behavior is tested.

`email_verified` must not be forced to `true` without a real email-verification
process. Current Authentik defaults it to `false` for security reasons.

This Sprint does not migrate or merge existing Nextcloud users. The first PoC
must use a synthetic identity and determine whether an existing local account
can be linked safely without changing its storage identity.

## Encryption Constraint

Nextcloud server-side and end-to-end encryption remain disabled. Authentik's
Nextcloud guidance warns that OIDC and SAML are incompatible with Nextcloud
server-side encryption because the application does not receive the user's
cleartext password.

The future PoC must verify:

```text
encryption: enabled false
encryption app: disabled
end_to_end_encryption app: disabled or absent
```

## Lockout Prevention

The built-in Nextcloud administrator remains enabled during the PoC. The direct
login bypass URL and exact recovery procedure must be validated before any
automatic OIDC redirect is considered.

The PoC must not disable multiple user backends or regular login. Production
SSO enforcement belongs to a later approved implementation decision.

---

# Future Compatibility

The following assessment validates architectural compatibility only. It does
not approve or configure these applications.

| Consumer | Integration path | Compatibility assessment | Constraint |
|---|---|---|---|
| Nextcloud | Native/user-backend OIDC | Preferred first consumer | Preserve local admin and disabled server-side encryption |
| Gitea | Native OpenID Connect auth source | Compatible | Dedicated strict callback and client secret |
| Grafana | Generic OAuth/OIDC | Compatible | Validate signed ID tokens and role claim mapping |
| Immich | Native OIDC | Compatible | Include web and mobile redirect URIs; claims apply differently over lifecycle |
| Paperless-ngx | django-allauth OIDC | Compatible | Private JSON/client secret configuration and controlled signup/group sync |
| Jellyfin | Community OIDC plugin | Conditional | No native external auth; plugin lifecycle and client support require a separate PoC |

Evidence:

- [Gitea integration](https://docs.goauthentik.io/integrations/services/gitea/)
- [Grafana Generic OAuth](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/generic-oauth/)
- [Immich OIDC](https://docs.immich.app/administration/oauth/)
- [Paperless-ngx OIDC](https://docs.paperless-ngx.com/advanced_usage/)
- [Jellyfin integration](https://docs.goauthentik.io/integrations/services/jellyfin/)

The reusable pattern is one Authentik platform with one provider/client per
consumer. Future consumers do not require a new identity server or database.
They require only protocol-specific client configuration, strict redirects,
private credentials and claim-policy validation.

---

# Security Considerations

## Secret Management

- Keep `AUTHENTIK_SECRET_KEY`, database credentials, bootstrap hash and OIDC
  client secrets in `HomeLab07.private/`.
- Do not print secrets in scripts, Compose output, validation logs or docs.
- Use a distinct client secret for every consumer.
- Back up private configuration through the approved private backup process.
- Rotate a client secret through a documented consumer-by-consumer procedure.

## Network Security

- Publish only Nginx Proxy Manager gateway ports.
- Keep PostgreSQL and worker internal-only.
- Trust only the actual proxy-network CIDR for forwarded headers.
- Require HTTPS for all browser-facing OIDC endpoints and callbacks.
- Enable WebSocket support through Nginx Proxy Manager.
- Never mount the Docker socket for the baseline deployment.

## Protocol Security

- Use Authorization Code, not Implicit or Password grants.
- Use confidential clients where server-side consumers can protect secrets.
- Require strict redirect URIs.
- Verify ID-token signatures and issuer/audience in each consumer.
- Prefer per-provider issuer mode.
- Use immutable UUID-based subjects.
- Request only necessary scopes.
- Do not assert verified email without verification evidence.
- Treat logout and access revocation as consumer-specific behaviors that require
  testing; an IdP logout does not automatically prove consumer-session logout.

## Administrative Security

- Retain separate local break-glass accounts for Authentik and the first
  consumer.
- Do not use the Authentik bootstrap administrator for normal use.
- Record all administrative provider and mapping changes.
- Do not grant administrator roles solely from an unvalidated group claim.
- Keep MFA planning outside this Sprint; absence of MFA must remain an explicit
  risk rather than an undocumented assumption.

## Supply Chain And Upgrade Security

- Pin exact image tags and digests.
- Review Authentik and PostgreSQL release/security notes before every update.
- Keep server and worker on the exact same Authentik version.
- Upgrade Authentik sequentially across release trains; skipping major releases
  is prohibited.
- Never downgrade Authentik in place. Restore the pre-upgrade database and
  filesystem state with the prior image instead.

Official reference:

- [Authentik upgrade guidance](https://docs.goauthentik.io/install-config/upgrade)

---

# Recovery Strategy

## Recovery Objectives

Recovery must restore:

- users and groups;
- flows, policies and provider configuration;
- OIDC client records and signing material;
- sessions and identity application state as supported by the restored point;
- uploaded media and reports;
- the same pinned server/worker version;
- private secrets required to decrypt or validate stored application state.

## Recovery Order

1. Keep Authentik server and worker stopped.
2. Restore the same pinned PostgreSQL major version.
3. Restore the Authentik PostgreSQL database from a verified logical backup.
4. Restore `/data` from the same consistent recovery point.
5. Restore private configuration through its separate approved process.
6. Start PostgreSQL and validate readiness.
7. Start Authentik server and worker using the matching pinned image.
8. Validate migrations, tasks, provider discovery, JWKS and administrative
   login.
9. Validate local break-glass login and one synthetic OIDC consumer.
10. Re-enable public traffic only after successful validation.

## Identity Outage Behavior

The PoC must document what remains possible when Authentik is unavailable:

- existing Nextcloud sessions may continue until application expiry;
- new OIDC login and token refresh fail;
- local Nextcloud break-glass access must remain available;
- Authentik local recovery access must work after database restore;
- consumer data remains owned by the consumer and must not be modified during
  identity recovery.

---

# Backup Boundary

A complete Authentik backup includes:

- a PostgreSQL-native logical backup of the Authentik database;
- `${AUTHENTIK_DATA_ROOT}/data`;
- the pinned Compose and blueprint definitions;
- image tag and digest records;
- private configuration through the approved private backup process;
- signing-key and certificate state stored in the database;
- any later custom template, certificate or blueprint filesystem mounts if
  introduced.

The PostgreSQL database is the most important backup component. It contains
users, policies, flows and configuration. Copying only `/data` does not produce
a usable identity restore.

A raw live copy of `/var/lib/postgresql/data` is not the primary backup method.
Use `pg_dump`/`pg_restore` or another PostgreSQL-native consistent mechanism.
Backup automation remains outside this Sprint.

Official reference:

- [Authentik backup and restore](https://docs.goauthentik.io/sys-mgmt/ops/backup-restore)

---

# Upgrade Strategy

The future implementation must separate application and database upgrades.

## Authentik Patch Upgrade

1. Review release and security notes.
2. Record current image digests and configuration.
3. Back up PostgreSQL and `/data`.
4. Update server and worker to the same exact patch.
5. Recreate both roles through the operation layer.
6. Validate migrations, worker tasks, health and OIDC login.

## Authentik Release-Train Upgrade

Release trains must be upgraded sequentially. Do not skip supported
intermediate major/date releases. Downgrade is not supported; rollback restores
the complete pre-upgrade recovery point.

## PostgreSQL Major Upgrade

PostgreSQL major upgrades are independent maintenance operations requiring a
logical dump, downtime, new major-version data directory, restore and
validation. Changing only the image tag over an existing data directory is not
approved.

Official reference:

- [PostgreSQL Docker Compose upgrade guidance](https://docs.goauthentik.io/troubleshooting/postgres/upgrade_docker)

---

# Operation Layer Integration

The operation layer remains HomeLab07's public lifecycle interface.

Planned order:

```text
Start:
  shared networks
  → MariaDB
  → PostgreSQL
  → Valkey
  → Nginx Proxy Manager
  → Authentik server and worker
  → Nextcloud and other applications

Stop:
  applications
  → Authentik server and worker
  → Nginx Proxy Manager
  → Valkey
  → PostgreSQL
  → MariaDB
```

Expected commands:

```bash
./operation/compose.sh postgresql <compose-command>
./operation/compose.sh authentik <compose-command>
./operation/authentik-db-create.sh
./operation/authentik-db-drop.sh
./operation/authentik-storage-check.sh
```

`status.sh` must report PostgreSQL, Authentik server and Authentik worker
separately. Database provisioning remains explicit rather than a side effect of
platform start.

---

# Implementation Sequence For The Future PoC

## Phase 1 — Dependency Preparation

1. Resume the `identity` branch from the then-current stable `main` baseline.
2. Reconcile Sprint numbering in the roadmap.
3. Revalidate Authentik stable patch, image digest and PostgreSQL support.
4. Select an exact PostgreSQL 17 patch tag and digest.
5. Create dedicated NAS paths for PostgreSQL and Authentik media.
6. Create placeholder-only example configuration.
7. Implement the shared PostgreSQL service.
8. Implement Authentik-specific database create/drop commands.

## Phase 2 — Isolated Identity Deployment

1. Deploy PostgreSQL on `homelab07-internal` without host ports.
2. Provision the isolated Authentik database and role.
3. Deploy Authentik server and worker without the Docker socket.
4. Validate storage ownership, health and background tasks.
5. Validate local administrator access before publication.

## Phase 3 — Secure Publication

1. Create the private DNS record and Nginx Proxy Manager host.
2. Enable HTTPS and WebSockets.
3. Validate forwarded headers and trusted proxy CIDR.
4. Validate OIDC discovery and JWKS from browser and internal consumers.

## Phase 4 — Nextcloud Consumer PoC

1. Preserve local Nextcloud administrator access.
2. Create one Authentik application/provider pair.
3. Install and pin the approved Nextcloud OIDC backend.
4. Configure a synthetic user and strict redirect URI.
5. Validate login, logout, claims and session behavior.
6. Validate that existing local users and files remain unchanged.
7. Validate direct-login recovery after an intentional Authentik stop.

## Phase 5 — Recovery Evidence

1. Back up PostgreSQL and Authentik `/data` consistently.
2. Recreate containers and validate persistence.
3. Perform a clean restore using disposable identity data.
4. Validate signing keys, discovery and OIDC login after restore.
5. Record the decision without enabling production SSO enforcement.

---

# Validation Plan

## Static Validation

- Docker Compose resolves with example environment files.
- All images use exact stable tags and recorded digests.
- No Authentik, worker or PostgreSQL host ports are published.
- PostgreSQL and worker do not join `homelab07-proxy`.
- No Redis/Valkey settings exist in Authentik configuration.
- No Docker socket is mounted.
- No real hostname, IP, password, secret or certificate exists in Git.
- Blueprints resolve secrets from environment and contain no user data.

## Shell And Configuration Validation

```bash
bash -n operation/authentik-db-create.sh
bash -n operation/authentik-db-drop.sh
bash -n operation/authentik-storage-check.sh
bash -n operation/start.sh
bash -n operation/stop.sh
bash -n operation/status.sh
```

Validate effective Authentik configuration without printing secret values:

```bash
./operation/compose.sh authentik run --rm worker ak dump_config
```

The implementation must sanitize captured output before placing evidence in
the repository.

## Runtime Validation

- PostgreSQL becomes healthy before Authentik depends on it.
- Server and worker run the same image digest.
- Server and worker remain healthy after recreation.
- Worker tasks execute without repeated failures.
- `/data` survives recreation.
- Authentik UI and API are reachable only through Nginx Proxy Manager.
- OIDC discovery and JWKS endpoints return valid documents.
- Nginx Proxy Manager preserves required headers and WebSockets.
- Direct host-port inspection returns no Authentik or PostgreSQL mappings.
- Valkey shows no Authentik consumer connection or keys.

## OIDC Validation

- Authorization Code flow succeeds for one synthetic Nextcloud user.
- Redirect URI matching is strict.
- ID token issuer, audience, expiry and signature validate.
- `sub` remains stable across username/display-name changes.
- Only approved scopes and claims are returned.
- A user without an application binding is denied.
- Logout behavior is documented from actual evidence.
- Stopping Authentik prevents new OIDC login without corrupting Nextcloud.
- Local Nextcloud break-glass login remains available.
- Existing Nextcloud users, files and shares remain unchanged.
- Nextcloud encryption stays disabled.

## Recovery Validation

- A logical PostgreSQL backup completes and is non-empty.
- `/data` is captured from a consistent recovery point.
- A clean restore recreates users, flows, application/provider, signing keys
  and synthetic identity.
- Discovery, JWKS and Nextcloud OIDC login work after restore.
- The same pinned version is used before any upgrade test.

## Future Compatibility Validation

For each future consumer, the PoC decision record must confirm only that:

- a supported OIDC or conditional plugin path exists;
- a dedicated provider/client can be created without changing Authentik core;
- strict redirect URIs can be expressed;
- claims can be mapped without sharing client secrets.

No future consumer is deployed or configured.

---

# Risks

| Risk | Impact | Likelihood | Mitigation | Exit evidence |
|---|---|---|---|---|
| Identity becomes a single login dependency | New logins fail during outage | Medium | Local break-glass access, health checks, tested restore | Intentional outage test |
| PostgreSQL adds a second database engine | More operational maintenance | High | Shared platform service, native backup runbook, pinned upgrades | Deployment and restore evidence |
| Database loss destroys identity configuration | Complete identity-platform loss | Medium | Logical backups plus `/data` and private configuration | Clean restore succeeds |
| Client secrets enter Git or logs | Credential compromise | Medium | Private configuration, sanitized output, secret scanning | Repository scan passes |
| Docker socket grants host control | Host compromise | Medium if mounted | Do not mount it; no external outposts | Container inspection |
| Incorrect proxy headers or CIDR | Spoofed IPs, CSRF or redirect failures | Medium | Strict trusted proxy CIDR and header validation | Proxy tests and logs |
| OIDC subject mapping changes | Duplicate or orphaned consumer accounts | Medium | Immutable UUID-based `sub`; migration tests | Rename test preserves identity |
| Existing Nextcloud users are auto-linked incorrectly | Data exposure or duplicate accounts | Medium | Synthetic user first; no migration; explicit mapping decision | User and file inventory unchanged |
| IdP logout does not terminate consumer session | Revoked user retains session | Medium | Measure token/session behavior per consumer | Logout and revocation evidence |
| Email is falsely asserted verified | Account-linking vulnerability | Medium | Keep `email_verified=false` absent proof | Token claim inspection |
| Authentik patch or release breaks providers | Login outage | Medium | Pin, review notes, backup, sequential upgrades | Upgrade PoC |
| PostgreSQL connection pressure after Redis removal | Identity instability | Medium | Observe connections and set evidence-based limits | Connection metrics during load |
| Jellyfin depends on a community plugin | Upgrade fragility | High | Classify as conditional; separate integration PoC | Plugin/version compatibility record |
| Local admin is disabled too early | Administrative lockout | Medium | Keep break-glass accounts and direct login | Recovery login succeeds |
| Roadmap numbering remains inconsistent | Traceability confusion | High | Reconcile before implementation | Roadmap and Sprint IDs agree |

---

# Acceptance Criteria

This planning Sprint is complete only when:

- Authentik is classified as a shared platform capability;
- the required server, worker and PostgreSQL roles are documented;
- PostgreSQL is justified as a new shared platform dependency;
- MariaDB non-compatibility is explicit;
- current Authentik non-use of Redis/Valkey is explicit;
- OIDC Authorization Code is selected and justified over OAuth2-only and
  SAML baseline use;
- the Nextcloud provider, claims, encryption and break-glass boundaries are
  designed;
- future Gitea, Grafana, Immich, Paperless-ngx and Jellyfin compatibility is
  assessed without implementation;
- persistent storage and complete backup boundaries are defined;
- reverse proxy, DNS and Docker networks reuse existing capabilities;
- the Docker socket and unnecessary outposts are excluded;
- private configuration contains every secret and environment-specific value;
- implementation phases and repository impact are explicit;
- static, runtime, OIDC, security and recovery validation plans are complete;
- risks have mitigations and evidence requirements;
- non-goals remain excluded;
- every major recommendation traces to official documentation or a HomeLab07
  engineering principle.

Planning acceptance does not approve Authentik for production use. That
decision requires the future PoC evidence.

---

# Explicit Non-Goals

- Deploying Authentik or PostgreSQL.
- Modifying Docker Compose or operation scripts.
- Configuring MFA.
- Configuring LDAP, RADIUS, SCIM or social login.
- Deploying or managing outposts.
- Migrating users or passwords.
- Linking existing Nextcloud users.
- Enforcing production SSO.
- Disabling local application login.
- Connecting every future application.
- Implementing backup automation.
- Implementing monitoring or alerting.
- Implementing high availability.
- Performance tuning beyond defining PoC measurements.
- Replacing MariaDB or Valkey for existing consumers.

---

# Required Research Before PoC Implementation

The future PoC may begin only after completing these time-sensitive checks:

1. Confirm the latest supported stable Authentik patch and security status.
2. Record the Authentik server image digest for the target architecture.
3. Confirm the upstream Compose service commands, healthchecks and required
   mounts for that exact patch.
4. Select and record an exact supported PostgreSQL 17 patch image and digest.
5. Confirm PostgreSQL data-path, UID/GID, locale and UTF-8 initialization
   behavior on Rockstor.
6. Confirm server and worker behavior with `no-new-privileges` and other
   proposed hardening controls.
7. Confirm the pinned Nextcloud `user_oidc` version supports Nextcloud 33.
8. Confirm exact callback, direct-login and logout behavior for that version.
9. Test whether the planned Nextcloud client requires `offline_access`, PKCE or
   custom claims.
10. Confirm blueprint schema/API identifiers for the pinned Authentik version.
11. Measure target-host CPU, memory and PostgreSQL connection headroom.
12. Revalidate the Sprint 010 schedule and candidate scope in `ROADMAP.md`.

---

# Expected Decision Record

After the future PoC, HomeLab07 must answer:

> Does Authentik provide a recoverable, maintainable and reusable identity
> platform whose operational cost is justified by consistent OIDC integration
> for Nextcloud and future services?

Valid outcomes:

- approve an Authentik Identity Platform implementation Sprint;
- extend the PoC for unresolved recovery, mapping or session evidence;
- reject Authentik because the additional PostgreSQL and identity operations
  are disproportionate to HomeLab07 requirements;
- select another identity candidate through a separately approved spike.

Feature count, appearance and successful login alone are insufficient. Approval
requires recovery, lockout prevention, stable identity mapping, secret
separation and reusable consumer onboarding evidence.

---

# Related Requirements

| Requirement | Contribution |
|---|---|
| FR-001 Service Deployment | Independent identity and database services |
| FR-002 Persistent Storage | NAS-backed PostgreSQL and Authentik data |
| FR-003 Infrastructure Configuration | Planned version-controlled Compose and blueprints |
| FR-004 HTTPS | Identity endpoints published through Nginx Proxy Manager |
| FR-006 Service Isolation | Server, worker, database and consumers have separate roles |
| FR-007 Configuration Management | Private environment and declarative provider design |
| FR-008 Recovery | Complete database/media/private restore boundary |
| FR-009 Documentation | Implementation and operational documentation required |
| NFR-001 Reproducibility | Pinned images, repository definitions and explicit provisioning |
| NFR-002 Maintainability | One identity provider and repeatable consumer pattern |
| NFR-005 Security | Strict redirects, private secrets and no Docker socket |
| NFR-006 Modularity | Identity remains application agnostic |
| NFR-007 Observability | Separate health, task, log and protocol validation |
| NFR-010 Recoverability | Native PostgreSQL backup and clean restore test |

---

# Official Sources

Authentik platform:

- [Docker Compose installation](https://docs.goauthentik.io/install-config/install/docker-compose/)
- [Architecture](https://docs.goauthentik.io/core/architecture)
- [Configuration](https://docs.goauthentik.io/install-config/configuration/)
- [Reverse proxy](https://docs.goauthentik.io/install-config/reverse-proxy/)
- [Backup and restore](https://docs.goauthentik.io/sys-mgmt/ops/backup-restore)
- [Upgrade guidance](https://docs.goauthentik.io/install-config/upgrade)
- [PostgreSQL Docker upgrade](https://docs.goauthentik.io/troubleshooting/postgres/upgrade_docker)
- [Automated install](https://docs.goauthentik.io/install-config/automated-install)
- [Blueprint YAML tags](https://docs.goauthentik.io/customize/blueprints/v1/tags)
- [Release 2025.10](https://docs.goauthentik.io/releases/2025.10)
- [Release 2026.5](https://docs.goauthentik.io/releases/2026.5/)

Protocols and consumers:

- [OAuth2/OIDC provider](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/)
- [Nextcloud integration](https://docs.goauthentik.io/integrations/services/nextcloud/)
- [Gitea integration](https://docs.goauthentik.io/integrations/services/gitea/)
- [Jellyfin integration](https://docs.goauthentik.io/integrations/services/jellyfin/)
- [Grafana Generic OAuth](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/generic-oauth/)
- [Immich OIDC](https://docs.immich.app/administration/oauth/)
- [Paperless-ngx OIDC](https://docs.paperless-ngx.com/advanced_usage/)

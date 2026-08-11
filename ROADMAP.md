# HomeLab07 Roadmap

Version: 2.0

Status: Active

---

# Vision

HomeLab07 is a reference implementation of a modern self-hosted platform.

The roadmap prioritizes reusable platform capabilities before business-facing applications.

Each Sprint should either:

- Introduce a reusable platform capability, or
- Deliver a platform service that consumes those capabilities.

This approach keeps the platform modular, maintainable and reproducible.

---

# Phase 1 — Platform Foundation

The objective of this phase is to establish the technical foundation of the platform.

---

## Sprint 001 — Foundation

Status

✅ Completed

Objective

Create the engineering foundation of HomeLab07.

Deliverables

- Repository structure
- Engineering standards
- Operation Layer
- Shared Docker networking
- Documentation standards
- Engineering Principles
- Project Charter

---

## Sprint 002 — Data Foundation

Status

✅ Completed

Objective

Provide persistent shared relational storage.

Deliverables

- Shared MariaDB
- Persistent storage
- Database conventions
- Shared database architecture
- Backup-ready storage layout

Platform Capability

Shared relational database.

---

## Sprint 003 — Zero Touch SSL

Status

✅ Completed

Objective

Provide secure publication of platform services.

Deliverables

- Nginx Proxy Manager
- Automatic Let's Encrypt certificates
- HTTPS by default
- Reverse Proxy
- Cloudflare Dynamic DNS
- Public publication architecture

Platform Capability

Shared networking.

---

# Phase 2 — Shared Platform Capabilities

The objective of this phase is to introduce reusable services consumed by multiple applications.

Applications should never own these capabilities.

---

## Sprint 004 — In-Memory Data Platform

Status

✅ Completed

Objective

Provide a shared in-memory platform service for caching, distributed locking and transient application state.

Platform Capability

Valkey

Deliverables

- Valkey deployment
- Internal Docker networking
- Stateless configuration
- Operation Layer integration
- Service documentation
- Security hardening
- Validation procedures

Architecture Principles

- Shared platform service
- Application agnostic
- Stateless
- No persistent storage
- No published host ports
- Internal network only
- Reusable by future platform services

Validation

- Service deployment
- Platform integration
- Network isolation
- Container recreation
- Operation Layer support
- Memory limit validation
- Memory policy validation

---

## Sprint 005 — Collaboration Platform

Status

Completed

Historical implementation: OwnCloud. Superseded in the active repository by
Nextcloud after POC-001. The original implementation remains available from
the `v0.6.0-collaboration-platform` tag.

Objective

Deploy the first business-facing platform service.

Business Service

OwnCloud

Approved Technology Stack

- `owncloud/server:10.16.3`
- Shared MariaDB 11.4
- Shared Valkey
- Nginx Proxy Manager
- Cloudflare Dynamic DNS

Not Approved

- OCIS
- `latest` image tags
- release candidate images
- dedicated MariaDB
- dedicated Valkey

Consumes

- MariaDB
- Valkey
- Nginx Proxy Manager
- Cloudflare Dynamic DNS

Storage Principles

- The NAS is the authoritative storage layer.
- OwnCloud provides collaboration services on top of NAS-backed storage.
- Applications must not become the owners of user data.
- Persistent OwnCloud data must remain directly recoverable from NAS storage.
- `OWNCLOUD_DATA_ROOT` points to the dedicated OwnCloud share and is mounted directly at `/mnt/data`.
- OwnCloud internal volume paths are explicit: `OWNCLOUD_VOLUME_ROOT=/mnt/data` and `OWNCLOUD_VOLUME_FILES=/mnt/data/files`.
- Existing NAS shares should be integrated later through OwnCloud External Storage instead of direct internal data tree mounts.

Encryption Policy

OwnCloud server-side encryption must remain disabled.

The following are not approved for Sprint 005:

- Default Encryption Module
- server-side encryption
- application-managed encryption at rest

The engineering objective is to preserve direct file recoverability from the NAS.

Database Provisioning

- Database provisioning is handled through the HomeLab07 operation layer during this Sprint.
- SQL examples must use placeholders only.
- Database collation must not be hardcoded before implementation.
- Database collation must be validated against OwnCloud Server 10.16.3 recommendations before creating the database.
- MariaDB remains application agnostic.

Reverse Proxy Configuration

OwnCloud reverse proxy documentation must include placeholders for:

- `trusted_domains`
- `trusted_proxies`
- `overwrite.cli.url`
- `overwriteprotocol=https`

Real public URLs belong exclusively inside `HomeLab07.private/`.

Platform Publication

```text
Internet
    ↓
Cloudflare
    ↓
Nginx Proxy Manager
    ↓
OwnCloud
```

OwnCloud must not assume direct Internet exposure.

Manual Nginx Proxy Manager Configuration

- Proxy Host is created manually during Sprint 005.
- Manual NPM configuration is a temporary approved exception with a reproducible placeholder-based procedure.
- Domain belongs in `HomeLab07.private/` and must be documented with placeholders in the repository.
- Forward Host: `homelab07-owncloud`
- Forward Port: `8080`
- HTTPS via Let's Encrypt.
- Force SSL enabled.
- HTTP/2 enabled.

Valkey Decision

- ACL authentication remains deferred.
- The current trust model relies on Docker internal networking.
- OwnCloud consumes the shared Valkey platform capability.
- No application-specific Valkey instance shall be deployed.

Future ACL evaluation triggers:

- multiple application consumers
- reduced trust boundary
- multi-host deployment

Deliverables

- OwnCloud
- Shared storage
- HTTPS publication
- Platform documentation
- Operation Layer integration

Validation

- File upload
- File download
- Concurrent access
- Transactional locking
- HTTPS publication
- OwnCloud system configuration validation:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:list system
```

Expected configuration:

- `memcache.local` is configured.
- `memcache.locking` is configured.
- Redis configuration is present.
- Redis-backed configuration points to `homelab07-valkey`.

Completion Notes

- OwnCloud Server 10.16.3 deployed successfully.
- Shared MariaDB integration validated.
- Shared Valkey usage validated through Redis-compatible cache activity.
- HTTPS publication through Cloudflare and Nginx Proxy Manager validated.
- Dedicated NAS-backed OwnCloud storage validated.
- Uploaded files are recoverable from the NAS-backed OwnCloud data tree.
- Server-side encryption remains disabled.
- Existing NAS shares are deferred to a future External Storage evaluation.

Healthcheck Requirements

- Healthchecks must tolerate the initial installation and migration process.
- Startup probes must not be aggressive.

Operational Principle

- Prefer `php occ` as `www-data` for administrative actions over manual file editing.
- Every `occ` command executed during installation must be documented.

---

## Sprint 006 — Document Management Platform

Status

Completed

Objective

Provide searchable document ingestion, OCR, classification and archival through
the shared platform.

Business Service

Paperless-ngx

Consumes

- Shared MariaDB
- Shared Valkey
- Shared Storage
- Nginx Proxy Manager
- Cloudflare Dynamic DNS

Deliverables

- Paperless-ngx
- Document consumption directory
- OCR processing
- Searchable document archive
- HTTPS publication
- Platform operations integration
- Service documentation

Validation

- Document upload and consumption
- OCR and full-text search
- Metadata and classification
- MariaDB integration
- Valkey-backed task processing
- NAS-backed persistence
- HTTPS publication
- Export and recovery boundary documentation

Completion Notes

- Paperless-ngx deployed reproducibly through the operation layer.
- Shared MariaDB and Valkey integration validated on the target host.
- Synthetic PDF and image ingestion, OCR, classification and search validated.
- NAS-backed persistence and polling behavior validated across recreation.
- HTTPS publication validated without a direct application host port.
- Database dump, portable export and disposable restore validated.

---

## Sprint 007 — Media Platform

Status

Completed

Objective

Provide multimedia services through the shared platform.

Business Service

Jellyfin

Consumes

- Shared Storage
- Nginx Proxy Manager
- Cloudflare Dynamic DNS

Deliverables

- Jellyfin
- HTTPS publication
- Movie, music and family-photo/video libraries
- Streaming

Validation

- Browser and representative-client playback
- Music playback and family-photo browsing
- Direct play, seeking, subtitles and controlled transcoding
- Read-only media and persistent configuration boundaries
- HTTPS, WebSockets and exact trusted-proxy behavior
- Secure remote access without a direct application host port
- Container recreation and disposable configuration restore

Architecture Decisions

- Official Jellyfin image pinned to an exact stable release.
- Source media mounted read-only from Rockstor.
- Dedicated durable `/config` and replaceable `/cache` boundaries.
- No MariaDB or Valkey dependency.
- Bridge networking and proxy-only publication; DLNA excluded.
- Limited Intel VA-API acceleration is approved for validated H.264,
  MPEG-2 and VC-1 profiles through scoped render-device access.

---

# Phase 3 — Local Services And Platform Operations

The objective of this phase is to operationalize, protect and recover the
platform before introducing centralized identity.

---

## Sprint 008 — Homebridge Platform

Status

Completed

Objective

Operationalize Homebridge as a reproducible, recoverable and LAN-only
HomeLab07 business service without redesigning the broader smart-home
architecture.

Business Service

Homebridge

Consumes

- NAS-backed storage
- Operation Layer
- Private environment configuration

Architecture Decisions

- Host networking is a limited Homebridge exception for mDNS and HAP.
- Homebridge consumes no public DNS, reverse proxy or shared application
  network.
- Pairing identity, plugins and child-bridge state form a protected recovery
  boundary.

Validation

- HomeKit discovery, controllers and home hubs
- Camera snapshots and streaming
- Approved-LAN access and unapproved-network denial
- Container recreation and state recovery without re-pairing
- No direct public exposure

---

## Sprint 009 — Platform Operations

Status

Complete

Objective

Harden and operationalize the platform for production-quality operation.

Deliverables

- Public and management exposure inventory
- Cloudflare WAF
- Rate Limiting
- Zero Trust evaluation
- Security Headers
- Nginx Proxy Manager administration isolation
- Read-only platform security audit
- Edge-policy and incident-response documentation
- Platform security review
- Infrastructure hardening

Validation

- Security assessment
- Public exposure review
- Infrastructure review
- Approved-management access and unapproved-network denial
- Published-application compatibility after edge hardening
- WAF, rate-limit and management-boundary rollback

---

## Sprint 010 — Backup & Recovery

Status

✅ Completed

Objective

Provide reliable disaster recovery for platform services.

Deliverables

- Operation-layer backup commands
- Versioned recovery manifest
- Restore procedures
- Disaster Recovery documentation
- Backup validation
- Recovery testing

Validation

- Successful restore
- Backup integrity
- Recovery documentation

---

## Sprint 011 — Identity Platform

Status

✅ Completed

Objective

Provide reusable centralized authentication and authorization after application
requirements have been demonstrated by the preceding Sprints.

Platform Capability

Keycloak 26.7.0 using the existing shared MariaDB 11.4 platform.

Decision

Keycloak was selected because it provides the required OIDC capability and
officially supports the existing MariaDB LTS baseline. Authentik was rejected
because it would require a second relational database platform.

Deliverables

- Identity platform decision record
- OpenID Connect
- Single Sign-On
- User and group management appropriate to demonstrated requirements
- Nextcloud integration
- Compatibility validation for existing platform applications
- Controlled Paperless-ngx OIDC consumer enhancement
- Explicit retention of Jellyfin local authentication

Validation

- OIDC login
- User lifecycle validation
- Application integration
- Recovery and local administrative access

---

## Sprint 012 — Vulnerability Management

Status

🚧 In Progress

Objective

Provide repeatable vulnerability, secret and misconfiguration visibility for
the repository and all declared platform container images.

Platform Capability

Trivy-based vulnerability management with private evidence storage.

Deliverables

- Read-only repository and image scanning
- Docker Compose image inventory and existing policy-audit integration
- CycloneDX software bills of materials
- Atomic detailed reports on a dedicated private share
- Sanitized, reviewable security summaries
- Documented exception, remediation and retention workflow

Validation

- Scanner preflight and pinned runtime identity
- Complete unique-image coverage
- Report and SBOM integrity checksums
- Report-share permission and mount boundary
- Failed-run atomicity and absence of partial published evidence

---

## Sprint 013 — Observability & Alerting

Status

🚧 In progress — repository implementation complete; target validation pending

Objective

Provide actionable host, storage, service and operation visibility with bounded
metrics and log retention, LAN-only access and a small alert baseline.

Platform Capability

Grafana Alloy, Prometheus, Loki and Grafana.

Deliverables

- Host and approved service health collection
- Atomic metrics from backup, vulnerability management and platform operations
- Batch freshness contract evaluated through Alloy's embedded textfile collector
- Read-only Rockstor/Btrfs mount, capacity, error and scrub visibility
- Selected redacted diagnostic logs
- Declaratively provisioned dashboards, datasources and alert rules
- LAN-only Grafana access with no Docker socket or privileged containers
- Actionable alerts and operational runbooks

Validation

- Immutable runtime image identities and reproducible Compose configuration
- Explicit Grafana LAN bind and absence of public Prometheus/Loki ports
- Host, endpoint, operation and Rockstor metric coverage
- Batch last-run, last-success, status and stale-metric evaluation
- Missing-mount detection and atomic textfile publication
- Log redaction, label-cardinality and retention controls
- Alert firing, notification, resolution, recreation and rollback

---

# Future Platform Enhancements

The following capabilities remain outside the current roadmap.

They should only be introduced when justified by platform requirements.

Potential future enhancements include:

- SPIKE-002 — Identity Source of Truth and SSO Experience
- Multi-node deployment
- High Availability
- Object Storage
- GitOps
- Infrastructure as Code
- Kubernetes
- Multi-site replication

---

# Roadmap Principles

The roadmap follows the engineering philosophy of HomeLab07.

Platform capabilities are introduced when demonstrated application requirements
justify their operational cost.

Applications consume shared platform services rather than implementing infrastructure independently.

The platform should evolve by increasing reuse, reducing duplication and preserving reproducibility.

Business-facing services should demonstrate the value of the platform, inform
future shared-capability decisions and remain loosely coupled to the underlying
infrastructure.

Every Sprint should strengthen the platform as a whole, not only the service being introduced.

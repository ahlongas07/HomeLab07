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

In Progress

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

Healthcheck Requirements

- Healthchecks must tolerate the initial installation and migration process.
- Startup probes must not be aggressive.

Operational Principle

- Prefer `php occ` as `www-data` for administrative actions over manual file editing.
- Every `occ` command executed during installation must be documented.

---

## Sprint 006 — Identity Platform

Status

Planned

Objective

Provide centralized authentication and authorization for the platform.

Platform Capability

Authentik

Provides

- OpenID Connect
- Single Sign-On
- Identity Management
- User Management
- Group Management

Consumes

- PostgreSQL (if required)
- Nginx Proxy Manager

Integrates With

- OwnCloud

Validation

- OIDC login
- User provisioning
- Group synchronization
- Identity integration

---

## Sprint 007 — Media Platform

Status

Planned

Objective

Provide multimedia services through the shared platform.

Business Service

Jellyfin

Consumes

- Identity Platform
- Shared Storage
- Nginx Proxy Manager

Deliverables

- Jellyfin
- HTTPS publication
- Media library
- Streaming

Validation

- Media playback
- Secure remote access
- Identity integration

---

## Sprint 008 — Smart Home Platform

Status

Planned

Objective

Provide smart home automation services.

Business Service

Homebridge

Consumes

- Identity Platform (where applicable)
- Nginx Proxy Manager

Deliverables

- Homebridge
- HomeKit integration
- Remote access
- Platform documentation

Validation

- HomeKit connectivity
- Remote access
- Stable operation

---

# Phase 3 — Platform Operations

The objective of this phase is to operationalize and secure the platform.

---

## Sprint 009 — Platform Hardening

Status

Planned

Objective

Harden the platform for production-quality operation.

Deliverables

- Cloudflare WAF
- Rate Limiting
- Zero Trust evaluation
- Security Headers
- Platform security review
- Infrastructure hardening

Validation

- Security assessment
- Public exposure review
- Infrastructure review

---

## Sprint 010 — Backup & Recovery

Status

Planned

Objective

Provide reliable disaster recovery for platform services.

Deliverables

- Automated backups
- Restore procedures
- Disaster Recovery documentation
- Backup validation
- Recovery testing

Validation

- Successful restore
- Backup integrity
- Recovery documentation

---

# Future Platform Enhancements

The following capabilities remain outside the current roadmap.

They should only be introduced when justified by platform requirements.

Potential future enhancements include:

- Observability
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

Platform capabilities are implemented before applications.

Applications consume shared platform services rather than implementing infrastructure independently.

The platform should evolve by increasing reuse, reducing duplication and preserving reproducibility.

Business-facing services should demonstrate the value of the platform while remaining loosely coupled to the underlying infrastructure.

Every Sprint should strengthen the platform as a whole, not only the service being introduced.

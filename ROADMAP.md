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

In Progress

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

---

## Sprint 005 — Collaboration Platform

Status

Planned

Objective

Deploy the first business-facing platform service.

Business Service

OwnCloud

Consumes

- MariaDB
- Valkey
- Nginx Proxy Manager
- Cloudflare Dynamic DNS

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

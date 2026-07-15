# HomeLab07 Roadmap

## Vision

Build a modern, self-hosted infrastructure platform that is simple, maintainable, reproducible, and documented using professional engineering practices.

Every sprint must deliver one complete platform capability that can be demonstrated, validated, and integrated into the platform without increasing unnecessary complexity.

---

# Project Milestones

## ✅ Kickoff

**Status:** Completed

### Objectives

- Project definition
- Engineering principles
- Repository creation
- Documentation
- Git workflow
- Development environment
- Runtime environment
- SSH authentication
- Docker installation
- Foundation architecture

---

## ✅ Sprint 001 — Foundation

**Status:** Completed

### Goal

Validate the complete deployment pipeline by deploying the first operational platform service and establishing the operational foundation of HomeLab07.

### Capabilities

- Docker Compose
- First Nginx service
- Landing page
- GitHub → NAS deployment
- Deployment workflow validation
- Platform operation layer
- Reproducible service architecture

---

## ✅ Sprint 002 — Data Foundation

**Status:** Completed

### Goal

Establish the persistent storage foundation for HomeLab07.

### Capabilities

- Shared relational database
- Persistent platform storage
- Stateful service architecture
- Storage strategy
- Backup foundation
- Secure credential management
- Internal-only database networking

---

## Sprint 003 — Zero Touch SSL

**Status:** Planned

### Goal

Provide automatic HTTPS with secure service publication.

### Capabilities

- Reverse Proxy
- Automatic TLS certificates
- HTTP → HTTPS redirection
- Secure default configuration
- Public service publication

---

## Sprint 004 — Identity

**Status:** Planned

### Goal

Centralize authentication for self-hosted services.

### Capabilities

- Identity Provider
- Single Sign-On
- Forward Authentication
- Protected services

---

## Sprint 005 — Observability

**Status:** Planned

### Goal

Provide visibility into platform health.

### Capabilities

- Logs
- Metrics
- Dashboards
- Health checks
- Alerting foundation

---

## Sprint 006 — Backup & Recovery

**Status:** Planned

### Goal

Guarantee platform recoverability.

### Capabilities

- Backup strategy
- Restore procedures
- Disaster Recovery documentation
- Backup validation

---

## Sprint 007 — Application Platform

**Status:** Planned

### Goal

Deploy the first production application on the HomeLab07 platform.

### Capabilities

- First production workload
- Shared database consumption
- Persistent storage
- Secure publication
- Operational validation

---

## Sprint 008 — Platform Hardening

**Status:** Planned

### Goal

Increase security and operational maturity.

### Capabilities

- Secret management improvements
- Least privilege review
- Network segmentation
- Security review
- Operational documentation

---

# Version Milestones

| Version | Milestone |
|---------|-----------|
| v0.1.0-kickoff | Project Kickoff |
| v0.2.0-foundation | First operational platform |
| v0.3.0-data-foundation | Persistent platform services |
| v0.4.0-zero-touch-ssl | Automatic HTTPS |
| v0.5.0-identity | Centralized authentication |
| v0.6.0-observability | Platform monitoring |
| v0.7.0-backup-recovery | Disaster recovery |
| v0.8.0-application-platform | First production workload |
| v1.0.0-production | Stable platform |

---

# Engineering Strategy

Each sprint must:

- Deliver one complete platform capability.
- Be independently demonstrable.
- Be fully documented.
- Preserve simplicity.
- Strengthen the platform architecture.
- Minimize operational complexity.
- Keep GitHub as the single source of truth.
- Separate source code, secrets, and persistent data.
- Prefer explicit configuration over implicit behavior.
- Follow the principle of secure-by-default.

---

# Documentation Hierarchy

HomeLab07 follows a single source of truth model for project documentation.

Priority order:

1. `sprints/SPRINT-XXX.md`
2. `ROADMAP.md`
3. `PROJECT_CHARTER.md`

Sprint documents define the implementation plan.

The roadmap summarizes the platform evolution.

The Project Charter defines the long-term vision and changes only when the project's strategic direction changes.

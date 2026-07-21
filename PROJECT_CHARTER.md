# PROJECT CHARTER

**Project:** HomeLab07

**Version:** v0.5.0-in-memory-platform

**Status:** Active

**Project Type:** Infrastructure Engineering Project

**Last Updated:** 2026-07-16

---

# Executive Summary

HomeLab07 is an infrastructure engineering project dedicated to designing, building, and maintaining a modern self-hosted platform based on simplicity, automation, security, and reproducibility.

The project applies professional engineering practices to home infrastructure by treating documentation, architecture, operations, and persistent storage as first-class components of the platform.

Rather than being a collection of services, HomeLab07 is intended to become a reference implementation for building reliable self-hosted environments through reusable platform capabilities and business-facing services that consume them.

---

# Vision

Build a modern self-hosted infrastructure platform that is simple, maintainable, secure, reproducible, professionally documented, and useful as a reference implementation.

---

# Mission

Reduce operational complexity through standardization, automation, and clear engineering practices while preserving full control over the platform.

---

# Purpose

HomeLab07 exists to answer a single engineering question:

> **How can a personal self-hosted environment achieve enterprise-quality engineering without enterprise-level complexity?**

---

# Core Principles

## Simplicity

Prefer the simplest solution that correctly solves the problem.

Complexity must always have a measurable benefit.

---

## Documentation First

Every architectural decision should be documented before implementation.

Documentation is part of the deliverable.

---

## Secure by Default

No service should become publicly accessible unless explicitly configured.

Security should always favor intentional exposure over convenience.

---

## Automation Over Manual Operations

Any operational task performed repeatedly should eventually become automated.

Automation must never compromise security or maintainability.

---

## Infrastructure as Code

Infrastructure definitions should be version-controlled, reproducible, and reviewable.

---

## Storage First

Persistent application data belongs to the storage platform.

Applications should remain stateless whenever reasonably possible.

---

## Separation of Concerns

Clearly separate:

- Source Code
- Platform Operations
- Infrastructure Services
- Application Services
- Secrets
- Persistent Data

Each layer evolves independently while preserving reproducibility.

---

## Continuous Improvement

Every sprint should strengthen the platform architecture while reducing operational complexity.

---

# Project Objectives

## Short-Term

- Establish engineering standards.
- Define platform architecture.
- Standardize platform operations.
- Introduce persistent platform services.
- Automate secure service publication.
- Prioritize reusable platform capabilities before business-facing applications.

---

## Medium-Term

- Build reusable deployment patterns.
- Introduce shared in-memory data services.
- Deploy business-facing services that consume shared platform capabilities.
- Improve observability.
- Standardize backup and recovery.
- Simplify platform operations.

---

## Long-Term

- Create a reusable engineering platform for self-hosted infrastructure.
- Share engineering knowledge with the community.
- Promote reproducible infrastructure practices.
- Enable community contributions through clear engineering standards.

---

# Scope

The project includes:

- Infrastructure architecture
- Storage architecture
- Platform operations
- Docker-based services
- Persistent services
- In-memory platform services
- Business-facing platform services
- Reverse proxy
- SSL automation
- DNS automation
- Identity management
- Documentation
- Operational procedures
- Backup and recovery procedures
- Engineering standards

---

# Out of Scope

The following topics are intentionally excluded during the initial phases:

- Kubernetes
- Multi-node orchestration
- High Availability clusters
- Enterprise IAM platforms
- Public cloud deployment
- Complex CI/CD platforms

---

# Engineering Philosophy

Every engineering decision should satisfy the following priorities:

1. Simplicity
2. Security
3. Reliability
4. Reproducibility
5. Maintainability
6. Performance

If a solution improves performance while significantly increasing operational complexity or reducing security, it should be reconsidered.

---

# Platform Architecture

HomeLab07 follows a layered architecture.

```
Source Code
        │
        ▼
Platform Operations
        │
        ▼
Infrastructure Services
        │
        ▼
Application Services
        │
        ▼
Persistent Data
```

Platform responsibilities are intentionally separated.

- Git manages source code.
- Docker executes services.
- Rockstor manages persistent storage.
- Cloudflare manages public DNS.
- The operation layer manages the platform lifecycle.

---

# Platform Operations

All lifecycle operations are centralized through the platform operation layer.

Administrators interact with HomeLab07 through a consistent operational interface instead of directly managing individual containers.

Current operational commands:

- start
- stop
- status
- compose

Future operational capabilities should extend this interface rather than bypass it.

---

# Persistent Storage

Persistent application data is managed outside the Git repository.

Platform services remain reproducible from version-controlled configuration while storing runtime state in dedicated persistent storage.

Persistent services must:

- survive container recreation;
- separate runtime data from configuration;
- avoid writable container layers for persistence.

---

# Success Criteria

The project will be considered successful when:

- Infrastructure can be rebuilt from documentation.
- Platform services are reproducible.
- Deployments are predictable.
- Operational effort is minimized.
- Persistent data remains independent from source code.
- Documentation accurately represents the running platform.

---

# Initial Roadmap

The roadmap is capability-driven.

Each sprint either introduces one reusable platform capability or delivers a platform service that consumes existing capabilities.

## Sprint 001 — Foundation

Deliver the first operational platform service and validate the deployment pipeline.

## Sprint 002 — Data Foundation

Establish the persistent storage foundation and introduce the first shared stateful service.

## Sprint 003 — Zero Touch SSL

Provide secure public service publication with automatic HTTPS.

## Sprint 004 — In-Memory Data Platform

Introduce Valkey as the shared in-memory platform service.

## Sprint 005 — Collaboration Platform

Deploy and evolve the collaboration platform as the first business-facing
platform service.

## Sprint 006 — Identity Platform

Centralize authentication and authorization for platform services.

## Sprint 007 — Media Platform

Deploy multimedia services through the shared platform.

## Sprint 008 — Smart Home Platform

Provide smart home automation services.

## Sprint 009 — Platform Hardening

Increase security and operational maturity.

## Sprint 010 — Backup & Recovery

Implement the platform recovery strategy.

---

# Definition of Done

A feature is considered complete only when:

- It is documented.
- It is version-controlled.
- It is reproducible.
- It has been validated.
- It integrates with the operation layer.
- It strengthens the platform architecture.

---

# Documentation Model

HomeLab07 follows a single source of truth documentation strategy.

Documentation hierarchy:

1. Sprint Documents (`sprints/`)
2. Roadmap (`ROADMAP.md`)
3. Project Charter (`PROJECT_CHARTER.md`)

Responsibilities:

- Sprint documents define implementation.
- The Roadmap summarizes platform evolution.
- The Project Charter defines long-term vision, architectural principles, and engineering philosophy.

---

# Motto

> **Build • Host • Automate**

---

# Guiding Statement

HomeLab07 is not a collection of containers.

It is an engineering discipline applied to self-hosted infrastructure.

Every implementation should leave the platform simpler, more secure, better documented, and easier to reproduce than before.

---

# Version History

| Version | Date | Description |
|----------|------------|----------------------------------------------|
| 0.1.0-alpha | 2026-07-11 | Initial Project Charter |
| 0.2.0 | 2026-07-15 | Architecture and engineering principles updated after Foundation milestone |
| v0.3.0-data-foundation | 2026-07-15 | Data Foundation milestone completed |
| v0.4.0-zero-touch-ssl | 2026-07-15 | Zero Touch SSL milestone completed |
| Roadmap 2.0 | 2026-07-16 | Product roadmap updated to prioritize reusable platform capabilities and business-facing services |
| v0.5.0-in-memory-platform | 2026-07-16 | In-Memory Data Platform milestone completed |

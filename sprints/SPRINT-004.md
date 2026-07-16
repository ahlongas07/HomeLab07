# Sprint 004 — In-Memory Data Platform

**Version:** v0.5.0-in-memory-platform

**Status:** Completed

---

# Objective

Introduce a shared in-memory data platform for HomeLab07 by deploying **Valkey** as a reusable platform capability.

This sprint establishes the platform's distributed cache and transient data layer, allowing applications to consume high-performance in-memory services without owning their own cache implementation.

The service is intentionally application-agnostic and will become a shared dependency for future platform services.

---

# Scope

## In Scope

- Deploy Valkey.
- Stateless deployment.
- Internal Docker networking.
- Platform service documentation.
- Operation Layer integration.
- Service validation.
- Security hardening.
- Platform architecture documentation.

---

## Out of Scope

- OwnCloud integration.
- Session persistence.
- Persistent storage.
- Redis Sentinel.
- Valkey Cluster.
- High Availability.
- Backup and Restore.
- Monitoring.
- Authentication integration.

Application integration will begin in Sprint 005.

---

# Platform Capability

Valkey provides reusable in-memory services for the platform.

Supported workloads include:

- Distributed cache
- Transactional file locking
- Session storage
- Temporary application state
- Future Pub/Sub workloads
- Future rate limiting

Applications consume the platform capability rather than deploying their own cache services.

---

# Deliverables

Create:

```text
services/valkey/
```

Including:

```text
services/valkey/
├── compose.yaml
├── README.md
└── .env.example
```

Integrate with:

```text
operation/start.sh
operation/stop.sh
operation/status.sh
operation/compose.sh
```

Document:

- deployment
- architecture
- validation
- security
- operational model

---

# Dependencies

Requires:

- Sprint 001 — Foundation
- Sprint 002 — Data Foundation
- Sprint 003 — Zero Touch SSL

---

# Storage Architecture

Valkey is intentionally deployed as a stateless platform service.

No persistent application data is stored.

No Rockstor Share is required.

No backup strategy is required.

Persistent storage is intentionally omitted to reduce operational complexity.

---

# Network Architecture

Valkey is an internal platform service.

It must never be published externally.

```text
                    Internet
                        │
                        ▼
                 Cloudflare
                        │
                        ▼
          Nginx Proxy Manager
                        │
                Published Services
                        │
────────────────────────────────────────

            Internal Platform

      MariaDB        Valkey

────────────────────────────────────────

          Platform Applications
```

Valkey communicates exclusively through:

```text
homelab07-internal
```

No service should access Valkey through published host ports.

---

# Security Requirements

Valkey must:

- Run without published host ports.
- Be accessible only through the internal Docker network.
- Run with a read-only root filesystem whenever possible.
- Drop unnecessary Linux capabilities.
- Disable privilege escalation.
- Store no secrets.
- Store no persistent application data.

---

# Configuration Principles

HomeLab07 intentionally deploys Valkey as an ephemeral platform capability.

Recommended configuration:

- No AOF persistence.
- No RDB snapshots.
- Explicit memory limit.
- No eviction policy.
- Restart automatically.
- Rebuild transient state after restart.

The platform should tolerate cache loss without data loss.

---

# Operational Principles

Valkey is a shared platform capability.

Applications must never own their own Valkey deployment.

The lifecycle is managed exclusively through the HomeLab07 Operation Layer.

Supported operations:

- start
- stop
- status
- logs
- config

Administrators should avoid interacting directly with Docker except for diagnostics.

---

# Architecture Principles

This sprint reinforces the following permanent engineering principles.

- One shared in-memory platform.
- Infrastructure remains application-agnostic.
- Applications consume shared capabilities.
- Stateless platform services should remain stateless.
- No unnecessary persistent storage.
- Security by default.
- Platform services remain internally isolated.
- Infrastructure should remain reproducible.

---

# Validation

Validate the following:

- Valkey starts successfully.
- Platform networking functions correctly.
- No public ports are exposed.
- Operation Layer integration succeeds.
- Container recreation succeeds.
- Stateless restart succeeds.
- Service logs report healthy startup.
- Internal connectivity succeeds.
- Memory limit is configured as `128mb`.
- Memory policy is configured as `noeviction`.

Validation commands:

```bash
./operation/compose.sh valkey config
./operation/status.sh
docker exec homelab07-valkey valkey-cli ping
docker port homelab07-valkey
docker inspect homelab07-valkey \
  --format '{{json .NetworkSettings.Networks}}'
docker exec homelab07-valkey valkey-cli CONFIG GET maxmemory
docker exec homelab07-valkey valkey-cli CONFIG GET maxmemory-policy
```

---

# Success Criteria

The sprint is complete when:

- Valkey deploys successfully.
- Internal networking is validated.
- Operation Layer integration is complete.
- Documentation is complete.
- No persistent storage is required.
- No host ports are published.
- Valkey memory limits are configured and validated.
- Platform architecture documentation reflects the new capability.

---

# Risks

Potential risks include:

- Accidental public exposure.
- Persistent storage being introduced unnecessarily.
- Application-specific configuration leaking into the platform layer.
- Future applications assuming persistence.

---

# Expected Outcome

At the end of this sprint HomeLab07 provides a reusable in-memory platform capability.

Future applications no longer deploy their own Redis-compatible cache.

Instead, they consume the shared Valkey platform service, preserving a clean separation between infrastructure capabilities and business-facing applications.

This sprint establishes the foundation for:

- OwnCloud
- Paperless
- Future collaboration services
- Future platform capabilities requiring distributed cache or transient state

without coupling those applications to their own infrastructure.

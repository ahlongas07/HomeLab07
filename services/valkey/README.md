# Valkey

## Purpose

Valkey provides the shared in-memory data platform for HomeLab07.

It is a reusable platform capability for caching, distributed locking, session storage, and transient application state.

This service is infrastructure, not application functionality.

---

## Responsibilities

- Shared Redis-compatible in-memory data service.
- Internal cache endpoint for platform applications.
- Foundation for transactional locking in future applications.
- Stateless transient data layer.
- Reference implementation for shared ephemeral services.

Valkey is not responsible for:

- Persistent application data.
- Application-specific cache configuration.
- Public networking.
- Authentication integration.
- High Availability.
- Backup and restore.

---

## Design Principles

- One shared in-memory platform.
- Applications consume Valkey instead of deploying their own cache.
- Runtime state is transient.
- Cache loss must not cause data loss.
- No persistent storage is configured.
- No host ports are published.
- The service is internal-only.

---

## Technology

| Component | Technology |
|-----------|------------|
| In-memory data platform | Valkey 8 |
| Runtime | Docker Compose |
| Network | homelab07-internal |
| Operations | HomeLab07 operation layer |

The image uses the stable major tag:

```text
valkey/valkey:8-alpine
```

---

## Architecture Overview

Valkey belongs to the internal platform layer.

```text
Published Services
       │
       ▼
Platform Applications
       │
       ▼
Internal Platform

MariaDB        Valkey
```

Applications connect to Valkey through the internal Docker network.

Valkey must never be exposed to the public Internet.

---

## Directory Structure

Repository:

```text
services/valkey/
├── compose.yaml
├── README.md
└── .env.example
```

No private environment file is required.

No persistent runtime storage is required.

---

## Configuration

Valkey is configured as an ephemeral platform service.

Persistence is disabled:

```text
--save ""
--appendonly no
```

Protected mode is disabled because Valkey must accept connections from other containers on `homelab07-internal`.

```text
--protected-mode no
```

The service remains private because it does not publish host ports and only joins the internal Docker network.

The container filesystem is read-only, and `/data` is provided as temporary memory-backed storage:

```text
tmpfs: /data
```

This allows Valkey to start cleanly while preserving the rule that no runtime data is persisted.

---

## Network Access

Valkey attaches only to:

```text
homelab07-internal
```

It does not publish host ports.

Future applications should connect using:

```text
Host: homelab07-valkey
Port: 6379
```

---

## Deployment

Validate the Compose configuration:

```bash
./operation/compose.sh valkey config
```

Start the platform:

```bash
./operation/start.sh
```

Check service status:

```bash
./operation/status.sh
```

View logs:

```bash
./operation/compose.sh valkey logs
```

Stop the platform:

```bash
./operation/stop.sh
```

---

## Operational Commands

HomeLab07 operations must go through the `operation/` layer.

```bash
./operation/start.sh
./operation/status.sh
./operation/stop.sh
./operation/compose.sh valkey config
./operation/compose.sh valkey logs
```

External automation should invoke these scripts instead of calling Docker Compose directly.

---

## Validation

Validate the following after deployment:

- Container starts successfully.
- Healthcheck reports healthy.
- No host ports are published.
- Service is attached only to `homelab07-internal`.
- Container recreation succeeds.
- Restart does not require persistent storage.
- Logs report normal startup.
- Internal clients can connect to `homelab07-valkey:6379`.

Example diagnostic command:

```bash
docker exec homelab07-valkey valkey-cli ping
```

Expected response:

```text
PONG
```

---

## Backup

No backup is required.

Valkey stores only transient state in HomeLab07.

Applications must not use Valkey as the source of truth for persistent data.

---

## Restore

No restore procedure is required.

Restarting the container recreates the empty in-memory state.

Applications must tolerate cache loss.

---

## Security

HomeLab07 follows a secure-by-default approach.

The following rules apply:

- Valkey is internal-only.
- No host ports are published.
- No secrets are stored.
- No persistent data is stored.
- The root filesystem is read-only.
- Linux capabilities are dropped.
- Privilege escalation is disabled.
- Applications must explicitly opt in to consume Valkey.

---

## Related Sprint

- Sprint 004 — In-Memory Data Platform
- Version: `v0.5.0-in-memory-platform`

This sprint establishes a shared Redis-compatible in-memory capability for future platform services, starting with OwnCloud in Sprint 005.

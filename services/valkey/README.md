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

This keeps the service on the Valkey 8 release line while allowing patch updates from the upstream image. Pinning to a patch tag, such as `8.1.8-alpine`, can improve deployment repeatability but requires intentional patch maintenance.

Recommendation: keep `8-alpine` for Sprint 004. Valkey is not yet consumed by an application, so the operational benefit of automatic patch updates is currently higher than the release-control benefit of patch pinning. Re-evaluate patch pinning when the first application consumes Valkey and compatibility testing becomes part of the release process.

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

Memory usage is bounded explicitly:

```text
--maxmemory 128mb
--maxmemory-policy noeviction
```

The `128mb` limit is intentionally conservative for Sprint 004 because Valkey is introduced as a shared platform capability before any application consumes it. It prevents uncontrolled memory growth while leaving enough capacity for initial cache, lock, and transient state workloads.

The `noeviction` policy prevents Valkey from silently evicting keys when the configured memory limit is reached. Applications should treat memory exhaustion as an operational signal rather than relying on implicit cache eviction. This favors predictable failure over hidden data loss in coordination workloads such as distributed locking.

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

The container runs as a non-root user:

```text
user: 999:999
```

The `/data` tmpfs mount is owned by the same UID/GID, and the container starts Valkey directly through `valkey-server`. This avoids startup ownership changes from the image entrypoint while preserving the non-root runtime model.

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

Confirm no host ports are published:

```bash
docker port homelab07-valkey
```

Expected response:

```text
No output
```

Inspect the container network attachments:

```bash
docker inspect homelab07-valkey \
  --format '{{json .NetworkSettings.Networks}}'
```

Expected result:

```text
The JSON output includes homelab07-internal and no published host-port mapping.
```

Confirm the memory limit:

```bash
docker exec homelab07-valkey valkey-cli CONFIG GET maxmemory
```

Expected response:

```text
maxmemory
134217728
```

Confirm the memory policy:

```bash
docker exec homelab07-valkey valkey-cli CONFIG GET maxmemory-policy
```

Expected response:

```text
maxmemory-policy
noeviction
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
- Valkey is reachable only through `homelab07-internal`.
- No secrets are stored.
- No persistent data is stored.
- The root filesystem is read-only.
- The container runs as a non-root user.
- Linux capabilities are dropped.
- Privilege escalation is disabled.
- Applications must explicitly opt in to consume Valkey.

Current trust model:

- Containers attached to `homelab07-internal` are trusted platform participants.
- Valkey exposes no host ports and is not reachable directly from the host network or the public Internet.
- Network isolation is the active security boundary for Sprint 004.
- Authentication is intentionally omitted during this Sprint because there is no consuming application or credential contract yet.

`protected-mode` is intentionally disabled because Valkey is isolated inside the `homelab07-internal` Docker network and exposes no host ports. This allows future platform applications on the internal network to connect while preserving the external security boundary.

ACL authentication is not enabled in Sprint 004 because no application consumes Valkey yet and no shared credential contract has been defined. ACL authentication will be evaluated when the first platform application consumes Valkey, starting with Sprint 005.

---

## Related Sprint

- Sprint 004 — In-Memory Data Platform
- Version: `v0.5.0-in-memory-platform`

This sprint establishes a shared Redis-compatible in-memory capability for future platform services, starting with OwnCloud in Sprint 005.

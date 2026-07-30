# Sprint 010 — Backup & Recovery

**Status:** In Progress — architecture approved; implementation underway

**Classification:** Platform Capability

**Primary Focus:** Recoverability and disaster recovery

**Last Reviewed:** 2026-07-29

---

# Objective

Implement a simple, encrypted and testable backup capability for HomeLab07
that produces consistent recovery points, verifies their integrity and restores
into a safe disposable location before production recovery is attempted.

Sprint 010 protects persistent application state, databases, private
configuration and the matching repository revision. It does not treat a
container image, RAID, a Rockstor snapshot or a second directory on the same
storage pool as a complete disaster-recovery strategy.

# Architecture Decision

HomeLab07 uses Restic as the backup repository format and the existing
`operation/` layer as the operator interface.

Restic provides:

- client-side encryption;
- content-defined deduplication;
- compression;
- local and remote repository backends;
- snapshot retention;
- integrity verification;
- restore into a selected destination.

HomeLab07 remains responsible for application consistency, MariaDB logical
dumps, service quiescing, sanitized output, recovery ordering and validation.

Official references:

- [Restic documentation](https://restic.readthedocs.io/en/stable/)
- [Repository preparation](https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html)
- [Repository checking](https://restic.readthedocs.io/en/stable/077_troubleshooting.html)

# Recovery Model

```text
Repository definitions + private configuration
                         │
Application quiesce ─────┼──→ consistent filesystem state
MariaDB logical dumps ───┤
                         ▼
                protected staging set
                         │
                         ▼
             encrypted Restic repository
                         │
              integrity and retention
                         │
                         ▼
             disposable restore location
                         │
            application-level validation
                         │
                         ▼
          reviewed production recovery only
```

The Restic repository must be outside the production data trees. For disaster
recovery it must ultimately exist on another physical device, host or remote
backend. A repository on the same NAS is accepted only as an operational first
copy and must not be represented as protection from NAS loss.

# Private Configuration

Backup configuration belongs in:

```text
HomeLab07.private/env/backup.env
```

The Restic password belongs in a separate owner-readable file:

```text
HomeLab07.private/secrets/restic-password
```

The repository stores no path, credential, endpoint or account identifier.
`operation/backup.env.example` defines placeholders only.

# Backup Scope

| Capability | Required state | Consistency method |
|---|---|---|
| Repository | Git bundle, revision and clean/dirty status | Captured before application backup |
| Private configuration | `env/`, `secrets/` and approved certificates | Owner-only staging; never printed |
| MariaDB | Logical dump of all application databases and grants | Applications quiesced; MariaDB remains running |
| Nginx Proxy Manager | `/data`, certificates and database | Proxy container stopped during capture |
| Nextcloud | `html`, `data` and database | Maintenance mode plus application and cron stop |
| Paperless-ngx | `data`, `media`, `consume`, `export` and database | Application stopped during capture |
| Jellyfin | `/config` | Container stopped; cache and source media excluded |
| Homebridge | Complete `/homebridge` root | Container stopped; duplicate identity never started |
| Landing Page | Repository only | No persistent runtime state |
| Valkey | None | Runtime state is intentionally transient |
| Dynamic DNS | Private configuration only | No persistent runtime state |

Source media libraries are authoritative NAS data and require their own storage
backup policy. They are not silently included in the platform-state backup
because their capacity and retention requirements differ materially.

# Consistency And Availability

The first implementation creates a coordinated recovery point with bounded
downtime. It records which services were running, quiesces only stateful
applications, captures logical and filesystem state, and restores only the
previously running services.

The backup must use an exclusive lock and fail before changing runtime state
when prerequisites are not satisfied. A trap must attempt to restore prior
service state after an interrupted capture. It must never delete production
data.

# Retention Baseline

The default policy is:

- 7 daily snapshots;
- 4 weekly snapshots;
- 6 monthly snapshots;
- 1 yearly snapshot.

Retention is applied only after a new snapshot and metadata check succeed.
`forget --prune` is a separate explicit operation from backup creation so a
failed or compromised backup job cannot immediately remove recovery points.

# Recovery Objectives

Initial targets:

- **RPO:** 24 hours after daily automation is enabled.
- **RTO:** documented best effort; measured during the full restore exercise.

These targets apply to platform state, not the separately protected media
library. A missed backup must be visible through a non-zero exit code and the
absence of a new validated snapshot.

# Operator Interface

Sprint 010 adds:

```text
operation/backup-preflight.sh
operation/backup-init.sh
operation/backup.sh
operation/backup-check.sh
operation/backup-retention.sh
operation/restore-test.sh
operation/backup.env.example
```

Expected flow:

```bash
./operation/backup-preflight.sh
./operation/backup-init.sh
./operation/backup.sh
./operation/backup-check.sh
./operation/restore-test.sh latest
./operation/backup-retention.sh
```

Initialization, backup, validation, restore testing and retention remain
separate commands so destructive retention never occurs implicitly.

# Restore Safety

The automated restore command:

- requires an explicit snapshot identifier;
- requires a new or empty destination outside production roots;
- refuses `/`, the repository root, project root, private root and production
  mount sources;
- never starts restored containers;
- never advertises a restored Homebridge identity;
- verifies restored manifest and checksums;
- prints the reviewed service-specific recovery sequence.

Production recovery remains a deliberate operator procedure after disposable
restore validation.

# Security

- Restic encryption is mandatory.
- The password file must be mode `600` and remain outside Git.
- Backup repositories are treated as sensitive even when encrypted.
- Script output uses service classifications and counts, not real paths,
  domains, database names, tokens or filenames from private configuration.
- Staging files use owner-only permissions and are removed after successful or
  interrupted operation.
- No Docker socket is mounted into another container.
- Backups do not weaken public exposure or stop unrelated internal services.
- A second repository copy or backend with independent failure characteristics
  is required before claiming full disaster recovery.

# Validation

## Static

- Shell scripts pass `bash -n` and ShellCheck when available.
- Examples contain placeholders only.
- Backup artifacts and private configuration are ignored by Git.
- No script contains production domains, addresses or credentials.

## Backup

- Preflight proves Restic, Docker, storage and private permissions.
- Application state is restored after backup whether it succeeds or fails.
- A snapshot is created with the expected tags and non-zero content.
- MariaDB logical dumps are non-empty and parseable.
- The manifest records repository revision, image identity and component class.
- `restic check` succeeds.

## Restore

- Latest snapshot restores into a disposable empty directory.
- Manifest and staged checksums validate.
- Representative database dumps can be imported into disposable databases.
- Nextcloud user data and metadata agree.
- Paperless documents remain searchable and downloadable.
- Jellyfin users, libraries and watched state recover.
- Homebridge identity, accessories and automations recover without simultaneous
  production advertisement.
- Nginx Proxy Manager hosts and certificates recover.
- Restore time is measured and the achieved RTO is recorded.

# Rollback

Backup implementation rollback removes scheduling and stops invoking the new
operation commands. Existing Restic snapshots are retained; rollback never
deletes the repository. Production services continue to use their existing
persistent roots.

# Explicit Non-Goals

- Backing up cache or Valkey runtime state.
- Treating RAID or same-pool snapshots as disaster recovery.
- Automatically overwriting production during restore.
- Starting a duplicate Homebridge identity.
- Media-library backup without a separately approved capacity policy.
- Database point-in-time recovery or replication.
- Immutable/append-only remote repository service deployment.
- High availability or multi-node orchestration.
- Identity Platform implementation.

# Acceptance Criteria

Sprint 010 is complete only when:

- private backup configuration is documented and protected;
- the repository is initialized with encryption;
- all required platform state produces a consistent snapshot;
- service state is recovered after success and controlled failure;
- integrity checks pass;
- retention is explicit and validated in dry-run before application;
- a disposable restore succeeds without touching production;
- representative application and database recovery succeeds;
- external or independent-device copy status is recorded accurately;
- RPO and measured RTO are documented;
- service README backup and restore procedures use the Operation Layer;
- no private or environment-specific value enters Git.

# Completion Notes

To be completed after target-host backup and disposable restore validation.

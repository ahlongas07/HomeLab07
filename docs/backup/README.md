# HomeLab07 Backup & Recovery

## Purpose

Sprint 010 protects platform state with encrypted Restic snapshots and
application-aware consistency controls. The repository contains policy and
automation; real destinations, passwords and storage paths remain private.

## Prerequisites

- Restic installed from a trusted distribution source.
- Docker access for the HomeLab07 operator.
- A backup destination on an independent filesystem or remote backend.
- An owner-only staging directory outside production and repository paths.
- Enough destination capacity for the initial snapshot and retention policy.

Restic 0.14 or newer is required for repository format 2 and compression. Pin
and review the installed version through normal host maintenance.

## Private Setup

Create the configuration from the example:

```bash
cp operation/backup.env.example ../HomeLab07.private/env/backup.env
chmod 600 ../HomeLab07.private/env/backup.env
```

Create a strong repository password without printing it into shell history,
store it at the configured `RESTIC_PASSWORD_FILE`, and apply mode `600`. Keep an
independent offline copy of this password. Losing it makes the encrypted backup
unrecoverable.

The destination must not be inside the project, private configuration, staging
or production data trees. A local destination must use another filesystem.

## Initial Deployment

```bash
./operation/backup-preflight.sh
./operation/backup-init.sh
./operation/backup-check.sh
```

Initialization is idempotent: an accessible initialized repository is retained.

## Manual Recovery Point

Commit and deploy all repository changes first. Then run:

```bash
./operation/backup.sh
```

The operation:

1. validates prerequisites and storage boundaries;
2. records which stateful services are running;
3. enables Nextcloud maintenance mode;
4. stops filesystem-backed stateful applications without stopping MariaDB;
5. creates a transactionally consistent logical MariaDB dump, including the
   dedicated Keycloak database, and a Git bundle;
6. writes an encrypted platform-state snapshot;
7. checks repository integrity and restores the previous runtime state;
8. generates a versioned `backup-manifest.json` with checksums and results;
9. writes a coordinated manifest snapshot referencing the data snapshot;
10. removes sensitive staging files.

An interrupted run attempts to restore the previous runtime state. Always run
`./operation/status.sh` after an unexpected host or process failure.

## Recovery Manifest

The machine-readable contract is defined in
[`architecture/RECOVERY_MANIFEST.md`](../../architecture/RECOVERY_MANIFEST.md).
The manifest is stored in its own encrypted Restic snapshot because it must
reference the already-created platform-state snapshot ID.

The restore command resolves the manifest first, restores the referenced data
snapshot and verifies every declared artifact checksum. Human-readable Restic
output is never the recovery contract.

## Integrity

Metadata and structural check:

```bash
./operation/backup-check.sh
```

Full repository read, scheduled periodically according to repository size:

```bash
./operation/backup-check.sh --full
```

The full check reads every stored pack and may take significant time.

## Retention

Always review the dry-run first:

```bash
./operation/backup-retention.sh
```

Apply only after a current backup, integrity check and disposable restore pass:

```bash
./operation/backup-retention.sh --apply
```

Retention is intentionally not part of the daily backup command.
Snapshots are grouped by host and recovery tag rather than source paths because
the protected staging directory is unique for every recovery point.

## Disposable Restore

Use an empty location on a non-production filesystem:

```bash
./operation/restore-test.sh latest /path/to/empty-restore-test
```

The command restores files but never starts containers or overwrites production.
Continue with [`DISASTER_RECOVERY.md`](DISASTER_RECOVERY.md) for component-level
validation and [`RECOVERY_MATRIX.md`](RECOVERY_MATRIX.md) for dependency order.
Record sanitized outcomes with
[`VALIDATION_RECORD.md`](VALIDATION_RECORD.md); detailed private evidence remains
outside Git.

## Backup Monitoring

The command exit state, latest coordinated manifest, repository check and
restore test are the operational signals. Sprint 010 installs no scheduler and
claims no automatic RPO.

## Future Evolution

Multiple repositories, S3-compatible backends, append-only storage, off-site
copies, scheduler integration and failure alerts are documented as future work
in `sprints/SPRINT-010.md`. None is represented as active protection in this
Sprint.

## Security

- Repository and password access are separate controls.
- Staging, environment and password files use owner-only permissions.
- Restic encryption does not replace physical security or an offline copy.
- A client with repository delete permission can remove snapshots; a future
  enhancement may add an append-only remote backend.
- Never paste Restic repository URLs, paths, keys or snapshot contents into
  public issues or repository documents.

## Related Sprint

See `sprints/SPRINT-010.md`.

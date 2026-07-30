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
4. stops stateful applications without stopping MariaDB;
5. creates a logical MariaDB dump and Git bundle;
6. writes an encrypted Restic snapshot;
7. checks repository integrity;
8. restores the previous runtime state;
9. removes sensitive staging files.

An interrupted run attempts to restore the previous runtime state. Always run
`./operation/status.sh` after an unexpected host or process failure.

## Daily Automation

Copy the templates under `operation/systemd/` to private host-managed unit
files, replace every placeholder and review them before installation. Do not
commit the rendered units because they contain environment paths and operator
identifiers.

After installation:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now homelab07-backup.timer
systemctl list-timers homelab07-backup.timer
```

Inspect status without copying private paths or application output into Git:

```bash
systemctl status homelab07-backup.service
journalctl -u homelab07-backup.service --since today
```

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

## Disposable Restore

Use an empty location on a non-production filesystem:

```bash
./operation/restore-test.sh latest /path/to/empty-restore-test
```

The command restores files but never starts containers or overwrites production.
Continue with [`DISASTER_RECOVERY.md`](DISASTER_RECOVERY.md) for component-level
validation.

## Backup Monitoring

The timer exit state, last successful snapshot, repository check and restore
test are the operational signals. A running timer alone does not prove a usable
backup.

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

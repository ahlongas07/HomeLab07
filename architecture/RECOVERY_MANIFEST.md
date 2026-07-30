# Recovery Manifest Contract

## Purpose

Every HomeLab07 platform-state backup produces a machine-readable
`backup-manifest.json`. Restore tooling depends on this versioned contract
instead of parsing human-oriented command output.

## Snapshot Relationship

A Restic snapshot ID exists only after its snapshot is written. Therefore one
snapshot cannot contain a manifest that truthfully references its own ID.
HomeLab07 creates two coordinated snapshots:

1. `homelab07-platform-state` contains protected platform data and artifacts.
2. `homelab07-recovery-manifest` contains `backup-manifest.json`, which references
   the exact platform-state snapshot ID.

Restore begins with the manifest snapshot and then resolves the referenced data
snapshot. An unreferenced data snapshot is incomplete evidence and must not be
selected automatically for recovery.

## Version 1.0.0

Required top-level fields:

| Field | Type | Meaning |
|---|---|---|
| `manifest_version` | string | Semantic contract version |
| `timestamp_utc` | string | Completion timestamp in UTC RFC 3339 format |
| `backup_started_utc` | string | Capture start timestamp |
| `restic_snapshot` | object | Referenced data snapshot ID and required tag |
| `git` | object | Revision, ref, worktree state and bundle artifact |
| `operation` | object | Backup operation version and scripts revision |
| `components` | array | Logical platform components included |
| `services` | array | Configured image and runtime image identity per service |
| `databases_exported` | array | Databases present in the logical export |
| `git_repositories` | array | Protected Git repositories and revisions |
| `artifacts` | array | Artifact name, SHA-256 and byte size |
| `backup` | object | Processed bytes, stored bytes, duration and Restic version |
| `retention_policy` | object | Declared policy and whether backup applied it |
| `validations` | object | Named validation outcomes |

Minimum structure:

```json
{
  "manifest_version": "1.0.0",
  "timestamp_utc": "YYYY-MM-DDTHH:MM:SSZ",
  "backup_started_utc": "YYYY-MM-DDTHH:MM:SSZ",
  "restic_snapshot": {
    "id": "64-character-lowercase-hex-id",
    "tag": "homelab07-platform-state"
  },
  "git": {
    "revision": "commit-id",
    "ref": "tag-or-commit-description",
    "worktree_status": "clean",
    "bundle_artifact": "repository.bundle"
  },
  "operation": {
    "version": "1.0.0",
    "scripts_git_revision": "commit-id"
  },
  "components": [],
  "services": [],
  "databases_exported": [],
  "git_repositories": [],
  "artifacts": [],
  "backup": {
    "total_bytes_processed": 0,
    "data_added_bytes": 0,
    "duration_seconds": 0,
    "restic_version": "restic version string"
  },
  "retention_policy": {
    "keep_daily": 7,
    "keep_weekly": 4,
    "keep_monthly": 6,
    "keep_yearly": 1,
    "applied_by_backup": false
  },
  "validations": {}
}
```

Values shown above are placeholders or neutral examples. Real database and
runtime identities exist only inside the encrypted backup repository.

`backup.duration_seconds` measures the coordinated platform capture through
repository verification and restoration of the prior runtime state. It excludes
the subsequent small manifest-snapshot write. `data_added_bytes` is the storage
reported by Restic for the platform-state snapshot, not repository-wide usage.

## Validation Rules

- Unsupported major manifest versions fail closed.
- The referenced Restic ID must be 64 lowercase hexadecimal characters.
- The data snapshot must carry `homelab07-platform-state`.
- Every artifact must restore exactly once and match its SHA-256.
- Every artifact byte size must match the manifest.
- Database and repository artifacts must be non-empty.
- Git worktree status must be `clean` for scheduled platform backups.
- Required validations must equal `pass` before a manifest is accepted.
- Retention remains a separate operation and is never inferred from policy
  declaration alone.

## Compatibility

Additive optional fields may be introduced in a minor contract version. A
renamed field, changed meaning or incompatible type requires a new major
version and explicit restore-tool support. Old manifests remain immutable.

## Security

The manifest may contain database names, image IDs and operational metadata.
It belongs only inside the encrypted Restic repository and disposable restore
evidence. Scripts print only the contract version, shortened snapshot IDs and
sanitized counts.

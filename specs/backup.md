# Backup and Recovery Capability

**Status:** Implemented; validated recovery point and disposable restore

## Required behavior

- Produce encrypted, deduplicated recovery points from repository state,
  approved private configuration, application state and a consistent logical
  MariaDB dump.
- Quiesce stateful writers for a coordinated capture and restore their prior
  running state after the operation.
- Publish a versioned recovery manifest with checksums and explicit artifact
  identities.
- Verify repository integrity and support restore into an empty disposable
  destination before production recovery is considered.
- Keep the repository outside the production data trees; a copy on the same
  NAS is not protection against NAS loss.

## Boundaries

Production restore remains a reviewed operator action. Backup credentials,
destinations and private paths stay outside Git. Source media and other NAS
authoritative data follow their own storage protection policy. The capability
does not claim an automatic schedule or RPO unless separately implemented and
validated.

## Operational references

- [Backup and recovery procedure](../docs/backup/README.md)
- [Recovery manifest contract](../architecture/RECOVERY_MANIFEST.md)
- [Recovery matrix](../docs/backup/RECOVERY_MATRIX.md)
- [Sprint 010 decision and evidence](../sprints/SPRINT-010.md)

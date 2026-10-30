# Medical Records Ingestion Capability

**Status:** Implemented and validated on the target host; Sprint 015 closure
pending residual work

## Required behavior

- Archive the owner's medical exams in Paperless-ngx from an authoritative,
  read-only NAS folder that is never modified, moved or deleted.
- Upload through the Paperless-ngx REST API (version 10) from a dedicated
  container that uses only the Python standard library and a pinned `qpdf`.
- Sync at start-up, after a settled change in the source folder and daily as a
  fallback; defer files still being copied.
- Identify each exam by its NFC-normalized relative path (`Ruta origen`) and
  original hash; report modified files, duplicates, unsupported formats and
  encrypted PDFs without a working password instead of re-uploading.
- Derive date, title and category tag from the path, removing personal data
  configured privately from titles and masking it in logs.
- Assign every exam to the owner's personal user through a workflow; the
  `sync-medico` service user can create and view exams but never change them.
- Publish batch metrics used by the platform batch alerts and the Operations
  dashboard.

## Boundaries

No public route, host port or listener; the container reaches Paperless only
on `homelab07-internal`. No change to the NAS operating system. Tokens, PDF
passwords, the source path, personal-data patterns and the category map stay
in private configuration. The sync holds no persistent state; the original
folder is outside Restic scope and protected by the NAS data backup, and the
platform backup only stops and restores the sync around Paperless.
Read-only consumers, such as the medical agent, are reconciled by `model-init`
to view-only rights and use an API token through the public route; their
data reaches the agent's model provider, an accepted risk. Their view rights
cover only the contract tags and the exam owner's correspondents and exams;
`model-init` never shares or reassigns objects of another owner, such as
JuanchoAI's, and warns about objects without owner (Sprint 019). Re-upload or
versioning of changed exams, health-application exports and any write access
for agents are not accepted behavior.

## Operational references

- [Paperless Medical Sync service procedure](../services/paperless-medical-sync/README.md)
- [Recovery matrix](../docs/backup/RECOVERY_MATRIX.md) and
  [disaster recovery](../docs/backup/DISASTER_RECOVERY.md)
- [Alert runbook](../docs/observability/ALERTS.md#batch-operation-failed-or-stale)
- [Medical agent access](../docs/security/MEDICAL_AGENT_ACCESS.md)
- [JuanchoAI access](../docs/security/JUANCHOAI_ACCESS.md) and
  [Paperless permission findings](../docs/security/PAPERLESS_PERMISSIONS.md)
- [Sprint 015 contract and closure evidence](../sprints/SPRINT-015.md)
- [Sprint 019 user isolation](../sprints/SPRINT-019.md)

# Quote Archive Capability

**Status:** Implemented in Sprint 020; target-host validation pending

## Required behavior

- Archive the final PDF of each JuanchoAI quote in Paperless-ngx as the
  `juanchoai` user from an authoritative NAS folder that the JuanchoAI API
  writes and that is never modified, moved or deleted by the platform.
- Upload through the Paperless-ngx REST API (version 10) from a dedicated
  container that uses only the Python standard library and a pinned `qpdf`.
- Sync at start-up, after a settled change in the folder, after
  `QUOTE_RETRY_SECONDS` while an upload is unconfirmed, and daily as a
  fallback; defer files still being written.
- Enforce the contract: `<YYYY>/<uuid>__<external_id>__<YYYY-MM-DD>.pdf` with
  a canonical lowercase UUID, `external_id` in `[A-Za-z0-9-]{1,64}`, a valid
  date whose year equals the folder, and an unencrypted PDF of 20 MB or less;
  anything else is rejected and never uploaded.
- Identify each quote by the `Work Item` custom field: an existing document
  with the same SHA-256 is skipped, a different content or more than one
  document is a conflict, and an upload is confirmed by the `Work Item` search
  and `original_checksum`, never by `/api/tasks/`.
- Report a file that Paperless does not confirm after the configured attempts
  as a failure and stop retrying it; keep rejected, conflict and failure files
  unresolved until the operator acknowledges their path and SHA-256.
- Publish metrics for the pending, unresolved and heartbeat alerts.

## Boundaries

No public route, host port or listener; the container reaches Paperless only
on `homelab07-internal` with the `juanchoai` token, which the JuanchoAI API
shares. The sync creates no Paperless object and knows nothing about the
JuanchoAI API; the DONE rule belongs to JuanchoAI. The folder, the token and
the acknowledgement list stay in private configuration; the folder is outside
Restic scope and protected by the NAS data backup, and the platform backup
only stops and restores the sync around Paperless. The API and the sync run
with the platform operator UID, an accepted risk while JuanchoAI is a proof of
concept. Nothing medical is reused: the medical users, workflow and fields
never apply to quotes, and `juanchoai` never sees exams.

## Operational references

- [Paperless Quote Sync service procedure](../services/paperless-quote-sync/README.md)
- [JuanchoAI access](../docs/security/JUANCHOAI_ACCESS.md) and
  [Paperless permission findings](../docs/security/PAPERLESS_PERMISSIONS.md)
- [Recovery matrix](../docs/backup/RECOVERY_MATRIX.md) and
  [disaster recovery](../docs/backup/DISASTER_RECOVERY.md)
- [Alert runbook](../docs/observability/ALERTS.md#quote-archive-sync)
- [Sprint 020 contract and closure evidence](../sprints/SPRINT-020.md)

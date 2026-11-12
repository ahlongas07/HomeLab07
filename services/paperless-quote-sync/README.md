# Paperless Quote Sync

## Purpose

Archives the final PDF of each JuanchoAI quote in Paperless-ngx as the
`juanchoai` user, within minutes of the JuanchoAI API writing it to a NAS
folder. The NAS keeps the original under the NAS data backup; Paperless is the
searchable archive that JuanchoAI checks before a Work Item reaches DONE. The
folder is never modified. Sprint 020 delivers this service.

## Responsibilities

- Walk the read-only quotes folder and upload every new PDF that follows the
  contract through the Paperless-ngx API (version 10).
- Detect changes in the folder by polling and start a sync once they settle;
  keep a daily run as a fallback.
- Validate the file name, year folder and PDF against the contract; reject
  anything else without uploading it.
- Identify each quote by its `Work Item` custom field and confirm the upload
  by searching that field and comparing SHA-256 checksums; never use
  `/api/tasks/`.
- Report rejected files, conflicts and permanent failures as unresolved until
  the operator acknowledges them, and publish metrics for the Grafana alerts.

The service does not modify the folder, knows nothing about the JuanchoAI API
and opens no network listener. It creates no Paperless object: the `juanchoai`
user, the `Cotización` type, the `juanchoai` and `cotizacion-final` tags and
the `Work Item` field exist since 2026-10-30 (see
[JuanchoAI Access](../../docs/security/JUANCHOAI_ACCESS.md)).

## Technology

| Capability | Selection |
|---|---|
| Image | Built locally from `python:3.13-alpine3.24` pinned by digest, the same base as the medical sync |
| PDF check | `qpdf` 12.3.2-r0 (`--requires-password`) |
| Code | Python standard library only, no `pip` packages |
| Scheduling | Container entrypoint loop: run at start, on settled folder changes, every `QUOTE_RETRY_SECONDS` while something is unconfirmed, and daily |
| Change detection | Standard-library `stat` polling of the folder; no inotify |
| Paperless access | REST API version 10 on `homelab07-internal` with the `juanchoai` token |

## Directory Structure

```text
services/paperless-quote-sync/
├── .env.example
├── Dockerfile
├── README.md
├── compose.yaml
├── entrypoint.sh
├── quote_sync.py
└── tests/
    └── test_quote_sync.py
```

The tests are not copied into the image.

Runtime mounts:

| Container path | Source | Access |
|---|---|---|
| `/quotes` | `QUOTES_SOURCE_ROOT` (the JuanchoAI quote folder, polled for changes) | read-only |
| `/metrics` | `QUOTE_SYNC_METRICS_ROOT` (observability textfile directory) | read-write |
| `/acknowledged` | `HomeLab07.private/env/paperless-quote-sync.ack` (acknowledgement list) | read-only |
| `/run/sync` | size-limited `tmpfs` (lock, heartbeat, folder snapshot, attempt counters) | read-write |

The root filesystem is read-only, all capabilities are dropped and the process
runs as `QUOTE_SYNC_UID:QUOTE_SYNC_GID`, the platform operator identity that
owns the quotes folder.

## Contract with JuanchoAI

The contract is identical in this README, the
[quote archive specification](../../specs/quote-archive.md) and the JuanchoAI
specification.

| Item | Agreement |
|---|---|
| Location | `QUOTES_SOURCE_ROOT`, one subfolder per year (`<YYYY>/`). Mounted as `/quotes` in both containers: read-write in the API, read-only here. |
| File name | `<uuid>__<external_id>__<YYYY-MM-DD>.pdf`, exactly two `__` separators. `uuid` is the Work Item ID as a canonical lowercase UUID; `external_id` matches `[A-Za-z0-9-]{1,64}`; the date is a valid issue date whose year equals the folder. Anything else is `rejected`. |
| Atomic write | The API writes `.<name>.tmp` and renames it. Files that start with `.` or do not end in `.pdf` are ignored. |
| Immutability | A file is never deleted, overwritten or renamed. At most one PDF per `uuid`. |
| Content | Uploaded unchanged, so the Paperless `original_checksum` equals the file's SHA-256. |
| Limit | 20 MB, unencrypted PDF. |
| Permissions | Folder owned by the platform operator user and group, mode `750`; files `640`. Both containers run as that UID/GID, never as root. |
| In Paperless | Owner `juanchoai`, type `Cotización`, tags `juanchoai` and `cotizacion-final`, `Work Item` = `uuid`, title = `external_id`, created = date from the name. |
| Verification by JuanchoAI | `custom_field_query=["Work Item","exact","<uuid>"]`, then compare the file's SHA-256 with `original_checksum` from `/api/documents/<id>/metadata/`. Never `/api/tasks/`. |
| Expected latency | Under 5 minutes between the rename and the document appearing in Paperless. |

## Configuration

```bash
cp services/paperless-quote-sync/.env.example \
  ../HomeLab07.private/env/paperless-quote-sync.env
chmod 600 ../HomeLab07.private/env/paperless-quote-sync.env
install -m 0600 /dev/null ../HomeLab07.private/env/paperless-quote-sync.ack
```

The acknowledgement file must exist before the first start, even empty:
Docker would otherwise create a directory in its place.

| Variable | Purpose |
|---|---|
| `QUOTES_SOURCE_ROOT` | Host folder where the JuanchoAI API writes the quotes |
| `QUOTE_SYNC_METRICS_ROOT` | Same host path as `HOMELAB07_OBSERVABILITY_METRICS_ROOT` |
| `QUOTE_SYNC_UID`, `QUOTE_SYNC_GID` | Platform operator identity that owns the folder and can write metrics |
| `QUOTE_SYNC_MEMORY_LIMIT` | Container memory limit |
| `PAPERLESS_INTERNAL_URL` | Paperless on `homelab07-internal` |
| `TZ` | Same value as `PAPERLESS_TIME_ZONE` |
| `QUOTE_SYNC_HOUR` | Hour of the daily fallback run |
| `QUOTE_WATCH_INTERVAL`, `QUOTE_SETTLE_SECONDS` | Folder polling interval and stabilization time (`0` disables the watcher) |
| `QUOTE_RETRY_SECONDS` | Next attempt while Paperless is unreachable, a run failed or an upload is unconfirmed |
| `QUOTE_STARTUP_WAIT` | Maximum wait for Paperless after a start |
| `QUOTE_CONFIRM_TIMEOUT` | Seconds to wait for an upload to appear in the `Work Item` search |
| `QUOTE_MAX_ATTEMPTS` | Uploads of the same content before it is reported as `failure` |
| `QUOTE_HEARTBEAT_SECONDS` | Heartbeat metric refresh while waiting for changes |
| `PAPERLESS_QUOTE_TOKEN` | API token of the `juanchoai` user, the same the JuanchoAI API uses |

The token reaches only Paperless inside `homelab07-internal`. Paperless allows
one token per user, so the API and the sync share it; rotation updates both
private environment files (see [JuanchoAI Access](../../docs/security/JUANCHOAI_ACCESS.md)).

## Deployment

1. Confirm the folder: owned by the platform operator user and group, mode
   `750`, outside Restic scope and covered by the NAS data backup, and that the
   file-sharing configuration of its share does not alter permissions.
2. Create the private environment and the acknowledgement file as above.
3. Build and verify the data model without writing anything:

   ```bash
   ./operation/compose.sh paperless-quote-sync build
   ./operation/compose.sh paperless-quote-sync run --rm paperless-quote-sync quote-sync check-model
   ./operation/compose.sh paperless-quote-sync run --rm paperless-quote-sync quote-sync preview
   ```

   `check-model` fails if the type, tags or field are missing or the type or
   tags belong to another user. `preview` lists every file with its
   validation result and the metadata a sync would send.
4. Start the service:

   ```bash
   ./operation/compose.sh paperless-quote-sync up -d --build
   ./operation/compose.sh paperless-quote-sync logs --tail=50
   ```

   The first run reports existing quotes as `skipped` and uploads only new
   valid files.
5. After the first metrics are published, apply the alert rules with
   `./operation/compose.sh observability up -d grafana`; the watcher alert
   treats absent metrics as a down container.

### Processing each file

1. Name and year folder are validated against the contract; otherwise
   `rejected`, logged, never uploaded.
2. The file is validated: PDF, not encrypted, 20 MB or less; otherwise
   `rejected`.
3. Paperless is searched for `Work Item` = `uuid`:
   - exactly one document with the same SHA-256: `skipped`;
   - exactly one with a different SHA-256, or more than one: `conflict`;
   - none: upload.
4. The upload carries the contract metadata; Paperless makes the uploader
   the owner.
5. Confirmation polls the `Work Item` search until the document appears with
   the right SHA-256 or `QUOTE_CONFIRM_TIMEOUT` expires. On timeout the file is
   `pending` and the next run, after `QUOTE_RETRY_SECONDS`, repeats step 3; a
   late confirmation is then `skipped`.
6. After `QUOTE_MAX_ATTEMPTS` uploads without confirmation the file is
   `failure`: it is not uploaded again until it is acknowledged, and a changed
   content (new SHA-256) counts as a new file. This is how a file that
   Paperless discards as a duplicate of any user's document, including the
   trash, is detected: `juanchoai` cannot see that task.

The attempt counters live in the `tmpfs`, so after a container restart a file
is retried up to `QUOTE_MAX_ATTEMPTS` times again; accepted, because every
attempt is idempotent and bounded.

A run that fails before it completes, for example an invalid token (`HTTP
401`), a missing Paperless object or an HTTP error while reading metadata,
exits with status `4` (`75` when Paperless is unreachable) and is retried
after `QUOTE_RETRY_SECONDS`; it never waits for the daily run. Its metrics keep
the pending and unresolved values of the last completed run, so the pending
and review alerts neither resolve nor fire because of the failure; the failing
alert reports it instead.

### Acknowledging a file

A file stops counting as unresolved, and as pending, when its relative path
and SHA-256 appear in `HomeLab07.private/env/paperless-quote-sync.ack`, one
`<relative path> <sha256>` per line (`#` starts a comment). The list is read
again on every run; no restart is needed. If the file content changes, the
SHA-256 no longer matches and the file counts again. The PDF stays on the NAS
as evidence. `preview` prints the SHA-256 prefix; the full value comes from
`sha256sum` on the host.

| Result | Review |
|---|---|
| `rejected` | Review the log reason and acknowledge. If the quote is needed, JuanchoAI writes it again with a valid name. |
| `conflict` | Decide which PDF is correct. If it is the one in Paperless, acknowledge the new file. If it is the new one, correct the document by hand in Paperless, then acknowledge. More than one document with the same `Work Item`, for example one uploaded by hand, is also a conflict. |
| `failure` | Check whether the content already exists in Paperless, in the documents of any user or in the trash. Restore it from the trash or reassign it to `juanchoai` if that is the intended archive, then acknowledge; otherwise investigate the Paperless log before acknowledging. |

### Manual run

```bash
./operation/compose.sh paperless-quote-sync exec paperless-quote-sync quote-sync sync
```

A manual run and the scheduled loop share a lock; the second one exits
without doing anything.

## Validation

- `python3 -m unittest discover -s services/paperless-quote-sync/tests` (name
  format, PDF checks, the decision table, attempt limit, acknowledgement list,
  metrics, failed runs and the heartbeat during confirmation).
- `python3 -m py_compile services/paperless-quote-sync/quote_sync.py`,
  `bash -n services/paperless-quote-sync/entrypoint.sh` and
  `./operation/compose.sh paperless-quote-sync config --quiet`.
- `check-model` succeeds and `docker port homelab07-paperless-quote-sync`
  returns no mappings.
- Target-host acceptance criteria QS-01 to QS-17 of
  [Sprint 020](../../sprints/SPRINT-020.md).
- `./operation/paperless-access-check.sh juanchoai` passes after the first
  upload.

## Observability

The sync writes `paperless-quote-sync.prom` with the prefix
`homelab07_paperless_quote_sync_`:

| Metric | Meaning |
|---|---|
| `last_run_timestamp_seconds`, `last_success_timestamp_seconds`, `last_status`, `last_duration_seconds` | The latest completed attempt |
| `heartbeat_timestamp_seconds` | Refreshed by every run and every `QUOTE_HEARTBEAT_SECONDS` while watching or while a confirmation polls Paperless |
| `files{result}` | Files per result in the latest attempt: `uploaded`, `skipped`, `rejected`, `conflict`, `failure`, `pending`, `deferred`, `acknowledged`; history, no alert |
| `pending_files`, `oldest_pending_timestamp_seconds`, `oldest_pending_age_seconds` | Valid files not confirmed in Paperless (`pending` and `failure`), acknowledged ones excluded |
| `unresolved{reason}` | `rejected`, `conflict` and `failure` files awaiting review, acknowledged ones excluded |

Alerts, provisioned in Grafana:

- "Quote archive file pending too long": the oldest pending file reached the
  folder more than 15 minutes ago.
- "Quote archive files need review": any unresolved `rejected`, `conflict` or
  `failure`.
- "Quote archive sync is down": the heartbeat metric is older than 15 minutes
  or absent.
- "Quote archive sync failing": the latest run has been failing for 15
  minutes (invalid token, missing Paperless object or Paperless errors).

The runbook is [Quote archive sync](../../docs/observability/ALERTS.md#quote-archive-sync).
The sync is not part of "Platform batch operation failed": a failed attempt is
retried after `QUOTE_RETRY_SECONDS` and the failing alert reports it after 15
minutes. Logs are read with `docker logs`; they show file names (Work Item ID,
external ID and date), never the token or the PDF content.

## Backup

The service holds no persistent state (only `tmpfs`). Archived quotes are
protected with Paperless (MariaDB and `PAPERLESS_ROOT`). The quotes folder is
the source of truth; it is outside Restic scope and protected by the NAS data
backup. During a platform backup the container is stopped before Paperless
and started again afterwards if it was running, so no false pending alert is
recorded. API tokens are not part of Paperless exports and must be recreated
after a restore.

## Restore

1. Restore Paperless-ngx.
2. Restore the quotes folder from the NAS data backup with the same relative
   paths and grant the platform operator UID read access.
3. Recover the repository and the private environment and acknowledgement
   files, recreate the `juanchoai` token and update it in both private
   environment files.
4. Start the service with
   `./operation/compose.sh paperless-quote-sync up -d --build`; existing
   quotes are `skipped` by `Work Item` and SHA-256.

The full order is in the
[recovery matrix](../../docs/backup/RECOVERY_MATRIX.md).

## Rollback

1. `./operation/compose.sh paperless-quote-sync down`; Paperless keeps
   running and JuanchoAI answers `QUOTATION_ARCHIVE_PENDING`.
2. Remove the quote archive alert rules and delete
   `paperless-quote-sync.prom`.
3. The files stay on the NAS; archived documents are not touched.

## Security

- No published ports, no proxy network and no public route; the token
  reaches only Paperless inside `homelab07-internal`.
- Isolation relies on Paperless object ownership (Sprint 019): uploads are
  owned by `juanchoai`, the JuanchoAI type and tags use matching "None", and
  the medical workflow triggers only on the `medico` tag.
- The sync's only write targets are its `tmpfs` and the metrics directory.
- Accepted risk: the API and the sync share the platform operator UID, so an
  escape from either container reaches the other data of that user; review it
  if JuanchoAI leaves the proof-of-concept stage.
- Accepted risk: the API and the sync share the `juanchoai` token, because
  Paperless allows one token per user.
- Secrets live only in the private environment file (mode `600`); they are
  visible through `docker inspect`, like other platform passwords.
- The image is included in the vulnerability scan scope as a locally built
  image: `./operation/security-scan.sh scan` exports it with `docker save`
  and scans the archive, so build it before scanning.

## Related Sprint

- Sprint 020 — Paperless Quote Sync
- Sprint 019 — Paperless User Isolation

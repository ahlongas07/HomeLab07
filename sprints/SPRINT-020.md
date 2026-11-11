# SPRINT-020 — Paperless Quote Sync (JuanchoAI Quote Archive)

**Status:** Approved 2026-11-11 after team review — implemented, target-host validation pending

**Classification:** Application Service

**Phase:** Phase 2 — Shared Platform Capabilities

**Depends On:** Sprint 019 Paperless user isolation (completed 2026-11-05)

## Objective

JuanchoAI writes the final PDF of each quote to a folder on the NAS. A new
HomeLab07 container, `paperless-quote-sync`, archives it in Paperless-ngx as
the `juanchoai` user. The NAS keeps the original under the NAS data backup and
Paperless is the searchable archive. JuanchoAI verifies the archived document
directly in Paperless before it allows a Work Item to reach DONE.

The container knows nothing about the JuanchoAI API: it reads a folder,
uploads to Paperless and publishes metrics.

## Scope

### Included

- Mounting the quotes folder and confirming its backup coverage.
- `services/paperless-quote-sync`: code, image, `compose.yaml`,
  `.env.example`, tests and README.
- Metrics and Grafana alerts.
- Documenting the JuanchoAI API access to Paperless over
  `homelab07-internal`.
- `operation/paperless-access-check.sh`: the `juanchoai` profile checks that
  every visible document is owned by `juanchoai` and none carries the `medico`
  tag, instead of requiring zero visible documents (ISO-02); the `examen`
  search must still return `0`.
- Documentation in `docs/security/JUANCHOAI_ACCESS.md`, `specs/backup.md` and
  a new capability specification under `specs/`.

### Excluded

- The JuanchoAI API and its DONE rule (JuanchoAI Sprint 008), including the
  API's own Compose definition, mount and user.
- Anything medical. The medical `model-init`, personal-data cleanup,
  categories, read-only users and the `Ruta origen` and `Hash origen` fields
  are not reused.
- Creating users or objects in Paperless: the `juanchoai` user, the
  `Cotización` type, the `juanchoai` and `cotizacion-final` tags and the
  `Work Item` field exist since 2026-10-30.

## Contract with JuanchoAI

Identical in the HomeLab07 and JuanchoAI specifications.

| Item | Agreement |
|---|---|
| Location | A NAS folder set privately as `QUOTES_SOURCE_ROOT`, with one subfolder per year (`<YYYY>/`). Mounted as `/quotes` in both containers: read-write in the API, read-only in the sync. |
| File name | `<uuid>__<external_id>__<YYYY-MM-DD>.pdf`, with exactly two `__` separators. `uuid` is the Work Item ID as a canonical lowercase UUID (`[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`). `external_id` matches `[A-Za-z0-9-]{1,64}`, for example `RFQ-123-R1`: no underscores, spaces or accented characters. The date is the issue date as a valid calendar date, and the year subfolder must match its year. Any other name is `rejected`. |
| Atomic write | The API writes `.<name>.tmp` and then renames it. The sync ignores every file that starts with `.` or does not end in `.pdf`. |
| Immutability | A file is never deleted, overwritten or renamed. At most one PDF per `uuid`. |
| Content | The sync uploads the file unchanged, so the Paperless checksum equals the file's SHA-256. |
| Limit | 20 MB, unencrypted PDF. |
| User and permissions | The folder is owned by the platform operator user and group with mode `750`. The API and the sync run with the platform operator UID/GID, never as root. The API creates year subfolders with `750` and files with `640` (umask `0027`). |
| In Paperless | Owner `juanchoai`, type `Cotización`, tags `juanchoai` and `cotizacion-final`, `Work Item` = `uuid`, title = `external_id`, created = date from the file name. |
| Verification | Search with `custom_field_query=["Work Item","exact","<uuid>"]` and compare the file's SHA-256 with `original_checksum` from `/api/documents/<id>/metadata/`. Never use `/api/tasks/`. |
| Expected latency | Under 5 minutes between the rename and the document appearing in Paperless. |

Paperless-ngx 3.4.1 stores SHA-256 checksums (migration
`0016_sha256_checksums`); the earlier MD5 assumption does not apply.

## Requirements

### QS-R1 — NAS folder

- The folder exists since 2026-11-05, owned by the platform operator user and
  group with mode `750`.
- Mounted read-write only in the JuanchoAI API and read-only in the sync; no
  other service mounts it.
- The project owner confirms that the file-sharing configuration of the share
  that contains the folder (forced user, create mask or similar options) does
  not alter its permissions.
- The folder is outside Restic scope and protected by the NAS data backup, an
  off-site cloud copy managed outside HomeLab07. The project owner confirms
  that a test PDF in a new year subfolder reaches that copy;
  `specs/backup.md` and the recovery matrix document it.
- Accepted risk: the API and the sync share the platform operator UID, so an
  escape from either container reaches the other data of that user,
  including the medical exam originals. Review it if JuanchoAI leaves the
  proof-of-concept stage.

### QS-R2 — Container

- The same hardening as `paperless-medical-sync`: `read_only`,
  `cap_drop: ALL`, `no-new-privileges`, memory, CPU and PID limits, network
  `homelab07-internal`, heartbeat healthcheck, and secrets only through
  `env_file` in `HomeLab07.private/env/paperless-quote-sync.env`.
- Python standard library only.
- Reuses the medical sync patterns: API v10 client with its own User-Agent,
  polling watcher with a stabilization time, `wait-ready`, `preview`, retries
  and text-file metrics for Alloy.
- Watcher state lives in tmpfs, never in `/quotes`.

### QS-R3 — Commands

- `sync`: watcher mode, the normal mode.
- `preview`: lists what would be uploaded, without writing anything.
- `check-model`: verifies that the type, tags and field exist and that the
  type and tags are owned by `juanchoai`. Fails if anything is missing. Creates
  nothing.
- `wait-ready`.

### QS-R4 — Processing each file

1. Validate the name and year subfolder against the contract. Otherwise
   `rejected`: not uploaded, logged.
2. Validate the file: PDF, not encrypted, 20 MB or less. Otherwise
   `rejected`.
3. Search Paperless for `Work Item` = `uuid`:
   - exactly one document with the same SHA-256: `skipped`;
   - exactly one document with a different SHA-256: `conflict`, nothing is
     uploaded;
   - more than one document, for example one uploaded by hand: `conflict`,
     nothing is uploaded;
   - not found: upload.
4. Upload with `post_document`, with the `juanchoai` token and the contract
   metadata.
5. Confirm without `/api/tasks/`: poll the `Work Item` search until the
   document appears with the correct SHA-256 or `QUOTE_CONFIRM_TIMEOUT`
   expires. On timeout, `failure`; step 3 retries it in the next cycle.
6. Paperless discards a file whose content duplicates any existing document
   of any user, including the trash; this also happens when someone moves an
   archived quote to the Paperless trash, because the sync uploads the file
   again. `juanchoai` cannot see that task, so the sync detects it only as a
   confirmation timeout: after the configured number of attempts the file is
   reported as `failure` with an alert and is not uploaded again; it stays
   unresolved until it is acknowledged, and a changed content (new SHA-256)
   counts as a new file. The attempt counter lives in the
   watcher tmpfs, so after a container restart the file is retried up to the
   configured number of attempts again; accepted, because every retry is
   idempotent and bounded.

### QS-R5 — Metrics and alerts

- Prefix `homelab07_paperless_quote_sync_`.
- Files per result in the latest run: `uploaded`, `skipped`, `rejected`,
  `conflict`, `failure`, `pending`, `deferred` and `acknowledged`. They are
  history and raise no alert.
- Gauges: last run and last successful run, watcher heartbeat, pending files,
  age of the oldest pending file, and
  `unresolved{reason="rejected|conflict|failure"}`.
- Alerts are based on unresolved files, not on counters. A file stops
  counting as unresolved, and as pending, when its relative path and SHA-256
  appear in the acknowledgement list
  `HomeLab07.private/env/paperless-quote-sync.ack` (one
  `<relative path> <sha256>` per line), mounted read-only and read again on
  every cycle, without restarting the container. If the content changes, the
  SHA-256 no longer matches and the file counts again. The PDF stays on the
  NAS as evidence.
- Grafana alerts:
  - a file has not appeared in Paperless after 15 minutes;
  - any unresolved `rejected`, `conflict` or `failure`;
  - the container is down or its heartbeat expired (older than 15 minutes).
- Logs never show the token or PDF content.
- The README documents the review and acknowledgement procedure:
  - `rejected`: review and acknowledge; if the quote is needed, JuanchoAI
    sends it again with a valid name.
  - `conflict`: decide which PDF is correct. If it is the one in Paperless,
    acknowledge the new file. If it is the new one, correct the document by
    hand in Paperless, then acknowledge.
  - `failure`: check whether the content already exists in Paperless, in the
    documents of any user or in the trash. Restore it from the trash or
    reassign it to `juanchoai` if that is the intended archive, then
    acknowledge; otherwise investigate the Paperless log before acknowledging.

### QS-R6 — JuanchoAI API access

- The API reaches Paperless over `homelab07-internal` at
  `http://homelab07-paperless-ngx:8000`, without Cloudflare. The API container
  already joins that network (checked 2026-11-05).
- The API uses the same `juanchoai` token, because Paperless allows one token
  per user. Accepted risk for the proof of concept.
- `JUANCHOAI_ACCESS.md` documents the two token consumers, the folder and its
  permissions, and token rotation, which now updates two `env_file`s.

## Acceptance criteria

| ID | Scenario | Expected |
|---|---|---|
| QS-01 | Copy a valid PDF with a contract name | In Paperless within 5 minutes with the correct owner, type, tags, `Work Item`, title and date |
| QS-02 | Process the same file again, for example after a restart | `skipped`, no duplicate |
| QS-03 | Write `.x.tmp` and rename it mid-cycle | The final file is uploaded once |
| QS-04 | Invalid name, wrong year subfolder, non-PDF, encrypted PDF and PDF over 20 MB | `rejected`, nothing in Paperless, alert |
| QS-05 | A second, different PDF with the same `uuid` | `conflict`, nothing new, alert |
| QS-06 | Paperless stopped while a file arrives | Retries; when Paperless returns the file is uploaded once |
| QS-07 | File SHA-256 compared with `original_checksum` | Equal |
| QS-08 | Search the uploaded document with the `agente-medico` token | Not visible; the medical workflow did not run |
| QS-09 | `paperless-access-check.sh juanchoai` after deployment, with the adjusted ISO-02 | Passes: every visible document is owned by `juanchoai`, none has the `medico` tag, and the `examen` search stays `0` |
| QS-10 | A file pending over 15 minutes, simulated with an invalid token | The alert fires |
| QS-11 | `preview` | Lists files without uploading |
| QS-12 | End-to-end test with JuanchoAI | The API writes, the sync uploads and the API allows DONE |
| QS-13 | From the sync, create a file in `/quotes`; from the API, list a path outside `/quotes` | Both fail: read-only file system and path not found |
| QS-14 | Acknowledge a `rejected` file, then modify that file | The alert resolves; when the SHA-256 changes it fires again |
| QS-15 | A test PDF in a new year subfolder | Present in the NAS data backup copy (confirmed by the project owner) |
| QS-16 | Move an archived quote to the Paperless trash, let the sync exhaust its attempts, then acknowledge the file | `failure` with alert, no retry loop; after the acknowledgement both the unresolved and the pending alerts resolve |
| QS-17 | Names with `__` inside `external_id`, a space, an accented character, an uppercase UUID or an invalid date | All `rejected` |

QS-12 runs together with JuanchoAI when its Sprint 008 is ready. Until then
HomeLab07 tests with sample PDFs copied by hand.

## Architecture and security contracts

- No new network, route or public exposure. The sync joins
  `homelab07-internal` only.
- The sync's only write targets are its tmpfs and the metrics directory.
- The token reaches only Paperless inside `homelab07-internal`.
- Isolation relies on Paperless object ownership (Sprint 019): uploads are
  owned by `juanchoai`, the JuanchoAI type and tags use matching "None", and
  the medical workflow triggers only on the `medico` tag.
- No integration depends on `/api/tasks/`.

## Assumptions

- Confirmed 2026-11-05: the JuanchoAI API runs on the same host and joins
  `homelab07-internal`.
- Confirmed 2026-11-05 in the Paperless-ngx 3.4.1 source: `/api/documents/`
  accepts `checksum__iexact` and `custom_field_query`, and `post_document`
  accepts `custom_fields` and `created`.
- JuanchoAI changes its API container from the image default user (`65532`)
  to the platform operator UID/GID (JuanchoAI Sprint 008). Until then the API
  cannot write to the folder. An ACL for `65532` is not used: files would be
  owned by a UID that does not exist on the NAS and permissions become harder
  to audit. The folder is never opened to `770` or `777`.

## Validation

- `py_compile` and standard-library unit tests for the exact name format,
  PDF checks, the decision table of QS-R4 including more than one document
  per `Work Item`, the attempt limit and the acknowledgement list.
- `docker compose config` and shell syntax checks.
- Target-host acceptance criteria QS-01 to QS-17.

## Rollback

Stop the container. The files stay on the NAS and archived documents are not
touched. Meanwhile JuanchoAI answers `QUOTATION_ARCHIVE_PENDING`.

## Closure record

Record outcome, sanitized validation summary and deviations here.
Detailed private evidence remains in its approved private location.
Update the affected living specification under `/specs` before marking this
Sprint complete.

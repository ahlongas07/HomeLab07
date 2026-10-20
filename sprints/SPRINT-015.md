# SPRINT-015 — Medical Records Ingestion

**Status:** In progress — implementation complete; target validation pending

**Classification:** Application Service

**Phase:** Phase 3 — Local Services And Platform Operations

**Selected Technology:** Existing Paperless-ngx 3.3.3 REST API (API version 10); dedicated minimal container (`python:3.13-alpine` + `qpdf`)

**Depends On:** Paperless-ngx 3 upgrade target validation (including the Valkey-backed task system), Sprint 013 textfile metrics

---

## Objective

Make Paperless-ngx the searchable archive of the owner's medical exams without
changing the original files. A daily synchronization uploads exams from the
authoritative NAS folder through the Paperless API with correct type, tags,
date and OCR text. The data model leaves room for a future read-only AI agent,
but this Sprint opens no new access path.

## Scope

Included:

- an idempotent data-model script, shipped in the sync image, that creates the
  document type, tags, custom fields, the `sync-medico` service user, its
  permissions and the ownership workflow;
- a dedicated `services/paperless-medical-sync/` stack: Dockerfile, Compose
  file, sync script, scheduler entrypoint and README;
- one change to the Paperless stack: `PAPERLESS_IGNORE_DATES` in its private
  configuration, which requires recreating the Paperless container;
- decryption of password-protected PDFs before upload;
- the initial load of existing exams and daily upload of new exams;
- example configuration with placeholders, documentation, operational
  procedures and sync observability through the existing batch alerts.

Excluded:

- the medical AI agent, its `agente-medico` user and its API access;
- Cloudflare behavior for non-browser API clients, token use alongside OIDC
  login and Cloudflare Access for `/api`;
- re-uploading or versioning exams that change after their first upload;
- health-application exports (XML, GPX, CSV);
- Tika, Gotenberg, Paperless AI features and remote OCR;
- any package, systemd unit, cron entry or other change to the NAS operating
  system;
- new Grafana dashboards or panels;
- shipping the sync container logs to Loki (Alloy collects only Nginx Proxy
  Manager logs today); logs are read with `docker logs`.

## Data model

All objects are created through the API by a re-runnable script; nothing is
created by hand.

| Object | Value |
|---|---|
| Document type | `Examen médico` |
| Tags | `medico` on every exam; one category tag derived from the folder path; `revisar-fecha` and `revisar-titulo` for manual review |
| Custom field `Ruta origen` | Text; NFC-normalized relative path inside the source folder; idempotency key |
| Custom field `Hash origen` | Text; SHA-256 of the original file before decryption |
| Service user `sync-medico` | Local user, token only, not staff, not superuser; view and create documents; view tags, types and fields |
| Workflow | Trigger: document added via API with tag `medico`; sets the type, sets the owner's personal user as owner and grants view to `sync-medico` |

Year and month are never tags; they belong to the document date. The folder →
category table lives in private configuration. Correspondents are assigned
manually during the initial review.

No exam may remain without an owner: in Paperless an unowned document is
visible to every user with global document view permission.

`sync-medico` cannot create users, permissions or workflows. The data-model
script therefore runs from the sync image as a one-off
`docker compose run --rm` and receives a temporary administrator token only for
that run, passed to that command alone. The token is never stored in
`paperless-medical-sync.env` or any other file, and it is revoked in the
Paperless administration when the run finishes.

## Deployment order

1. Confirm the Paperless-ngx 3 upgrade target validation is closed.
2. Add `PAPERLESS_IGNORE_DATES` to the private Paperless configuration and
   recreate the Paperless container. This is the only change to the Paperless
   stack.
3. Run the data-model script with a temporary administrator token, then revoke
   it.
4. Create the `sync-medico` token and place it in the private sync
   configuration.
5. Deploy the sync stack and validate with synthetic documents.
6. Point the sync at the real source folder for the initial load, then review
   documents tagged `revisar-fecha` and `revisar-titulo`.

## Container contract

The sync runs in its own minimal container and its own Compose project, fully
decoupled from the Paperless-ngx stack. A sync failure, rebuild or removal
never restarts, modifies or depends on the Paperless containers, and a
Paperless upgrade never changes the sync runtime. Nothing is installed on the
NAS host.

| Aspect | Contract |
|---|---|
| Image | Built from `services/paperless-medical-sync/Dockerfile`: `python:3.13-alpine` pinned by digest plus a pinned `qpdf` package; no `pip` dependencies |
| Script | Python standard library only (HTTP, multipart upload, NFC normalization, task pagination) |
| Scheduling | A shell entrypoint runs the sync once a day and then sleeps; idle cost is a single `sleep` process. A manual run uses `docker compose exec` |
| Failure handling | The entrypoint never exits on a sync failure: it records the result in metrics and continues its cycle. If Paperless is unreachable (for example after a NAS reboot), the next attempt runs after 1 hour instead of 24 |
| Concurrency | A `flock` on a lock file in the `tmpfs` prevents a manual run from overlapping the scheduled run; the second run exits without uploading |
| Lifecycle | `restart: unless-stopped` covers only crashes of the entrypoint itself; healthcheck based on the age of the last completed run |
| Network | `homelab07-internal` only; reaches `homelab07-paperless-ngx:8000`; no published ports, no proxy network |
| User and filesystem | Non-root user, read-only root filesystem, size-limited `tmpfs` for decrypted copies and the lock, `no-new-privileges`, all capabilities dropped |
| Resources | Memory limit 256 MB, CPU limit. Uploads stream the file from disk instead of building the multipart body in memory. The `tmpfs` counts against the memory limit, so its size is set from the largest source file |
| Time zone | `TZ` equals `PAPERLESS_TIME_ZONE` |
| Secrets | `PAPERLESS_SYNC_TOKEN` and `PDF_PASSWORDS` (JSON list) live in `HomeLab07.private/env/paperless-medical-sync.env` (mode `600`), loaded with `env_file:` and never interpolated as `${VAR}` under `environment:`. The script reads both at start-up and removes them from `os.environ` |
| Mounts | Source folder read-only; the existing observability metrics directory (`HOMELAB07_OBSERVABILITY_METRICS_ROOT`) read-write, with write access granted to the container UID |
| Metrics | The container writes `paperless-medical-sync.prom` with the repository's temporary-file + rename pattern. A single bind-mounted file cannot be replaced by rename, and the Alloy textfile collector reads only `/var/lib/homelab07/metrics` without subdirectories, so the whole directory is mounted |
| Logs | Read with `docker logs`; not shipped to Loki in this Sprint |
| Supply chain | The image joins the Sprint 012 vulnerability scan scope; base digest and `qpdf` version are updated deliberately |

## Synchronization contract

The consume folder is not used because Paperless deletes what it consumes.

Per file:

1. Walk the source folder recursively. Accept PDF, PNG and JPG; ignore hidden
   files and `.DS_Store`; report any other format as unsupported.
2. Compute the NFC-normalized relative path and the SHA-256 of the original.
3. Look up `Ruta origen`. Same hash → skip. Different hash → do not upload;
   report a modified-file warning.
4. Detect encryption with `qpdf --requires-password`. If the PDF is
   encrypted, try the private passwords in order with
   `qpdf --decrypt --password-file=-`, passing each password through stdin:
   never on the command line and never written to disk. `qpdf` runs with a
   minimal environment (only `PATH`). Write the decrypted
   copy to the `tmpfs`. No password works → report an error and do not upload.
5. Derive date and title (rules below).
6. Upload with `POST /api/documents/post_document/` including `title`,
   `created` when known, `document_type`, `tags` and both custom fields.
7. Poll `/api/tasks/` (paginated in API version 10) until success, failure or
   timeout. A duplicate rejection is a warning.
8. Always delete the temporary copy.

Duplicates: when the same content exists at two paths, Paperless rejects the
second upload, and without a check the sync would retry it every day with the
same warning. If the documents API in 3.3.3 supports filtering by checksum, the
sync computes the SHA-256 checksum that Paperless 3 stores, over the file
actually uploaded (the decrypted copy for encrypted PDFs, not the original),
and reports a duplicate without uploading. Otherwise the recurring warning is
documented and resolved during the initial review.

File identifier: logs, warnings and the run summary identify each file by its
relative path with the private personal-data patterns masked, followed by the
first 12 characters of the original's SHA-256. The unmasked path never
appears in logs.

Uploads are sequential because Paperless runs one task worker. Every request
sends `Accept: application/json; version=10`, and the script stops if
`X-Api-Version` does not support version 10.

Date rules (first match wins):

| Order | Source | Example shape |
|---:|---|---|
| 1 | File name with `DD-MM-YYYY` | `Name_21-08-2020.pdf` |
| 2 | File name with a `YYYYMMDD` delimited by non-digits or the name boundary, forming a valid calendar date between 2000 and today; digits inside a longer number never match | `xxx-20231201-Name.pdf` |
| 3 | Folder `YYYY-MM-DD` | `2021-11-29/file.pdf` |
| 4 | Spanish month folder under a year: first day of that month. Matching ignores case and accents and accepts both `Septiembre` and `Setiembre` | `2025/Octubre/…` |
| 5 | Year only: `created` is not sent; tag `revisar-fecha` | `2024/file.pdf` |

For rule 5, Paperless detects the date from content.
`PAPERLESS_IGNORE_DATES` in the private Paperless configuration prevents the
holder's birth date from being selected.

Title rules:

1. Start from the file name without date or extension, with `_` and `-`
   replaced by spaces.
2. Remove the personal-data patterns defined in private configuration (for
   example the holder's name and identity document number), together with
   leftover labels and separators.
3. If useful descriptive text remains, it is the title. If the name was a UUID,
   a number or only a date, or nothing useful remains, the title is
   `Examen médico` + category + date and the document is tagged
   `revisar-titulo`.

Each run produces a summary (uploaded, skipped, modified warnings, duplicates,
encrypted without password, unsupported, failed) and textfile metrics for
Prometheus. The script exits non-zero when any file fails; the entrypoint
records that result without stopping its cycle. Logs and metrics never contain
document content, passwords, tokens, environment variables or file names that
include personal-data patterns.

## Observability

The sync publishes metrics in the same format as the existing batch jobs
(`operation/observability-metrics-lib.sh`):

- `homelab07_paperless_medical_sync_last_status`
- `homelab07_paperless_medical_sync_last_run_timestamp_seconds`
- `homelab07_paperless_medical_sync_last_success_timestamp_seconds`
- one counter per result (uploaded, skipped, modified, duplicate, encrypted
  without password, unsupported, failed)

Alerting reuses the existing Grafana rules, with no new dashboard or panel:

- the job is added to "Platform batch operation failed" (failed or absent
  status);
- "not run for 48 hours" is a new condition with a 172800-second threshold,
  like "Backup recovery point is stale"; the 900-second threshold of "Fast
  collector metrics are stale" does not apply to a daily job;
- the runbook "Batch operation failed or stale" in
  `docs/observability/ALERTS.md` applies unchanged.

## Architecture and security contracts

- No new public route, host port or listener. The sync uses the internal
  Docker network only.
- No change to the NAS operating system; host-side work is limited to
  creating private directories and files.
- The source folder remains the source of truth and is never modified, moved
  or deleted.
- Private configuration lives in
  `HomeLab07.private/env/paperless-medical-sync.env` (mode `600`), loaded with
  `env_file:`: source root, internal Paperless URL, `PAPERLESS_SYNC_TOKEN`,
  `PDF_PASSWORDS`, owner username, folder → category table and the
  personal-data patterns removed from titles.
- PDF passwords never reach Paperless, logs, metrics or process arguments.
- Validation uses `docker compose config --quiet`; the full rendered output is
  never stored or shared because it contains the secrets.
- Accepted risk: the token and passwords are visible through `docker inspect`,
  as are the other platform passwords.
- Accepted risk: the container UID can write to the shared metrics directory
  and could therefore overwrite another job's `.prom` file.
- The repository ships only `paperless-medical-sync.env.example`, a fictitious
  category table and a `PAPERLESS_IGNORE_DATES` placeholder in the Paperless
  `.env.example`.
- Backup scope is unchanged: Paperless documents and metadata are already
  covered through MariaDB and `PAPERLESS_ROOT`. The source folder is not in
  Restic scope; its protection depends on NAS storage.

## Requirements and acceptance criteria

Initial validation uses synthetic documents. Real exams are loaded only after
it passes.

- **Given** the data-model script has run, **when** it runs again, **then** no
  object is duplicated.
- **Given** `sync-medico`, **when** it creates and reads exams, **then** it
  succeeds, and edit or delete attempts return `403`.
- **Given** a test user without exam permissions, **when** it searches or
  requests an exam by ID, **then** no exam is visible.
- **Given** a completed sync, **when** documents tagged `medico` are listed,
  **then** none is unowned.
- **Given** a completed sync, **when** originals are checked, **then** hash and
  modification time are unchanged.
- **Given** no source changes, **when** the sync runs again, **then** nothing is
  uploaded.
- **Given** an uploaded file changes at the same path, **when** the sync runs,
  **then** it is not uploaded and a modified-file warning is reported.
- **Given** a PDF with a known password, **when** synced, **then** it is uploaded
  decrypted with OCR text; with an unknown password it is not uploaded and is
  reported.
- **Given** one test case per date and title rule, **when** synced, **then** each
  produces the expected result.
- **Given** file names with accents, **when** synced, **then** they upload and are
  found by `Ruta origen`.
- **Given** any run, **when** logs are inspected, **then** they contain no
  passwords, tokens or document content.
- **Given** a simulated sync failure, or no run for 48 hours, **when** alerts are
  evaluated, **then** the Grafana alert fires.
- **Given** the sync container crashes or is removed, **when** Paperless is
  checked, **then** its containers, data and availability are unaffected.
- **Given** the sync container, **when** its configuration is inspected,
  **then** it runs as non-root with a read-only root filesystem, no published
  ports and no network other than `homelab07-internal`.
- **Given** a file name with the holder's name and identity document number,
  **when** synced, **then** the title contains neither.
- **Given** a file name with a number of 12 or more digits, **when** synced,
  **then** no date is derived from it.
- **Given** the largest PDF in the source folder, **when** synced, **then** it
  uploads without the container being killed for memory.
- **Given** Paperless is stopped, **when** the sync runs, **then** the container
  does not enter a restart loop, retries after 1 hour and the alert fires.
- **Given** a manual run during the scheduled run, **when** both overlap,
  **then** no file is uploaded twice.
- **Given** the same content at two paths, **when** the sync runs again,
  **then** the duplicate is reported and not re-uploaded, or the recurring
  warning is documented if the API cannot filter by checksum.
- **Given** the running container, **when** `docker compose config --quiet`
  and the logs are reviewed, **then** neither the token nor the PDF passwords
  appear.

## Validation

- `sh -n` and ShellCheck for the entrypoint; `python -m py_compile` for the
  sync script.
- Hadolint for the Dockerfile and a successful image build.
- `docker compose config --quiet` for the sync stack and for the Paperless
  stack after example changes.
- Vulnerability scan of the built image.
- YAML validation of the Grafana alert provisioning after adding the sync
  conditions.
- Target validation with synthetic documents covering every acceptance
  criterion, plus a memory test with the largest source file, then the
  initial load and the manual review of `revisar-fecha` and `revisar-titulo`
  documents.
- Token rotation for `sync-medico` exercised once.

## Rollback

1. Stop and remove the sync stack; Paperless keeps running.
2. Remove the sync conditions from the Grafana alert rules and delete
   `paperless-medical-sync.prom`.
3. Delete the documents tagged `medico` that the sync created, then empty
   them from the Paperless trash so no copy of the exams remains.
4. With a temporary administrator token, delete the workflow, `sync-medico`,
   custom fields, tags and document type, then revoke the token.
5. Remove `PAPERLESS_IGNORE_DATES` from the private Paperless configuration
   and recreate the Paperless container.

The source folder needs no rollback because it is mounted read-only.

Restic snapshots taken before the rollback keep the exams until the retention
policy removes them.

## Implementation notes

Delivered in `services/paperless-medical-sync/` (see its README). Deviations
from the plan, all within scope:

- `PAPERLESS_IGNORE_DATES` needed a pass-through line in the Paperless
  `compose.yaml` because that stack lists its environment explicitly; the value
  itself stays private.
- The data model resolves the owner by `SYNC_OWNER_USERNAME` instead of a
  numeric user ID.
- The 48-hour condition is a separate rule, "Medical records sync is stale",
  that uses the same runbook.
- The service is added to the platform lifecycle list so `start`, `stop` and
  `status` include it.

Static validation completed: `sh -n`, `py_compile`, YAML parsing,
`docker compose config --quiet` with example values, and a functional run of the
sync against a simulated Paperless API (upload, skip, modified warning,
duplicate, unsupported format and unreachable retry). Not run locally: image
build, Hadolint, ShellCheck and the vulnerability scan; they run on the target
host.

Paperless API behaviors to confirm during synthetic validation: custom field
values sent with `post_document`, the `checksum__iexact` filter and the
workflow and user payloads created by `model-init`.

## Closure record

Record outcome, sanitized validation summary, deviations and residual work here.
Detailed private evidence remains in its approved private location.
Update the affected living specification under `/specs` before marking this
Sprint complete.

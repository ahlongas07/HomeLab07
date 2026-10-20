# Paperless Medical Sync

## Purpose

Uploads the owner's medical exams from an authoritative NAS folder into
Paperless-ngx once a day, with document type, tags, date, title and OCR text.
The folder is never modified. Sprint 015 delivers this service.

## Responsibilities

- Walk the read-only source folder and upload new PDF, PNG and JPG exams
  through the Paperless-ngx API (version 10).
- Decrypt password-protected PDFs in memory-backed temporary storage before
  upload.
- Derive dates, titles and category tags from paths, removing personal data
  from titles.
- Report modified files, duplicates, unsupported formats and failures without
  re-uploading.
- Publish batch metrics for the existing Grafana alerts.
- Create the Paperless data model once through `model-init`.

The service does not modify originals, does not version changed exams and
opens no network listener. It is independent from the Paperless-ngx stack: a
failure, rebuild or removal never restarts or changes Paperless.

## Technology

| Capability | Selection |
|---|---|
| Image | Built locally from `python:3.13-alpine3.24` pinned by digest |
| PDF decryption | `qpdf` 12.3.2-r0 |
| Code | Python standard library only, no `pip` packages |
| Scheduling | Container entrypoint loop; no host cron or systemd |
| Paperless access | REST API version 10 on `homelab07-internal` |

## Directory Structure

```text
services/paperless-medical-sync/
├── .env.example
├── Dockerfile
├── README.md
├── compose.yaml
├── entrypoint.sh
└── medical_sync.py
```

Runtime mounts:

| Container path | Source | Access |
|---|---|---|
| `/source` | `SYNC_SOURCE_ROOT` (original exams) | read-only |
| `/metrics` | `SYNC_METRICS_ROOT` (observability textfile directory) | read-write |
| `/run/sync` | size-limited `tmpfs` (decrypted copies, lock, heartbeat) | read-write |

The root filesystem is read-only, all capabilities are dropped and the process
runs as `SYNC_UID:SYNC_GID`.

## Configuration

```bash
cp services/paperless-medical-sync/.env.example \
  ../HomeLab07.private/env/paperless-medical-sync.env
chmod 600 ../HomeLab07.private/env/paperless-medical-sync.env
```

| Variable | Purpose |
|---|---|
| `SYNC_SOURCE_ROOT` | Host folder with the original exams |
| `SYNC_METRICS_ROOT` | Same host path as `HOMELAB07_OBSERVABILITY_METRICS_ROOT` |
| `SYNC_UID`, `SYNC_GID` | Identity that can read the source and write metrics |
| `SYNC_MEMORY_LIMIT`, `SYNC_TMPFS_SIZE` | Memory limit and decrypted-copy space; the `tmpfs` counts against the limit |
| `TZ` | Same value as `PAPERLESS_TIME_ZONE` |
| `SYNC_HOUR` | Local hour of the daily run |
| `SYNC_RETRY_SECONDS` | Retry delay when Paperless is unreachable |
| `SYNC_OWNER_USERNAME` | Paperless user that owns every exam |
| `SYNC_CATEGORY_MAP` | JSON: folder name → category tag |
| `SYNC_PERSONAL_PATTERNS` | JSON list of case-insensitive regular expressions removed from titles and masked in logs |
| `PAPERLESS_SYNC_TOKEN` | Secret: `sync-medico` API token |
| `PDF_PASSWORDS` | Secret: JSON list of PDF passwords tried in order |

The file is both the Compose interpolation file and the container `env_file`.
Secrets are never interpolated into `environment:`. The script reads them at
start-up and removes them from its environment; `qpdf` receives each password
through stdin with an environment that contains only `PATH`.

Personal-data patterns must include their labels (for example `CC`) and allow
`_`, `-` or spaces between words, because they are applied to raw paths in
logs and to normalized names in titles.

## Deployment

Follow this order. Steps 1–3 run once.

1. Set `PAPERLESS_IGNORE_DATES` (for example the holder's birth date) in the
   private Paperless environment and recreate Paperless:

   ```bash
   ./operation/compose.sh paperless-ngx up -d
   ```

2. Create a temporary administrator token in the Paperless administration
   (`/admin/` → Auth tokens) and run the data model with it. The token is read
   from the terminal and never stored:

   ```bash
   ./operation/compose.sh paperless-medical-sync build
   ./operation/compose.sh paperless-medical-sync run --rm \
     paperless-medical-sync medical-sync model-init
   ```

   Delete the temporary token in `/admin/` immediately afterwards. The command
   is idempotent: it creates missing objects, resets the `sync-medico`
   permissions and staff flags to the contract, and verifies an existing
   workflow. It does not rewrite an existing workflow; on drift it stops and
   asks for the workflow to be deleted and the command run again.

3. Create the `sync-medico` token in `/admin/` → Auth tokens and store it as
   `PAPERLESS_SYNC_TOKEN` in the private environment file.

4. Grant `SYNC_UID` write access to the metrics directory and read access to
   the source folder. Point `SYNC_SOURCE_ROOT` at a folder of synthetic
   documents first.

5. Start the service:

   ```bash
   ./operation/compose.sh paperless-medical-sync config --quiet
   ./operation/compose.sh paperless-medical-sync up -d --build
   ./operation/compose.sh paperless-medical-sync logs --tail=100
   ```

6. After the first sync has published `paperless-medical-sync.prom`, recreate
   the observability stack so Grafana loads the sync alert conditions. Loading
   them earlier fires the alerts, because an absent status counts as a
   failure.

7. After synthetic validation passes, point `SYNC_SOURCE_ROOT` at the real
   folder, recreate the service and review documents tagged `revisar-fecha`
   and `revisar-titulo`.

On start-up the container waits up to `SYNC_STARTUP_WAIT` seconds (default
600) for Paperless to answer before the first run, so a NAS reboot does not
produce a failed attempt.

Run a sync manually; a run in progress holds a lock and the second exits
without uploading:

```bash
./operation/compose.sh paperless-medical-sync exec paperless-medical-sync medical-sync sync
```

Never store or share the full output of `docker compose config`: it contains
the rendered secrets. Use `--quiet`.

## Validation

```bash
./operation/compose.sh paperless-medical-sync ps
./operation/compose.sh paperless-medical-sync logs --tail=100
cat "${SYNC_METRICS_ROOT}/paperless-medical-sync.prom"
```

Validate with synthetic documents before loading real exams. The Sprint 015
acceptance criteria are the checklist. Confirm at least:

1. A second run without changes uploads nothing.
2. A modified file is reported and not re-uploaded.
3. Encrypted PDFs with a known password upload with OCR text; an unknown
   password is reported.
4. Every uploaded exam has an owner, and a test user without permissions sees
   none.
5. With Paperless stopped, the container keeps running and retries after
   `SYNC_RETRY_SECONDS`.
6. Logs contain no tokens, passwords, document content or unmasked personal
   data.

Task polling follows the API v10 task format (lowercase `status`,
`related_document_ids` and `result_data` with `document_id` and
`duplicate_of`). After each upload the sync confirms that the workflow
reassigned the owner: `sync-medico` must no longer be able to change the
document (`user_can_change` is false).

Validate against a disposable Paperless-ngx 3.3.3 instance with synthetic
documents before deploying on the NAS. The following Paperless API behaviors
are assumed and must be confirmed there:

- `post_document` stores custom field values sent as a JSON object of field
  ID → value;
- `/api/documents/?checksum__iexact=` filters by checksum; when it does not,
  duplicates are still detected by Paperless at consumption and reported as a
  recurring warning;
- the workflow and user payloads created by `model-init` are accepted as sent.

## Observability

The sync writes `paperless-medical-sync.prom` with
`homelab07_paperless_medical_sync_last_status`,
`..._last_run_timestamp_seconds`, `..._last_success_timestamp_seconds`,
`..._last_duration_seconds` and `..._files{result=…}`.

Alerts: "Platform batch operation failed" covers a failed or absent status and
"Medical records sync is stale" fires after 48 hours without an attempt. The
runbook is [Batch operation failed or stale](../../docs/observability/ALERTS.md#batch-operation-failed-or-stale).
Logs are read with `docker logs`; they are not shipped to Loki.

Load the alert changes only after the sync has published its first metrics
(Deployment step 6): the batch rule treats an absent status as a failure.

Failure handling: a connection error aborts the run and retries after
`SYNC_RETRY_SECONDS`. Any HTTP error, including 5xx, fails only the file being
processed; the run continues with the next file. Error excerpts from Paperless
are masked with the personal-data patterns before logging.

## Backup

The service holds no persistent state. Uploaded exams are protected with
Paperless (MariaDB and `PAPERLESS_ROOT`). The source folder is not in Restic
scope; its protection depends on NAS storage. API tokens are not part of
Paperless exports and must be recreated after a restore.

## Restore

1. Restore Paperless-ngx.
2. Recreate the `sync-medico` token and update the private environment file.
3. Start the service; existing exams are skipped by `Ruta origen` and hash.

## Rollback

1. `./operation/compose.sh paperless-medical-sync down`; Paperless keeps
   running.
2. Remove the sync conditions from the Grafana alert rules and delete
   `paperless-medical-sync.prom`.
3. Delete the documents tagged `medico` and empty them from the Paperless
   trash.
4. With a temporary administrator token, delete the workflow, `sync-medico`,
   custom fields, tags and document type; then delete the token.
5. Remove `PAPERLESS_IGNORE_DATES` and recreate Paperless.

Restic snapshots taken before the rollback keep the exams until the retention
policy removes them.

## Security

- No published ports, no proxy network and no public route.
- `sync-medico` is a token-only local user, not staff and not superuser, that
  sees only exams.
- Every exam is owned by the owner's personal user through the workflow; an
  unowned exam would be visible to every user with global view permission.
- Secrets live only in the private environment file (mode `600`). Accepted
  risk: they are visible through `docker inspect`, like other platform
  passwords.
- Accepted risk: the container UID can write to the shared metrics directory.
- The image is included in the Sprint 012 vulnerability scan scope.

## Related Sprint

- Sprint 015 — Medical Records Ingestion

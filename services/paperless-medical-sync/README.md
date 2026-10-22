# Paperless Medical Sync

## Purpose

Uploads the owner's medical exams from an authoritative NAS folder into
Paperless-ngx within minutes of being added, with document type, tags, date,
title and OCR text. A daily run is kept as a fallback. The folder is never
modified. Sprint 015 delivers this service.

## Responsibilities

- Walk the read-only source folder and upload new PDF, PNG and JPG exams
  through the Paperless-ngx API (version 10).
- Detect changes in the source folder by polling and start a sync once they
  settle.
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
| Scheduling | Container entrypoint loop: run at start, on settled source changes and daily; no host cron or systemd |
| Change detection | Standard-library `stat` polling of the source folder; no inotify, works on any mount |
| Paperless access | REST API version 10 on `homelab07-internal` |

## Directory Structure

```text
services/paperless-medical-sync/
├── .env.example
├── Dockerfile
├── README.md
├── compose.yaml
├── entrypoint.sh
├── medical_sync.py
└── tests/
    └── test_watcher.py
```

The tests are not copied into the image.

Runtime mounts:

| Container path | Source | Access |
|---|---|---|
| `/source` | `SYNC_SOURCE_ROOT` (original exams, polled for changes) | read-only |
| `/metrics` | `SYNC_METRICS_ROOT` (observability textfile directory) | read-write |
| `/run/sync` | size-limited `tmpfs` (decrypted copies, lock, heartbeat, source snapshot) | read-write |

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
| `SYNC_HOUR` | Local hour of the daily fallback run |
| `SYNC_WATCH_INTERVAL` | Seconds between source-folder polls (default 30; `0` disables the watcher) |
| `SYNC_SETTLE_SECONDS` | Seconds a change must stay stable before a sync, and minimum age of a file before upload (default 30) |
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

Set `SYNC_PERSONAL_PATTERNS` and `SYNC_CATEGORY_MAP` to real values before the
first load of real exams; the example values match nothing. Check them with
the preview (Deployment step 7).

Category tag names are compared in Unicode NFC, so a tag typed with a
decomposed accent (NFD, common from macOS) matches the same name in
`SYNC_CATEGORY_MAP`. Every category tag must be visible to `sync-medico`:
create it with `model-init` (add the category to `SYNC_CATEGORY_MAP` and run it
again), or, if it was created in the Paperless interface, grant `sync-medico`
view permission on it. Otherwise every run stops with
`Missing Paperless object`.

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

   On every run it also replaces the owner and the view and change
   permissions of the `Examen médico` document type and of every contract tag
   (`medico`, `revisar-fecha`, `revisar-titulo` and the categories in
   `SYNC_CATEGORY_MAP`). The exam owner becomes the owner, `sync-medico`
   gets view, and nobody else gets either: permissions granted by hand to
   other users or groups on those objects are removed and must be granted
   again afterwards.

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
   folder and set the real `SYNC_PERSONAL_PATTERNS` and `SYNC_CATEGORY_MAP`.
   Preview the result before anything is uploaded. The preview reads only the
   source folder and the environment file: it does not contact Paperless and
   uploads nothing.

   ```bash
   ./operation/compose.sh paperless-medical-sync stop
   ./operation/compose.sh paperless-medical-sync build
   ./operation/compose.sh paperless-medical-sync run --rm \
     paperless-medical-sync medical-sync preview
   ```

   Each line shows the masked path, date, category, title and review tags.
   Check that no title contains personal data, that every folder has a
   category, and that `-` dates and `revisar-titulo` are the expected cases.
   Adjust the patterns or the map and repeat until the output is correct.
   The terminal shows the derived titles: do not store or share it.

8. Recreate the service for the initial load and review documents tagged
   `revisar-fecha` and `revisar-titulo`:

   ```bash
   ./operation/compose.sh paperless-medical-sync up -d
   ```

On start-up the container waits up to `SYNC_STARTUP_WAIT` seconds (default
600) for Paperless to answer before the first run, so a NAS reboot does not
produce a failed attempt.

### Change-triggered runs

After each run the container polls the source folder every
`SYNC_WATCH_INTERVAL` seconds with a `stat`-only walk (path, size and mtime;
no file is read). When the result differs from the snapshot taken at the start
of the last run and then stays unchanged for `SYNC_SETTLE_SECONDS`, it starts
`medical-sync sync`. Copying several files at once therefore starts one run,
usually within two minutes of the copy finishing.

The watcher only starts the existing sync; upload, deduplication and title
rules are unchanged. A full run still happens at start-up and daily at
`SYNC_HOUR` as a fallback. While Paperless is unreachable the watcher pauses
and the next attempt follows `SYNC_RETRY_SECONDS`.

Every run, whatever started it, defers files changed less than
`SYNC_SETTLE_SECONDS` ago, so a file still being copied is never uploaded half
written. Deferred files are counted as `deferred` and start another run once
they settle. The age comes from the inode change time (ctime), which every
write updates; the modification time is ignored because the copying client
sets it and may set it in the future.

The snapshot is taken before the walk, so a file copied while a run is in
progress starts another run. A run that finds the lock held exits without
touching the snapshot, so the change is picked up again instead of being
treated as handled.

Disk standby: each poll only reads directory entries and file metadata, which
the NAS usually serves from its cache. If that cache is evicted, the poll can
wake the disks every `SYNC_WATCH_INTERVAL` seconds and keep them from entering
standby. If the disks do not enter standby, raise `SYNC_WATCH_INTERVAL` (for
example to `120`, so new exams arrive within about four minutes) or set it to
`0` to keep only the daily run. The two-minute target needs an interval of about 45
seconds or less.

### Moved or renamed files

An exam is identified by `Ruta origen`, its relative path. Moving or renaming
an already uploaded file or folder makes it a new path whose content already
exists in Paperless, so every run reports it as a duplicate (counted as
`duplicate`, run status unaffected) and never uploads it. Nothing is reported
for the old path. The warning stops only when one of these is done, as the
exam owner, in Paperless:

- set `Ruta origen` on the existing document to the new relative path; this
  keeps manual edits such as correspondent and corrected title; or
- delete the document and also empty it from the Paperless trash, because a
  document in the trash still counts as a duplicate; the next run uploads it
  again with the new path, and manual edits are lost.

Prefer leaving uploaded files where they are.

### Manual run

Run a sync manually; a run in progress holds a lock and the second exits
without uploading:

```bash
./operation/compose.sh paperless-medical-sync exec paperless-medical-sync medical-sync sync
```

Never store or share the full output of `docker compose config`: it contains
the rendered secrets. Use `--quiet`.

## Validation

Before building, run the watcher tests (standard library only, about 25
seconds, no Paperless needed):

```bash
python3 -m unittest discover -s services/paperless-medical-sync/tests
```

They cover a deferred file retried without further folder changes, a file
with a future modification time that is not deferred, a file copied during a
run, a run that finds the lock held, a batch copy that settles once and NFD
tag lookup.

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
7. A file copied over SMB appears in Paperless in less than 2 minutes, a batch
   copy produces a single `SUMMARY` line, and a large file being copied is
   logged as `DEFERRED` instead of uploaded.
8. With `SYNC_WATCH_INTERVAL=0`, a file added during the day is uploaded by
   the daily run.
9. A category tag whose name uses a decomposed accent (NFD) is found.

Task polling follows the API v10 task format (lowercase `status`,
`related_document_ids` and `result_data` with `document_id` and
`duplicate_of`). After each upload the sync confirms that the workflow
reassigned the owner: `sync-medico` must no longer be able to change the
document (`user_can_change` is false). Every later run repeats the check for
already uploaded exams from the same list response and reports a failure while
`sync-medico` can still change one.

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

The "HomeLab07 — Operations" dashboard shows the latest status (OK or Failed),
the age of the last success in "Operation age" and a table of files per result
in the latest run. Grafana reloads the provisioned dashboard within a minute of
a change; no restart is needed.

Metrics and the healthcheck describe the latest completed run, whether it was
started by a change or by the daily schedule; the daily run guarantees at least
one per day.

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

The service holds no persistent state (only `tmpfs`). Uploaded exams are
protected with Paperless (MariaDB and `PAPERLESS_ROOT`). The source folder
(`SYNC_SOURCE_ROOT`) is the source of truth and is captured in every platform
recovery point by `./operation/backup.sh`; the backup operator needs read
access to it. During a backup the container is stopped before Paperless and
started again afterwards if it was running, so no failed attempt or false
alert is recorded; the restart runs a full pass. API tokens are not part of
Paperless exports and must be recreated after a restore.

## Restore

1. Restore Paperless-ngx.
2. Restore the source folder from the same recovery point, keeping the
   relative paths, and grant `SYNC_UID` read access.
3. Recover the repository and the private environment file, recreate the
   `sync-medico` token and update `PAPERLESS_SYNC_TOKEN`.
4. Start the service with
   `./operation/compose.sh paperless-medical-sync up -d --build`; existing
   exams are skipped by `Ruta origen` and hash.

The full order is in the
[recovery matrix](../../docs/backup/RECOVERY_MATRIX.md).

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

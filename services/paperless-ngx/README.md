# Paperless-ngx

## Purpose

Paperless-ngx provides document ingestion, OCR, classification, search and
archival as the Sprint 006 business service.

## Responsibilities

- Consume PDF and image documents.
- Preserve originals and create searchable archive versions.
- Store metadata in shared MariaDB.
- Use shared Valkey for transient task brokering.
- Persist application state and documents on Rockstor.

Paperless-ngx does not own database, broker, DNS, TLS, identity or backup
infrastructure.

## Technology

| Capability | Selection |
|---|---|
| Application | `ghcr.io/paperless-ngx/paperless-ngx:2.20.15` |
| Database | Shared MariaDB 11.4 |
| Broker | Shared Valkey 8 compatibility PoC |
| OCR | OCRmyPDF and Tesseract from the official image |
| Publication | Nginx Proxy Manager and Cloudflare Dynamic DNS |
| Persistence | Dedicated Rockstor tree |

Record the registry digest on the target architecture before publication.

## Directory Structure

```text
services/paperless-ngx/
├── .env.example
├── IMPLEMENTATION_NOTES.md
├── README.md
└── compose.yaml
```

Private persistent storage:

```text
${PAPERLESS_ROOT}/
├── data/
├── media/
│   └── trash/
├── consume/
└── export/
```

`consume` is an inbox, not an archive. Successfully consumed files are moved
to managed storage under `media`.

## Configuration

```bash
cp services/paperless-ngx/.env.example \
  ../HomeLab07.private/env/paperless-ngx.env
```

Replace every placeholder privately. Choose UID/GID values that can write to
the Rockstor paths. The baseline enables 60-second consumer polling because
NAS filesystems may not expose reliable inotify events.

The default OCR languages are Spanish and English. Change this only through
private configuration. Tika, Gotenberg, email ingestion and Identity Platform
integration are outside Sprint 006.

## Deployment

Create the required NAS directories manually, then run:

```bash
./operation/paperless-storage-check.sh
./operation/compose.sh mariadb up -d
./operation/compose.sh valkey up -d
./operation/paperless-db-create.sh
./operation/compose.sh paperless-ngx config
./operation/compose.sh paperless-ngx up -d
```

Create the initial administrator using the supported management command after
the service is healthy; do not place administrator credentials in Git:

```bash
./operation/compose.sh paperless-ngx exec paperless-ngx createsuperuser
```

## Reverse Proxy

Create the Proxy Host using private values:

| Setting | Value |
|---|---|
| Scheme | `http` |
| Forward hostname | `homelab07-paperless-ngx` |
| Forward port | `8000` |
| Force SSL | enabled |
| Public URL | same value as private `PAPERLESS_URL` |

Do not publish a Docker host port. Configure upload limits and timeouts only as
needed for the controlled validation documents.

## Validation

```bash
./operation/compose.sh paperless-ngx ps
./operation/compose.sh paperless-ngx logs --tail=150
docker port homelab07-paperless-ngx
docker exec homelab07-paperless-ngx document_sanity_checker
docker exec homelab07-valkey valkey-cli -n 1 DBSIZE
```

Validate with synthetic data:

1. Upload a PDF and confirm full-text search.
2. Place an image in `consume` and confirm OCR completes.
3. Confirm the inbox file disappears only after durable ingestion.
4. Recreate the Paperless container and confirm documents and metadata remain.
5. Restart Valkey and verify failure/retry behavior without document loss.

Valkey compatibility is a release gate. If protocol errors occur, stop and
record evidence; do not add Redis silently.

## Backup

A complete recovery point requires the MariaDB database, `data`, `media`, the
pinned repository definition and protected private configuration. Validate a
portable export with:

```bash
./operation/compose.sh paperless-ngx exec -T paperless-ngx \
  document_exporter ../export
```

The exporter and importer should use the same Paperless version. API tokens are
not included and must be recreated.

## Restore

1. Restore private configuration and the same repository version.
2. Restore the MariaDB database plus `data` and `media`, or prepare a clean
   instance for importer validation.
3. Start MariaDB and Valkey, then Paperless-ngx.
4. For a portable export, run `document_importer ../export` on the matching
   Paperless version.
5. Run `document_sanity_checker` and verify search, originals and archives.

## Security

- Documents are stored unencrypted by Paperless-ngx.
- Protect Rockstor, host access and backups accordingly.
- Use separate administrator and daily-use accounts.
- Keep secrets and real endpoint values in `HomeLab07.private`.
- No host ports, Docker socket, public uploads or anonymous links are enabled.

## Related Sprint

See `sprints/SPRINT-006.md`.

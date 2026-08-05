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
private configuration. Tika, Gotenberg and email ingestion are outside Sprint
006. The later Identity Platform enhancement adds optional Keycloak OIDC
configuration while retaining local authentication and disabling automatic
account creation by default.

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

## Keycloak OIDC

Paperless-ngx consumes Keycloak through its supported django-allauth OpenID
Connect provider. Create a dedicated confidential Keycloak client named
`paperless`; never reuse the Nextcloud client or its secret.

Configure the client with:

- client authentication enabled;
- standard authorization-code flow enabled;
- direct access grants disabled;
- exact redirect URI
  `https://<paperless-domain>/accounts/oidc/keycloak/login/callback/`;
- exact web origin `https://<paperless-domain>`;
- scopes `openid`, `profile` and `email`.

Copy the single-line `PAPERLESS_SOCIALACCOUNT_PROVIDERS` example to the private
environment file and replace its public placeholders and dedicated secret.
Do not record the resulting JSON in this repository or command output.

The baseline intentionally sets social auto-signup and social signup to false.
Link an existing Paperless PoC account by logging in locally and selecting the
Keycloak connection from **My Profile**. The local administrator must remain
usable until login, logout, OTP and rollback have all passed.

Because Paperless uses the realm's normal browser flow, a user subject to OTP
in Keycloak receives the same second-factor challenge. Paperless does not own
or separately configure that OTP credential.

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

OIDC validation after linking the PoC account:

1. Confirm local administrator login still succeeds.
2. Authenticate through Keycloak and complete the configured OTP challenge.
3. Confirm the returning identity resolves to the linked Paperless account.
4. Confirm logout completes without a redirect loop.
5. Confirm an unlinked Keycloak user cannot create a Paperless account.
6. Clear `PAPERLESS_SOCIALACCOUNT_PROVIDERS`, recreate the container and
   confirm local-only authentication as the rollback path.

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

Sprint 010 captures the database and persistent roots through
`./operation/backup.sh`. Portable export remains an additional compatibility
artifact, not a replacement for the consistent platform recovery point.

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
- Use a dedicated OIDC client and secret for Paperless-ngx.
- Keep automatic social signup and forced SSO disabled until explicitly
  approved and recovery-tested.
- Keep secrets and real endpoint values in `HomeLab07.private`.
- No host ports, Docker socket, public uploads or anonymous links are enabled.

## Related Sprint

- Sprint 006 — Paperless-ngx
- Sprint 011 — Identity Platform foundation
- Platform Enhancement — Paperless-ngx OIDC consumer

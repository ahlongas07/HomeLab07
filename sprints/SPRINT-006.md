# Sprint 006 — Document Management Platform

**Status:** Completed

**Classification:** Business Service

**Primary Technology:** Paperless-ngx

**Last Reviewed:** 2026-07-23

---

# Objective

Introduce Paperless-ngx as HomeLab07's document management service and validate
document ingestion, OCR, classification, search and archival on the existing
shared platform.

The Sprint must deliver visible application functionality while reusing
MariaDB, Valkey, Rockstor persistence, Docker networks, Nginx Proxy Manager,
Cloudflare Dynamic DNS, the operation layer and `HomeLab07.private`.

---

# Decision Context

HomeLab07 already provides the infrastructure required by Paperless-ngx:

- MariaDB for relational application state;
- Valkey as a Redis-compatible transient service;
- NAS-backed storage through Rockstor;
- HTTPS publication through Nginx Proxy Manager and Cloudflare;
- internal and proxy Docker networks;
- private environment configuration;
- standardized lifecycle commands.

Paperless-ngx supports MariaDB, PostgreSQL and SQLite. PostgreSQL is recommended
upstream for new installations, but introducing another database engine is not
justified while the existing MariaDB version satisfies the supported Django
backend requirements. MariaDB caveats must be accepted and validated rather
than hidden.

Paperless-ngx requires a Redis-compatible broker for document consumption,
scheduled work and background processing. The official documentation specifies
Redis 6 or newer but does not explicitly certify Valkey. Reuse of shared Valkey
is therefore a PoC hypothesis and an acceptance gate, not an assumed fact.

---

# Architecture

```text
Internet
   │
Cloudflare Dynamic DNS
   │
Nginx Proxy Manager
   │
Paperless-ngx
   ├── MariaDB       durable metadata and application state
   ├── Valkey        transient task broker
   └── Rockstor
       ├── data      search index and auxiliary state
       ├── media     originals, archives and thumbnails
       ├── consume   ingestion inbox
       └── export    portable exports
```

Paperless-ngx owns document-management behavior. It does not own database,
broker, DNS, TLS or backup infrastructure.

---

# Technology Stack

| Capability | Selection | Rationale |
|---|---|---|
| Document management | Official Paperless-ngx container | Supported Docker deployment |
| Database | Shared MariaDB 11.4 | Reuses the existing relational platform |
| Task broker | Shared Valkey 8 candidate | Reuse subject to runtime compatibility evidence |
| OCR | Bundled OCRmyPDF and Tesseract | Native searchable-document workflow |
| Storage | Dedicated Rockstor directory tree | Preserves Storage First boundaries |
| Publication | Nginx Proxy Manager and Cloudflare | Reuses existing HTTPS capability |
| Operations | Existing operation layer | Standard lifecycle and diagnostics |

The implementation must select an exact stable Paperless-ngx image tag and
record its target-architecture digest. `latest` and prerelease tags are not
acceptable for a reproducible deployment.

Tika and Gotenberg are excluded from the baseline. They add two services to
support Office documents, while PDF and image ingestion is sufficient to prove
the Sprint objective. A later enhancement may introduce them after a
demonstrated requirement.

---

# Repository Impact

The implementation is expected to add:

```text
services/paperless-ngx/
├── .env.example
├── README.md
├── IMPLEMENTATION_NOTES.md
└── compose.yaml

operation/
├── paperless-db-create.sh
├── paperless-db-drop.sh
└── paperless-storage-check.sh
```

The implementation is expected to update:

```text
operation/start.sh
operation/stop.sh
operation/status.sh
README.md
ROADMAP.md
CHANGELOG.md
```

This planning document implements none of those runtime changes.

---

# Persistent Storage

The private storage root must map four distinct paths:

```text
${PAPERLESS_ROOT}/
├── data/
├── media/
├── consume/
└── export/
```

- `data` contains the search index, classification model and auxiliary state.
- `media` contains original documents, archive versions and thumbnails.
- `consume` is an inbox; successfully consumed files are moved into Paperless
  storage and must not be treated as the archive.
- `export` contains portable exporter output and must not overlap `media`.

All four paths must reside on the dedicated Rockstor storage boundary. The
implementation must validate container UID/GID ownership on the NAS. Because
NAS filesystems may not provide usable `inotify` behavior, the PoC must test
event-driven consumption and enable `PAPERLESS_CONSUMER_POLLING` through
private configuration if required.

No existing Nextcloud data directory or general NAS share may be reused as
Paperless internal storage.

---

# Docker Architecture

The baseline uses one Paperless-ngx container. The official image supervises
the web application, consumer, scheduler and task workers internally.

The service must:

- join `homelab07-internal` for MariaDB and Valkey;
- join `homelab07-proxy` for Nginx Proxy Manager;
- publish no host ports;
- use `restart: unless-stopped`;
- apply `no-new-privileges` where compatible;
- mount only the four dedicated persistent paths;
- expose a healthcheck with a generous initialization start period;
- avoid Docker socket access.

Health must distinguish initial migrations from a failed runtime. OCR load can
be CPU and memory intensive, so worker concurrency must begin conservatively
and be tuned only from target-host evidence.

---

# Database Design

Paperless-ngx owns one MariaDB database and one least-privilege database user.
The shared MariaDB service initializes neither. Provisioning must remain an
explicit operation-layer action.

The database must use `utf8mb4`. The exact collation requires PoC validation
against current Paperless/Django requirements. MariaDB comparisons are commonly
case-insensitive, which means names such as `Invoice` and `INVOICE` may compare
as equivalent. Manually changing all tables to a binary collation would also
make searches case-sensitive and is excluded unless a demonstrated requirement
justifies that trade-off.

The PoC must validate migrations, Unicode metadata, date queries, tag searches
and database export/restore with the deployed MariaDB version.

---

# Valkey Integration

Paperless-ngx must receive a private `PAPERLESS_REDIS` connection URL targeting
the shared internal Valkey service and a dedicated database index or namespace.
The connection value belongs in `HomeLab07.private`.

Compatibility evidence must include:

- application startup and broker connection;
- web upload and consumption-directory processing;
- scheduled-task execution;
- search-index and classifier maintenance tasks;
- behavior across a Valkey restart;
- absence of protocol or command errors in both services' logs.

Valkey is intentionally ephemeral and configured with `noeviction`. The Sprint
must determine how Paperless handles an interrupted or full broker. Documents
and metadata must remain durable in MariaDB and Rockstor; pending work may be
retried or requeued, but silent document loss is unacceptable. The existing
128 MiB limit must be measured under OCR load and changed only with evidence.

If current Paperless-ngx is incompatible with Valkey, the Sprint stops for an
architecture decision. It must not silently add a dedicated Redis container.

---

# Private Configuration

Environment-specific values belong only in:

```text
HomeLab07.private/env/paperless-ngx.env
```

The repository `.env.example` must contain placeholders for:

- storage root;
- database host, name, user and password;
- Valkey connection URL;
- application secret key;
- public URL and allowed hosts;
- trusted proxy or CSRF origins where required;
- timezone;
- UID and GID mapping;
- OCR language and optional polling interval;
- initial administrator values only if the selected bootstrap method supports
  secure non-interactive creation.

No real domain, filesystem path, credential, email address or token may enter
Git. Prefer supported `_FILE` secret variables where the official image
supports them.

---

# Reverse Proxy And Network Integration

Nginx Proxy Manager terminates TLS and forwards HTTP to the Paperless container
on its internal application port. Force SSL is required. WebSocket support is
enabled only if verified as necessary by the selected release.

The application must receive its canonical public HTTPS URL and trust only the
required proxy path. Upload-size and timeout settings must support the agreed
document-size validation without creating unrestricted global proxy defaults.

MariaDB and Valkey remain internal-only. Paperless is the only new service that
joins both platform networks. Cloudflare configuration must reuse the existing
DDNS mechanism and must not expose database or broker endpoints.

---

# Security Considerations

- Keep Paperless authentication local during Sprint 006; Identity Platform is
  deferred.
- Create a separate administrator and least-privilege daily-use account.
- Treat ingested documents, OCR text, thumbnails and exports as sensitive.
- Never log database credentials, secret keys or document contents.
- Use exact image tags and record digests.
- Reject executable preprocessing hooks and custom scripts in the baseline.
- Do not enable email ingestion, webhooks, public share links or API automation
  without separate scope and threat analysis.
- Validate file type and upload limits with synthetic documents only.
- Preserve application audit history and test authorization between users.

Paperless does not encrypt stored documents by default. Storage confidentiality
depends on Rockstor, host access controls and backup handling. Application-level
encryption is not introduced by this Sprint.

---

# Recovery Strategy And Backup Boundary

A complete recovery point includes:

- the Paperless MariaDB database;
- `data` and `media` from a consistent point;
- repository configuration and pinned image identity;
- private configuration through its separate protected backup process.

The `consume` directory is an ingestion inbox, not a backup. The `export`
directory is a portable recovery artifact but is not by itself the complete
platform backup policy.

The official document exporter must be validated because it captures documents,
thumbnails and metadata and supports import into a clean instance. Export and
import should use the same Paperless version. API tokens are not included and
must be recreated.

Backup automation belongs to Sprint 009. Sprint 006 documents commands,
boundaries and a disposable restore test without scheduling production jobs.

---

# Validation Plan

## Static Validation

- Compose resolves with the example environment file.
- Shell scripts pass `bash -n`.
- No service publishes host ports.
- No private value exists in the repository.
- Paperless uses only the two existing Docker networks.
- Image tag and digest evidence are recorded.

## Runtime Validation

- MariaDB and Valkey are healthy before Paperless starts.
- Paperless migrations complete and the web service becomes healthy.
- A synthetic PDF uploaded through the UI is consumed and searchable.
- A synthetic image placed in `consume` is detected, OCR'd and removed from the
  inbox after durable ingestion.
- Original, archive and thumbnail files appear under `media`.
- Metadata, tags, correspondents and document types survive recreation.
- Spanish and English OCR are tested with synthetic samples.
- Valkey shows Paperless activity without errors or data persistence claims.
- Nginx Proxy Manager provides HTTPS without direct host-port exposure.

## Recovery Validation

- A native MariaDB dump is non-empty.
- A Paperless document export completes and contains a manifest and documents.
- Containers can be recreated without losing state.
- A clean disposable restore recovers documents, metadata and searchability.
- Recovery limitations, including API-token recreation, are documented.

---

# Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Valkey differs from officially documented Redis | Tasks fail or stall | Treat compatibility as a PoC gate and inspect commands/logs |
| Valkey reaches its 128 MiB no-eviction limit | Background work fails | Measure usage and queue behavior before changing the shared limit |
| NAS lacks reliable inotify | Consume inbox is ignored | Validate and enable polling when required |
| MariaDB collation is case-insensitive | Tags or searches behave unexpectedly | Document caveat and test realistic metadata |
| OCR exhausts CPU or memory | Platform degradation | Conservative concurrency and synthetic load tests |
| Incomplete backup omits media or database | Documents become unrecoverable | Define consistent DB, data, media and private boundaries |
| Export version mismatch | Import fails | Pin and restore with the same Paperless version |
| Public upload configuration is too permissive | Resource exhaustion | Explicit size limits and authenticated access |

---

# Explicit Non-Goals

- Identity Platform, OIDC, SAML or social login.
- MFA configuration.
- Tika or Gotenberg.
- Office-document ingestion.
- Email ingestion.
- Scanner automation or mobile workflow design.
- Custom preprocessing/postprocessing scripts.
- Public share links or anonymous uploads.
- Automated backups or monitoring.
- High availability or horizontal scaling.
- Migrating an existing document archive.
- Replacing MariaDB or Valkey.

---

# Acceptance Criteria

Sprint 006 is complete when:

- Paperless-ngx is reproducibly deployed through the operation layer;
- MariaDB and Valkey reuse are proven with runtime evidence;
- PDF and image ingestion, OCR, classification and search succeed;
- Rockstor persistence survives container recreation;
- HTTPS publication works without direct host ports;
- storage ownership and NAS polling behavior are documented;
- a MariaDB dump and Paperless export are validated;
- a disposable restore recovers documents and metadata;
- service README and implementation notes satisfy repository standards;
- security, recovery and operational limitations are explicit;
- no non-goal or private value enters the implementation.

## Completion Evidence

Sprint 006 runtime acceptance was completed on the target host on 2026-07-23
using synthetic documents and private environment configuration.

- Paperless-ngx became healthy through the operation layer with shared MariaDB
  and Valkey.
- PDF upload, image consumption, Spanish and English OCR, classification and
  full-text search completed successfully.
- NAS ownership, polling-based consumption and managed media storage were
  validated without publishing a host port.
- HTTPS publication through Nginx Proxy Manager was validated with the
  canonical private application URL.
- Scheduled tasks and document processing completed through Valkey without
  observed protocol errors or document loss.
- Documents, metadata and searchability survived container recreation and a
  Valkey restart.
- MariaDB dump, Paperless export and disposable import/restore validation
  completed successfully.
- `document_sanity_checker` reported no issues after validation.

Environment-specific paths, domains, credentials and document contents remain
outside the repository.

---

# Required Research Before Implementation

1. Select the exact stable Paperless-ngx tag and image digest.
2. Confirm that release's supported Django/MariaDB versions.
3. Verify the official container's internal port, health endpoint and process
   model.
4. Confirm whether the selected release documents or tests Valkey explicitly.
5. Measure Valkey commands and memory use during representative OCR tasks.
6. Confirm UID/GID behavior on the target Rockstor paths.
7. Determine whether the NAS requires consumer polling.
8. Confirm required reverse-proxy headers, CSRF origins, upload size and
   timeout behavior.
9. Select OCR languages from demonstrated document requirements.
10. Record the exact exporter/importer behavior of the pinned release.

---

# Official Sources

- [Paperless-ngx installation](https://docs.paperless-ngx.com/setup/)
- [Paperless-ngx configuration](https://docs.paperless-ngx.com/configuration/)
- [Paperless-ngx basic usage](https://docs.paperless-ngx.com/usage/)
- [Paperless-ngx administration and recovery](https://docs.paperless-ngx.com/administration/)
- [Paperless-ngx advanced usage and MariaDB caveats](https://docs.paperless-ngx.com/advanced_usage/)
- [Paperless-ngx troubleshooting](https://docs.paperless-ngx.com/troubleshooting/)

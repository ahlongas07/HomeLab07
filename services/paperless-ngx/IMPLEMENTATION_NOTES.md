# Paperless-ngx Implementation Notes

Record target-host evidence here during Sprint 006. Do not record real domains,
paths, credentials, document contents or personal data.

## Required Evidence

- Image digest for `ghcr.io/paperless-ngx/paperless-ngx:2.20.15`.
- MariaDB migration and Unicode/collation validation.
- Valkey connection, command compatibility and memory use.
- NAS ownership and polling behavior.
- PDF and image OCR using synthetic documents.
- HTTPS publication and absence of host port mappings.
- Container recreation and disposable export/import recovery.

## Registry Verification

The tag was verified in GHCR on 2026-07-22. Published Linux manifests:

- amd64: `sha256:835974fc3368fc6714aa38542db7a1f0f542d03244e39b981e519aefc100f355`
- arm64: `sha256:123a6ada7dd63981d229780463431e2d5976bf96b75bafd8b0e8d21ab76219c3`

Confirm the NAS architecture and record the runtime image identity before
deployment; do not substitute one platform digest for another.

## Paperless-ngx 3 Upgrade

`ghcr.io/paperless-ngx/paperless-ngx:3.3.3` was verified in GHCR on
2026-10-19. The Compose definition pins the multi-architecture index digest:

- index: `sha256:dba0242c1df1843643df4eb50ce5639f3a7900f414879088fd5bed8eaf2d456d`
- amd64: `sha256:4097c7925229c1fd6c2a5230d50ba0e056fb9dde076a08654f5c19ae88dff7db`
- arm64: `sha256:bf51fc62a57abc327dd8408ac487f2509507ab8d78841424ca62dd3f50019c54`

Upgrade decisions reviewed against the upstream v3 migration guide:

- The consumer polling setting is renamed to
  `PAPERLESS_CONSUMER_POLLING_INTERVAL`; NAS storage still requires polling.
- Archive generation stays `always` to keep the original-plus-archive contract.
- Duplicate rejection stays enabled through
  `PAPERLESS_CONSUMER_DELETE_DUPLICATES`.
- Login rate limiting trusts one `X-Forwarded-For` hop. django-allauth rejects
  a count above the hops present, so the safe baseline counts only Nginx Proxy
  Manager.
- Document encryption, consume scripts, barcode scanner selection, advanced
  database options and the removed OCR modes are not used; no action needed.

Target evidence to record: x86-64-v2 CPU check, pre-upgrade recovery point,
runtime image identity, clean startup logs, search index rebuild, OIDC and
local login, duplicate rejection and archive creation.

Target validation of the 3.3.3 upgrade, including the Valkey failure/retry
gate, was confirmed complete by the project owner on 2026-10-20. Detailed
evidence remains in the private evidence location.

## Security Update 3.3.3 → 3.3.4

Reviewed and approved on 2026-10-23 as a version update only.

| | Current | Target |
|---|---|---|
| Tag | `3.3.3` | `3.3.4` (upstream release 2026-10-22) |
| Index digest | `sha256:dba0242c1df1843643df4eb50ce5639f3a7900f414879088fd5bed8eaf2d456d` | `sha256:9bc6e8248891bcfa6f52fffe8b81e4ea8cae75790c3ec1b9906961a7ba55c969` |
| amd64 manifest | `sha256:4097c7925229c1fd6c2a5230d50ba0e056fb9dde076a08654f5c19ae88dff7db` | `sha256:b3f480cc5a8beb3ad45cb484b7c606f93240ae58fbfaf4f609be1cfa248267e8` |
| arm64 manifest | `sha256:bf51fc62a57abc327dd8408ac487f2509507ab8d78841424ca62dd3f50019c54` | `sha256:d04b5709f31ea22003a39b24ca51bbc3cec7d3410d215bf6cbe3a2863191bf4b` |

Digests were read from GHCR on 2026-10-23.

Upstream security maintenance release: certifi 2026.10.19 for the emSign CA
incident (GHSA-6q48-6c7w-9gw2), Pillow 13.0.0 (CVE-2026-112393,
CVE-2026-112403, CVE-2026-112900), aiohttp 3.14.4 and yarl 1.25.1. No
database migrations and no setting changes; `PAPERLESS_SCRATCH_DIR` is only
newly documented with its existing default.

Pillow moves to a new major version. Upstream ships and tests it; validate
image and PDF ingestion, OCR and thumbnails after the update.

Candidate scan with the pinned scanner and policy: critical findings with an
available fix drop from 4 to 0. Detailed results stay in the private review.

Rollback restores the pre-upgrade recovery point; see the README Upgrade
section.

Target result (2026-10-23, upgrade at 03:06 UTC, about one minute of
downtime). Detailed evidence remains in the private evidence location.

- [x] Pre-upgrade recovery point: platform backup run by the project owner
      immediately before the upgrade. The restore test was skipped by owner
      decision.
- [x] Paperless-ngx runs `3.3.4@sha256:9bc6e824…` healthy without restarts;
      the log reports v3.3.4 with no errors or deprecated settings.
- [x] Pillow 13.0.0, certifi 2026.10.19 and aiohttp 3.14.4 in the runtime;
      no pending migrations; `manage.py check` reports no issues.
- [x] Celery worker and beat connected to Valkey.
- [x] Through the proxy network: the UI redirects to login, the login page
      and Keycloak login entry return `200`, the API returns `401` without a
      session.
- [x] Pillow decoded and re-encoded stored thumbnails; OCRmyPDF and Tesseract
      respond.
- [x] Medical sync healthy without restarts.
- [ ] Owner functional checks: local and Keycloak login, ingestion of a
      synthetic image and PDF with OCR and thumbnail.

## Decision Gates

- Stop if Valkey produces protocol errors or silently loses documents.
- Stop if MariaDB migrations or required queries are incompatible.
- Do not add Redis, PostgreSQL, Tika or Gotenberg without a separate decision.

## Target-Host Acceptance

Acceptance validation completed on 2026-07-23 using synthetic documents and
private environment configuration. No private paths, domains, credentials or
document contents are recorded here.

- MariaDB migrations, metadata operations and application startup succeeded.
- Valkey carried scheduled and document-processing tasks without observed
  protocol errors or document loss.
- NAS ownership and 60-second polling-based consumption were validated.
- Synthetic PDF and image ingestion, Spanish and English OCR, classification
  and full-text search succeeded.
- HTTPS publication through Nginx Proxy Manager succeeded without a direct
  Paperless host-port mapping.
- Documents and metadata survived Paperless container recreation and a Valkey
  restart.
- A native MariaDB dump, Paperless export and disposable import/restore were
  validated.
- `document_sanity_checker` reported no issues after validation.

The Valkey compatibility PoC passed for the Sprint 006 workload. This evidence
does not claim general compatibility beyond the pinned Paperless release and
the tested HomeLab07 deployment model.

## Keycloak OIDC Platform Enhancement

Repository configuration supports Paperless-ngx as a Keycloak OIDC consumer.
This extends beyond the original Sprint 011 Nextcloud-only PoC.

Target acceptance completed on 2026-08-06:

- dedicated confidential client with exact redirect URI and web origin;
- local Paperless administrator login before and after the change;
- existing PoC account linked from **My Profile**;
- successful Keycloak login and OTP challenge;
- logout without a redirect loop;
- just-in-time creation of a non-administrator user was accepted;
- local administrator access remained available;
- the post-change backup and disposable recovery validation succeeded.

Automatic social signup is an explicit private-environment policy for this
consumer. Forced SSO, group synchronization and administrator-role mapping
remain disabled.

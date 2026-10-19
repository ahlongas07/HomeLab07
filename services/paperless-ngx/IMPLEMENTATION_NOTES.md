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

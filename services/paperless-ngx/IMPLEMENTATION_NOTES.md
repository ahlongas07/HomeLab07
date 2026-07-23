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

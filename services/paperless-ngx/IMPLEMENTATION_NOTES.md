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

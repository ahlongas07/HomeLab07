## [Unreleased]

---

## [v0.8.0-document-management-platform] - 2026-07-23

### Added

- Sprint 006 Paperless-ngx service definition using shared MariaDB and Valkey.
- Dedicated Paperless-ngx database provisioning, reset and storage validation
  commands.
- NAS-backed document, application, consumption and export storage boundaries.
- Paperless-ngx deployment, validation and recovery documentation.
- POC-001 Nextcloud Files service definition with a dedicated cron container.
- Independent Nextcloud database provisioning and destructive reset commands.
- Non-destructive Nextcloud storage validation.
- Deployment, validation, backup, restore and rollback documentation.

### Changed

- Mark Sprint 006 as completed after target-host acceptance validation.
- Extend start, stop and status operations with Paperless-ngx.
- The operation-layer lifecycle selects Nextcloud as the active collaboration
  service.
- Removed pre-installation `NEXTCLOUD_INIT_HTACCESS` execution after runtime
  validation showed it caused a restart loop before initial setup completed.
- Require an IP or CIDR for Nextcloud trusted proxies after runtime checks
  rejected the Nginx Proxy Manager container hostname.
- Promote Nextcloud from PoC candidate to the active collaboration service.
- Update current platform documentation and landing-page status for Nextcloud.

### Removed

- OwnCloud service definition and service-specific operation scripts from the
  active repository. The implementation remains reproducible from the
  `v0.6.0-collaboration-platform` tag.

### Notes

- Paperless-ngx runtime acceptance covered synthetic PDF and image ingestion,
  OCR, search, NAS persistence, HTTPS publication, export and disposable
  recovery.
- Paperless-ngx publishes no host port and consumes the shared MariaDB and
  Valkey platform capabilities.
- This change does not delete the OwnCloud database, NAS data, private
  configuration or historical Git tag.

---

## [v0.6.0-collaboration-platform] - 2026-07-17

### Added

- OwnCloud Server 10.16.3 as the first business-facing platform service.
- Shared MariaDB integration for OwnCloud metadata.
- Shared Valkey integration for OwnCloud cache and transactional file locking.
- OwnCloud service documentation and implementation notes.
- OwnCloud database provisioning and reset scripts in the operation layer.
- OwnCloud storage validation helper.
- Landing Page status update for the collaboration platform milestone.

### Changed

- Sprint 005 marked as completed.
- Project README and Roadmap updated to reflect the completed collaboration platform milestone.
- OwnCloud storage model documented with explicit internal volume paths:
  - `OWNCLOUD_VOLUME_ROOT=/mnt/data`
  - `OWNCLOUD_VOLUME_FILES=/mnt/data/files`

### Notes

- OwnCloud publishes no host ports and is reachable only through Cloudflare and Nginx Proxy Manager.
- Server-side encryption remains disabled to preserve direct NAS recoverability.
- Existing NAS shares are deferred to a future External Storage evaluation.

---

## [v0.4.0-zero-touch-ssl] - 2026-07-15

### Added

- Nginx Proxy Manager shared platform service.
- Automatic HTTPS publication through Let's Encrypt.
- Standard Docker proxy network:
  - homelab07-proxy
- Landing Page publication through Nginx Proxy Manager.
- Persistent Nginx Proxy Manager storage for configuration and certificates.
- Nginx Proxy Manager integration with platform operation commands:
  - start
  - stop
  - status
- Nginx Proxy Manager service documentation.

### Changed

- Landing Page no longer publishes a public host port directly.
- Public service exposure now goes through Nginx Proxy Manager.
- Sprint 003 marked as completed.

---

## [v0.3.0-data-foundation] - 2026-07-15

### Added

- MariaDB shared infrastructure service.
- MariaDB 11.4.12 deployment.
- Persistent database storage model using the `homelab07-data` share.
- Private service environment loading from `HomeLab07.private/env`.
- MariaDB integration with platform operation commands:
  - start
  - stop
  - status
- Initial MariaDB backup and restore documentation.

### Changed

- MariaDB initializes only the root account.
- Application-specific databases, users, passwords, and privileges are now owned by each application deployment.
- MariaDB is documented as a shared infrastructure service.
- Sprint 002 marked as completed.

---

## [0.2.0-foundation] - 2026-07-15

### Added

- First operational platform service.
- Landing page service.
- Platform operation layer.
- Shared operation library.
- Standard lifecycle commands:
  - start
  - stop
  - status

### Changed

- Sprint 001 marked as completed.

---

## [0.1.0-alpha] - 2026-07-11

### Added

- Initial engineering documentation.
- Project Charter.
- Engineering Principles.
- Project Roadmap.
- Sprint 001 definition.
- Development environment.
- Repository structure.

### Notes

Official project kickoff completed.

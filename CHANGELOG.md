## [Unreleased]

### Added

- POC-001 Nextcloud Files service definition with a dedicated cron container.
- Independent Nextcloud database provisioning and destructive reset commands.
- Non-destructive Nextcloud storage validation.
- Deployment, validation, backup, restore and rollback documentation.

### Changed

- The operation-layer lifecycle selects Nextcloud instead of OwnCloud for the
  controlled PoC window.

### Notes

- OwnCloud configuration and state remain preserved for rollback.
- Runtime acceptance and any production migration decision remain pending.

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

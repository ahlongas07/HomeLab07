## [Unreleased]

### Added

- Add the Sprint 010 Backup & Recovery architecture and private configuration
  contract based on encrypted Restic repositories and safe disposable restores.
- Add a versioned JSON recovery-manifest contract, coordinated data/manifest
  snapshots, artifact checksums and manifest-driven disposable restore.
- Add shared platform control principles, a service recovery matrix and a
  documented future path for off-site, append-only and scheduled backups.
- Add a sanitized target-host validation record for backup, controlled failure,
  disposable restore, recovery objectives and Sprint acceptance.

### Changed

- Complete Sprint 010 with encrypted snapshot integrity, manifest-driven
  disposable restore, Git bundle verification, isolated MariaDB import,
  reviewed retention and explicitly accepted residual recovery risks.
- Update the Landing Page with the completed Backup & Recovery milestone.

- Make backup runtime restoration fail visibly for every quiesced service and
  align service recovery documentation with the operation layer.
- Resolve Nginx Proxy Manager state from its owning private configuration and
  validate the exact proxy state root during backup preflight.
- Fail backup preflight before service quiescing when any protected source tree
  cannot be traversed or read by the operator.
- Include staging recovery artifacts in the platform-state snapshot and verify
  their presence before writing the coordinated Recovery Manifest.
- Reject disposable restore destinations that overlap any part of a local
  Restic repository.
- Group Restic retention by host and recovery tag so unique staging paths do
  not prevent expiration of older recovery points.

- Add the Sprint 009 Platform Operations implementation plan covering exposure
  inventory, management isolation, WAF, rate limiting, security headers,
  runtime hardening, security audit and Zero Trust evaluation.
- Add the sanitized edge-security policy, validation and incident-response
  procedures for the manually managed Cloudflare and gateway controls.
- Add a read-only security audit for Compose exposure, runtime privilege,
  network exceptions, private-file permissions and external validation gates.
- Complete Sprint 009 target validation with zero required-control failures,
  owner-only private-file permissions, successful Dynamic DNS recreation and
  successful rendering of all service Compose definitions.
- Update the Landing Page to present the completed Sprint 009 Platform
  Operations and validated edge-security milestone.
- Update the Landing Page to present Homebridge and the completed Sprint 008
  milestone while preserving its LAN-only service boundary.

---

## [v0.10.0-homebridge-platform] - 2026-07-27

### Added

- Sprint 008 Homebridge service definition using an official immutable image
  reference, host networking and one NAS-backed recovery boundary.
- Homebridge storage, image-reference and mount-conflict validation through
  the operation layer.
- Homebridge deployment, LAN security, plugin ownership, backup, restore and
  controlled-cutover documentation.
- Sprint 007 Media Platform implementation plan using Jellyfin.
- Jellyfin service definition using the official pinned image, non-root
  execution, read-only media mounts and scoped Intel VA-API access.
- Jellyfin storage and render-device validation through the operation layer.
- Jellyfin deployment, playback, publication, backup, restore and security
  documentation.
- Dedicated read-only music and family-photo libraries, preserving Rockstor as
  the authoritative owner and backup boundary.

### Changed

- Approve Homebridge as Sprint 008, formalize its LAN-only, host-networking,
  runtime-ownership and recovery boundaries, and reconcile subsequent Sprint
  numbers without removing planned platform capabilities.
- Extend start, stop and status operations with Homebridge and optional
  single-service selection while preserving the existing all-service mode.
- Validate Homebridge state permissions with the image's effective runtime
  user instead of incorrectly requiring write access from the shell operator.
- Allow a stopped legacy Homebridge container to retain the state mount for
  rollback while continuing to reject concurrent running containers.
- Complete Sprint 008 after controlled cutover, HomeKit and camera validation,
  LAN isolation tests, container recreation, restore and rollback acceptance.
- Extend start, stop and status operations with Jellyfin.
- Complete Sprint 007 after deployment, playback, HTTPS, scoped VA-API,
  container recreation and configuration-restore validation.
- Revalidate and pin Jellyfin `10.11.11` at implementation entry.
- Reinforce Sprint 007 storage ownership, identity deferral, future integration,
  engineering principles and disaster-recovery boundaries after architecture
  review.
- Update the Landing Page to present Paperless-ngx and the completed document
  management milestone.
- Record the Sprint 007 Intel Sandy Bridge VA-API capability decision and
  restrict acceleration to the validated render device and codec profiles.
- Update the Landing Page to present Jellyfin and the completed media-platform
  milestone.
- Reconcile Identity Platform planning with its deferred Sprint 011 roadmap
  position without changing its technical scope.

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

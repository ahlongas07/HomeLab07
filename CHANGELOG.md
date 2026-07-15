## [0.3.0-data-foundation] - 2026-07-15

### Added

- MariaDB shared infrastructure service.
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

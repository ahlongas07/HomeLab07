# HomeLab07

> Build • Host • Automate
>
> > ⚠️ **Project Status**
>
> HomeLab07 is currently in active early development.
> The repository reflects the project's operational, data, secure publication, and in-memory platform foundation and will evolve incrementally through documented sprints.

HomeLab07 is an infrastructure engineering project focused on designing and building a modern, reproducible, secure, and maintainable self-hosted platform.

The project emphasizes:

- Simplicity
- Automation
- Security
- Documentation
- Reproducibility
- Infrastructure as Code
- Persistent storage separation
- Secure public service publication
- Cloudflare-backed DNS automation

## Project Status

The current sprint, open validation items, completed milestones and proposed
investigations are tracked in the [Roadmap](ROADMAP.md). The Roadmap is the
single source of truth for project status.

The project has established:

- The first operational platform service.
- The platform operation layer.
- The persistent data foundation.
- MariaDB as the first shared infrastructure service.
- Nginx Proxy Manager as the centralized public entry point.
- HTTPS publication for the Landing Page.
- Cloudflare Dynamic DNS as an implemented platform enhancement.
- Valkey as the shared in-memory data platform.
- Nextcloud as the active business-facing collaboration service.
- Paperless-ngx as the active document-management service.
- Jellyfin as the active media service.
- Homebridge as the active LAN-only HomeKit integration service.
- Keycloak as the validated shared identity provider for supported consumers.
- Trivy-based vulnerability management as the active platform enhancement.

Sprint 007 completed the media-platform milestone with NAS-backed movies,
music and family media, secure HTTPS publication, recoverable application
state and validated Intel VA-API acceleration.

Sprint 008 completed the Homebridge operational-adoption milestone with an
immutable runtime, preserved HomeKit identity, working camera integrations,
LAN isolation and validated recovery.

Sprint 009 completed the Platform Operations milestone with validated edge
controls, origin restrictions, LAN-only proxy administration, staged HSTS,
sanitized incident procedures and a target-tested read-only security audit.

Sprint 013 completed the observability baseline. Sprint 014's NAS Command
Center implementation is complete and awaits target validation. Sprint 012
remains open for remediation review and a new private run covering full-history
Gitleaks; see the Roadmap and sprint records for current validation details.

POC-001 closed with Nextcloud selected as the active collaboration service.
The previous OwnCloud implementation remains recoverable from the
`v0.6.0-collaboration-platform` tag; its database, NAS data and private
configuration are outside this repository change.

Implemented direction:

- Shared MariaDB, Valkey, Nginx Proxy Manager, and Cloudflare Dynamic DNS.
- NAS-backed storage remains the authoritative user data layer.
- Nextcloud server-side and end-to-end encryption remain disabled to preserve
  direct file recoverability from NAS storage.
- Public endpoint values and environment-specific configuration belong only in `HomeLab07.private/`.
- Nextcloud uses `nextcloud:33.0.6-apache` with shared MariaDB and Valkey,
  dedicated NAS-backed state, and a separate cron container.
- Paperless-ngx uses the shared MariaDB and Valkey capabilities with dedicated
  NAS-backed document storage and HTTPS publication through Nginx Proxy Manager.
- Jellyfin uses dedicated NAS-backed state, read-only media libraries and
  scoped Intel VA-API access without MariaDB, Valkey or direct host ports.
- Homebridge uses a complete NAS-backed application-state boundary and a
  service-specific host-networking exception without public DNS, reverse proxy
  publication or shared Docker networks.
- Platform exposure, edge controls and management boundaries are defined in
  [`docs/security/`](docs/security/); [`operation/security-audit.sh`](operation/security-audit.sh)
  checks repository and runtime posture without changing infrastructure state
  or exposing environment data.
- [`operation/security-scan.sh`](operation/security-scan.sh) orchestrates
  report-only repository and remote-image scans and writes detailed evidence
  only to the configured private report share.

## Documentation

- [Project Charter](PROJECT_CHARTER.md)
- [Engineering Principles](ENGINEERING_PRINCIPLES.md)
- [Roadmap and canonical project status](ROADMAP.md)
- [Sprint documents](sprints/)
- [Architecture contracts](architecture/)
- [Backup and recovery](docs/backup/)
- [Observability](docs/observability/)
- [Security](docs/security/)

## License

MIT License

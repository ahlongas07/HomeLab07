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

🚧 Early Development

Sprint 001 through Sprint 005 are complete. Sprint 006 implementation is in
progress.

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
- Paperless-ngx as the Sprint 006 document-management implementation target.

Sprint 005 completed the collaboration platform milestone.

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

## Documentation

- Project Charter
- Engineering Principles
- Roadmap
- Sprint documents

## License

MIT License

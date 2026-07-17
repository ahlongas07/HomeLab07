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

Sprint 001, Sprint 002, Sprint 003, Sprint 004, and Sprint 005 are complete.

The project has established:

- The first operational platform service.
- The platform operation layer.
- The persistent data foundation.
- MariaDB as the first shared infrastructure service.
- Nginx Proxy Manager as the centralized public entry point.
- HTTPS publication for the Landing Page.
- Cloudflare Dynamic DNS as an implemented platform enhancement.
- Valkey as the shared in-memory data platform.
- OwnCloud as the first business-facing collaboration service.

Sprint 005 completed the collaboration platform milestone.

Implemented direction:

- OwnCloud Server using `owncloud/server:10.16.3`.
- Shared MariaDB, Valkey, Nginx Proxy Manager, and Cloudflare Dynamic DNS.
- NAS-backed storage remains the authoritative user data layer.
- OwnCloud server-side encryption remains disabled to preserve direct file recoverability from NAS storage.
- Public endpoint values and environment-specific configuration belong only in `HomeLab07.private/`.

## Documentation

- Project Charter
- Engineering Principles
- Roadmap
- Sprint documents

## License

MIT License

# Sprint 002 – Data Foundation

**Version:** v0.3.0-data-foundation

**Status:** Planned

---

# Objective

Establish the persistent data foundation for HomeLab07 by introducing the platform's first shared stateful service.

This sprint defines the storage architecture that future platform services will follow, ensuring that application state survives container recreation while remaining independent from the source code repository.

---

# Scope

## In Scope

- Deploy MariaDB as the first shared platform service.
- Persistent database storage.
- Integration with the existing `operation/` layer.
- Secure credential management using `HomeLab07.private`.
- Define the platform storage architecture.
- Initial backup strategy.
- Service documentation.

## Out of Scope

- Reverse proxy.
- HTTPS.
- Let's Encrypt.
- Public Internet exposure.
- Identity management.
- Application deployment.
- Database replication.
- High availability.
- Performance tuning.

---

# Deliverables

Create:

```
services/mariadb/
```

Including:

- compose.yaml
- README.md
- Environment template
- Persistent volume configuration
- Initial database configuration

Create the persistent storage layout:

```
homelab07-data/
└── mariadb/
```

Integrate the service with:

- operation/start.sh
- operation/stop.sh
- operation/status.sh

Document the storage architecture and deployment process.

---

# Storage Architecture

This sprint establishes the standard persistent storage model for HomeLab07.

Persistent application data must never be stored inside the Git repository.

All persistent platform data will be stored under the dedicated Rockstor share:

```
homelab07-data/
```

Each stateful service owns its own directory inside the share.

Example:

```
homelab07-data/
├── mariadb/
├── nginx-proxy-manager/
├── owncloud/
├── authentik/
└── ...
```

This storage model becomes the standard for all future persistent services.

---

# Stateful Service Principles

Every stateful service must:

- Persist data outside the Git repository.
- Survive container recreation.
- Be fully reproducible from version-controlled configuration.
- Keep runtime data separated from configuration.
- Never depend on writable container layers for persistence.

---

# Success Criteria

The sprint will be considered complete when:

- MariaDB starts successfully through:

```bash
./operation/start.sh
```

- The database survives container recreation.

- Persistent data is stored under:

```
homelab07-data/mariadb/
```

- Credentials are stored outside the Git repository.

- The service is reachable only from the internal Docker network.

- Database initialization is documented.

- Platform operations continue to be executed exclusively through the `operation/` layer.

---

# Security Requirements

The database must never be exposed directly to the public network.

Every application must have:

- its own database;
- its own database user;
- its own password;
- only the minimum required privileges.

Database credentials must never be committed to Git.

All secrets must remain under:

```
HomeLab07.private/
```

Persistent application data must never be stored inside:

- the Git repository;
- writable container layers.

---

# Architecture Principles

This sprint reinforces the architectural principles established during Sprint 001.

In particular:

- MariaDB is a shared platform service.
- Applications consume the database but never own it.
- Operational actions remain centralized in `operation/`.
- Source code, secrets, and persistent data remain physically separated.
- Rockstor manages persistent storage.
- Docker manages service execution.
- Git manages platform definition.

---

# Risks

- Incorrect volume mapping.
- File permission issues.
- Credential management errors.
- Database initialization failures.
- Data loss due to incorrect storage configuration.

---

# Dependencies

Requires completion of:

- Sprint 001 – Foundation

---

# Expected Outcome

At the end of this sprint, HomeLab07 provides its first production-ready stateful platform service together with the persistent storage architecture that all future services will adopt.

This sprint establishes the permanent separation between:

- Source Code
- Secrets
- Persistent Application Data

forming one of the core architectural principles of HomeLab07.

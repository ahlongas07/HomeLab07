# Sprint 002 – Data Foundation

**Version:** v0.3.0-data-foundation

**Status:** Completed

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
- Automatic TLS certificates.
- Public Internet publication.
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
- .env.example
- Persistent volume configuration
- Root account bootstrap configuration

Create the persistent storage structure inside the dedicated Rockstor Share:

```
homelab07-data/
└── mariadb/
```

Integrate the service with:

- operation/start.sh
- operation/stop.sh
- operation/status.sh

Document:

- Deployment procedure
- Storage architecture
- Initial backup procedure
- Initial restore procedure

---

# Storage Architecture

This sprint establishes the standard persistent storage model for HomeLab07.

Persistent application data must never be stored inside the Git repository.

Persistent data is stored in a dedicated Rockstor Share.

Share name:

```
homelab07-data
```

The physical mount point depends on the NAS configuration and must never be hardcoded.

The mount point is provided through the private environment variable:

```bash
HOMELAB07_DATA_ROOT=/path/to/homelab07-data
```

This value belongs outside the Git repository in:

```text
HomeLab07.private/env/mariadb.env
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

This storage model becomes the standard for all future persistent platform services.

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

The sprint is complete because:

- [x] MariaDB starts successfully through:

```bash
./operation/start.sh
```

- [x] MariaDB stops successfully through:

```bash
./operation/stop.sh
```

- [x] Platform status reports MariaDB correctly through:

```bash
./operation/status.sh
```

- [x] `docker compose config` validates successfully.

- [x] The database survives container recreation.

- [x] Persistent data is stored inside the dedicated Rockstor Share.

- [x] Credentials are stored outside the Git repository.

- [x] The service is reachable only from the internal Docker network.

- [x] MariaDB root account initialization is documented.

- [x] Application-specific database provisioning is documented.

- [x] Backup procedure is documented.

- [x] Restore procedure is documented.

---

# Validation Results

Sprint 002 implementation was fully validated.

- [x] MariaDB 11.4.12 deployed successfully.
- [x] Persistent storage validated using the dedicated Rockstor Share.
- [x] Data survives container recreation.
- [x] MariaDB runs as the `mysql` user.
- [x] Healthcheck is operational.
- [x] Docker bind mount verified.
- [x] `operation/start.sh` implemented and validated.
- [x] `operation/stop.sh` implemented and validated.
- [x] `operation/status.sh` implemented and validated.
- [x] Secrets are stored in `HomeLab07.private`.
- [x] No application-specific database is created during MariaDB bootstrap.
- [x] MariaDB acts exclusively as a shared infrastructure service.

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

- MariaDB is a shared infrastructure service.
- MariaDB initializes only the root account.
- Applications create and own their own databases, users, passwords, and privileges.
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

Requires:

- Sprint 001 – Foundation (Completed)

---

# Expected Outcome

At the end of this sprint, HomeLab07 provides its first production-ready stateful platform service together with the persistent storage architecture that all future services will adopt.

This sprint establishes the permanent separation between:

- Source Code
- Secrets
- Persistent Application Data

forming one of the core architectural principles of HomeLab07.

---

# Sprint Outcome

Sprint 002 successfully established the HomeLab07 data foundation.

The platform now provides:

- A shared MariaDB infrastructure service.
- Persistent database storage outside the Git repository.
- Private environment configuration through `HomeLab07.private/env/mariadb.env`.
- Internal-only database networking.
- Operational integration through `operation/start.sh`, `operation/stop.sh`, and `operation/status.sh`.
- Initial backup and restore documentation.

This sprint confirms that stateful infrastructure services can be deployed reproducibly while keeping source code, secrets, and persistent data separated.

Release version:

```text
v0.3.0-data-foundation
```

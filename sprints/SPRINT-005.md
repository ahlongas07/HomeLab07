# Sprint 005 — Collaboration Platform

**Version:** v0.6.0-collaboration-platform

**Status:** Completed

---

# Objective

Deploy the first business-facing platform service on top of the HomeLab07 shared platform.

This sprint validates that the platform capabilities introduced in previous sprints can be consumed without modifying the underlying infrastructure.

The objective is **not** simply to deploy OwnCloud.

The objective is to demonstrate that HomeLab07 has successfully evolved into a reusable application platform.

---

# Engineering Objective

This sprint validates the core engineering philosophy of HomeLab07.

Infrastructure capabilities are implemented once.

Business applications consume those capabilities.

No platform service should become application-specific.

The successful completion of this sprint demonstrates that new applications can be onboarded without redesigning the platform.

---

# Scope

## In Scope

- Deploy OwnCloud Server.
- Shared MariaDB integration.
- Shared Valkey integration.
- HTTPS publication through Nginx Proxy Manager.
- Persistent application storage.
- Operation Layer integration.
- Platform documentation.
- Engineering validation.

---

## Out of Scope

- Authentik.
- Single Sign-On.
- LDAP.
- External Storage Providers.
- Object Storage.
- Backup automation.
- Monitoring.
- High Availability.
- Clustering.
- Performance tuning.

Identity is planned for Sprint 010.

Backup automation is planned for Sprint 009.

Existing NAS shares should not be mounted directly into OwnCloud's internal data tree during Sprint 005. The preferred future integration model for existing NAS data is OwnCloud External Storage over SMB, WebDAV, FTP, or SFTP.

---

# Approved Technology Stack

The following technology stack is approved for Sprint 005.

| Capability | Approved Technology |
|------------|---------------------|
| Application | `owncloud/server:10.16.3` |
| Database | Shared MariaDB 11.4 |
| In-memory platform | Shared Valkey |
| Reverse proxy | Nginx Proxy Manager |
| Dynamic DNS | Cloudflare Dynamic DNS |

Do not use:

- OCIS.
- `latest` image tags.
- release candidate images.
- dedicated MariaDB.
- dedicated Valkey.

---

# Platform Dependencies

OwnCloud consumes the following platform capabilities.

| Capability | Service |
|------------|---------|
| Database | MariaDB |
| In-Memory Data | Valkey |
| HTTPS Publication | Nginx Proxy Manager |
| Dynamic DNS | Cloudflare Dynamic DNS |

The sprint must not modify any existing platform capability unless a platform-wide engineering improvement is identified.

---

# Persistent Storage

Create a dedicated Rockstor Share.

Recommended:

```text
homelab07-owncloud
```

Suggested layout:

```text
homelab07-owncloud/
└── <official-owncloud-runtime-layout>
```

Persistent data must remain isolated from other platform services.

The entire official OwnCloud persistent root is mounted at:

```text
${OWNCLOUD_DATA_ROOT} -> /mnt/data
```

The OwnCloud container must set the internal volume paths explicitly:

```text
OWNCLOUD_VOLUME_ROOT=/mnt/data
OWNCLOUD_VOLUME_FILES=/mnt/data/files
```

The expected OwnCloud `datadirectory` is:

```text
/mnt/data/files
```

The official image owns the internal layout. The resulting directories, ownership and permissions must be captured after first initialization and documented in the service README.

No individual subdirectory mount should be introduced during Sprint 005 unless required by a demonstrated operational need.

---

# Storage Principles

- The NAS is the authoritative storage layer.
- OwnCloud provides collaboration services on top of NAS-backed storage.
- Applications must not become the owners of user data.
- Persistent OwnCloud data must remain directly recoverable from NAS storage.
- Files uploaded through OwnCloud should be recoverable from `${OWNCLOUD_DATA_ROOT}/files/<owncloud-user>/files/`.
- Existing NAS shares require a future External Storage evaluation instead of direct internal data tree mounts.

---

# Encryption Policy

OwnCloud server-side encryption must remain disabled.

The following are not approved for Sprint 005:

- Default Encryption Module.
- Server-side encryption.
- Application-managed encryption at rest.

The engineering objective is to preserve direct recoverability of files from the NAS.

Encryption that prevents direct file recovery from NAS storage is out of scope.

This is a permanent engineering rule for OwnCloud in HomeLab07 unless a future sprint explicitly approves a different storage and recovery model.

---

# Database Provisioning

Database creation is handled through the HomeLab07 operation layer during this sprint.

The operation scripts read private values from `HomeLab07.private/`.

Required scripts:

```text
operation/owncloud-db-create.sh
operation/owncloud-db-drop.sh
operation/owncloud-storage-check.sh
```

The drop script must require interactive confirmation.

The storage check script must be non-destructive and validate that `OWNCLOUD_DATA_ROOT` is an absolute path, exists on the host, and contains the expected OwnCloud data marker after successful initialization.

SQL must use placeholders only.

Do not hardcode the database collation before implementation.

Database collation must be validated against OwnCloud Server 10.16.3 recommendations before creating the database.

Example:

```sql
CREATE DATABASE owncloud
CHARACTER SET <owncloud-database-charset>
COLLATE <validated-owncloud-collation>;

CREATE USER 'owncloud'@'%'
IDENTIFIED BY '<owncloud-database-password>';

GRANT ALL PRIVILEGES
ON owncloud.*
TO 'owncloud'@'%';

FLUSH PRIVILEGES;
```

MariaDB remains application agnostic.

No OwnCloud-specific MariaDB container shall be introduced.

The OwnCloud table prefix must be defined before initialization:

```text
OWNCLOUD_DB_PREFIX=oc_
```

If the prefix is missing, OwnCloud may query unprefixed tables such as `appconfig` while the schema contains `oc_appconfig`.

---

# Private Configuration

The following values belong exclusively inside:

```text
HomeLab07.private/
```

Expected variables include:

- database credentials;
- OwnCloud administrator credentials;
- public URL;
- trusted domains;
- reverse proxy configuration where applicable.

The repository must contain only placeholder values.

Real public URLs must not be committed to the repository.

The approved public endpoint value belongs in `HomeLab07.private/` and must be represented in repository documentation with placeholders.

---

# Reverse Proxy Configuration

OwnCloud must be published exclusively through Nginx Proxy Manager.

OwnCloud must never expose host ports.

OwnCloud must not assume direct Internet exposure.

Publication path:

```text
Internet
    ↓
Cloudflare
    ↓
Nginx Proxy Manager
    ↓
OwnCloud
```

The service documentation must include placeholder-based configuration for:

- `trusted_domains`;
- `trusted_proxies`;
- `overwrite.cli.url`;
- `overwriteprotocol=https`.

The approved public endpoint is environment-specific and belongs in `HomeLab07.private/`.

Configuration must prevent:

- redirect loops;
- mixed content;
- incorrect HTTPS detection;
- login failures.

Real public URLs belong exclusively inside `HomeLab07.private/`.

---

# Valkey Decision

Sprint 004 intentionally deployed Valkey without authentication.

Sprint 005 must evaluate this decision.

Current engineering decision:

- ACL authentication remains deferred.
- The current trust model relies on Docker internal networking.
- OwnCloud consumes the shared Valkey platform capability.
- No application-specific Valkey instance shall be deployed.

Future ACL evaluation triggers include:

- multiple application consumers;
- reduced trust boundary;
- multi-host deployment.

---

# MariaDB Compatibility Risk

HomeLab07 currently uses shared MariaDB 11.4.

OwnCloud documentation may not explicitly certify MariaDB 11.4.

The compatibility risk is accepted for Sprint 005 and must be validated during implementation.

No platform downgrade shall be performed unless a reproducible incompatibility is demonstrated.

If MariaDB compatibility issues are identified:

1. Capture logs.
2. Identify the failing component.
3. Validate whether the issue is configuration-related.
4. Evaluate OwnCloud adjustments.
5. Evaluate OwnCloud version adjustments.
6. Evaluate MariaDB workarounds.
7. Consider platform downgrade only as a last resort.

Platform capabilities must not be modified solely to satisfy a single application.

---

# Docker Principles

The service must follow existing HomeLab07 conventions.

Expected characteristics:

- `restart: unless-stopped`;
- healthcheck enabled;
- read-only filesystem where practical;
- no unnecessary Linux capabilities;
- no privilege escalation.

If OwnCloud requires writable runtime paths, document the engineering decision rather than introducing unnecessary complexity.

---

# Networking

OwnCloud joins:

- `homelab07-internal`;
- `homelab07-proxy`.

No host ports shall be published.

Public traffic enters exclusively through Nginx Proxy Manager.

Cloudflare Dynamic DNS remains transparent to the application.

No application-specific DNS logic shall be implemented.

---

# Operation Layer

Integrate OwnCloud with:

```text
operation/start.sh
operation/stop.sh
operation/status.sh
operation/compose.sh
```

Normal operation should never require direct Docker Compose commands.

---

# Manual Nginx Proxy Manager Configuration

During Sprint 005, the Nginx Proxy Manager Proxy Host is created manually.

Use placeholders in repository documentation.

The approved public endpoint and real public domain belong exclusively inside `HomeLab07.private/`.

This is a temporary, sprint-approved manual administrative change. Production must never become the undocumented source of truth. Every manual Nginx Proxy Manager change must have a placeholder-based, reproducible procedure in the repository.

Proxy Host requirements:

| Setting | Value |
|---------|-------|
| Domain | `<owncloud-public-domain>` |
| Forward Host | `homelab07-owncloud` |
| Forward Port | `8080` |
| Scheme | `http` |
| SSL Certificate | Let's Encrypt |
| Force SSL | enabled |
| HTTP/2 | enabled |

Validate that OwnCloud is reachable through the full publication path:

```text
Internet
    ↓
Cloudflare
    ↓
Nginx Proxy Manager
    ↓
OwnCloud
```

---

# Operational Principle

Whenever administrative actions are required, prefer:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ
```

over manual file editing.

Every `occ` command executed during installation must be documented.

---

# Documentation

Create:

```text
services/owncloud/
├── compose.yaml
├── README.md
└── .env.example
```

The README must include:

- Purpose.
- Responsibilities.
- Platform Dependencies.
- Storage.
- Networking.
- Deployment.
- Validation.
- Security.
- Backup.
- Restore.
- Related Sprint.

---

# Backup

Backup automation is intentionally outside the scope of Sprint 005.

The README must document the critical persistent data.

Expected paths:

```text
${OWNCLOUD_DATA_ROOT}
```

Backup implementation is planned for Sprint 009.

---

# Healthcheck Requirements

Healthchecks must tolerate the initial installation and migration process.

Startup probes must not be aggressive.

A healthcheck that marks OwnCloud unhealthy during expected first-run initialization is not acceptable.

---

# Validation

## Platform Validation

Validate:

- MariaDB connectivity.
- Valkey connectivity.
- HTTPS publication.
- Nginx Proxy Manager routing.
- Cloudflare publication.
- OwnCloud host storage path through `operation/owncloud-storage-check.sh`.

---

## Application Validation

Validate:

- Installation wizard.
- Administrator login.
- User creation.
- File upload.
- File download.
- Folder creation.
- File sharing between users.
- Uploaded file visibility from the NAS under `${OWNCLOUD_DATA_ROOT}/files/<owncloud-user>/files/`.
- Transactional file locking.

---

## Infrastructure Validation

Validate:

```bash
docker port homelab07-owncloud
```

Expected:

```text
No output
```

Validate:

```bash
docker inspect homelab07-owncloud \
  --format '{{json .NetworkSettings.Networks}}'
```

Expected:

- `homelab07-internal`;
- `homelab07-proxy`.

Validate:

```bash
docker exec homelab07-owncloud id
docker exec homelab07-owncloud id www-data
docker exec homelab07-owncloud ps -eo user,pid,ppid,args
```

Expected:

```text
Container initialization and web worker users are understood and documented.
```

Validate:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ status
```

Expected:

```text
OwnCloud reports a healthy installation.
```

Validate:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:list system
```

Expected:

- `memcache.local` is configured.
- `memcache.locking` is configured.
- Redis configuration is present.
- Redis-backed configuration points to `homelab07-valkey`.
- `datadirectory` points to `/mnt/data/files`.

Validate:

- Runtime storage layout and permissions.
- Container recreation.
- Persistent storage survives restart.
- HTTPS remains functional.

---

# Acceptance Criteria

Sprint 005 is complete when:

- OwnCloud Server 10.16.3 deploys successfully.
- MariaDB integration succeeds.
- Valkey integration succeeds.
- HTTPS publication succeeds.
- Reverse proxy configuration is validated.
- File locking functions correctly.
- Files survive container recreation.
- No host ports are exposed.
- Platform documentation is complete.
- No shared platform capability required application-specific modifications.

Warnings and non-blocking deprecations must be documented but do not automatically fail the sprint.

---

# Completion Notes

Sprint 005 was completed after validating OwnCloud as the first business-facing service on top of the shared HomeLab07 platform.

Validated outcomes:

- OwnCloud Server 10.16.3 deployed successfully.
- Shared MariaDB integration succeeded.
- Shared Valkey integration succeeded.
- Valkey usage was confirmed through Redis-compatible cache activity observed with `valkey-cli MONITOR`.
- HTTPS publication through Cloudflare and Nginx Proxy Manager succeeded.
- No OwnCloud host ports are published.
- OwnCloud storage uses a dedicated NAS-backed share mounted at `/mnt/data`.
- OwnCloud `datadirectory` is `/mnt/data/files`.
- Uploaded files are recoverable from the NAS under `${OWNCLOUD_DATA_ROOT}/files/<owncloud-user>/files/`.
- OwnCloud server-side encryption remains disabled.
- Existing NAS shares remain outside the internal OwnCloud data tree and are deferred to a future External Storage evaluation.

Operational lessons were captured in:

```text
services/owncloud/IMPLEMENTATION_NOTES.md
```

---

# Success Criteria

At the completion of Sprint 005:

- HomeLab07 successfully hosts its first business-facing application.
- Shared platform capabilities remain independent.
- The platform architecture is validated.
- Future applications can reuse the same capabilities without redesigning the infrastructure.

This sprint represents the transition from building infrastructure to delivering reusable platform services.

---

# Engineering Principles

This sprint reinforces the HomeLab07 Engineering Contract.

Platform capabilities are implemented once.

Applications consume those capabilities.

Infrastructure remains application agnostic.

Engineering decisions are documented.

Operational procedures remain reproducible.

Security is introduced incrementally without unnecessary complexity.

Every implementation should strengthen the platform rather than increase coupling between infrastructure and applications.

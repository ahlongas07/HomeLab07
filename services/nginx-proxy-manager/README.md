## Nginx Proxy Manager

## Purpose

Nginx Proxy Manager is the centralized networking gateway of HomeLab07.

It provides secure publication of platform services through automatic HTTPS while abstracting reverse proxy configuration and certificate management from individual applications.

---

# Service Classification

**Type**

Platform Service

---

# Responsibilities

Nginx Proxy Manager is responsible for:

- Reverse Proxy
- HTTPS termination
- Automatic Let's Encrypt certificate management
- Public service publication
- HTTP → HTTPS redirection

Nginx Proxy Manager is **not** responsible for:

- Identity management
- Authentication
- Database management
- Secret management
- Application configuration

---

# Technology

| Component | Technology |
|-----------|------------|
| Reverse Proxy | Nginx Proxy Manager 2.15.1 |
| Database | MariaDB |
| Certificates | Let's Encrypt |
| Runtime | Docker Compose |

---

# Infrastructure Requirements

Requires available shared infrastructure:

- MariaDB (Sprint 002)

---

# Platform Integration

Uses shared infrastructure:

- MariaDB

Provides:

- Reverse Proxy
- HTTPS
- Certificate Management

Consumed by:

- Landing Page
- Future Platform Services

---

# Architecture Overview

```
                 Internet
                      │
                      ▼
          Nginx Proxy Manager
                      │
       ┌──────────────┴──────────────┐
       ▼                             ▼
Landing Page                Future Services

──────────────────────────────────────────

          Shared Infrastructure

               MariaDB
```

Nginx Proxy Manager is the **only service exposed to the public Internet**.

All remaining platform services remain on private Docker networks unless explicitly published.

MariaDB belongs to the shared infrastructure layer and is not part of the public publication path.

Published services, such as the Landing Page, are reached through the proxy network and do not publish their own public ports.

Port `81` is a management exception. It must remain reachable only from the
approved LAN and denied from WAN, guest and untrusted networks. The Compose
mapping alone does not prove that boundary; validate it externally using
`docs/security/VALIDATION.md`.

Proxy hosts that traverse Cloudflare use a Cloudflare-source-only access list
followed by deny-all. DNS-only services must not use that list because their
traffic does not traverse the Cloudflare HTTP proxy. Desired edge state and
rollback procedures are maintained under `docs/security/`.

---

# Directory Structure

Repository

```
services/

nginx-proxy-manager/

├── compose.yaml
├── README.md
└── .env.example
```

External Resources

```
HomeLab07.private/

└── env/
    └── nginx-proxy-manager.env

homelab07-data/

└── nginx-proxy-manager/
    ├── data/
    └── letsencrypt/
```

---

# Environment Configuration

Environment variables are stored outside the Git repository.

Location:

```
HomeLab07.private/env/nginx-proxy-manager.env
```

Create the private environment file from the repository template:

```bash
mkdir -p ../HomeLab07.private/env
cp services/nginx-proxy-manager/.env.example ../HomeLab07.private/env/nginx-proxy-manager.env
```

Expected variables:

```dotenv
HOMELAB07_DATA_ROOT=/path/to/homelab07-data

NPM_DB_HOST=homelab07-mariadb
NPM_DB_PORT=3306

NPM_DB_NAME=npm_db
NPM_DB_USER=npm_user
NPM_DB_PASSWORD=replace-with-a-strong-password
```

---

# Deployment Prerequisites

Before deploying Nginx Proxy Manager, initialize the application database inside the shared MariaDB instance.

Connect to MariaDB:

```bash
docker exec -it homelab07-mariadb mariadb -u root -p
```

Create the database:

```sql
CREATE DATABASE npm_db;
```

Create the application user:

```sql
CREATE USER 'npm_user'@'%'
IDENTIFIED BY '<strong-password>';
```

Grant permissions:

```sql
GRANT ALL PRIVILEGES
ON npm_db.*
TO 'npm_user'@'%';

FLUSH PRIVILEGES;
```

Verify:

```sql
SHOW DATABASES;

SELECT User, Host
FROM mysql.user;
```

Store the generated credentials inside:

```
HomeLab07.private/env/nginx-proxy-manager.env
```

---

# Deployment

1. Configure:

```
HomeLab07.private/env/nginx-proxy-manager.env
```

2. Deploy the platform:

```bash
./operation/start.sh
```

3. Verify:

```bash
./operation/status.sh
```

4. Access the administration interface.

---

# Networking

## Public Ports

| Port | Purpose |
|------|----------|
| 80 | HTTP |
| 443 | HTTPS |
| 81 | Administration UI |

## Docker Networks

HomeLab07 standardizes two Docker networks.

Internal Network:

```text
homelab07-internal
```

Purpose:

- Private communication between platform services.

Topology:

```
MariaDB
      │
      ▼
Nginx Proxy Manager
```

Proxy Network:

```text
homelab07-proxy
```

Purpose:

- Traffic between the reverse proxy and published services.

Topology:

```
Internet
      │
      ▼
Nginx Proxy Manager
      │
      ▼
Published Platform Services
```

Only Nginx Proxy Manager is publicly exposed.

Platform services published through Nginx Proxy Manager should join `homelab07-proxy` and avoid publishing host ports directly.

---

# Landing Page Integration

During Sprint 003, the Landing Page becomes the first service published through Nginx Proxy Manager.

The Landing Page should:

- join the `homelab07-proxy` Docker network;
- stop relying on direct public host port publication;
- remain reachable through Nginx Proxy Manager;
- be validated through HTTPS.

This keeps Nginx Proxy Manager as the single public entry point of HomeLab07.

---

# Persistent Storage

Persistent runtime data is stored inside the dedicated Rockstor Share.

| Host | Container | Purpose |
|------|-----------|----------|
| `${HOMELAB07_DATA_ROOT}/nginx-proxy-manager/data` | `/data` | Application configuration |
| `${HOMELAB07_DATA_ROOT}/nginx-proxy-manager/letsencrypt` | `/etc/letsencrypt` | TLS certificates |

Persistent runtime data must never be stored inside the Git repository.

---

# First Login

After the first deployment:

1. Access the administration interface.
2. Sign in using the initial administrator account created by Nginx Proxy Manager.
3. Immediately change:
   - Administrator email
   - Administrator password
4. Store the new credentials securely.

Do not keep the default administrator credentials.

---

# Backup

Nginx Proxy Manager backup requires both persistent files and its application database.

Sprint 010 performs the coordinated stopped-state capture through
`./operation/backup.sh`. This is the authoritative backup interface:

```bash
./operation/backup.sh
```

It stops Nginx Proxy Manager, captures its persistent tree with the coordinated
MariaDB logical dump, verifies the Restic repository and restores the prior
runtime state. A separate filesystem copy is not a complete recovery point.

---

# Restore

Nginx Proxy Manager recovery requires its persistent files and application
database from the same manifest-selected recovery point.

```bash
./operation/restore-test.sh latest /path/to/empty-restore-test
```

After disposable validation, follow the reviewed disaster-recovery order to
restore MariaDB first and the Nginx Proxy Manager tree second. Then validate the
administration boundary, proxy hosts, certificates and representative HTTPS
routes before returning service.

---

# Validation

Sprint 003 validation completed successfully.

- [x] Nginx Proxy Manager starts successfully.
- [x] MariaDB connection succeeds.
- [x] Administration interface is available.
- [x] HTTP redirects to HTTPS.
- [x] HTTPS certificates are issued successfully.
- [x] Certificate renewal is operational.
- [x] Configuration survives container recreation.
- [x] Certificates survive container recreation.
- [x] Landing Page is published through HTTPS.
- [x] Operation layer integration is validated.
- [x] Cloudflare DNS configuration is complete.

---

# Security

HomeLab07 follows a secure-by-default approach.

The following rules apply:

- Only Nginx Proxy Manager is exposed publicly.
- MariaDB remains on the internal Docker network.
- Secrets are stored outside the Git repository.
- Persistent runtime data is stored outside the Git repository.
- HTTPS is enabled for published services.
- Applications are published explicitly.

---

# Engineering Decisions

HomeLab07 intentionally follows these architectural decisions.

- MariaDB is a shared infrastructure service.
- Nginx Proxy Manager owns its own database.
- Application databases are created manually.
- Database initialization is considered a one-time administrative task.
- Operational automation targets recurring activities rather than installation steps.
- Nginx Proxy Manager is the single public entry point of the platform.
- Persistent runtime data remains outside the Git repository.
- Secrets remain outside the Git repository.
- Platform operations remain centralized through the operation layer.

---

# Related Sprint

- Sprint 003 — Zero Touch SSL
- Version: `v0.4.0-zero-touch-ssl`

---

# Future Integration

Future platform services should integrate with Nginx Proxy Manager instead of exposing ports directly.

Examples include:

- Landing Page
- Authentik
- Paperless-ngx
- Nextcloud

This architecture ensures a single, centralized, and secure entry point for all HomeLab07 services.

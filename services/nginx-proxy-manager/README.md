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
| Reverse Proxy | Nginx Proxy Manager |
| Database | MariaDB |
| Certificates | Let's Encrypt |
| Runtime | Docker Compose |

---

# Dependencies

Requires:

- MariaDB (Sprint 002)

---

# Platform Integration

Consumes:

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
              │             │
              │             ▼
              │          MariaDB
              │
              ▼
       Published Platform Services
```

Nginx Proxy Manager is the **only service exposed to the public Internet**.

All remaining platform services remain on private Docker networks unless explicitly published.

MariaDB is a dependency of Nginx Proxy Manager, not a public service.

Published services, such as the Landing Page, are reached through the proxy network and do not publish their own public ports.

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

Internal Network:

```text
homelab07-internal
```

Purpose:

- MariaDB connectivity.
- Private infrastructure communication.

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

- Reverse proxy traffic.
- Communication between Nginx Proxy Manager and explicitly published services.

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

Back up:

- `${HOMELAB07_DATA_ROOT}/nginx-proxy-manager/`
- MariaDB database `npm_db`

1. Stop Nginx Proxy Manager before backing up its persistent files.

```bash
./operation/compose.sh nginx-proxy-manager down
```

2. Back up persistent files:

```
homelab07-data/nginx-proxy-manager/
```

3. Ensure MariaDB is running before creating the logical database backup.

```bash
./operation/compose.sh mariadb up -d
```

4. Back up the Nginx Proxy Manager database:

```bash
docker exec homelab07-mariadb \
  mariadb-dump \
  --single-transaction \
  --quick \
  --lock-tables=false \
  -uroot \
  -p \
  npm_db > /path/to/backups/npm_db.sql
```

5. Store backups outside the Git repository.

Recommended location:

```text
HomeLab07.private/backups/nginx-proxy-manager/
```

6. Start Nginx Proxy Manager again.

```bash
./operation/compose.sh nginx-proxy-manager up -d
```

---

# Restore

Nginx Proxy Manager restore requires both persistent files and its application database.

Restore:

- `${HOMELAB07_DATA_ROOT}/nginx-proxy-manager/`
- MariaDB database `npm_db`

1. Stop Nginx Proxy Manager before restoring its persistent files.

```bash
./operation/compose.sh nginx-proxy-manager down
```

2. Restore persistent files:

```
homelab07-data/nginx-proxy-manager/
```

3. Ensure MariaDB is running before restoring the logical database backup.

```bash
./operation/compose.sh mariadb up -d
```

4. Restore the Nginx Proxy Manager database:

```bash
docker exec -i homelab07-mariadb \
  mariadb \
  -uroot \
  -p \
  npm_db < /path/to/backups/npm_db.sql
```

5. Start Nginx Proxy Manager again.

```bash
./operation/compose.sh nginx-proxy-manager up -d
```

6. Validate the administration interface, proxy hosts, and certificates.

---

# Validation

Deployment is considered successful when:

- Nginx Proxy Manager starts successfully.
- MariaDB connection succeeds.
- Administration interface is available.
- HTTP redirects to HTTPS.
- HTTPS certificates are issued successfully.
- Certificate renewal is operational.
- Configuration survives container recreation.
- Certificates survive container recreation.
- Landing Page is published through HTTPS.
- Operation layer integration is validated.

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

Sprint 003 — Zero Touch SSL

---

# Future Integration

Future platform services should integrate with Nginx Proxy Manager instead of exposing ports directly.

Examples include:

- Landing Page
- Authentik
- Paperless-ngx
- OwnCloud

This architecture ensures a single, centralized, and secure entry point for all HomeLab07 services.

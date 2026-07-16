# MariaDB

## Purpose

Provide the first shared stateful infrastructure service for HomeLab07.

MariaDB establishes the persistent data foundation for platform applications that require relational storage.

---

## Responsibilities

- Shared relational database server
- Persistent database storage
- Internal-only database access
- Stateful service reference implementation
- Initial backup and restore procedure

MariaDB does not create application-specific databases during bootstrap.

---

## Architecture Overview

MariaDB is an infrastructure service, not an application service.

It provides only the database server and initializes only the root account. Each platform application is responsible for creating and managing:

- its own database;
- its own database user;
- its own password;
- its own minimum required privileges.

Examples:

```text
Nginx Proxy Manager
  Database: npm_db
  User: npm_user

OwnCloud
  Database: owncloud_db
  User: owncloud_user

Authentik
  Database: authentik_db
  User: authentik_user
```

This follows the HomeLab07 Storage First architecture:

- source code remains in Git;
- secrets remain in `HomeLab07.private`;
- persistent data remains in the Rockstor storage share;
- lifecycle operations go through `operation/`;
- applications own their own database schema and privileges.

---

## Technology

- MariaDB 11.4.12
- Docker Compose
- Rockstor persistent storage
- HomeLab07 operation layer

---

## Directory Structure

```text
mariadb/
├── compose.yaml
├── .env.example
└── README.md
```

Runtime data is not stored in this directory.

---

## Storage Layout

Persistent database files belong under the dedicated Rockstor share:

```text
homelab07-data/
└── mariadb/
```

The physical mount point is environment-specific and must be configured outside the Git repository through:

```text
HomeLab07.private/env/mariadb.env
```

The service reads the mount point from:

```bash
HOMELAB07_DATA_ROOT=/path/to/homelab07-data
```

The Docker bind mount maps:

```text
${HOMELAB07_DATA_ROOT}/mariadb -> /var/lib/mysql
```

---

## Private Configuration

Create the private configuration file outside this repository:

```bash
mkdir -p ../HomeLab07.private/env
cp services/mariadb/.env.example ../HomeLab07.private/env/mariadb.env
```

Edit the private environment file:

```bash
HOMELAB07_DATA_ROOT=/path/to/homelab07-data
MARIADB_ROOT_PASSWORD=replace-with-a-strong-root-password
```

Do not commit the private environment file.

---

## Deployment Procedure

Validate the Compose configuration through the operation layer:

```bash
./operation/compose.sh mariadb config
```

Start the platform:

```bash
./operation/start.sh
```

Check service status:

```bash
./operation/status.sh
```

Stop the platform:

```bash
./operation/stop.sh
```

If running Docker Compose directly, include the private env file:

```bash
docker compose \
  --env-file ../HomeLab07.private/env/mariadb.env \
  -f services/mariadb/compose.yaml \
  config
```

---

## Operational Commands

HomeLab07 operations must go through the `operation/` layer.

```bash
./operation/start.sh
./operation/status.sh
./operation/stop.sh
./operation/compose.sh mariadb config
```

External automation should invoke these scripts instead of calling Docker Compose directly.

---

## Network Access

MariaDB is attached only to the internal Docker network:

```text
homelab07-internal
```

The service does not publish host ports.

Applications should connect to MariaDB through the internal Docker network, not through the public network.

---

## Validation Results

Sprint 002 validation completed successfully.

- MariaDB 11.4.12 deployed successfully.
- Persistent storage validated using the dedicated Rockstor Share.
- Data survives container recreation.
- MariaDB runs as the `mysql` user inside the container.
- Healthcheck is operational.
- Docker bind mount verified.
- `operation/start.sh` implemented and validated.
- `operation/stop.sh` implemented and validated.
- `operation/status.sh` implemented and validated.
- Secrets are stored in `HomeLab07.private`.
- No application-specific database is created during MariaDB bootstrap.
- MariaDB acts exclusively as a shared infrastructure service.

---

## Backup Strategy

Sprint 002 defines an initial logical backup strategy.

Run the backup from the runtime environment:

```bash
docker exec homelab07-mariadb \
  mariadb-dump \
  --all-databases \
  --single-transaction \
  --quick \
  --lock-tables=false \
  -uroot \
  -p > /path/to/backups/mariadb-backup.sql
```

Backups must be stored outside the Git repository.

Recommended private backup location:

```text
HomeLab07.private/backups/
```

Future backup automation should preserve this separation between source code, secrets, and persistent data.

---

## Restore Procedure

Restore from a logical backup:

```bash
docker exec -i homelab07-mariadb \
  mariadb \
  -uroot \
  -p < /path/to/backups/mariadb-backup.sql
```

Validate the restored databases before returning dependent applications to service.

---

## Security

Database credentials must remain outside Git in:

```text
../HomeLab07.private/env/mariadb.env
```

Database backups must remain outside Git.

Do not expose MariaDB directly to the public network.

Do not commit database dumps, credentials, certificates, or environment-specific storage paths.

---

## Related Sprint

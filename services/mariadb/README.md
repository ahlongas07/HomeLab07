# MariaDB

## Purpose

Provide the first shared stateful platform service for HomeLab07.

MariaDB establishes the persistent data foundation that future platform and application services will use when they require relational storage.

---

## Responsibilities

- Shared relational database service
- Persistent database storage
- Internal-only database access
- Stateful service reference implementation
- Initial backup and restore procedure

---

## Technology

- MariaDB official container image
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

Persistent database files belong under the Rockstor share:

```text
homelab07-data/
└── mariadb/
```

The physical mount point is environment-specific and must be configured outside the Git repository.

---

## Configuration

Create the private configuration file outside this repository:

```bash
mkdir -p ../HomeLab07.private/env
cp services/mariadb/.env.example ../HomeLab07.private/env/mariadb.env
```

Edit the private `.env` file and set real values:

```bash
HOMELAB07_DATA_ROOT=/path/to/homelab07-data
MARIADB_ROOT_PASSWORD=replace-with-a-strong-root-password
```

`HOMELAB07_DATA_ROOT` must point to the mounted Rockstor share named `homelab07-data`.

Do not commit the private `.env` file.

---

## Validation

Validate the Compose configuration through the operation layer:

```bash
./operation/compose.sh mariadb config
```

If running Docker Compose directly, include the private env file:

```bash
docker compose \
  --env-file ../HomeLab07.private/env/mariadb.env \
  -f services/mariadb/compose.yaml \
  config
```

---

## Run

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

---

## Network Access

MariaDB is attached only to the internal Docker network:

```text
homelab07-internal
```

The service does not publish host ports.

Applications should connect to MariaDB through the internal Docker network, not through the public network.

---

## Database Provisioning

MariaDB is a shared infrastructure service.

This service provides only the database server and initializes only the root account.

Application-specific databases are not created during MariaDB bootstrap.

Every platform application is responsible for creating:

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

Application database creation belongs to each application's deployment procedure.

---

## Backup

This sprint defines an initial logical backup procedure.

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

Store backups outside the Git repository.

The backup destination should be managed by the storage platform or a future backup service.

---

## Restore

Restore from a logical backup:

```bash
docker exec -i homelab07-mariadb \
  mariadb \
  -uroot \
  -p < /path/to/backups/mariadb-backup.sql
```

Validate the restored databases before returning dependent applications to service.

---

## Verification

The service is considered healthy when:

- `./operation/start.sh` starts MariaDB successfully;
- `./operation/status.sh` reports the container as running or healthy;
- data remains present after container recreation;
- no database ports are exposed on the host;
- persistent data exists under `homelab07-data/mariadb`.

---

## Security

Database credentials must remain outside Git in:

```text
../HomeLab07.private/env/mariadb.env
```

Do not expose MariaDB directly to the public network.

Do not commit database dumps, credentials, certificates, or environment-specific storage paths.

---

## Related Sprint

- Sprint 002 - Data Foundation

# OwnCloud

## Purpose

OwnCloud provides the first business-facing collaboration service on top of the HomeLab07 shared platform.

It validates that platform capabilities can be consumed by an application without making those capabilities application-specific.

---

## Responsibilities

- Browser-based file collaboration.
- File upload and download.
- Folder creation and sharing.
- User-facing access to NAS-backed data.
- Consumption of shared MariaDB for application metadata.
- Consumption of shared Valkey for cache and transactional file locking.
- Publication through Nginx Proxy Manager.

OwnCloud is not responsible for:

- Owning the authoritative storage layer.
- Managing public DNS records.
- Providing identity federation.
- Providing backup automation.
- Providing platform-wide encryption at rest.
- Running a dedicated database or dedicated cache.

---

## Platform Dependencies

| Capability | Service |
|------------|---------|
| Application | `owncloud/server:10.16.3` |
| Database | Shared MariaDB 11.4 |
| In-memory data | Shared Valkey |
| HTTPS publication | Nginx Proxy Manager |
| Dynamic DNS | Cloudflare Dynamic DNS |
| Storage | NAS-backed Rockstor Share |

Not approved for this sprint:

- OCIS.
- `latest` image tags.
- release candidate images.
- dedicated MariaDB.
- dedicated Valkey.

---

## Storage

The NAS is the authoritative storage layer.

OwnCloud provides collaboration services on top of NAS-backed storage.

Applications must not become the owners of user data.

OwnCloud persistent state is mounted at:

```text
${OWNCLOUD_DATA_ROOT} -> /mnt/data
```

`OWNCLOUD_DATA_ROOT` must point to the dedicated Rockstor Share for OwnCloud.

The entire official OwnCloud persistent root is mounted at `/mnt/data`.

The container sets the OwnCloud internal volume paths explicitly. These values are required because the first deployment showed that relying on image defaults can leave `datadirectory` empty or inconsistent after a failed initialization:

```text
OWNCLOUD_VOLUME_ROOT=/mnt/data
OWNCLOUD_VOLUME_FILES=/mnt/data/files
```

The expected `datadirectory` inside OwnCloud is:

```text
/mnt/data/files
```

The official image owns the internal layout. The resulting directories, ownership and permissions must be captured after first initialization and documented in this README.

Capture the runtime layout with:

```bash
find <OWNCLOUD_DATA_ROOT> -maxdepth 2 \
  -printf '%M %u:%g %p\n'
```

No individual subdirectory mount should be introduced during Sprint 005 unless required by a demonstrated operational need.

Before first start or after a failed initialization, validate the host storage path with:

```bash
./operation/owncloud-storage-check.sh
```

After a successful initialization, the expected OwnCloud data marker is:

```text
${OWNCLOUD_DATA_ROOT}/files/.ocdata
```

If the marker is missing after the service has already installed, reset storage and database together before re-running the first installation. Do not keep a new database with stale storage, or stale storage with a new database.

Files uploaded through the UI are expected to be directly recoverable on the NAS under:

```text
${OWNCLOUD_DATA_ROOT}/files/<owncloud-user>/files/
```

Existing NAS shares should not be mounted directly into OwnCloud's internal `files/` tree during Sprint 005. The preferred future integration model for existing NAS data is OwnCloud External Storage over SMB, WebDAV, FTP, or SFTP, evaluated in a later sprint.

---

## Encryption Policy

OwnCloud server-side encryption must remain disabled.

Do not enable:

- Default Encryption Module.
- Server-side Encryption.
- Application-managed encryption at rest.

The engineering objective is to preserve direct recoverability of files from NAS storage.

Encryption that prevents direct file recovery from NAS storage is out of scope unless a future sprint explicitly approves a different storage and recovery model.

---

## Networking

OwnCloud joins:

```text
homelab07-internal
homelab07-proxy
```

No host ports are published.

Public traffic must follow this path:

```text
Internet
    ↓
Cloudflare
    ↓
Nginx Proxy Manager
    ↓
OwnCloud
```

OwnCloud must never assume direct Internet exposure.

---

## Configuration

Create the private environment file:

```bash
mkdir -p ../HomeLab07.private/env
cp services/owncloud/.env.example ../HomeLab07.private/env/owncloud.env
```

Edit only the private file:

```text
HomeLab07.private/env/owncloud.env
```

Container configuration variables consumed by Docker Compose and the OwnCloud image:

- `OWNCLOUD_DATA_ROOT`
- `OWNCLOUD_DOMAIN`
- `OWNCLOUD_TRUSTED_DOMAINS`
- `OWNCLOUD_OVERWRITE_CLI_URL`
- `OWNCLOUD_OVERWRITE_PROTOCOL`
- `OWNCLOUD_TRUSTED_PROXIES`
- `OWNCLOUD_DB_HOST`
- `OWNCLOUD_DB_NAME`
- `OWNCLOUD_DB_USERNAME`
- `OWNCLOUD_DB_PASSWORD`
- `OWNCLOUD_DB_PREFIX`
- `OWNCLOUD_VOLUME_ROOT`
- `OWNCLOUD_VOLUME_FILES`
- `OWNCLOUD_ADMIN_USERNAME`
- `OWNCLOUD_ADMIN_PASSWORD`
- `OWNCLOUD_REDIS_HOST`

Database provisioning variables consumed only by `operation/owncloud-db-create.sh`:

- `OWNCLOUD_DB_CHARSET`
- `OWNCLOUD_DB_COLLATION`

Real public URLs and credentials belong exclusively inside `HomeLab07.private/`.

Repository examples must use placeholders only.

---

## Database Provisioning

OwnCloud uses the shared HomeLab07 MariaDB platform service.

Database provisioning is managed through the HomeLab07 operation layer during Sprint 005.

Validate the recommended collation for OwnCloud Server 10.16.3 before creating the database.

Do not hardcode the collation until validation is complete.

The operation scripts read private values from:

```text
HomeLab07.private/env/mariadb.env
HomeLab07.private/env/owncloud.env
```

Create or update the OwnCloud database and user:

```bash
./operation/owncloud-db-create.sh
```

Drop the OwnCloud database and user:

```bash
./operation/owncloud-db-drop.sh
```

The drop script is destructive and requires interactive confirmation.

The selected charset and collation are supplied by private configuration:

```env
OWNCLOUD_DB_CHARSET=utf8mb4
OWNCLOUD_DB_COLLATION=replace-with-validated-owncloud-collation
```

The create script applies the equivalent of:

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

Do not introduce a dedicated MariaDB container for OwnCloud.

The OwnCloud table prefix must match the database schema and generated configuration:

```env
OWNCLOUD_DB_PREFIX=oc_
```

The official image writes an `overwrite.config.php` file that reads `OWNCLOUD_DB_PREFIX`. If this variable is missing, OwnCloud can look for unprefixed tables such as `appconfig` instead of `oc_appconfig`.

During the first deployment this mismatch produced `Table 'owncloud.appconfig' doesn't exist` while the database correctly contained `oc_appconfig`. Keep `OWNCLOUD_DB_PREFIX=oc_` in the private environment before initialization.

---

## Reverse Proxy

OwnCloud is published exclusively through Nginx Proxy Manager.

The Nginx Proxy Manager Proxy Host is created manually during Sprint 005.

Use placeholders in repository documentation. The approved public endpoint value belongs in `HomeLab07.private/`.

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

Cloudflare may remain DNS-only during initial validation. Cloudflare proxying can be enabled after the application validates cleanly through Nginx Proxy Manager.

OwnCloud reverse proxy configuration must include:

- `trusted_domains`
- `trusted_proxies`
- `overwrite.cli.url`
- `overwriteprotocol=https`

Apply administrative configuration through `occ` whenever practical.

Document every `occ` command executed during installation.

Example commands:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:system:set trusted_domains 1 --value="<owncloud-public-domain>"

docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:system:set trusted_proxies 0 --value="homelab07-nginx-proxy-manager"

docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:system:set overwrite.cli.url --value="https://<owncloud-public-domain>"

docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:system:set overwriteprotocol --value="https"
```

If the official Docker image rejects the `php occ` form, use the image-provided `occ` wrapper and document the substituted command.

---

## Valkey

OwnCloud consumes the shared Valkey platform capability.

Current decision:

- ACL authentication remains deferred.
- The current trust model relies on Docker internal networking.
- No application-specific Valkey instance is deployed.

Future ACL evaluation triggers:

- multiple application consumers;
- reduced trust boundary;
- multi-host deployment.

Expected Valkey endpoint:

```text
homelab07-valkey:6379
```

---

## Deployment

Validate the Compose configuration with placeholder values:

```bash
docker compose \
  --env-file services/owncloud/.env.example \
  -f services/owncloud/compose.yaml \
  config
```

After private configuration and database provisioning are complete, start through the operation layer:

```bash
./operation/start.sh
```

Or start only OwnCloud:

```bash
./operation/compose.sh owncloud up -d
```

Check status:

```bash
./operation/status.sh
```

View logs:

```bash
./operation/compose.sh owncloud logs
```

If a first installation fails after writing config or database state, perform a clean retry. Stop OwnCloud, drop and recreate the database, and empty the dedicated OwnCloud storage root only after confirming it contains no user data:

```bash
./operation/compose.sh owncloud down
./operation/owncloud-db-drop.sh
./operation/owncloud-db-create.sh
```

Then remove stale first-run storage artifacts from `${OWNCLOUD_DATA_ROOT}` on the host, restore ownership for the container web user, and recreate the service.

---

## Operational Commands

HomeLab07 operations should go through the `operation/` layer.

```bash
./operation/start.sh
./operation/status.sh
./operation/stop.sh
./operation/owncloud-storage-check.sh
./operation/compose.sh owncloud config
./operation/compose.sh owncloud logs
```

Administrative OwnCloud actions should prefer `occ` over manual file editing.

Every `occ` command executed during installation must be documented.

---

## Healthcheck

The healthcheck uses the script provided by the official OwnCloud image:

```text
/usr/bin/healthcheck
```

The healthcheck includes a longer startup grace period to tolerate initial installation and migration:

```text
start_period: 180s
retries: 10
```

Avoid aggressive startup probes during the first deployment.

---

## Validation

Validate the following after deployment.

Validate the host storage path:

```bash
./operation/owncloud-storage-check.sh
```

Expected result:

- `OWNCLOUD_DATA_ROOT` is an absolute path.
- The host path exists.
- After successful initialization, `${OWNCLOUD_DATA_ROOT}/files/.ocdata` exists.

Check that OwnCloud is running:

```bash
./operation/compose.sh owncloud ps
```

Confirm no host ports are published:

```bash
docker port homelab07-owncloud
```

Expected response:

```text
No output
```

Inspect network attachments:

```bash
docker inspect homelab07-owncloud \
  --format '{{json .NetworkSettings.Networks}}'
```

Expected networks:

```text
homelab07-internal
homelab07-proxy
```

Validate container and application users:

```bash
docker exec homelab07-owncloud id
docker exec homelab07-owncloud id www-data
docker exec homelab07-owncloud ps -eo user,pid,ppid,args
```

The container may initialize as `root`, but administrative OwnCloud commands must run as `www-data`.

Validate OwnCloud status:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ status
```

Expected result:

```text
OwnCloud reports a healthy installation.
```

Validate system configuration:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:list system
```

Expected configuration:

- `datadirectory` is `/mnt/data/files`.
- `memcache.local` is configured.
- `memcache.locking` is configured.
- Redis configuration is present.
- Redis-backed configuration points to `homelab07-valkey`.

Validate OwnCloud storage write permissions:

```bash
docker exec \
  --user www-data \
  homelab07-owncloud \
  sh -c 'touch /mnt/data/.permission-test && rm /mnt/data/.permission-test'
```

Validate application behavior:

- Administrator login succeeds.
- User creation succeeds.
- File upload succeeds.
- File download succeeds.
- Folder creation succeeds.
- File sharing between users succeeds.
- Uploaded files are visible on the NAS under `${OWNCLOUD_DATA_ROOT}/files/<owncloud-user>/files/`.
- Transactional file locking works.
- Files survive container recreation.
- HTTPS access works through Cloudflare and Nginx Proxy Manager.

---

## Backup

Backup automation is outside the scope of Sprint 005.

The critical persistent data lives under:

```text
${OWNCLOUD_DATA_ROOT}
```

The OwnCloud MariaDB database must also be backed up for a complete service backup.

Backup implementation will be introduced during Sprint 010.

---

## Restore

Restore automation is outside the scope of Sprint 005.

A future restore procedure must restore both:

- `${OWNCLOUD_DATA_ROOT}`
- the OwnCloud MariaDB database

Restoring only files or only the database may produce an inconsistent application state.

For a failed first installation with no production data, reset both layers together:

```bash
./operation/compose.sh owncloud down
./operation/owncloud-db-drop.sh
./operation/owncloud-db-create.sh
```

Then empty the dedicated OwnCloud storage path from the host only after confirming that it contains no user data.

---

## Implementation Record

Record sanitized implementation evidence here before closing Sprint 005.

Do not include real public domains, IP addresses, passwords, secrets, or private paths that must remain outside the repository.

### Database

- Charset: `<owncloud-database-charset>`
- Collation: `<validated-owncloud-collation>`
- Database creation command: `./operation/owncloud-db-create.sh`
- Result: `<pending-validation>`

### Persistent Storage

- Rockstor Share: `<owncloud-share-name>`
- Host mount path: `<OWNCLOUD_DATA_ROOT>`
- Container mount path: `/mnt/data`
- OwnCloud volume root: `/mnt/data`
- OwnCloud files path: `/mnt/data/files`
- OwnCloud datadirectory: `/mnt/data/files`
- Runtime UID/GID: `<pending-validation>`
- Permissions observed: `<pending-validation>`
- Data marker: `<OWNCLOUD_DATA_ROOT>/files/.ocdata`
- Storage check command: `./operation/owncloud-storage-check.sh`
- Runtime layout command:

```bash
find <OWNCLOUD_DATA_ROOT> -maxdepth 2 \
  -printf '%M %u:%g %p\n'
```

### OwnCloud Administration

Commands executed:

```bash
<document-occ-commands-executed-as-www-data>
```

### Reverse Proxy

- DNS record created manually: `<documented-with-placeholder>`
- Nginx Proxy Manager Proxy Host created manually: `<pending-validation>`
- TLS certificate issued: `<pending-validation>`
- HTTPS publication validated: `<pending-validation>`

### Runtime Validation

- `docker port homelab07-owncloud`: `<pending-validation>`
- `docker inspect homelab07-owncloud --format '{{json .NetworkSettings.Networks}}'`: `<pending-validation>`
- `occ status`: `<pending-validation>`
- `occ config:list system`: `<pending-validation>`
- file upload/download: `<pending-validation>`
- UI file share between users: `<pending-validation>`
- NAS file visibility under `<OWNCLOUD_DATA_ROOT>/files/<owncloud-user>/files/`: `<pending-validation>`
- container recreation persistence: `<pending-validation>`
- server-side encryption disabled: `<pending-validation>`

---

## Security

Security model:

- OwnCloud publishes no host ports.
- Public access is only through Nginx Proxy Manager.
- MariaDB access uses `homelab07-internal`.
- Valkey access uses `homelab07-internal`.
- Public URLs and credentials remain in `HomeLab07.private/`.
- Server-side encryption remains disabled to preserve NAS recoverability.
- Dedicated MariaDB and Valkey instances are not allowed.

The container does not use `read_only: true` or `cap_drop: ALL` in Sprint 005 because the official image performs initialization and writes runtime state under `/mnt/data`. This may be revisited after the first deployment is stable.

---

## Related Sprint

- Sprint 005 — Collaboration Platform
- Version: `v0.6.0-collaboration-platform`

This sprint validates HomeLab07 as an application platform by deploying a business-facing service that consumes shared MariaDB, shared Valkey, Nginx Proxy Manager, Cloudflare Dynamic DNS, and NAS-backed storage.

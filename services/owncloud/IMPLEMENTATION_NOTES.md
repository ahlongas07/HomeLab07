# OwnCloud Implementation Notes

## Purpose

This document captures the engineering notes from the Sprint 005 OwnCloud implementation.

It exists because the first deployment required several operational corrections that should remain visible for future maintenance, rebuilds and reviews.

The service README remains the operational reference. These notes explain the reasoning behind the final configuration.

---

## Final Working Model

OwnCloud runs as the first business-facing HomeLab07 service.

Approved stack:

- `owncloud/server:10.16.3`
- Shared MariaDB 11.4
- Shared Valkey
- Nginx Proxy Manager
- Cloudflare Dynamic DNS
- NAS-backed dedicated OwnCloud storage

The service publishes no host ports.

Public access follows:

```text
Internet
    -> Cloudflare
    -> Nginx Proxy Manager
    -> homelab07-owncloud:8080
```

---

## Storage Decision

OwnCloud uses a dedicated NAS-backed share mounted into the container as:

```text
${OWNCLOUD_DATA_ROOT} -> /mnt/data
```

The internal OwnCloud paths are explicit:

```text
OWNCLOUD_VOLUME_ROOT=/mnt/data
OWNCLOUD_VOLUME_FILES=/mnt/data/files
```

The resulting OwnCloud `datadirectory` must be:

```text
/mnt/data/files
```

Uploaded files are expected on the NAS under:

```text
${OWNCLOUD_DATA_ROOT}/files/<owncloud-user>/files/
```

This preserves direct NAS recoverability while allowing OwnCloud to manage its own runtime layout.

---

## Why Explicit Volume Paths Are Required

During implementation, OwnCloud reached a state where `/status.php` returned HTTP 200, but `occ` failed with:

```text
Your Data directory must be an absolute path
Your Data directory is invalid
Please check that the data directory contains a file ".ocdata" in its root.
```

The fix was to make the container's internal volume paths explicit instead of relying on image defaults or stale generated configuration.

Required values:

```env
OWNCLOUD_VOLUME_ROOT=/mnt/data
OWNCLOUD_VOLUME_FILES=/mnt/data/files
```

This prevents OwnCloud from generating an empty or inconsistent `datadirectory` after a failed first initialization.

---

## Database Prefix Issue

The first deployment also exposed a database prefix mismatch.

OwnCloud created tables with the expected prefix:

```text
oc_appconfig
```

But generated configuration caused OwnCloud to query:

```text
appconfig
```

The visible failure was:

```text
Table 'owncloud.appconfig' doesn't exist
```

The required private environment value is:

```env
OWNCLOUD_DB_PREFIX=oc_
```

This value must exist before first initialization because the official image writes generated configuration that reads `OWNCLOUD_DB_PREFIX`.

---

## Reset Rule

If the first installation fails after writing either database state or storage state, reset both layers together.

Do not reuse a new database with stale storage.

Do not reuse stale database state with a cleaned storage directory.

Clean retry sequence:

```bash
./operation/compose.sh owncloud down
./operation/owncloud-db-drop.sh
./operation/owncloud-db-create.sh
```

Then clean the dedicated OwnCloud storage root on the host only after confirming it contains no user data.

After cleanup, recreate the service:

```bash
./operation/compose.sh owncloud up -d --force-recreate
```

---

## Permissions Notes

The OwnCloud container may initialize as `root`.

OwnCloud administrative commands should run as `www-data`:

```bash
docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ status
```

The NAS-backed storage path must allow the container web user to write to `/mnt/data`.

The storage validation helper is:

```bash
./operation/owncloud-storage-check.sh
```

If the host user cannot read the NAS share because of expected ownership restrictions, run the check with elevated host permissions.

---

## Reverse Proxy Notes

Nginx Proxy Manager forwards traffic to:

```text
Forward Host: homelab07-owncloud
Forward Port: 8080
Scheme: http
```

OwnCloud must know the public endpoint through:

```text
trusted_domains
trusted_proxies
overwrite.cli.url
overwriteprotocol=https
```

Real public URLs remain in `HomeLab07.private/`.

Repository documentation must continue using placeholders.

---

## Valkey Notes

OwnCloud uses shared Valkey for cache and transactional file locking.

Expected Redis-compatible endpoint:

```text
homelab07-valkey:6379
```

Do not include the port in `OWNCLOUD_REDIS_HOST` unless the image variable explicitly requires host and port in a single value.

In this implementation, the host and default Redis-compatible port are handled separately by the generated OwnCloud configuration.

---

## NAS Share Strategy

The dedicated OwnCloud share is viable for the OwnCloud runtime and user-uploaded files.

Existing NAS shares should not be mounted directly into OwnCloud's internal `files/` tree.

Preferred future model:

- OwnCloud External Storage
- SMB, WebDAV, FTP, or SFTP
- Explicit ownership and permission rules
- Validation of external changes, indexing, locks and performance

This keeps OwnCloud from becoming the owner of all NAS data while still enabling collaboration over selected shares.

---

## Validation Checklist

Runtime validation:

```bash
docker port homelab07-owncloud

docker inspect homelab07-owncloud \
  --format '{{json .NetworkSettings.Networks}}'

docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ status

docker exec \
  --user www-data \
  --workdir /var/www/owncloud \
  homelab07-owncloud \
  php occ config:list system
```

Expected configuration:

- `datadirectory` points to `/mnt/data/files`.
- `memcache.local` is configured.
- `memcache.locking` is configured.
- Redis configuration points to `homelab07-valkey`.
- No host ports are published.
- Networks include `homelab07-internal` and `homelab07-proxy`.

Functional UI validation:

- Administrator login succeeds.
- User creation succeeds.
- File upload succeeds.
- File download succeeds.
- Folder creation succeeds.
- File sharing between users succeeds.
- Uploaded files are visible under `${OWNCLOUD_DATA_ROOT}/files/<owncloud-user>/files/`.
- Files survive container recreation.

---

## Engineering Outcome

The final implementation required no dedicated MariaDB and no dedicated Valkey.

The platform services remained reusable and application agnostic.

The main engineering lesson is that OwnCloud first-run state must be treated atomically across:

- generated configuration;
- MariaDB schema and metadata;
- NAS-backed persistent storage.

When those layers drift, a clean reset of only one layer is not sufficient.

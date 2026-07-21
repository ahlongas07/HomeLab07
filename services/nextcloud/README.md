# Nextcloud PoC

## Purpose

Nextcloud validates a Files-focused collaboration service using the shared
HomeLab07 platform. It is a controlled replacement candidate for OwnCloud, not
an approved production migration.

## Responsibilities

- Browser, WebDAV, desktop and mobile file access.
- File and folder sharing, versions and deleted-file recovery.
- Administrative filesystem reconciliation through `occ files:scan`.
- Consumption of shared MariaDB, Valkey and reverse-proxy capabilities.

Nextcloud does not own DNS, TLS, database infrastructure, cache
infrastructure, backup automation or unrelated NAS shares.

## Technology

| Capability | Selection |
|---|---|
| Application and cron | `nextcloud:33.0.6-apache` |
| Database | Shared MariaDB 11.4 |
| Distributed cache and locking | Shared Valkey 8 |
| Local cache | APCu from the official image |
| Publication | Nginx Proxy Manager and Cloudflare Dynamic DNS |
| Persistence | Dedicated Rockstor share |

The image uses a stable patch tag. Its registry digest must be recorded during
the runtime validation on the target architecture.

## Directory Structure

```text
services/nextcloud/
├── .env.example
├── IMPLEMENTATION_NOTES.md
├── README.md
└── compose.yaml
```

The private NAS path uses this layout:

```text
${NEXTCLOUD_ROOT}/
├── html/    # installation, generated configuration, apps and themes
└── data/    # user content and Nextcloud data marker
```

Both mounts are shared by the web and cron containers. Only the web container
joins `homelab07-proxy`; neither service publishes host ports.

## Configuration

Create the private file outside this repository:

```bash
mkdir -p ../HomeLab07.private/env
cp services/nextcloud/.env.example ../HomeLab07.private/env/nextcloud.env
```

Replace every placeholder. Real paths, domains and credentials must remain in
`HomeLab07.private/`.

Nextcloud requires `trusted_proxies` to contain IP addresses or CIDR ranges;
Docker service names are not accepted. Obtain the private proxy-network CIDR
on the target host:

```bash
docker network inspect homelab07-proxy \
  --format '{{(index .IPAM.Config 0).Subnet}}'
```

Store that result only in the private environment file as
`NEXTCLOUD_TRUSTED_PROXIES`. Trusting the shared proxy network assumes that
membership of `homelab07-proxy` remains controlled by the platform.

Create `${NEXTCLOUD_ROOT}/html` and `${NEXTCLOUD_ROOT}/data` on the dedicated
Rockstor share. Do not point either path at OwnCloud data or an existing NAS
share.

`utf8mb4` with `utf8mb4_general_ci` follows the documented Nextcloud database
creation pattern and is compatible with the shared MariaDB service. Confirm it
on the target before provisioning:

```sql
SHOW COLLATION LIKE 'utf8mb4_general_ci';
```

## Deployment

OwnCloud must be stopped and preserved. Provisioning remains explicit:

```bash
./operation/compose.sh owncloud down
./operation/nextcloud-storage-check.sh
./operation/compose.sh mariadb up -d
./operation/nextcloud-db-create.sh
./operation/compose.sh nextcloud up -d
```

The official image performs non-interactive installation because the private
environment supplies database and initial administrator values. Do not install
the recommended application bundle through the first-run UI.

After installation, run administrative commands as `www-data`:

```bash
docker exec --user www-data homelab07-nextcloud php occ status
docker exec --user www-data homelab07-nextcloud php occ background:cron
docker exec --user www-data homelab07-nextcloud php occ app:list --enabled
```

Review the inventory before disabling optional apps. Mandatory shipped apps
must remain enabled. For each approved optional app:

```bash
docker exec --user www-data homelab07-nextcloud \
  php occ app:disable <optional-app-id>
```

No application directory may be removed manually.

## Reverse Proxy

Redirect the existing collaboration Proxy Host only during the announced PoC
window:

| Setting | Value |
|---|---|
| Domain | `<collaboration-public-domain>` |
| Scheme | `http` |
| Forward host | `homelab07-nextcloud` |
| Forward port | `80` |
| Force SSL | enabled |
| HTTP/2 | enabled |

The real domain remains private. Confirm generated proxy settings with:

```bash
docker exec --user www-data homelab07-nextcloud php occ config:list system
```

## Minimal Profile And Branding

The PoC covers Files only. Talk, Mail, Calendar, Contacts, Office, AI,
External Storage and other optional Hub applications remain out of scope.

The web container mounts the existing version-controlled HomeLab07 assets
read-only at `/opt/homelab07-branding`. Apply them through supported commands:

```bash
docker exec --user www-data homelab07-nextcloud \
  php occ theming:config name "HomeLab07"
docker exec --user www-data homelab07-nextcloud \
  php occ theming:config slogan "Build • Host • Automate"
docker exec --user www-data homelab07-nextcloud \
  php occ theming:config primary_color "#1f7a8c"
docker exec --user www-data homelab07-nextcloud \
  php occ theming:config logo /opt/homelab07-branding/logo.svg
docker exec --user www-data homelab07-nextcloud \
  php occ theming:config favicon /opt/homelab07-branding/favicon.svg
docker exec --user www-data homelab07-nextcloud \
  php occ theming:config background /opt/homelab07-branding/imagen.png
```

Record every command and result in `IMPLEMENTATION_NOTES.md` during runtime
evaluation.

## Validation

Static and shell validation:

```bash
docker compose --env-file services/nextcloud/.env.example \
  -f services/nextcloud/compose.yaml config
bash -n operation/nextcloud-*.sh operation/start.sh operation/stop.sh \
  operation/status.sh
```

Runtime validation:

```bash
./operation/compose.sh nextcloud ps
./operation/compose.sh nextcloud logs
docker port homelab07-nextcloud
docker exec --user www-data homelab07-nextcloud php occ status --output=json_pretty
docker exec --user www-data homelab07-nextcloud php occ setupchecks
docker exec --user www-data homelab07-nextcloud php occ config:list system
docker exec --user www-data homelab07-nextcloud php occ encryption:status
docker exec --user www-data homelab07-nextcloud php occ background-job:list
```

Expected security properties:

- no published host ports;
- web joins only internal and proxy networks;
- cron joins only the internal network;
- server-side encryption reports disabled;
- APCu is local cache and Valkey is distributed cache and file locking;
- OwnCloud remains stopped.

For a controlled external addition while Nextcloud is stopped, place a
synthetic file inside one PoC user's `files/` directory, restore ownership,
start the service and run:

```bash
docker exec --user www-data homelab07-nextcloud \
  php occ files:scan --path='<user>/files/<relative-path>'
```

External writes are a recovery operation, not a normal workflow.

## Backup

A consistent PoC backup includes `${NEXTCLOUD_ROOT}/html`,
`${NEXTCLOUD_ROOT}/data`, a MariaDB dump, the pinned repository definition and
the private configuration through its approved private backup process.

1. Enable maintenance mode.
2. Stop both Nextcloud containers.
3. Dump the Nextcloud database using private credentials without printing them.
4. Snapshot or archive both NAS directories from the same recovery point.
5. Disable maintenance mode only after the application is restarted.

User files alone are not a complete Nextcloud backup.

## Restore

1. Keep OwnCloud and Nextcloud stopped.
2. Restore `html`, `data` and the independent Nextcloud database from one
   consistent recovery point.
3. Deploy the same pinned image version.
4. Validate ownership, permissions and `.ocdata`.
5. Start Nextcloud and run `occ maintenance:repair` if required by the pinned
   version's official restore guidance.
6. Verify checksums, users, shares, versions, cron and branding.

Restore testing uses disposable PoC data only. Backup automation belongs to
Sprint 010.

## Rollback

```bash
./operation/compose.sh nextcloud down
```

Restore the existing collaboration Proxy Host to
`homelab07-owncloud:8080`, switch the lifecycle scripts back to OwnCloud in a
reviewed repository change, then start OwnCloud. Do not drop or alter either
application's state as part of routing rollback.

## Security

- Credentials and environment-specific values remain outside Git.
- Server-side encryption remains disabled to preserve direct NAS recovery.
- Nextcloud is the normal writer to its data tree.
- The service has no direct public port.
- `no-new-privileges` is applied to both containers and must be verified for
  compatibility during initialization.

## Related Sprint

- Sprint 005 — Collaboration Platform
- SPIKE-001 — Collaboration Architecture Evaluation
- POC-001 — Nextcloud Files Platform Validation

# Nextcloud PoC

## Purpose

Nextcloud provides the active Files-focused collaboration service using the
shared HomeLab07 platform.

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
| Application and cron | `nextcloud:33.0.10-apache`, pinned by digest |
| Database | Shared MariaDB 11.4 |
| Distributed cache and locking | Shared Valkey 8 |
| Local cache | APCu from the official image |
| Publication | Caddy, proxied by Cloudflare |
| Persistence | Dedicated Rockstor share |

The image uses a stable patch tag pinned by its multi-architecture index
digest; see the implementation notes for the reviewed versions.

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
membership of `homelab07-proxy` remains controlled by the platform. Recreate
the subnet value if the network is ever recreated.

The Nextcloud image's Apache `remoteip` takes the client address from
`X-Real-IP` for requests from private networks; Caddy sets it to the visitor
address from `CF-Connecting-IP` (Sprint 018). As a second layer, if Apache
ever passes the proxy address through, Nextcloud reads `CF-Connecting-IP`
itself, because `X-Forwarded-For` ends with a Cloudflare address:

```bash
docker exec --user www-data homelab07-nextcloud \
  php occ config:system:set forwarded_for_headers 0 --value=HTTP_CF_CONNECTING_IP
```

The setting is stored in `config.php` on the application volume and is part of
the backup. Brute-force protection and logs then see each visitor.

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

Provisioning remains explicit:

```bash
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

Caddy publishes `CADDY_NEXTCLOUD_DOMAIN` to `homelab07-nextcloud:80` from
`services/caddy/sites/homelab07.caddy`, with forced HTTPS and HTTP/2. The real
domain remains private. Confirm generated proxy settings with:

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

1. Keep Nextcloud stopped.
2. Restore `html`, `data` and the independent Nextcloud database from one
   consistent recovery point.
3. Deploy the same pinned image version.
4. Validate ownership, permissions and `.ocdata`.
5. Start Nextcloud and run `occ maintenance:repair` if required by the pinned
   version's official restore guidance.
6. Verify checksums, users, shares, versions, cron and branding.

Sprint 010 centralizes encrypted backup and disposable restore through
`./operation/backup.sh` and `./operation/restore-test.sh`. The component steps
above remain the application-level recovery contract.

## Upgrade

Maintenance upgrades stay on the pinned major branch and are pinned by tag
and digest. The official image runs `occ upgrade` when it starts a newer
version. Nextcloud does not support downgrades: once the database has been
upgraded, rollback means restoring the pre-upgrade recovery point. Proposed
versions, advisories and compatibility are recorded in
[IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md).

Keep evidence sanitized and in the private evidence location
(`<evidence-dir>`); never store user names, domains or `config.php` content
in Git.

**Order matters.** Create the recovery point before the new pin reaches the
NAS, so the recovery point and the running version always match. `backup.sh`
restarts the containers it stopped with `docker compose start` and never
recreates them, so it cannot apply a new pin by itself.

1. Pre-checks, on the current repository revision:

   ```bash
   ./operation/backup-preflight.sh
   ./operation/security-audit.sh
   docker exec --user www-data homelab07-nextcloud php occ status --output=json
   docker exec --user www-data homelab07-nextcloud php occ app:list --enabled --output=json \
     | jq -S '.enabled | keys' > <evidence-dir>/nextcloud-apps-before.json
   ```

2. Recovery point, still on the current revision:

   ```bash
   ./operation/backup.sh
   ./operation/restore-test.sh latest <empty-restore-dir>
   ```

   Confirm that the disposable restore contains Nextcloud state, using counts
   only, then delete it because it holds private configuration:

   ```bash
   find <empty-restore-dir> -path '*/html/config/config.php' | wc -l
   find <empty-restore-dir> -path '*/data/.ocdata' | wc -l
   grep -c '^CREATE DATABASE.*`<nextcloud-database-name>`' \
     "$(find <empty-restore-dir> -name mariadb-all.sql)"
   rm -rf -- <empty-restore-dir>
   ```

   Each count must be at least `1`, and the database count exactly `1`.

3. Deploy the reviewed revision that changes the pin for both `nextcloud` and
   `nextcloud-cron`:

   ```bash
   git pull
   ./operation/compose.sh nextcloud config --quiet
   ```

4. Upgrade:

   ```bash
   ./operation/compose.sh nextcloud pull
   ./operation/compose.sh nextcloud up -d
   ./operation/compose.sh nextcloud logs --tail=200 nextcloud
   ```

   Wait until the health check reports `healthy`; the first start copies the
   new code and runs the database migration.

5. Validation:

   ```bash
   occ() { docker exec --user www-data homelab07-nextcloud php occ "$@"; }
   occ status --output=json          # new version, maintenance false, needsDbUpgrade false
   occ db:add-missing-indices
   occ db:add-missing-columns
   occ db:add-missing-primary-keys
   occ integrity:check-core          # must report no modified or missing file
   occ app:list --enabled --output=json | jq -S '.enabled | keys' \
     | diff <evidence-dir>/nextcloud-apps-before.json -
   occ setupchecks
   ./operation/security-audit.sh
   ```

   The application diff must be empty and `setupchecks` must show no new error.
   Then validate in the browser and clients: local administrator login with
   2FA, Keycloak login, upload, download, a share link, desktop or mobile sync
   and an image preview. Confirm that cron ran after the upgrade
   (`occ config:app:get core lastcron` shows a recent Unix time) and that
   `status.php` through the published route reports the new version.

6. Security scan and comparison with the previous run, as described in
   [Comparing an image between scan runs](../../docs/security/VULNERABILITY_MANAGEMENT.md#comparing-an-image-between-scan-runs)
   with the image prefix `nextcloud:`:

   ```bash
   ./operation/security-scan.sh scan
   ```

Update non-shipped applications such as `user_oidc` separately, after the
server upgrade has been validated.

Rollback, decided during validation because files uploaded after the upgrade
are lost:

1. Stop Nextcloud and its cron container:

   ```bash
   ./operation/compose.sh nextcloud stop
   ```

2. Restore `html`, `data` and the Nextcloud database from the pre-upgrade
   recovery point following
   [`docs/backup/DISASTER_RECOVERY.md`](../../docs/backup/DISASTER_RECOVERY.md).
3. Revert the pin to the previous tag and digest from the implementation
   notes, deploy that revision and start the service:

   ```bash
   ./operation/compose.sh nextcloud up -d
   ```

4. Repeat the validation in step 5 against the previous version.

## Historical Recovery

The retired OwnCloud repository implementation is preserved by the
`v0.6.0-collaboration-platform` tag. Restoring that version is a reviewed
redeployment operation; it must not reuse or modify Nextcloud state. OwnCloud
database, NAS and private configuration retirement are separate operations and
are not performed by this repository change.

## Security

- Credentials and environment-specific values remain outside Git.
- Server-side encryption remains disabled to preserve direct NAS recovery.
- Nextcloud is the normal writer to its data tree.
- The service has no direct public port.
- `no-new-privileges` is applied to both containers and must be verified for
  compatibility during initialization.

## Keycloak OIDC PoC

Sprint 011 adds Keycloak as an optional external identity provider through the
supported Nextcloud `user_oidc` application. Password login and the local
administrator remain enabled during the PoC. Automatic user provisioning,
group synchronization, mandatory redirects and MFA are not enabled until
claims, rollback and emergency access have been validated.

The sanitized operator sequence and acceptance tests are maintained in
`services/keycloak/IMPLEMENTATION_NOTES.md`; issuer, client identifier and
client secret remain private.

SPIKE-002 evaluates Keycloak as the bounded source of truth for supported
profile claims, Nextcloud auto-provisioning and default OIDC redirection. The
reproducible operation and runtime matrix are documented in
`services/keycloak/IDENTITY_AUTHORITY_POC.md`. Local emergency login remains a
required control and group-to-administrator mapping is not approved.

## Related Sprint

- Sprint 005 — Collaboration Platform
- Sprint 011 — Identity Platform
- SPIKE-002 — Identity Source of Truth and SSO Experience
- SPIKE-001 — Collaboration Architecture Evaluation
- POC-001 — Nextcloud Files Platform Validation

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
| Reverse Proxy | Nginx Proxy Manager 2.16.0, pinned by digest |
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
├── IMPLEMENTATION_NOTES.md
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
NPM_MANAGEMENT_BIND_ADDRESS=192.0.2.10

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
| 81 | Administration UI, bound only to the configured Docker-host LAN address |

`NPM_MANAGEMENT_BIND_ADDRESS` must be the private LAN address assigned to the
Docker host, not a wildcard, loopback or public address. This keeps the
administration interface reachable by devices that can route to the LAN while
preventing Docker from listening for it on every host interface. The router
must continue without a WAN forwarding rule for this port.

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

# Access List and SSL Audit

Upstream issue #5919 can render a proxy host without its `allow`/`deny` rules
or SSL directives while the UI and database still show them as applied. It
affects 2.15.1 and 2.16.0. The read-only audit compares the database with the
rendered Nginx configuration:

```bash
./operation/npm-access-audit.sh | tee <evidence-dir>/npm-access-audit-<UTC date>.txt
```

For every active proxy host it checks:

- with an access list: the rendered rule block carries the stored number of
  rules and ends in `deny all`, and basic authentication is rendered when the
  list has users;
- with a certificate: a `443 ssl` listener and the `ssl_certificate` of the
  assigned certificate are rendered, the certificate file is valid, and the
  HTTPS redirect is rendered when Force SSL is enabled;
- disabled hosts are not served, and no rendered host is missing from the
  database;
- `nginx -t` passes.

The output names hosts, access lists and certificates by numeric ID only: no
domain, address, user name, password or key material. Map IDs to services in
the NPM UI, not in the evidence file. The script exits non-zero on any
failure. Warnings require a decision: an access list without rules, per-path
access lists (not checked automatically), a host without a certificate or
with Force SSL disabled.

Run it before and after every upgrade and after any change to an access list,
host state or certificate, until an NPM release includes the upstream fix.

## When a host fails

A failing access check means the host is publicly reachable without its
restriction. Block it first, then correct it:

1. **Block.** In the NPM UI, disable the proxy host. Disabling removes its
   rendered configuration, so the host is no longer served. Run the audit
   again and confirm `disabled and not served`. A Cloudflare rule alone is not
   enough: requests sent directly to the origin bypass Cloudflare.
2. **Correct.** Edit the proxy host, select the access list (and, for an SSL
   failure, the certificate) again and save; then enable the host and run the
   audit immediately. Enabling a host is one of the affected upstream paths:
   if the audit still fails, disable the host again.
3. **If correction fails,** keep the host disabled until an NPM release that
   includes upstream PR #5935 is reviewed and deployed. Record the host ID,
   the decision and the date in the private evidence.
4. **Rendered configuration without an active host** serves traffic that the
   UI does not show. Do not delete files by hand; record it and investigate
   before continuing.

An upgrade or change is not complete while any host fails.

---

# Upgrade

Upgrades follow a reviewed target version pinned by tag and digest in
`compose.yaml`. Release review, compatibility findings, known open issues and
target evidence are recorded in [IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md).
A running container is not proof of success: the upgrade is complete only
after every validation step below passes.

Keep all evidence sanitized. Never paste domains, IP addresses, credentials,
certificate material or full logs into Git; store the files captured below in
the private evidence location (`<evidence-dir>`).

## 1. Recovery point before the upgrade

Update the repository on the NAS first; this changes no running container,
and `backup.sh` requires a clean worktree. The manifest records the image the
container is actually running (2.15.1) in its service inventory:

```bash
./operation/backup.sh
./operation/restore-test.sh latest <empty-restore-dir>
```

`backup.sh` stops NPM, captures `data` and `letsencrypt` with the coordinated
MariaDB dump and restores the runtime state. Confirm that the disposable
restore contains the NPM state, using counts only:

```bash
find <empty-restore-dir> -path '*/nginx-proxy-manager/data/nginx/proxy_host/*.conf' | wc -l
find <empty-restore-dir> -path '*/nginx-proxy-manager/letsencrypt/live/*/fullchain.pem' | wc -l
grep -c '^CREATE DATABASE.*`<npm-database-name>`' "$(find <empty-restore-dir> -name mariadb-all.sql)"
```

The first two counts must match the proxy hosts and certificates in the UI;
the last must be `1`. Then delete the restore directory, because it holds
private configuration and certificate keys:

```bash
rm -rf -- <empty-restore-dir>
```

## 2. Pre-upgrade baseline

Capture a fingerprint of every rendered host and certificate. The output uses
NPM's numeric file names and counts, not domains:

```bash
docker exec homelab07-nginx-proxy-manager sh -c '
for f in /data/nginx/proxy_host/*.conf /data/nginx/redirection_host/*.conf; do
  [ -f "$f" ] || continue
  printf "%s ssl=%s allow=%s deny=%s\n" "${f#/data/nginx/}" \
    "$(grep -c "ssl_certificate " "$f")" \
    "$(grep -cE "^[[:space:]]*allow " "$f")" \
    "$(grep -cE "^[[:space:]]*deny " "$f")"
done' > <evidence-dir>/npm-render-before.txt

docker exec homelab07-nginx-proxy-manager sh -c '
for c in /etc/letsencrypt/live/*/fullchain.pem; do
  printf "%s %s\n" "$(basename "$(dirname "$c")")" "$(openssl x509 -noout -enddate -in "$c")"
done' > <evidence-dir>/npm-certificates-before.txt
```

Run the access audit. It must pass before the upgrade starts; a failure here
already exists in 2.15.1 and is handled as described in
[When a host fails](#when-a-host-fails):

```bash
./operation/npm-access-audit.sh | tee <evidence-dir>/npm-access-audit-before.txt
```

Note the latest completed security scan run ID for the comparison in step 5.

## 3. Upgrade

Deploy the repository revision with the new pin, then recreate only NPM:

```bash
./operation/compose.sh nginx-proxy-manager config --quiet
./operation/compose.sh nginx-proxy-manager pull
./operation/compose.sh nginx-proxy-manager up -d
./operation/compose.sh nginx-proxy-manager logs --tail=200
```

Ports, networks and other services are not changed.

## 4. Validation

1. Container healthy and running the pinned image:

   ```bash
   ./operation/compose.sh nginx-proxy-manager ps
   docker inspect -f '{{.Config.Image}} {{.Image}}' homelab07-nginx-proxy-manager
   ```

2. Logs show the migrations step without errors and no `.conf.err` file was
   produced; the Nginx configuration is valid:

   ```bash
   docker exec homelab07-nginx-proxy-manager nginx -t
   docker exec homelab07-nginx-proxy-manager sh -c 'find /data/nginx -name "*.conf.err" | wc -l'
   ```

3. Rendered hosts unchanged: repeat the step 2 commands into
   `npm-render-after.txt` and `npm-certificates-after.txt`, then:

   ```bash
   diff <evidence-dir>/npm-render-before.txt <evidence-dir>/npm-render-after.txt
   diff <evidence-dir>/npm-certificates-before.txt <evidence-dir>/npm-certificates-after.txt
   ```

   Both must print nothing, and the access audit must pass:

   ```bash
   ./operation/npm-access-audit.sh | tee <evidence-dir>/npm-access-audit-after.txt
   ```

   A host that lost its `allow`/`deny` lines or SSL is publicly open or broken
   even if the UI shows the access list or certificate as applied (upstream
   issue #5919): block it as described in [When a host fails](#when-a-host-fails),
   then correct it or roll back.

4. Administration UI: sign in from the LAN, confirm the proxy hosts, access
   lists, redirections and certificates are listed, and verify from outside
   the LAN that port `81` is refused (`docs/security/VALIDATION.md`). Signing
   in again after the upgrade is expected because older tokens are
   invalidated.

5. Published services: open every published service through HTTPS, or check
   the status code of each from a client outside the Docker host:

   ```bash
   curl -sS -o /dev/null -w '%{http_code}\n' https://<published-service>/
   ```

   For a host behind the Cloudflare-only access list, a direct request that
   does not traverse Cloudflare must still be denied.

6. Certificate renewal still works with the new certbot:

   ```bash
   docker exec homelab07-nginx-proxy-manager certbot renew --dry-run --quiet; echo "exit $?"
   ```

   The exit code must be `0`. Do not store its verbose output: it names the
   domains.

7. Platform state:

   ```bash
   ./operation/status.sh
   ```

   No new Grafana alert may be firing.

After the upgrade, run the access audit after any access-list, host-enable or
certificate change until upstream releases the fix for issue #5919.

## 5. Security scan comparison

```bash
./operation/security-scan.sh scan
```

Compare the NPM image (`jc21/nginx-proxy-manager:`) between the last run
before the upgrade and the new one as described in
[Comparing an image between scan runs](../../docs/security/VULNERABILITY_MANAGEMENT.md#comparing-an-image-between-scan-runs).
Counts and finding lists stay on the private report share; the implementation
notes record only that the comparison was performed and whether any new
`CRITICAL` or `HIGH` finding was accepted.

## Rollback

2.16.0 adds no database schema migration, so the previous image can run on
the upgraded database.

1. Image rollback, for a defect in the new version: revert the pin in
   `compose.yaml` to the previous tag and digest from the implementation
   notes, deploy that revision and recreate NPM:

   ```bash
   ./operation/compose.sh nginx-proxy-manager pull
   ./operation/compose.sh nginx-proxy-manager up -d
   ```

   Then repeat the validation in step 4 against the pre-upgrade baseline.

2. State rollback, if hosts, access lists or certificates are damaged: stop
   NPM and restore its database and its `data` and `letsencrypt` trees from
   the pre-upgrade recovery point, following
   [`docs/backup/DISASTER_RECOVERY.md`](../../docs/backup/DISASTER_RECOVERY.md),
   then start the previous image and repeat step 4.

Record which rollback was used and why in the implementation notes.

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
- The image is pinned by tag and digest and upgraded through the procedure
  above. Known upstream issues still open in the deployed version, with their
  mitigations, are listed in [IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md).
- Only the platform administrator holds an NPM account.

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
- Platform Enhancement — Nginx Proxy Manager 2.16.0 security upgrade

---

# Future Integration

Future platform services should integrate with Nginx Proxy Manager instead of exposing ports directly.

Examples include:

- Landing Page
- Authentik
- Paperless-ngx
- Nextcloud

This architecture ensures a single, centralized, and secure entry point for all HomeLab07 services.

# Nextcloud PoC Implementation Notes

## Repository Outcome

The POC-001 repository implementation reuses MariaDB, Valkey, Nginx Proxy
Manager, Cloudflare Dynamic DNS, the shared Docker networks and the operation
layer.

After PoC closure, Nextcloud became the active collaboration service. The
superseded OwnCloud implementation was removed from the active tree and remains
available from the `v0.6.0-collaboration-platform` tag. Its database, NAS data
and private configuration are outside this repository change.

## Decisions

- `nextcloud:33.0.10-apache` is pinned by digest for application and cron
  (33.0.6 until the 2026-10-22 security update).
- The dedicated NAS root has explicit `html` and `data` directories.
- Application and cron share identical persistent mounts.
- Cron uses the official `/cron.sh` pattern and has no proxy-network access.
- Database provisioning is independent and grants privileges only on the
  Nextcloud database.
- `utf8mb4_general_ci` is the documented candidate collation for validation
  with MariaDB 11.4.
- APCu remains the local cache; shared Valkey is configured through the
  official image's Redis-compatible variables.
- No host ports, dedicated database or dedicated cache were added.
- Existing HomeLab07 logo, favicon and background assets are mounted read-only
  and remain managed in the repository rather than patched into the image.

## First-Run Correction

`NEXTCLOUD_INIT_HTACCESS=true` was removed after runtime validation showed that
the image attempted `maintenance:update:htaccess` before the initial install
was complete. The command was unavailable in that state, causing the web
container to restart continuously. The Apache image supplies its standard
`.htaccess`; any later refresh must be an explicit post-installation `occ`
operation.

Runtime setup checks also proved that a Docker service name is invalid in
Nextcloud's `trusted_proxies` array. The repository now requires an explicit
target-environment IP or CIDR supplied through private configuration. The
proxy-network CIDR was selected for container-recreation stability; membership
of that network must remain controlled.

## Version Verification

The `33.0.6-apache` tag was confirmed available in the official image registry
on 2026-07-21. Exact digest inspection was not completed during repository
implementation. Before runtime deployment, record:

```bash
docker pull nextcloud:33.0.6-apache
docker image inspect nextcloud:33.0.6-apache \
  --format '{{index .RepoDigests 0}}'
```

Do not silently replace the pinned version. A digest or version change requires
a reviewed repository update.

## Security Update 33.0.6 → 33.0.10

Reviewed and approved on 2026-10-22 as a version update only; the proposed
account and exposure mitigations were not approved and are not applied. The
pre-upgrade recovery point is the platform backup taken earlier the same day
with Nextcloud in maintenance mode.
Detailed scan findings and instance checks are kept in the private security
review on the report share, not in Git.

| | Current | Target |
|---|---|---|
| Tag | `nextcloud:33.0.6-apache` | `nextcloud:33.0.10-apache` (same image as `33-apache`) |
| Index digest | `sha256:d234808c4e63aad6889922228d64612a28682183dccaeac251db4db0be368aab` | `sha256:a4f8627d317e6de663b700f6a0d022530f038980930a4b81e967e7c19501b839` |
| amd64 manifest | `sha256:96501c7550521e093ae90adc119c4af17e577c59e8ccb80ac07b4a5e01eea274` | `sha256:1ae59dd29104449f1756aff63bc6b070dd634f4f6a3e956f2fb8be1a0d98c399` |
| arm64 manifest | `sha256:6086111db7d4f9fe791a4f1b8c2033ae44fbcfb9efbd9301b3316bed23ba136e` | `sha256:15531d894b5267cba3d0e001c3329c70b4e31ca5f4f0ae14c0a8c0cb57b1956d` |
| Image built | 2026-07-14 | 2026-10-21 |
| Upstream release | 2026-06-25 | 2026-10-15, latest stable of branch 33 |
| PHP | 8.4.23 | 8.4.27 |

Digests were read from Docker Hub on 2026-10-22.

Upstream advisory affecting 33.0.6, fixed in 33.0.7:
GHSA-7hwf-8pcj-33h4 / CVE-2026-104190 (high), ImageMagick abusable through
previews of malicious files. Bundled PHP dependencies updated by 33.0.10
include `mtdowling/jmespath.php` 2.9.1 and `guzzlehttp/guzzle` 7.15.2.

The branch stays at 33: the maintenance release carries the security fixes, so
a major upgrade to 34 has no security justification and would need a separate
application compatibility review.

Compatibility: same PHP minor and Debian 13 base, MariaDB 11.4 supported,
Valkey and APCu unchanged. The only non-shipped enabled application,
`user_oidc`, supports Nextcloud 29–34. The official image runs `occ upgrade`
on start. Nextcloud does not support downgrades: rollback restores the
pre-upgrade recovery point.

Account and exposure mitigations proposed with the update (2FA for every
administrator, fewer administrators, restricted preview providers, HSTS of at
least 180 days, public link policy) are listed in the private review; they
were not approved with this update.

Target result (2026-10-22, upgrade at 20:01 UTC, about one minute of
downtime). Detailed evidence remains in the private evidence location.

- [x] Pre-upgrade recovery point: the platform backup taken earlier the same
      day with Nextcloud in maintenance mode (chosen by the project owner
      instead of a new backup).
- [x] Application and cron run `nextcloud:33.0.10-apache@sha256:a4f8627d…`
      without restarts; the entrypoint upgraded from 33.0.6.2.
- [x] `occ status` reports 33.0.10, no maintenance mode and no pending
      database upgrade; no missing indices, columns or primary keys.
- [x] `occ integrity:check-core` clean; enabled application inventory
      unchanged.
- [x] `setupchecks` shows no new warning; the HSTS warning remains (set at the
      edge, outside this update).
- [x] Published route reports 33.0.10; security headers unchanged;
      administration and WebDAV return `401` without a session; Keycloak login
      redirects to the realm.
- [x] Cron ran after the upgrade without errors; NPM access audit passes.
- [x] Security scan compared with the last 33.0.6 run on the private share:
      no new finding, and no remaining finding with an available fix.
      Accepted.
- [x] The image's newer `redis.config.php` and `s3.config.php` templates add
      optional Unix-socket and SSE-KMS support; the installed files were left
      unchanged because neither feature is used.
- [x] Owner functional checks confirmed by the project owner: local and
      Keycloak login, upload, download, share link, client sync and image
      preview.

## Runtime Evidence

Observed during the controlled deployment on 2026-07-21:

- the web container reached normal Apache operation;
- `/status.php` returned HTTP 200 through the container health check;
- the UI loaded through Nginx Proxy Manager;
- the NAS data path reported numeric ownership `33:33`;
- removing pre-installation htaccess refresh resolved the restart loop;
- using the proxy-network CIDR resolved the invalid trusted-proxy model.

## Evidence Carried Forward

Repository implementation cannot prove target-environment behavior. Record the
following here during the controlled PoC:

- image digest and target architecture;
- NAS UID/GID and permission results;
- generated `config.php` cache and proxy settings;
- enabled application inventory and every `occ app:disable` command;
- every theming command and the asset paths used;
- cron execution timestamp;
- direct NAS file checksums;
- targeted `files:scan` result;
- container recreation result;
- complete backup and clean restore evidence;
- Proxy Host cutover and rollback evidence;
- historical-recovery validation from the tagged OwnCloud implementation, if
  rollback is required;

POC-001 is closed and the candidate is approved for a future implementation
sprint. These remaining results are mandatory before production migration.

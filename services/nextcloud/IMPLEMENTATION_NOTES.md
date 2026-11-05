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

## Security Rebuild 33.0.10 (2026-10-28 image)

Reviewed and approved on 2026-11-03 as a digest update only. Upstream rebuilt
the `33.0.10-apache` tag on a newer Debian 13 snapshot; Nextcloud stays at
33.0.10 and PHP at 8.4.27.

| | Current | Target |
|---|---|---|
| Tag | `nextcloud:33.0.10-apache` | `nextcloud:33.0.10-apache` |
| Index digest | `sha256:a4f8627d317e6de663b700f6a0d022530f038980930a4b81e967e7c19501b839` | `sha256:5ded1127972ea84c29792215f0621c71929ed315cc47be946b489c7a1c1ad305` |
| amd64 manifest | `sha256:1ae59dd29104449f1756aff63bc6b070dd634f4f6a3e956f2fb8be1a0d98c399` | `sha256:9ef9786fec0274ff88d7467e246034f8ad4e5742e344de6e049e05a3ee2bb74d` |
| arm64 manifest | `sha256:15531d894b5267cba3d0e001c3329c70b4e31ca5f4f0ae14c0a8c0cb57b1956d` | `sha256:05485fcc17e4fb751460a81127683eeabeaeb198f934ffd96e7a8d3b16bdd26d` |
| Image built | 2026-10-21 | 2026-10-28 |
| Debian snapshot | 2026-10-20 | 2026-10-27 |

Digests were read from Docker Hub on 2026-11-03.

The installed package lists of both images (283 packages each) differ only
in:

- `libbrotli1` 1.1.0-2+b7 → 1.1.0-2+deb13u1: DSA 6582, CVE-2026-111497
  (denial of service or potential code execution);
- `libheif1` and its `dav1d` and `libde265` plugins 1.23.4 → 1.23.6: DSA 6583,
  crafted HEIF/AVIF images causing denial of service, process memory
  disclosure, use-after-free and double-free; reachable through previews of
  uploaded images;
- `tzdata` 2026c → 2026e.

No database upgrade runs because the Nextcloud version is unchanged. Rollback
pins the previous digest.

Target result (2026-11-03, deployed at 15:22 UTC). Detailed evidence remains
in the private evidence location.

- [x] Pre-upgrade recovery point: platform backup run by the project owner
      immediately before the update.
- [x] Application and cron run `nextcloud:33.0.10-apache@sha256:5ded1127…`
      without restarts; `libbrotli1` 1.1.0-2+deb13u1, `libheif1` 1.23.6 and
      `tzdata` 2026e in the runtime.
- [x] `occ status` reports 33.0.10, no maintenance mode and no pending
      database upgrade.
- [x] `occ integrity:check-core` clean.
- [x] Through the proxy network: `status.php` reports 33.0.10;
      administration and WebDAV return `401` without a session; Keycloak
      login redirects to the realm. No proxy `5xx` after the deployment.
- [x] Cron ran after the deployment.
- [x] Security scan with the pinned scanner: 49 high findings with an
      available fix, from 13 CVEs. Twelve ImageMagick CVEs are counted once
      per installed ImageMagick package (48); Debian published the fix
      (`deb13u13`) to trixie-security on 2026-10-29, after this image was
      built. One CVE is in the bundled `symfony/http-foundation` v6.4.42,
      fixed upstream in branch 33 but not yet in a released version. The
      project owner accepted the residual risk until upstream publishes a
      newer image.
- [x] The `redis.config.php` and `s3.config.php` template warnings are the
      ones already accepted in the 33.0.10 update.
- [x] Image preview works for an uploaded HEIC or AVIF test image (confirmed by the project owner).

## Security Rebuild 33.0.10 (2026-11-05 image)

Reviewed and approved on 2026-11-05 as a digest update only. Upstream rebuilt
the `33.0.10-apache` tag again; Nextcloud stays at 33.0.10 and the image
environment (including PHP) is unchanged.

| | Current | Target |
|---|---|---|
| Tag | `nextcloud:33.0.10-apache` | `nextcloud:33.0.10-apache` |
| Index digest | `sha256:5ded1127972ea84c29792215f0621c71929ed315cc47be946b489c7a1c1ad305` | `sha256:56433adb270f1d7c1656fa8885dd1028d0ba8f76714c6c340b2f4a5159c9333d` |
| amd64 manifest | `sha256:9ef9786fec0274ff88d7467e246034f8ad4e5742e344de6e049e05a3ee2bb74d` | `sha256:1076141ec24541df3a9cfe3a862d8b1951977fcdc561bd98c31eeac114321bba` |
| arm64 manifest | `sha256:05485fcc17e4fb751460a81127683eeabeaeb198f934ffd96e7a8d3b16bdd26d` | `sha256:408402e15f9b5d468c185d647fe015ad91053c2b9a00ec31beb7e3ba363a375b` |
| Image built | 2026-10-28 | 2026-11-05 |

Digests were read from Docker Hub on 2026-11-05.

The 2026-11-05 security scan reported 38 new high findings against the
unchanged current image: new advisories, not an image change. The installed
package lists of both images (283 packages each) differ only in:

- ImageMagick packages `8:7.1.1.43+dfsg1-1+deb13u12` → `deb13u14`: the
  ImageMagick CVEs accepted in the previous rebuild (`deb13u13`) and the newer
  ones fixed in `deb13u14`;
- `apt` and `libapt-pkg7.0` 3.0.3 → 3.0.4;
- `linux-libc-dev` 6.12.113-1 → 6.12.115-2 (kernel headers, not executed);
- `tzdata` 2026e → 2026f.

Both images were scanned on 2026-11-05 with the pinned scanner (Trivy 0.72.0)
and the same vulnerability database:

| | Current | Target |
|---|---|---|
| Critical with an available fix | 1 | 0 |
| High with an available fix | 132 | 1 |
| Critical / high without a fix | 3 / 154 | 3 / 154 |
| Findings not present in the current image | — | 0 |

The remaining high finding with a fix is the bundled
`symfony/http-foundation` v6.4.42, already accepted in the previous rebuild
until upstream publishes a newer image.

No database upgrade runs because the Nextcloud version is unchanged. Rollback
pins the previous digest.

Target result (2026-11-05, deployed at 15:57 UTC). Detailed evidence remains
in the private evidence location.

- [x] Pre-upgrade recovery point: platform backup run by the project owner
      immediately before the update, completed successfully.
- [x] Application and cron run `nextcloud:33.0.10-apache@sha256:56433adb…`
      without restarts; ImageMagick `deb13u14`, `apt` 3.0.4 and `tzdata`
      2026f in the runtime.
- [x] `occ status` reports 33.0.10, no maintenance mode and no pending
      database upgrade.
- [x] `occ integrity:check-core` clean.
- [x] Through the proxy network: `status.php` reports 33.0.10;
      administration and WebDAV return `401` without a session; Keycloak
      login redirects to the realm. No proxy `5xx` after the deployment.
- [x] Cron ran after the deployment.

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

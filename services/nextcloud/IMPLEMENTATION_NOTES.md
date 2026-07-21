# Nextcloud PoC Implementation Notes

## Repository Outcome

The POC-001 repository implementation reuses MariaDB, Valkey, Nginx Proxy
Manager, Cloudflare Dynamic DNS, the shared Docker networks and the operation
layer. It does not modify OwnCloud service files, database scripts or state.

The lifecycle selects Nextcloud exclusively for the PoC. OwnCloud remains in
the repository as the rollback service.

## Decisions

- `nextcloud:33.0.6-apache` is pinned for application and cron.
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

## Runtime Evidence Pending

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
- OwnCloud state checks before and after the PoC.

Until those results exist, POC-001 is implemented in the repository but not
accepted as a successful runtime PoC or approved migration.

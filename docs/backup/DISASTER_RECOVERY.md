# Disaster Recovery Procedure

## Activation

Use this procedure after hardware loss, storage corruption or a deliberately
isolated restore exercise. Do not restore over a functioning production tree.
Resolve the versioned manifest first and follow
[`RECOVERY_MATRIX.md`](RECOVERY_MATRIX.md) for dependency order.

## Recovery Order

1. Recover the repository revision from Git or the protected Git bundle.
2. Recover private configuration and the Restic password through the approved
   offline channel.
3. Provision Docker, required networks and empty persistent roots.
4. Restore the selected snapshot into a disposable directory.
5. Verify the manifest contract, referenced snapshot, checksums, repository
   revision and image identities.
6. Restore MariaDB and validate application databases.
7. Restore Caddy certificates and state, and its private route files.
8. Restore Nextcloud state and database while maintenance mode remains active.
9. Restore Paperless state and database.
10. Restore the medical exam originals from the NAS data backup, then start
    the medical sync.
11. Restore Jellyfin configuration and reattach read-only source media.
12. Restore Homebridge only while production remains stopped and isolated.
13. Start services through the Operation Layer and execute application tests.

## MariaDB

The snapshot contains a logical all-database dump. Import it only into a clean,
disposable MariaDB instance running the compatible pinned major version. Check
database presence, grants and representative application queries before any
production cutover.

Do not import an all-database dump into the active production server as a test.

## Caddy

Restore `caddy/data` (certificates and ACME account) and `caddy/config` with
the Caddy UID/GID as owner; routes come from the repository and the private
`caddy.env` and `caddy/sites/`. Validate the configuration, certificate expiry,
the `403` for a direct non-Cloudflare request and one route before enabling all
public traffic. Missing certificates are issued again automatically.

Snapshots taken before the Sprint 017 decommission also contain the retired
Nginx Proxy Manager data and database; they are needed only to roll back the
migration.

## Nextcloud

Restore `html`, `data` and its database from the same snapshot. Verify ownership,
`.ocdata`, users, shares, versions, cron and representative file checksums.
Disable maintenance mode only after validation.

## Paperless-ngx

Restore data, media and database from the same snapshot. Run the application
sanity checker and validate representative originals, archives, search and
download. The consume directory is an inbox, not authoritative backup evidence.

## Medical exam originals and sync

The exam folder (`SYNC_SOURCE_ROOT`) is the source of truth for medical exams.
It is outside Restic scope and protected by the NAS data backup. Restore it
from that backup before starting the sync, keeping the same relative paths:
the sync identifies each exam by its relative path (`Ruta origen`) and hash,
so renamed or moved files would be reported as duplicates. Grant the sync UID
read access.

The sync container holds no persistent state (only `tmpfs`). Recover it from
the repository and its private environment file, create a new `sync-medico`
token (API tokens are not part of the Paperless restore), then:

```bash
./operation/compose.sh paperless-medical-sync up -d --build
```

The first run must report the existing exams as `skipped` and upload nothing.

## Jellyfin

Restore configuration with the approved UID/GID and attach existing source
media read-only. Validate users, libraries, watched state, direct play and one
hardware-assisted transcode. Cache does not require restoration.

## Homebridge

Never run production and restored Homebridge identities simultaneously on the
same HomeKit network. Restore the complete state root, image digest and private
configuration in an isolated test boundary. Recovery succeeds only when the
same bridge identity, accessories, automations and cameras work without
re-pairing.

## Acceptance Record

Record sanitized results only:

- snapshot age and policy tag;
- restore start and completion timestamps;
- component pass/fail results;
- achieved RPO and RTO;
- repository integrity result;
- confirmation that production paths were untouched;
- confirmation that duplicate Homebridge identity was never advertised;
- remediation owner for every failure.

## Production Cutover

Production cutover requires explicit owner approval, a final backup of any
recoverable current state, stopped application writers and a documented rollback
point. Restore one component at a time in dependency order. Do not delete the
disposable restore or prior recovery points until the restored platform passes
all Sprint acceptance checks.

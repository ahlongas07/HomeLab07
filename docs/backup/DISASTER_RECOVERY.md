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
7. Restore Nginx Proxy Manager state and certificates.
8. Restore Nextcloud state and database while maintenance mode remains active.
9. Restore Paperless state and database.
10. Restore Jellyfin configuration and reattach read-only source media.
11. Restore Homebridge only while production remains stopped and isolated.
12. Start services through the Operation Layer and execute application tests.

## MariaDB

The snapshot contains a logical all-database dump. Import it only into a clean,
disposable MariaDB instance running the compatible pinned major version. Check
database presence, grants and representative application queries before any
production cutover.

Do not import an all-database dump into the active production server as a test.

## Nginx Proxy Manager

Restore its data and certificate trees together with its database. Validate the
administration boundary, proxy hosts, certificate expiry and one route before
enabling all public traffic.

## Nextcloud

Restore `html`, `data` and its database from the same snapshot. Verify ownership,
`.ocdata`, users, shares, versions, cron and representative file checksums.
Disable maintenance mode only after validation.

## Paperless-ngx

Restore data, media and database from the same snapshot. Run the application
sanity checker and validate representative originals, archives, search and
download. The consume directory is an inbox, not authoritative backup evidence.

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

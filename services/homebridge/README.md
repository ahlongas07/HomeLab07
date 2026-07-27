# Homebridge

## Purpose

Homebridge provides the Sprint 008 LAN-only HomeKit integration service while
preserving the existing bridge identity, child bridges, accessories, camera
integrations and representative automations.

## Responsibilities

- Advertise the approved HomeKit bridges through mDNS and HAP.
- Preserve pairing identity and cached accessory state under `/homebridge`.
- Run the Homebridge UI, plugins and packaged FFmpeg runtime.
- Consume approved local camera streams and snapshot endpoints.

Homebridge does not own cameras, LAN infrastructure, Rockstor, public DNS,
reverse proxy publication or the platform lifecycle.

## Technology

| Capability | Selection |
|---|---|
| Application | Official `homebridge/homebridge` image by sha256 digest |
| Network | Host networking, limited architectural exception |
| State | One NAS-backed `/homebridge` persistent root |
| Lifecycle | HomeLab07 Operation Layer |
| Publication | Approved LANs only; no public publication |

The exact image digest and complete component inventory must be captured from
the validated target runtime before cutover.

## Directory Structure

```text
services/homebridge/
├── .env.example
├── IMPLEMENTATION_NOTES.md
├── README.md
└── compose.yaml
```

Private state is mounted as one recovery boundary:

```text
${HOMEBRIDGE_DATA_ROOT} -> /homebridge
```

At minimum it contains `config.json`, `persist/`, `accessories/`, UI state and
plugin state. Its contents are sensitive and must never enter Git or captured
validation evidence.

## Configuration

Create the private environment file on the target host:

```bash
cp services/homebridge/.env.example \
  ../HomeLab07.private/env/homebridge.env
```

Set `HOMEBRIDGE_IMAGE` to the official target-architecture repository digest
of the currently validated runtime. Set the canonical NAS-backed state path
and actual UI port privately. Mutable tags and placeholder digests are
rejected by the storage checker.

Do not edit `config.json`, install plugins or reset pairing state as part of
repository adoption.

## Deployment

Before cutover:

1. Freeze image and plugin changes.
2. Inventory Homebridge, UI, Node.js, FFmpeg and every plugin version.
3. Record the current image ID, digest, mounts, effective user and listeners.
4. Stop Homebridge and create a consistent storage recovery point.
5. Restart the baseline and validate it before proceeding.
6. Stop the baseline and confirm that its container no longer owns the state
   path or advertises the HomeKit identity.
7. Run `./operation/homebridge-storage-check.sh`.
8. Render Compose without starting another instance.

Controlled cutover:

```bash
./operation/compose.sh homebridge config
./operation/compose.sh homebridge config --images
./operation/start.sh homebridge
```

Never start the HomeLab07 definition while another runtime advertises the same
HomeKit identity. Do not use `pull` during cutover; the approved digest must
already be available and rollback-capable.

## Validation

```bash
./operation/compose.sh homebridge ps
./operation/compose.sh homebridge logs --tail=150
docker port homelab07-homebridge
docker inspect homelab07-homebridge \
  --format '{{.HostConfig.NetworkMode}} {{.HostConfig.Privileged}} {{.Config.User}}'
docker inspect homelab07-homebridge \
  --format '{{range .Mounts}}{{println .Destination .RW}}{{end}}'
```

Acceptance requires:

1. The UI works from every approved LAN.
2. UI access is denied from guest, visitor and unapproved IoT networks.
3. Controllers and home hubs discover and control representative accessories.
4. The primary bridge and camera child bridge retain their identities.
5. Snapshots, live view and two representative concurrent streams work.
6. Representative automations continue without re-pairing.
7. No proxy host, public DNS, tunnel, UPnP or router forwarding exists.
8. Direct external access to UI and HAP endpoints fails.
9. Container recreation preserves complete state with the same image.
10. A disposable restore reproduces the same runtime without simultaneous
    advertisement of the production identity.

## Backup

Stop Homebridge cleanly before creating a storage-level recovery point of the
complete persistent root. Protect the matching repository revision, private
configuration, image digest and version inventory with the state backup.

Container recreation alone is not a backup or disaster-recovery test.

## Restore

1. Keep production Homebridge stopped.
2. Restore the matching repository revision and private configuration.
3. Restore the complete persistent root, including plugin and UI state.
4. Confirm that no runtime advertises the same bridge identity.
5. Start the approved immutable image through the operation layer.
6. Validate identities, accessories, cameras and automations without
   re-pairing.
7. Stop the restored runtime before returning production to service.

A new Homebridge identity is not an acceptable restore.

## Security

- Host networking is approved only for this Homebridge container.
- Docker cannot enforce the LAN boundary; host, router, VLAN and firewall
  policies must deny unapproved networks.
- No Compose ports, Docker networks, Docker socket or privileged mode exist.
- The UI remains authenticated and LAN-only.
- Camera endpoints, credentials, HomeKit PINs and state remain private.
- Plugin installation, removal and upgrades are reviewed maintenance changes.
- Remote Apple Home control through a home hub is not direct Homebridge
  publication.

## Related Sprint

See `sprints/SPRINT-008.md`.

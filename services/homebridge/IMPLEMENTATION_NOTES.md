# Homebridge Implementation Notes

Record sanitized target-host evidence here during Sprint 008. Never record
real paths, addresses, names, HomeKit identities, pairing PINs, credentials,
camera URLs or backup contents.

## Required Evidence

- Current container image ID and target-architecture repository digest.
- Homebridge, Homebridge UI, Node.js and FFmpeg versions.
- Installed plugin versions, installation model and child-bridge inventory.
- Effective runtime user, storage ownership, mounts and listening ports.
- Host firewall, router, VLAN and mDNS boundary behavior.
- Approved-network access and unapproved-network denial.
- Preserved primary and child-bridge identities.
- Accessory, automation, snapshot and streaming validation.
- Container recreation, disposable restore and rollback validation.
- Confirmation that production and restored identities never advertised
  simultaneously.

## Image And Runtime Inventory

Target-host discovery and immutable image validation completed. The deployed
runtime uses Homebridge `2.2.1`; the exact target-architecture digest remains
in protected private configuration. Mutable tags are rejected by the storage
checker and are not used by the deployed Compose runtime.

## Plugin Recovery Model

The active camera runtime uses
`@homebridge-plugins/homebridge-camera-ffmpeg` `4.1.0` and the preserved camera
child bridge. Plugin state is protected with the complete `/homebridge`
recovery boundary. An incompatible unused camera plugin was removed through a
reviewed manual change after confirming that it did not provide the active
camera integrations. Automatic plugin changes remain prohibited.

## Security Boundary Evidence

Approved-LAN access and negative access tests from unapproved and external
networks completed successfully. No public DNS, reverse proxy, tunnel, UPnP or
router port forwarding exposes Homebridge.

## Recovery And Rollback Evidence

Container recreation, backup, disposable restore and rollback completed with
the same bridges, accessories, camera integrations and representative
automations. Production and restored instances did not advertise the same
HomeKit identity simultaneously.

## Target-Host Acceptance

Target-host acceptance completed on 2026-07-27.

- Homebridge and its camera child bridge started successfully.
- Existing accessories and representative automations remained operational.
- Camera snapshots and live streaming succeeded through the active Camera
  FFmpeg plugin.
- State survived container recreation and controlled restore.
- LAN isolation and absence of direct public exposure were validated.
- The previous container remained stopped and available for rollback during
  acceptance.

No sensitive or environment-specific value is retained in this evidence.

## Image Update Review (2026-10-22)

Reviewed with the other platform security updates; **deferred** by the
project owner until a stable image ships Node.js 24.22.1 or later.

- Running image: official stable `2026-07-20` (Ubuntu 24.04, Node.js 24.18.0,
  Homebridge UI 5.27.0). Homebridge core 2.2.1 and the camera plugin 4.1.0
  live in the persistent `/homebridge` root and do not change with the image.
- No upstream advisory exists for Homebridge, Homebridge UI, the Docker image
  or the camera plugin. The scan's critical findings are kernel headers
  (`linux-libc-dev`), not applicable to a container.
- The relevant risk is Node.js: the July 2026 security release (24.18.1) and
  the October 2026 security release (24.22.1, published 2026-10-20) are not in
  the running image. Homebridge is LAN-only, which limits exposure.
- Latest stable image `2026-10-16`
  (`sha256:d2370beb6a0208d3f20f869288bc070b5cc34d86b52a5872311ce2bcff02a670`)
  ships Node.js 24.22.0, Homebridge UI 5.29.0 and FFmpeg for Homebridge
  v2.2.2: it covers the July release but not the October one, and adds
  `python3-pip`, whose vendored libraries are flagged but unused at runtime.
  Updating twice in a short period was judged worse than waiting for one
  update.

Resume when a stable `homebridge/homebridge` date tag lists NodeJS 24.22.1 or
later in its release notes. The digest is set privately in `HOMEBRIDGE_IMAGE`;
pre-pull the image, create the recovery point with Homebridge stopped, then
recreate it and validate bridges, cameras and automations as described in the
README. Updating Homebridge core (2.2.1 → 2.3.x) in the persistent root is a
separate reviewed change.

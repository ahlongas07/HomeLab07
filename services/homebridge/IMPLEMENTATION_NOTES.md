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

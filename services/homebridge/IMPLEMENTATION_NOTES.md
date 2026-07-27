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

Pending target-host discovery. The committed Compose definition requires an
official `homebridge/homebridge@sha256:<digest>` reference and rejects mutable
tags. Record the validated digest and component compatibility set here before
cutover without including environment-specific information.

## Plugin Recovery Model

Pending target-host discovery. Document whether each plugin is included in the
image, installed under `/homebridge`, restored from persistent state or
reinstalled from an explicit version inventory. Automatic plugin changes are
not approved.

## Security Boundary Evidence

Pending target-host validation. Positive LAN access alone is insufficient;
record sanitized evidence that guest, visitor, unapproved IoT and external
networks cannot reach the Homebridge UI or HAP listeners.

## Recovery And Rollback Evidence

Pending controlled validation. Recovery succeeds only when the immutable
runtime plus restored complete state reproduces the same bridges, accessories,
camera integrations and representative automations without re-pairing.

## Target-Host Acceptance

Pending. Complete this section only after controlled cutover and every Sprint
008 acceptance criterion succeeds.

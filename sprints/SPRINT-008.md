# Sprint 008 — Homebridge Platform

**Status:** In Progress — repository implementation complete; target-host acceptance required

**Classification:** Business Service

**Primary Technology:** Homebridge

**Last Reviewed:** 2026-07-27

---

# Objective

Bring Homebridge under the reproducible operational model of HomeLab07 while
preserving local HomeKit behavior, camera integrations, pairing identity and
automation continuity.

Homebridge must remain a LAN-only service. Its administration interface and
HomeKit endpoints may be reached from approved local networks, but the service
must not be published through the reverse proxy, public DNS, a tunnel or router
port forwarding.

The Sprint operationalizes the validated Homebridge workload. It does not
redesign the smart-home environment, replace working integrations or introduce
additional automation platforms.

---

# Decision Context

HomeLab07 provides:

- Docker Compose service execution;
- a centralized operation layer;
- NAS-backed persistent storage;
- private environment configuration through `HomeLab07.private/`;
- shared internal and proxy networks for services that need them;
- HTTPS publication through Nginx Proxy Manager when explicitly approved;
- public DNS updates through Cloudflare Dynamic DNS when explicitly approved.

Homebridge has different networking requirements from conventional web
applications. HomeKit discovery depends on multicast DNS, and Homebridge must
communicate directly with controllers, accessories and local camera endpoints.
The standard proxy-only pattern therefore does not fit this workload.

Homebridge is intentionally local. Existing public-publication capabilities
are not consumed merely because they are available.

```text
Approved LAN clients
    ├── browsers ─────────────► Homebridge UI
    ├── HomeKit controllers ──► mDNS and HAP
    └── home hubs ────────────► mDNS and HAP
                                      │
                                      ▼
                                  Homebridge
                                      │
                                      ▼
                           approved local integrations

Internet ─────────────────────────────X Homebridge
Nginx Proxy Manager ──────────────────X Homebridge
Cloudflare public DNS ────────────────X Homebridge
```

---

# Discovery Baseline

The planning baseline observed on 2026-07-27 is:

| Component | Observed baseline |
|---|---|
| Container image | Official `homebridge/homebridge` repository using a mutable tag |
| Homebridge | `1.11.2` |
| Homebridge UI | `5.20.0` |
| Node.js | `24.14.0` |
| Container architecture | Linux x86-64 |
| Network mode | Host networking |
| Container storage path | `/homebridge` |
| Advertiser | `bonjour-hap` |
| Integrations | HomeKit bridge plus an isolated camera child bridge |
| Camera transport | Local RTSP and HTTP snapshot endpoints through FFmpeg |

This table is discovery evidence, not approval to recreate the container from
the mutable tag. The exact current image ID, repository digest and plugin
versions must be captured before implementation.

Homebridge 2.x is available upstream, but a major-version upgrade is not part
of this Sprint. Implementation must first reproduce the validated behavior on
an exact compatible image. A future upgrade requires its own compatibility,
plugin and rollback validation.

---

# Architecture

## Runtime Architecture

The baseline contains one container:

```text
homelab07-homebridge
```

The container owns the Homebridge runtime, UI, HomeKit bridge processes,
plugins and FFmpeg execution. It does not own the local devices, camera source
streams, router, public DNS, TLS or platform storage.

## Platform Reuse

| Existing capability | Decision | Use |
|---|---|---|
| NAS-backed storage | Reuse | Persistent Homebridge configuration and identity |
| Operation layer | Extend | Lifecycle and diagnostic interface |
| Host network | Approved exception | HomeKit and mDNS communication on the LAN |
| `homelab07-internal` | Not used | No internal container dependency exists |
| `homelab07-proxy` | Not used | Homebridge is not proxy-published |
| MariaDB | Not used | Homebridge has no relational database requirement |
| Valkey | Not used | Homebridge has no shared cache requirement |
| Nginx Proxy Manager | Not used | UI and HAP remain LAN-only |
| Cloudflare Dynamic DNS | Not used | No public Homebridge record is required |
| `HomeLab07.private` | Reuse | Host storage path and environment-specific values |

## Host Networking Exception

The official Homebridge Docker guidance uses host networking. HomeLab07
approves `network_mode: host` for this service because multicast discovery and
direct HomeKit connectivity are demonstrated requirements.

Host networking is approved only because HomeKit discovery and HAP
connectivity cannot be reliably reproduced through the standard proxy-only
Docker network model on the target environment.

The exception applies only to the Homebridge container. It does not authorize
host networking for unrelated services or establish host networking as a
HomeLab07 default.

Any future attempt to replace host networking must demonstrate equivalent
mDNS, HomeKit controller, home-hub and camera behavior before this exception
can be removed.

Consequences:

- Compose must not define `ports` for Homebridge;
- Homebridge must not join Docker bridge networks;
- listening sockets are exposed directly on the host LAN interface;
- Docker network isolation cannot enforce the LAN boundary;
- router and host firewall validation become required acceptance evidence;
- every configured HAP and UI port must be inventoried before deployment.

---

# Persistent Storage

## Storage Boundary

Homebridge receives one NAS-backed persistent root:

```text
${HOMEBRIDGE_DATA_ROOT} -> /homebridge
```

The real host path is environment-specific and belongs only in private
configuration. Example files must use placeholders.

The persistent root includes configuration, pairing identity, cached
accessories, child-bridge state, UI state and locally installed plugin state.
Its internal layout is managed by the official Homebridge image and must not be
partially reconstructed by Compose.

Critical state includes at least:

```text
/homebridge/
├── config.json
├── persist/
├── accessories/
└── Homebridge UI and plugin state
```

The exact runtime layout must be inventoried without copying secrets into the
repository.

## Mount Policy

Approved mounts:

```text
${HOMEBRIDGE_DATA_ROOT} -> /homebridge
/etc/localtime          -> /etc/localtime:ro
```

No broad NAS root, Docker socket, device tree or unrelated host directory may
be mounted.

Only one Homebridge container may write to the persistent root at a time.
Concurrent writers with the same pairing identity are prohibited.

## Sensitive State

The following must never be committed or included in public validation
evidence:

- HomeKit pairing PINs;
- bridge usernames and pairing identities;
- `persist/` and `accessories/` contents;
- UI credentials and sessions;
- plugin credentials, tokens and cookies;
- camera URLs, addresses, credentials and identifying names;
- real hostnames, IP addresses and storage paths;
- backup archives.

Repository examples must use non-functional placeholders.

## Data Ownership

| Component | Owner |
|---|---|
| HomeKit bridge identity | Homebridge |
| Pairing state | Homebridge |
| Cached accessories | Homebridge |
| Child-bridge state | Homebridge |
| Homebridge configuration | Homebridge |
| Camera source streams | Camera systems |
| Camera credentials and endpoints | Private environment configuration |
| Persistent storage platform | Rockstor |
| Service lifecycle | HomeLab07 Operation Layer |
| Local network access policy | Host, router and network infrastructure |
| Public DNS and reverse proxy | Not consumed |

Homebridge owns its application identity and state. It does not own camera
systems, LAN infrastructure or the NAS platform.

---

# Container Image And Version Policy

The runtime must use the official `homebridge/homebridge` image.

Before implementation:

1. capture the running container image ID;
2. record the target-architecture repository digest;
3. identify an immutable upstream reference for the validated runtime;
4. record Homebridge, UI, Node.js, FFmpeg and plugin versions;
5. render Compose without pulling or changing the image;
6. verify that rollback can start the same image again.

`latest`, rolling tags, prereleases and unrecorded digests are prohibited in
the committed Compose definition.

Homebridge, Node.js, the UI, FFmpeg and plugins must not be upgraded as part of
the initial operational adoption. Each update is a separate, reversible change
with compatibility evidence.

Automatic container-image updates are not approved.

## Plugin And Runtime Boundary

The validated Homebridge runtime includes:

- Homebridge;
- Homebridge UI;
- Node.js;
- FFmpeg;
- installed plugins;
- child-bridge configuration.

These components form one compatibility set. They must be inventoried and
restored together. An immutable container image alone is not sufficient when
plugin versions or plugin state may change independently inside `/homebridge`.

Plugin installation, removal or upgrade is a reviewed operational change and
must not occur automatically during normal startup.

Discovery must determine whether each plugin is baked into the image,
installed under the persistent root, restored from state or reinstalled from
an explicit version inventory. The recovery procedure must document and
validate the actual model discovered on the target host.

---

# HomeKit And Camera Integrations

## Bridge Topology

The validated topology uses:

- one primary Homebridge bridge;
- one isolated camera child bridge;
- fixed HAP ports recorded only in private configuration;
- mDNS advertisement through `bonjour-hap`.

Child-bridge isolation must be preserved during initial implementation. The
Sprint must not merge bridges, reset pairing state or generate new identities.

## Camera Boundary

Homebridge consumes approved local camera streams and snapshot endpoints.
Camera addresses, credentials, channel identifiers and names remain private.

The container must have only the network reachability needed for:

- approved RTSP source streams;
- approved HTTP snapshot endpoints;
- DNS and time services required by the runtime;
- package registries only during an explicitly approved maintenance window.

FFmpeg behavior must be validated with the packaged binary. Codec availability
must not be inferred from a different operating system or host installation.

Validation must cover:

- snapshot retrieval;
- live view startup;
- two representative concurrent streams;
- child-bridge restart;
- CPU and memory consumption;
- recovery after a camera endpoint is temporarily unavailable;
- absence of camera credentials in logs and repository evidence.

Camera recording, motion analysis, MQTT, FTP, SMTP and auxiliary HTTP services
remain disabled unless a future requirement explicitly approves them.

---

# LAN-Only Security Policy

Homebridge must be reachable only from approved local networks.

LAN-only does not mean implicitly trusted. Because host networking may cause
Homebridge to listen on every host LAN interface, Docker cannot enforce or by
itself prove the access boundary. The effective security boundary depends on
the host firewall, router, VLANs and network policy.

Required controls:

- no public DNS record for Homebridge;
- no Nginx Proxy Manager host;
- no Cloudflare Tunnel or equivalent tunnel;
- no router port forwarding;
- no automatic UPnP/NAT mapping;
- no direct WAN firewall allowance;
- authenticated Homebridge UI;
- explicit inventory of UI, HAP, child-bridge and mDNS ports;
- access from approved LAN clients only;
- outbound camera access limited to required local endpoints where the network
  platform supports enforcement.

Guest, visitor and untrusted IoT networks are denied unless explicitly
approved. Sprint acceptance requires positive access tests from approved
networks and negative access tests from unapproved and external networks;
successful local access alone is insufficient validation.

Remote control through an Apple home hub is an Apple HomeKit service path. It
does not constitute direct remote access to the Homebridge UI, HAP ports or
container. HomeLab07 must not expose Homebridge merely to reproduce
functionality already provided through the approved home-hub architecture.
This behavior does not change the LAN-only boundary of the service.

Guest and untrusted IoT networks are not implicitly approved LANs. If multiple
VLANs are present, routing and mDNS reflection require a separate documented
rule set with the minimum necessary reachability.

---

# Privilege Model

The discovery baseline runs with elevated container privileges. Changing the
runtime UID/GID during the initial adoption could alter storage access, plugin
installation and FFmpeg behavior.

The Sprint must:

1. record the effective container user and file ownership;
2. confirm that privileged mode and additional Linux capabilities are absent;
3. apply `no-new-privileges` if runtime validation proves compatibility;
4. avoid changing storage ownership merely to satisfy the container;
5. document rootless or explicit UID/GID execution as a follow-up hardening
   decision if it cannot be validated safely in this Sprint.

The container must never receive the Docker socket or privileged mode.

---

# Repository Impact

Implementation adds:

```text
services/homebridge/
├── .env.example
├── IMPLEMENTATION_NOTES.md
├── README.md
└── compose.yaml

operation/
└── homebridge-storage-check.sh
```

Implementation updates:

```text
operation/start.sh
operation/stop.sh
operation/status.sh
operation/lib.sh
README.md
ROADMAP.md
CHANGELOG.md
```

---

# Operation Layer Integration

Homebridge lifecycle operations must flow through the HomeLab07 operation
layer.

Expected operator interface:

```bash
./operation/start.sh homebridge
./operation/stop.sh homebridge
./operation/status.sh homebridge
./operation/compose.sh homebridge ps
./operation/compose.sh homebridge logs
./operation/homebridge-storage-check.sh
```

The storage checker must validate without printing sensitive values:

- `HOMEBRIDGE_DATA_ROOT` is defined and absolute;
- the path is not `/`, the repository or a broad storage root;
- the directory exists and is writable by the effective runtime user;
- critical state directories exist;
- symlinks do not escape the approved root;
- only the intended container uses the storage path;
- the example configuration contains placeholders only.

The operation layer must not reset Homebridge, remove cached accessories,
regenerate pairing identity or update plugins automatically.

---

# Implementation Plan

## Phase 1 — Discovery Freeze

1. Capture the running image ID, digest and component versions.
2. Inventory plugins, child bridges, ports, mounts and effective user.
3. Record container resource behavior under normal operation.
4. Confirm router, firewall, VLAN and mDNS boundaries.
5. Freeze image and plugin updates for the implementation window.

## Phase 2 — Recovery Point

1. Stop Homebridge cleanly.
2. Create a storage-level recovery point from a consistent state.
3. Record checksums or metadata needed to validate critical state without
   exposing its contents.
4. Confirm the previous container definition and exact image remain available
   for rollback.
5. Restart the baseline and verify normal operation before proceeding.

## Phase 3 — Reproducible Definition

1. Add placeholder-only private configuration examples.
2. Add the storage validation helper.
3. Add the official immutable Homebridge image reference.
4. Configure host networking without Compose port mappings.
5. Mount the persistent root and local time boundary.
6. Integrate lifecycle and status operations.
7. Validate Compose and shell syntax without starting a second instance.

## Phase 4 — Controlled Cutover

1. Announce a local smart-home maintenance window.
2. Stop the previous Homebridge container.
3. Confirm no Homebridge or child-bridge process remains active.
4. Start Homebridge through the HomeLab07 operation layer.
5. Confirm that pairing identities and child bridges are unchanged.
6. Validate UI, accessories, cameras and representative automations.
7. Observe logs and resource use without exposing private configuration.

## Phase 5 — Security And Recovery Validation

1. Verify UI access from representative approved LAN clients.
2. Verify HomeKit discovery and control from approved controllers and hubs.
3. Verify that no reverse proxy, public DNS or tunnel route exists.
4. Verify WAN-originated traffic cannot directly reach Homebridge.
5. Recreate the container using the same immutable image and validate state.
6. Exercise rollback or a disposable restore without resetting production
   pairing identity.
7. Record sanitized evidence and close the Sprint.

---

# Validation Plan

## Static Validation

- Compose resolves with the example environment file.
- The official image uses an immutable approved reference.
- The target architecture digest is recorded.
- `network_mode: host` is present and documented.
- No `ports` or Docker networks are defined.
- Only the approved storage and local-time mounts exist.
- No Docker socket, privileged mode or broad host mount exists.
- No MariaDB, Valkey, reverse-proxy or DNS dependency exists.
- No real PIN, username, IP, hostname, camera URL, credential or storage path
  exists in Git.
- Operation scripts pass `bash -n`.

## Runtime Validation

- Homebridge and its UI start successfully.
- The primary bridge and camera child bridge remain operational.
- Pairing identity remains unchanged.
- Approved accessories remain reachable.
- Configuration and cached accessories survive container recreation.
- Homebridge can reach approved camera endpoints.
- No unexpected listener or auxiliary protocol becomes active.
- Logs contain no repeated pairing, storage, plugin or FFmpeg failures.

## Camera Validation

- Representative snapshots load.
- Representative live streams start and remain stable.
- Two concurrent streams remain within the documented resource envelope.
- Camera recovery succeeds after a controlled endpoint interruption.
- Child-bridge restart does not interrupt the primary bridge.
- Source addresses and credentials do not appear in captured evidence.

## Network And Security Validation

- The UI is reachable from representative clients on every approved LAN.
- The UI is not reachable from guest or unapproved networks.
- HomeKit controllers discover and control accessories locally.
- Required multicast behavior remains constrained to approved networks.
- No Nginx Proxy Manager route exists.
- No public DNS record or tunnel exists.
- The router exposes no Homebridge port mapping.
- An external-origin test cannot directly reach UI or HAP endpoints.

## Recovery Validation

- A consistent recovery point can be created while Homebridge is stopped.
- The exact approved image remains available for rollback.
- Container recreation preserves configuration, pairing and child bridges.
- A controlled restore recovers representative state.
- Rollback never starts two containers with the same identity simultaneously.

Recovery success is defined as follows:

> A clean runtime using the approved immutable image plus restored Homebridge
> state reproduces the same bridge identity, child bridges, accessories,
> camera integrations and representative automations without re-pairing.

Container recreation alone is not disaster recovery. A fresh Homebridge
instance with a new pairing identity is not an acceptable restore. A recovery
test must never allow the restored instance and production instance to
advertise the same HomeKit identity simultaneously.

---

# Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Mutable image changes during recreation | Unplanned Homebridge, Node.js, UI or FFmpeg upgrade | Pin an immutable image and record its digest before cutover |
| Two containers announce the same identity | Pairing conflicts and state corruption | Enforce a single-writer, single-runtime cutover |
| Pairing state is incomplete or altered | Accessories must be paired again | Protect the complete persistent root and create a consistent recovery point |
| Host networking broadens exposure | UI or HAP is reachable from an unintended network | Validate router, firewall and VLAN boundaries explicitly |
| mDNS does not cross an approved VLAN | Controllers cannot discover Homebridge | Document approved networks and add narrowly scoped reflection only when required |
| Plugin or FFmpeg behavior changes | Camera streams fail | Freeze versions and validate packaged codecs before any upgrade |
| Camera configuration leaks through logs | Credentials or household metadata are exposed | Sanitize evidence and disable verbose logging after validation |
| Elevated runtime user increases impact | Container compromise affects writable storage | Prohibit privileged mode/socket access and evaluate UID/GID hardening separately |
| Automatic plugin update modifies runtime state | Reproducibility and rollback are lost | Disable automatic changes and perform reviewed update operations |
| Major Homebridge upgrade breaks plugins | Loss of smart-home functionality | Exclude Homebridge 2.x from this Sprint and plan a separate compatibility change |

---

# Explicit Non-Goals

- Home Assistant deployment.
- Replacement of Homebridge.
- Homebridge 2.x upgrade.
- Plugin, Node.js, UI or FFmpeg upgrade during initial adoption.
- Redesign or re-pairing of HomeKit accessories.
- Replacement of working camera integrations.
- Public access to Homebridge or its UI.
- Nginx Proxy Manager, Cloudflare DNS or tunnel integration.
- MQTT broker deployment.
- Zigbee2MQTT, Z-Wave, Matter or Thread platform deployment.
- Node-RED or ESPHome deployment.
- Camera recording, motion analysis or video retention platform.
- Broad VLAN redesign or unrestricted mDNS reflection.
- Automatic container or plugin updates.
- High availability or multi-instance Homebridge.
- Changes to unrelated platform services.

---

# Acceptance Criteria

The Sprint is complete only when:

- the roadmap records the approved Sprint number and priority;
- Homebridge deploys through the HomeLab07 operation layer;
- the official container image is immutable and its digest is recorded;
- `latest` is absent from the committed runtime definition;
- the complete Homebridge state uses one private NAS-backed persistent root;
- no sensitive or environment-specific value exists in Git;
- host networking is documented as a limited Homebridge exception;
- no other HomeLab07 service was moved to host networking by this Sprint;
- no Compose ports or Docker networks are configured;
- the UI is reachable from approved LAN clients;
- HomeKit controllers and home hubs operate locally;
- Homebridge is not directly reachable from the Internet;
- no reverse proxy, public DNS record, tunnel or router mapping exposes it;
- the primary bridge and camera child bridge preserve their identities;
- accessories, cameras and representative automations continue working;
- state survives container recreation with the same image;
- a consistent recovery point and rollback procedure are validated;
- applicable static, runtime, camera, network and security validation passes;
- service documentation covers configuration, deployment, validation, backup,
  restore, security and related Sprint information.

---

# Definition of Done

Sprint 008 is done when Homebridge is a reproducible, documented and
recoverable HomeLab07 service while remaining operationally local to the
approved LAN.

The implementation must preserve smart-home continuity, introduce no public
exposure and leave future upgrades as explicit, independently reviewable
changes.

---

# Engineering Principles

Sprint 008 introduces no new shared platform capability.

Homebridge consumes existing storage and operation capabilities while
remaining intentionally independent from public DNS, reverse proxy and shared
application networks.

Host networking is an approved architectural exception for a demonstrated
multicast and HomeKit requirement. It is not a precedent or default for other
HomeLab07 services.

LAN isolation is part of the application security model.

Operational reproducibility and smart-home continuity take precedence over
feature expansion, upgrades or topology redesign.

Homebridge remains a replaceable application, while its complete pairing and
identity state remains a protected recovery boundary.

---

# Completion Notes

This section will be completed after implementation.

It must summarize:

- roadmap and Sprint-number reconciliation;
- immutable image and component-version validation;
- successful controlled cutover;
- preservation of bridge and child-bridge identities;
- accessory and automation validation;
- camera snapshot and streaming validation;
- LAN access and unapproved-network denial validation;
- confirmation that no public exposure exists;
- container recreation validation;
- backup, restore and rollback validation;
- resource-use observations;
- any retained security exceptions or deferred hardening work.

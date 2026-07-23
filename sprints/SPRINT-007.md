# Sprint 007 — Media Platform

**Status:** In Progress — runtime validation required

**Classification:** Business Service

**Primary Technology:** Jellyfin

**Last Reviewed:** 2026-07-23

---

# Objective

Introduce Jellyfin as HomeLab07's media service and validate secure playback,
library management and recoverable application state while preserving the NAS
as the authoritative media-storage layer.

The Sprint must deliver useful media playback through the existing operation,
storage, networking, DNS and HTTPS capabilities without giving the application
unnecessary write access to source media or introducing a new database,
in-memory service or media-management stack.

---

# Decision Context

HomeLab07 already provides:

- NAS-backed persistent storage through Rockstor;
- secure publication through Nginx Proxy Manager;
- DNS updates through Cloudflare Dynamic DNS;
- shared Docker networking;
- private environment configuration through `HomeLab07.private`;
- standardized lifecycle operations.

Jellyfin stores its own application state and does not require MariaDB or
Valkey. Adding either dependency would increase coupling without platform
value. Source media remains owned by the NAS and is presented to Jellyfin as a
read-only library.

The planning baseline uses the official Jellyfin container. Implementation
entry revalidation on 2026-07-23 selected the latest stable release,
`10.11.11`. The target-architecture digest must be recorded immediately before
deployment. `latest`, prerelease and rolling tags are prohibited.

---

# Architecture

```text
Clients
   │
   ▼ HTTPS and WebSockets
Nginx Proxy Manager
   │
   ▼ HTTP on homelab07-proxy
Jellyfin
   ├── /config          durable application state
   ├── /cache           replaceable cache and transcode workspace
   └── /media/*        read-only Rockstor media libraries
```

Jellyfin owns media indexing, metadata, users, playback policy and sessions.
It does not own source media, TLS, DNS, shared identity, backups or the Docker
host.

## Platform Reuse

| Existing capability | Decision | Planned use |
|---|---|---|
| Rockstor | Reuse | Authoritative media plus dedicated Jellyfin state |
| `homelab07-proxy` | Reuse | Nginx Proxy Manager to Jellyfin traffic |
| `homelab07-internal` | Not required initially | Add only for a demonstrated internal dependency |
| MariaDB | Not consumed | Jellyfin owns its embedded application data |
| Valkey | Not consumed | No Jellyfin baseline requirement |
| Nginx Proxy Manager | Reuse | HTTPS termination and WebSocket proxying |
| Cloudflare Dynamic DNS | Reuse | Private hostname input and DNS update |
| Operation layer | Extend | Lifecycle and diagnostic interface |
| `HomeLab07.private` | Reuse | Paths, URL, timezone and UID/GID values |

---

# Technology Stack

| Capability | Planned selection | Decision |
|---|---|---|
| Media server | `jellyfin/jellyfin:10.11.11` | Official exact stable tag selected at implementation entry |
| Database | Jellyfin embedded state under `/config` | No shared database dependency |
| Media storage | Read-only Rockstor bind mounts | NAS remains authoritative |
| Configuration | Rockstor-backed `/config` | Required durable state |
| Cache/transcodes | Dedicated `/cache` | Replaceable; capacity and cleanup must be tested |
| Publication | Existing Nginx Proxy Manager | HTTPS and WebSockets |
| DNS | Existing Cloudflare Dynamic DNS | Environment-specific record remains private |
| Authentication | Jellyfin local users | Identity Platform remains Sprint 010 |
| Transcoding | VA-API on Intel Sandy Bridge plus software fallback | Scoped H.264 acceleration validated before implementation |

Not approved in the baseline:

- `latest` or prerelease images;
- LinuxServer.io, hotio or other third-party images;
- direct Internet exposure of port `8096`;
- host networking;
- writable source-media mounts;
- Docker socket access;
- privileged mode;
- MariaDB, PostgreSQL, Redis or Valkey dependencies;
- DLNA discovery;
- automatic media acquisition or download services;
- community authentication plugins;
- automatic image updates.

---

# Repository Impact

Implementation is expected to add:

```text
services/jellyfin/
├── .env.example
├── IMPLEMENTATION_NOTES.md
├── README.md
└── compose.yaml

operation/
└── jellyfin-storage-check.sh
```

Implementation is expected to update:

```text
operation/start.sh
operation/stop.sh
operation/status.sh
README.md
ROADMAP.md
CHANGELOG.md
```

This planning change adds none of those runtime files.

---

# Persistent Storage

## Planned Layout

Private configuration supplies dedicated state and library roots:

```text
${JELLYFIN_ROOT}/
├── config/       durable Jellyfin database, users and settings
└── cache/        cache, downloaded artwork and transcode workspace

${MEDIA_ROOT}/
├── movies/       source library, read-only to Jellyfin
├── music/        source library, read-only to Jellyfin
└── photos/       family photos and videos, read-only to Jellyfin
```

The real paths and enabled libraries belong only in private configuration.
Example files use placeholders and do not assume a production share layout.

## Mount Policy

Planned container mounts:

```text
${JELLYFIN_ROOT}/config -> /config
${JELLYFIN_ROOT}/cache  -> /cache
${MEDIA_MOVIES_ROOT}    -> /media/movies:ro
${MEDIA_MUSIC_ROOT}     -> /media/music:ro
${MEDIA_PHOTOS_ROOT}    -> /media/photos:ro
```

Additional libraries require explicit private variables and Compose review.
The implementation must not mount a broad NAS root merely for convenience.

Jellyfin must keep generated metadata in its application state by default.
Writing NFO files, artwork or subtitles beside source media is excluded because
it would require writable media mounts. Any future sidecar-metadata policy
requires a separate recoverability and ownership decision.

## Ownership

The container runs as an explicit unprivileged UID/GID matching the target
host. The storage checker must verify:

- `/config` and `/cache` exist and are writable by that UID/GID;
- each media root exists and is readable but not writable through the
  container mount;
- paths are absolute and are not `/` or the repository;
- symlink behavior does not escape the approved library roots.

Do not use `chmod 777`.

---

# Storage Principles

HomeLab07 follows a Storage First architecture.

Rockstor remains the authoritative storage layer. Jellyfin provides indexing,
metadata, playback and media-library management over NAS-backed storage.
Source media is never owned by Jellyfin.

Application state and media libraries remain separate recovery boundaries.
Media libraries are mounted read-only by default. Writable media mounts require
a separate architectural decision and are not approved by Sprint 007.

This boundary keeps Jellyfin replaceable without transferring ownership of
source media from the storage platform to the application.

## Data Ownership

| Component | Owner |
|---|---|
| Source media | Rockstor |
| Metadata | Jellyfin |
| Playback history | Jellyfin |
| Users | Jellyfin |
| Application configuration | Jellyfin |
| TLS | Nginx Proxy Manager |
| DNS | Cloudflare Dynamic DNS |
| Platform lifecycle | HomeLab07 Operation Layer |

---

# Docker Architecture

The baseline contains one service:

```text
homelab07-jellyfin
```

It must:

- use the official exact stable image tag and record its runtime digest;
- use `restart: unless-stopped`;
- run with an explicit non-root UID/GID;
- join `homelab07-proxy`;
- publish no host ports;
- mount `/config` and `/cache` from dedicated paths;
- mount each media library read-only;
- apply `no-new-privileges` where compatible;
- expose no Docker socket;
- provide a healthcheck against the local HTTP endpoint on port `8096`;
- define conservative resource expectations before load testing.

The official image's internal HTTP port is `8096`. Nginx Proxy Manager reaches
that port over `homelab07-proxy`; clients never address the container name or
port directly.

## Network Mode And DLNA

Bridge networking is the baseline. Official Jellyfin guidance notes that host
networking is required for DLNA discovery. HomeLab07 excludes DLNA from Sprint
007 because host networking weakens the standard proxy-only boundary and is
not required for web, mobile or TV clients configured with the HTTPS URL.

If DLNA becomes a demonstrated requirement, evaluate it as a platform
enhancement with explicit firewall, port and discovery behavior.

---

# Transcoding Strategy

## Direct Play First

The first goal remains direct play. Hardware acceleration is used only when a
client requires transcoding. Direct play reduces CPU use, cache writes and
playback complexity.

The synthetic test set should cover, where legally available:

- H.264 video with AAC audio;
- HEVC video;
- common containers such as MP4 and MKV;
- text subtitles;
- one subtitle format requiring burn-in;
- audio-only playback.

Do not place copyrighted sample media or identifying metadata in Git.

## Software Transcoding Baseline

Software transcoding is permitted only for controlled validation. Measure CPU,
memory, startup delay, seeking and `/cache` growth. The baseline is not accepted
for unrestricted concurrent transcoding without target-host evidence.

## Validated Hardware Acceleration Baseline

Target-host discovery completed on 2026-07-23. The host provides an Intel
Sandy Bridge Gen6 integrated GPU through the `i915` kernel driver and exposes
`/dev/dri/renderD128`. The official Jellyfin `10.11.10` planning image
successfully initialized VA-API 1.23 with the legacy Intel `i965` driver. The
final `10.11.11` pin must repeat this validation before acceleration is
accepted.

Reported VA-API capabilities are:

| Codec/profile | Decode | Encode |
|---|---:|---:|
| MPEG-2 Simple/Main | yes | no |
| H.264 Constrained Baseline/Main/High | yes | yes |
| H.264 Stereo High | yes | no |
| VC-1 Simple/Main/Advanced | yes | no |
| HEVC, VP9 and AV1 | no | no |

The modern `iHD` driver failing before successful `i965` fallback is expected
for this pre-Broadwell platform. Jellyfin must use VA-API rather than QSV and
must enable only the profiles reported by `vainfo`. HDR tone mapping, HEVC,
VP9, AV1 and Intel low-power encoding are not supported by this GPU.

The implementation may map only:

```text
/dev/dri/renderD128
```

It must not mount `card0`, all of `/dev/dri`, or use privileged mode. The final
group mapping must use the target host's private numeric group configuration
and must not be hardcoded in the repository.

Hardware acceleration remains conditionally accepted until an H.264 playback
test proves VA-API activity in Jellyfin playback information and
`intel_gpu_top`. Software fallback, subtitle burn-in, quality and concurrent
load must still be measured. Direct play remains preferred.

---

# Private Configuration

Expected private file:

```text
HomeLab07.private/env/jellyfin.env
```

The repository example should contain placeholders for:

```dotenv
JELLYFIN_ROOT=/path/to/homelab07-jellyfin
JELLYFIN_PUBLISHED_URL=https://media.example.com
JELLYFIN_TIME_ZONE=Region/City
JELLYFIN_UID=1000
JELLYFIN_GID=1000
MEDIA_MOVIES_ROOT=/path/to/media/movies
MEDIA_MUSIC_ROOT=/path/to/media/music
MEDIA_PHOTOS_ROOT=/path/to/media/photos
```

Movies, music and family media use dedicated roots. The `Photos` library
presents photos and home videos from the same directory tree. Jellyfin does not
ingest phone uploads, own originals or replace NAS backup. Any additional
library root requires explicit approval.

The public URL, host paths, real UID/GID values, library names and hardware
device details are environment-specific and must not enter Git. Administrator
credentials are created interactively in Jellyfin and must never be stored in
the example environment file.

---

# Reverse Proxy And DNS

Traffic path:

```text
Client
   ↓ HTTPS
Nginx Proxy Manager
   ↓ HTTP over homelab07-proxy
homelab07-jellyfin:8096
```

Planned Nginx Proxy Manager settings:

| Setting | Planned value |
|---|---|
| Domain | `<jellyfin-public-domain>` |
| Scheme | `http` |
| Forward host | `homelab07-jellyfin` |
| Forward port | `8096` |
| WebSocket support | enabled |
| Cache assets | disabled |
| Block common exploits | validate with playback before enabling permanently |
| Force SSL | enabled after certificate validation |
| HTTP/2 | enabled |
| HSTS | only after HTTPS and recovery access are validated |

Jellyfin's Network settings must list the actual Nginx Proxy Manager address or
approved proxy-network CIDR as a Known Proxy. This allows trusted forwarded
headers to preserve the client address and local/remote access policy. Broad
private ranges must not be trusted without justification.

The proxy configuration must preserve:

- `Host`;
- `X-Forwarded-For`;
- `X-Forwarded-Proto`;
- `X-Forwarded-Host`;
- WebSocket `Upgrade` and `Connection` behavior;
- HTTP range requests and long-running streaming responses.

Reverse-proxy logs require protection because Jellyfin may place an API key in
a request URL. Do not capture full production request paths in repository
evidence.

Cloudflare Dynamic DNS may maintain the record, but the implementation must
decide and document whether it is DNS-only or proxied based on current
Cloudflare policy and validated streaming behavior. Do not assume the Cloudflare
proxy is an approved media-delivery path.

No direct router forwarding to Jellyfin is approved. Any external traffic must
terminate at the existing Nginx Proxy Manager entry point.

---

# Security Model

- Disable anonymous access.
- Create a dedicated administrator and separate daily-use accounts.
- Use strong unique passwords stored outside Git.
- Grant remote access per user only when required.
- Disable remote access for administrative-only accounts where practical.
- Restrict library access and ratings per user where applicable.
- Do not enable public share plugins, community repositories or external
  authentication plugins in the baseline.
- Protect logs because request URLs may contain API credentials.
- Keep source media read-only.
- Publish only through Nginx Proxy Manager with HTTPS.
- Preserve a local administrative recovery path before future identity work.
- Limit GPU access to the validated render device and required group only.

Identity integration is explicitly deferred to Sprint 010. Sprint 007 uses
Jellyfin local authentication and must not install a community OIDC plugin.

---

# Identity

Sprint 007 intentionally uses Jellyfin local authentication.

No OpenID Connect, OAuth2, SAML or third-party authentication plugin is part of
this Sprint. Identity Platform evaluation belongs exclusively to Sprint 010.

Future identity integration must preserve the current recovery boundary and
local administrative access. It must not make recovery of Jellyfin dependent
on the availability of an external identity service.

---

# Future Integration

Future platform capabilities may integrate with Jellyfin through documented
interfaces.

Potential future integrations include:

- Identity Platform;
- shared platform monitoring;
- backup automation;
- centralized logging.

These entries document compatibility direction only and approve no
implementation. Media acquisition services, download managers and community
plugins remain outside the current HomeLab07 roadmap.

---

# Backup And Recovery Boundary

A complete recoverable Jellyfin service includes:

- `/config` from a consistent point;
- the same pinned image definition;
- private path and publication configuration through its protected backup;
- the independently protected source-media libraries.

`/cache` is replaceable and is not required for service recovery. It may be
excluded from backup after recreation behavior is validated.

Recovery order:

1. Keep Jellyfin stopped.
2. Restore the same repository version and private configuration.
3. Restore `/config` with the expected UID/GID.
4. Reattach the same read-only media roots.
5. Start the pinned Jellyfin version.
6. Validate administrator access, users, libraries and metadata.
7. Validate direct play and one controlled transcode.
8. Confirm media files were not modified.
9. Upgrade only after the restored baseline is healthy.

The Sprint must perform a disposable configuration restore. Recreating a fresh
empty Jellyfin server is not sufficient recovery evidence.

Recovery success is defined as follows:

> A clean Jellyfin installation plus a restored configuration produces an
> equivalent media server without modifying the original media library.

Container recreation alone is not disaster recovery. It validates runtime
replaceability but does not prove that application state can be recovered after
loss of `/config`.

---

# Operation Layer Integration

The operation layer remains the public lifecycle interface.

Expected commands:

```bash
./operation/jellyfin-storage-check.sh
./operation/compose.sh jellyfin config
./operation/compose.sh jellyfin up -d
./operation/compose.sh jellyfin ps
./operation/compose.sh jellyfin logs --tail=150
```

`start.sh`, `stop.sh` and `status.sh` must include Jellyfin. Start Jellyfin
after Nginx Proxy Manager; stop it before Nginx Proxy Manager. The service has
no database or Valkey ordering dependency.

---

# Implementation Sequence

## Phase 1 — Target-Host Discovery

1. Confirm Linux host architecture and available CPU, memory and storage.
2. Confirm exact media-library roots and read permissions.
3. Identify expected client devices and their codec support.
4. Preserve the completed GPU capability evidence without private group IDs.
5. Revalidate the Jellyfin stable tag, security status and image digest.

## Phase 2 — Reproducible Baseline

1. Add placeholder-only private configuration example.
2. Add the storage validation helper.
3. Add the pinned official Jellyfin Compose definition.
4. Mount `/config` and `/cache` read-write and media libraries read-only.
5. Integrate lifecycle and status operations.
6. Validate static configuration and security boundaries.

## Phase 3 — Isolated Application Validation

1. Start Jellyfin without public DNS changes.
2. Create the administrator interactively.
3. Add synthetic media libraries without enabling media writes.
4. Validate scanning, metadata, direct play and software transcoding.
5. Measure resource and cache behavior.

## Phase 4 — Secure Publication

1. Create the private DNS record and Nginx Proxy Manager host.
2. Enable HTTPS and WebSockets.
3. Configure the exact Known Proxy boundary.
4. Validate real client addresses, range requests and seeking.
5. Validate local and approved remote clients.

## Phase 5 — Hardware Validation

1. Map only `/dev/dri/renderD128` with the required private render group.
2. Enable VA-API for H.264, MPEG-2 and VC-1 only.
3. Validate H.264 hardware decode and encode with synthetic media.
4. Confirm GPU activity through playback information and `intel_gpu_top`.
5. Compare VA-API quality, CPU use and power behavior with software fallback.
6. Disable acceleration if runtime evidence does not justify its complexity.

## Phase 6 — Persistence And Recovery

1. Recreate the container and confirm configuration persistence.
2. Confirm media files remain unchanged.
3. Back up `/config` from a consistent point.
4. Perform a disposable restore with the pinned image.
5. Record runtime evidence and close the Sprint.

---

# Validation Plan

## Static Validation

- Compose resolves with the example environment file.
- The image uses an exact stable tag and recorded target digest.
- No Jellyfin host ports are published.
- Only `homelab07-proxy` is joined initially.
- Media mounts are read-only.
- `/config` and `/cache` use dedicated paths.
- No Docker socket, privileged mode or broad device mount exists.
- No MariaDB or Valkey dependency exists.
- No private hostname, IP, media path, credential or personal metadata exists
  in Git.
- Operation scripts pass `bash -n`.

## Runtime Validation

- Storage ownership validation succeeds.
- Jellyfin becomes healthy and remains healthy after recreation.
- Initial setup and local administrator login succeed.
- Library scans complete without modifying source media.
- Metadata and users survive container recreation.
- Cache growth and cleanup behavior are recorded.
- Logs contain no repeated database, permission or playback failures.

## Playback Validation

- Direct play succeeds on at least one browser and one representative client.
- H.264/AAC playback, seeking and resume succeed.
- HEVC behavior is recorded as direct play or an expected transcode.
- Text subtitles display correctly.
- A subtitle burn-in transcode is tested under controlled load.
- Music browsing, metadata and audio playback succeed.
- Family-photo scanning, browsing, slideshow and representative home-video
  playback succeed without modifying the originals.
- One controlled concurrent-playback test records CPU, memory and cache use.
- Playback information identifies whether each test used direct play,
  remuxing, software transcoding or approved hardware acceleration.

## Network And Publication Validation

- HTTPS works through Nginx Proxy Manager.
- WebSockets remain connected.
- Seeking and HTTP range behavior work through the proxy.
- Jellyfin records the actual client address only from the Known Proxy.
- Direct host-port inspection returns no Jellyfin mapping.
- Local and remote user policies behave as configured.
- DNS and any Cloudflare proxy mode are explicitly recorded without storing the
  real hostname.

## Security Validation

- Anonymous access is unavailable.
- Administrator and daily-use accounts are separate.
- Media mounts reject container write attempts.
- No API key or credential appears in committed logs or configuration.
- The container runs without root, privileged mode or Docker socket access.
- Any GPU device access is limited to the documented target devices and groups.

## Recovery Validation

- A consistent `/config` backup is non-empty.
- `/cache` can be recreated without losing durable state.
- A disposable restore recovers users, libraries, watched state and settings.
- Restored clients can direct play synthetic media.
- Source media remains unchanged throughout recovery.

---

# Risks

| Risk | Impact | Mitigation | Exit evidence |
|---|---|---|---|
| Client codec mismatch causes transcoding | High CPU and failed playback | Direct-play matrix and controlled transcode tests | Playback method recorded per client |
| Software transcoding exhausts the host | Platform degradation | Conservative tests and hardware decision gate | CPU, memory and concurrency evidence |
| Writable library corrupts or changes media | Source-data loss | Read-only mounts and write-denial test | Container cannot modify media |
| Cache fills its filesystem | Playback or host failure | Dedicated path, capacity measurement and cleanup validation | Cache behavior recorded |
| Incorrect proxy trust hides client identity | Remote policy bypass | Exact Known Proxy entry and header validation | Actual client IP observed |
| WebSocket or range proxying fails | Broken clients or seeking | NPM validation with representative clients | Stable session and seek tests |
| API keys appear in proxy logs | Credential disclosure | Protect logs and avoid committed request paths | Secret scan passes |
| GPU mapping grants excessive access | Host security reduction | Hardware gate and scoped devices/groups | Container inspection |
| Metadata is mistaken for source media | Incomplete backup | Document `/config` as durable boundary | Disposable restore succeeds |
| Cloudflare proxy is unsuitable for streaming | Remote playback failure or policy conflict | Validate current policy; prefer DNS-only when required | Publication mode recorded |
| Image update changes the database schema | Failed rollback | Exact pins and pre-upgrade `/config` backup | Restore with previous version succeeds |
| DLNA requires host networking | Network boundary expansion | Exclude from baseline | No host network mode |

---

# Acceptance Criteria

Sprint 007 is complete when:

- Jellyfin is reproducibly deployed through the operation layer;
- the official stable image is pinned and its target digest recorded;
- `/config`, `/cache` and read-only media boundaries are validated;
- MariaDB and Valkey remain application-agnostic and unused by Jellyfin;
- at least one browser and one representative client complete playback;
- music and family-photo libraries are validated through their dedicated
  read-only mounts;
- direct play, seeking, subtitles and controlled transcoding are validated;
- resource and cache behavior are documented;
- HTTPS, WebSockets and trusted proxy behavior work through Nginx Proxy
  Manager without a direct application host port;
- local and approved remote access policies are validated;
- the container cannot modify source media;
- state survives recreation;
- a disposable `/config` restore recovers users, libraries and settings;
- VA-API H.264 acceleration is validated with only the scoped render device,
  or disabled if playback evidence does not justify it;
- DLNA and other non-goals remain excluded;
- service documentation satisfies the repository README standard;
- no private value, credential, personal metadata or copyrighted test asset
  enters Git.

---

# Explicit Non-Goals

- Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, Overseerr or download clients.
- Automatic acquisition, renaming or deletion of media.
- Writable media libraries or sidecar metadata.
- DLNA and host networking.
- Live TV, tuners and DVR.
- IPTV configuration.
- Plugins, custom repositories or themes.
- Authentik, OIDC or SSO integration.
- Public sharing or anonymous access.
- Mobile sync or offline-download workflow design.
- Automated backup scheduling.
- Monitoring or alerting.
- High availability or multiple Jellyfin nodes.
- Changing the shared MariaDB or Valkey platforms.

---

# Engineering Principles

Sprint 007 introduces no new platform capability. Its objective is to validate
that a business-facing application can consume existing platform services
without increasing infrastructure complexity.

Operational simplicity takes precedence over feature count. The NAS remains
the permanent storage platform. Applications remain replaceable consumers of
shared platform capabilities.

The implementation must reinforce reusable operations, explicit ownership and
recoverability rather than introduce application-specific infrastructure.

---

# Completion Notes

This section will be completed after implementation. It must summarize:

- successful deployment;
- playback validation;
- HTTPS validation;
- direct play validation;
- hardware acceleration validation, if retained after runtime evidence;
- recovery validation;
- container recreation validation;
- confirmation that source media remained unchanged.

Completion notes must record results without including private paths, domains,
credentials, personal metadata or copyrighted test assets.

---

# Required Research Before Implementation

1. Revalidate the latest stable Jellyfin release and security notices.
2. Record the official image digest for the target architecture.
3. Confirm the official image UID/GID, health endpoint and file ownership
   behavior for the pinned release.
4. Confirm the private numeric render-group mapping without committing it.
5. Inventory representative clients and codec support.
6. Confirm private library paths, filesystem type and read-only bind behavior.
7. Measure available capacity for `/config`, `/cache` and transcoding.
8. Confirm exact Nginx Proxy Manager address/CIDR for Known Proxies.
9. Revalidate current Cloudflare policy and proxy behavior for the intended
   streaming model.
10. Select legally usable synthetic media for validation without committing it.

---

# Related Requirements

| Requirement | Contribution |
|---|---|
| FR-001 Service Deployment | Independent Jellyfin service |
| FR-002 Persistent Storage | Separate durable state, cache and media boundaries |
| FR-003 Infrastructure Configuration | Version-controlled Compose and operations |
| FR-004 HTTPS | Publication through Nginx Proxy Manager |
| FR-006 Service Isolation | No unnecessary database or broker dependency |
| FR-007 Configuration Management | Placeholder-only example and private values |
| FR-008 Recovery | Pinned version and disposable configuration restore |
| FR-009 Documentation | Service and operational procedures required |
| NFR-001 Reproducibility | Exact image and declarative deployment |
| NFR-002 Maintainability | One official container and limited scope |
| NFR-003 Reliability | Playback, recreation and resource validation |
| NFR-005 Security | Read-only media and proxy-only publication |
| NFR-006 Modularity | Media service remains independent |
| NFR-007 Observability | Health, logs and playback-method evidence |
| NFR-010 Recoverability | Durable `/config` boundary and restore test |

---

# Official Sources

- [Jellyfin official container installation](https://jellyfin.org/docs/general/installation/container/)
- [Jellyfin releases](https://github.com/jellyfin/jellyfin/releases)
- [Jellyfin networking](https://jellyfin.org/docs/general/post-install/networking/)
- [Jellyfin reverse proxy requirements](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/)
- [Jellyfin Nginx reverse proxy](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/nginx/)
- [Jellyfin hardware acceleration](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/)
- [Jellyfin hardware acceleration known issues](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/known-issues/)

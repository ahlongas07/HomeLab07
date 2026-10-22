# Jellyfin Implementation Notes

Record target-host evidence here during Sprint 007. Do not record real domains,
paths, credentials, personal metadata or copyrighted media.

## Required Evidence

- Runtime digest for `jellyfin/jellyfin:10.11.11` on the target architecture.
- Non-root UID/GID ownership for `/config` and `/cache`.
- Read-only media mounts and rejected container write attempts.
- Browser and representative-client direct play.
- Music browsing, metadata and audio playback.
- Family-photo browsing, slideshow and representative home-video playback
  without changes to originals.
- Seeking, resume, WebSockets and HTTP range behavior through the proxy.
- Controlled software transcoding and cache growth.
- VA-API H.264 decode and encode activity.
- Container recreation and disposable `/config` restore.
- Confirmation that source media remains unchanged.

## Image Verification

The stable release was revalidated at implementation entry on 2026-07-23.
`10.11.11` supersedes the planning candidate and is the pinned official
`jellyfin/jellyfin` image. The deployed target reported this repository digest:

```text
jellyfin/jellyfin@sha256:aefb67e6a7ff1debdd154a78a7bbb780fd0c873d8639210a7f6a2016ad2b35db
```

The digest was collected from the target-host image rather than copied from a
release page or another architecture.

## Security Upgrade 10.11.11 → 12.2

Approved on 2026-10-22 as a version update only. The pre-upgrade recovery point
is the platform backup taken earlier the same day.

| | Previous | Target |
|---|---|---|
| Tag | `jellyfin/jellyfin:10.11.11` | `jellyfin/jellyfin:12.2` (same image as `12` and `latest`) |
| Index digest | `sha256:aefb67e6a7ff1debdd154a78a7bbb780fd0c873d8639210a7f6a2016ad2b35db` | `sha256:357724bf0ae27a672c7cbaa899db2d9abeb13dbd8657ccce750258a4c059d037` |
| amd64 manifest | recorded from the target in the Image Verification section | `sha256:da3cd1e48322a35e4b60f3d0a49fca2649e7acce90346dd6e42db777f94e3bbd` |
| arm64 manifest | — | `sha256:c2544f368e2e6c317832caebe96c375f5161b8ab73e2a041f6cf4af519d58805` |
| Upstream release | 2026-06-06, last 10.11 release | 2026-10-05, latest stable |
| Runtime | .NET 9, jellyfin-ffmpeg 7.1 | .NET 10, jellyfin-ffmpeg 8.1 |

Digests were read from Docker Hub on 2026-10-22.

Why a major upgrade: the 10.11 branch has had no release since June, and six
upstream advisories published on 2026-09-22 affect every version before 12.0
and are fixed only in 12.0: GHSA-6828-c7cx-hvqm (critical; anonymous only
before the setup wizard is completed, administrator-only afterwards),
GHSA-cf3c-8m59-2vhx (high; SSRF and memory exhaustion through SVG images, any
authenticated user), GHSA-4vx8-xhc9-qg6x and GHSA-9x85-gx46-6522 (medium;
session remote control and private playlists of other users) and
GHSA-hw73-62vp-9gxf and GHSA-c39p-cgf8-866g (path handling hardening).

Compatibility reviewed against the 12.0 release notes:

- Direct upgrade from 10.11.x is supported; the database migration cannot be
  rolled back without restoring `/config`.
- No repository plugins are installed, so the plugin removal step does not
  apply.
- Legacy `/emby` and `/mediabrowser` routes and legacy authorization are
  removed; the project owner confirmed no legacy third-party client is used.
- A full scan of all libraries is required after the upgrade to restore
  automatically merged alternative versions.
- VA-API on the Sandy Bridge GPU was tested before the upgrade in disposable
  containers without Jellyfin state: the 12.2 image still bundles the `i965`
  driver, and an H.264 `h264_vaapi` test encode succeeded, as with 10.11.11.

Known residual risk in 12.2: the bundled ASP.NET Core and .NET runtime 10.0.12
has fixes available in 10.0.13 that only a future Jellyfin release can ship,
and `libxml2` has no published fix. Re-evaluate at the next release.

Target result (2026-10-22, upgrade at 20:23 UTC, about ten seconds of
downtime). Detailed evidence remains in the private evidence location.

- [x] Runtime `jellyfin/jellyfin:12.2@sha256:357724bf…`, healthy, no restarts;
      all 23 database migrations applied, no error in the logs.
- [x] The three libraries and the VA-API settings unchanged; the `i965`
      driver loads in the running container; media mounts read-only; no host
      port.
- [x] Setup wizard and library management endpoints return `401` without
      credentials, locally and through Cloudflare. The anonymous public system
      information now reports the wizard as not completed and omits the
      version for remote callers; the stored setting remains completed.
- [x] Web interface answers through the published route; NPM access audit
      passes.
- [x] Security scan compared with the last 10.11.11 run on the private share:
      no new finding. Accepted; the remaining .NET runtime findings wait for a
      Jellyfin release with .NET 10.0.13.
- [ ] Owner checks: full scan of all libraries, users and playback history,
      direct play and one VA-API transcode through the published route.

## Hardware Discovery

Target-host discovery completed on 2026-07-23 with the official Jellyfin
`10.11.10` image. Repeat `vainfo` and playback validation with the final
`10.11.11` pin before accepting acceleration.

- Intel Sandy Bridge Gen6 integrated graphics is available through `i915`.
- The scoped render device is `/dev/dri/renderD128`.
- VA-API 1.23 initializes through the legacy Intel `i965` driver.
- H.264 decode and encode are supported.
- MPEG-2 and VC-1 decode are supported.
- HEVC, VP9, AV1, HDR tone mapping and Intel low-power encoding are not
  supported.

The modern `iHD` driver failing before successful `i965` fallback is expected
for this pre-Broadwell platform. Jellyfin must use VA-API, not QSV, and enable
only the validated profiles.

## Hardware Playback Evidence

Target-host playback validation on 2026-07-23 confirmed active Sandy Bridge
acceleration. During a controlled transcode, `intel_gpu_top` reported sustained
activity of approximately 58% on the Video engine and 65% on Render/3D. The
device operated at its reported maximum clock during the sample. This confirms
that Jellyfin reached the scoped render device and used the GPU for actual
media processing rather than merely completing VA-API capability discovery.

Media-library scanning also emitted MP3 duration-estimation and unknown-stream
warnings. These are source-container metadata warnings and are not evidence of
a VA-API failure. Representative audio playback was accepted with those
warnings present.

## Decision Gates

- Prefer direct play; acceleration is used only when clients require it.
- Disable VA-API if runtime evidence does not reduce CPU use with acceptable
  quality and stability.
- Do not add `card0`, all of `/dev/dri`, privileged mode or host networking.
- Do not make media mounts writable.
- Do not add plugins, download managers, databases or broker services.

## Target-Host Acceptance

Target-host acceptance completed on 2026-07-23.

- The pinned image deployed successfully and remained healthy.
- Dedicated movie, music and family-media libraries indexed from read-only
  storage boundaries.
- HTTPS navigation and representative playback succeeded through the shared
  reverse proxy.
- Controlled H.264 transcoding activated the Video and Render/3D engines.
- Application state survived container recreation.
- A stopped-state `/config` backup was restored into a clean directory and
  recovered the existing Jellyfin configuration and libraries.
- Source media remained unchanged and independently recoverable.

Sprint 007 acceptance retains VA-API because the measured result justifies the
scoped render-device access. Modern unsupported codecs, writable media,
plugins, external identity and additional platform services remain excluded.

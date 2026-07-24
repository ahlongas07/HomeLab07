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

# Jellyfin Implementation Notes

Record target-host evidence here during Sprint 007. Do not record real domains,
paths, credentials, personal metadata or copyrighted media.

## Required Evidence

- Runtime digest for `jellyfin/jellyfin:10.11.11` on the target architecture.
- Non-root UID/GID ownership for `/config` and `/cache`.
- Read-only media mounts and rejected container write attempts.
- Browser and representative-client direct play.
- Seeking, resume, WebSockets and HTTP range behavior through the proxy.
- Controlled software transcoding and cache growth.
- VA-API H.264 decode and encode activity.
- Container recreation and disposable `/config` restore.
- Confirmation that source media remains unchanged.

## Image Verification

The stable release was revalidated at implementation entry on 2026-07-23.
`10.11.11` supersedes the planning candidate and is the pinned official
`jellyfin/jellyfin` image. Record the target-host runtime digest immediately
before deployment. Do not substitute a manifest-list digest or a digest from
another architecture for runtime identity evidence.

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

## Decision Gates

- Prefer direct play; acceleration is used only when clients require it.
- Disable VA-API if runtime evidence does not reduce CPU use with acceptable
  quality and stability.
- Do not add `card0`, all of `/dev/dri`, privileged mode or host networking.
- Do not make media mounts writable.
- Do not add plugins, download managers, databases or broker services.

## Target-Host Acceptance

Complete this section after runtime validation. Record only sanitized evidence
for deployment, playback, publication, acceleration, persistence, recovery and
unchanged source media.

# Jellyfin

## Purpose

Jellyfin provides media indexing, metadata, playback and controlled
transcoding as the Sprint 007 business service.

## Responsibilities

- Index approved NAS-backed movie, music and family-photo libraries.
- Provide browser and client playback.
- Preserve users, metadata, settings and playback history under `/config`.
- Use `/cache` for replaceable cache and transcode workspace.
- Consume HTTPS publication from Nginx Proxy Manager.

Jellyfin does not own source media, TLS, DNS, identity, backup automation or
the platform lifecycle.

## Technology

| Capability | Selection |
|---|---|
| Application | `jellyfin/jellyfin:10.11.11` |
| Application state | Dedicated NAS-backed `/config` |
| Cache/transcodes | Dedicated replaceable `/cache` |
| Media | Rockstor bind mounts, read-only |
| Publication | Nginx Proxy Manager and Cloudflare Dynamic DNS |
| Authentication | Jellyfin local users |
| Acceleration | Intel VA-API through scoped `renderD128` access |

Record the target-architecture runtime digest before publication.

## Directory Structure

```text
services/jellyfin/
├── .env.example
├── IMPLEMENTATION_NOTES.md
├── README.md
└── compose.yaml
```

Private persistent state:

```text
${JELLYFIN_ROOT}/
├── config/
└── cache/
```

Private media roots are mounted independently at `/media/movies`,
`/media/music` and `/media/photos`. They remain separate from Jellyfin state
and are read-only to the container.

Jellyfin catalogs, presents and shares the photo library. It does not ingest
phone photos, manage the authoritative originals or replace the NAS backup.

## Configuration

```bash
cp services/jellyfin/.env.example \
  ../HomeLab07.private/env/jellyfin.env
```

Replace every placeholder privately. Determine the render-group ID on the
target host with:

```bash
getent group render
```

Use the numeric group ID as `JELLYFIN_RENDER_GID`. Keep the public URL, host
paths, UID/GID values and real library layout outside Git.

## Deployment

Create the state directories and approved media roots on the target storage.
Assign `/config` and `/cache` to the configured Jellyfin UID/GID; do not use
`chmod 777`.

Then run:

```bash
./operation/jellyfin-storage-check.sh
./operation/compose.sh jellyfin config
./operation/compose.sh jellyfin pull
./operation/compose.sh jellyfin up -d
```

Complete initial setup interactively through HTTPS. Create a dedicated
administrator and a separate daily-use account. Credentials must not enter Git
or Compose environment files.

Create dedicated Jellyfin libraries using the matching `Movies`, `Music` and
`Photos` content types. The `Photos` library also presents family videos kept
inside the same directory tree. Point each library only at its corresponding
`/media/...` mount; do not create an unused `Shows` library.

## Validation

```bash
./operation/compose.sh jellyfin ps
./operation/compose.sh jellyfin logs --tail=150
docker port homelab07-jellyfin
docker inspect homelab07-jellyfin \
  --format '{{range .Mounts}}{{println .Destination .RW}}{{end}}'
docker exec homelab07-jellyfin \
  /usr/lib/jellyfin-ffmpeg/vainfo --display drm \
  --device /dev/dri/renderD128
```

`docker port` must return no mapping. Media destinations must report `false`
for write access. Validate with synthetic or legally usable media:

1. Direct play from one browser and one representative client.
2. Seeking, resume and text subtitles.
3. One controlled subtitle burn-in transcode.
4. H.264 VA-API decode and encode while observing `intel_gpu_top`.
5. Expected software fallback for unsupported codecs.
6. Music browsing, metadata and audio playback.
7. Family-photo scan, browsing, slideshow and representative home-video
   playback without modifying originals.
8. Container recreation without loss of users, settings or playback history.
9. A disposable `/config` restore without modifying source media.

## Reverse Proxy

Create the Proxy Host using private values:

| Setting | Value |
|---|---|
| Scheme | `http` |
| Forward hostname | `homelab07-jellyfin` |
| Forward port | `8096` |
| WebSocket support | enabled |
| Cache assets | disabled |
| Force SSL | enabled after certificate validation |
| Public URL | same value as private `JELLYFIN_PUBLISHED_URL` |

Configure the actual Nginx Proxy Manager address or exact approved proxy CIDR
as a Known Proxy in Jellyfin. Protect proxy logs because Jellyfin can place API
keys in request URLs. Do not publish port `8096` or enable host networking.

## Hardware Acceleration

In the Jellyfin dashboard select VA-API and device:

```text
/dev/dri/renderD128
```

Enable only:

- H.264 decode and encode;
- MPEG-2 decode;
- VC-1 decode.

Disable HEVC, VP9, AV1, HDR tone mapping, Intel low-power encoding and QSV.
Direct play remains preferred. Preserve the hardware setting only after
playback information and `intel_gpu_top` prove acceptable operation.

## Backup

A complete Jellyfin recovery point includes:

- a consistent backup of `/config`;
- the pinned repository definition and image identity;
- protected private configuration;
- independently protected source-media libraries.

`/cache` is replaceable and may be excluded after recreation validation.
Container recreation is not disaster recovery.

## Restore

1. Keep Jellyfin stopped.
2. Restore the matching repository and private configuration.
3. Restore `/config` with the expected UID/GID.
4. Reattach the same read-only media roots.
5. Start the pinned Jellyfin version.
6. Validate users, libraries, metadata, direct play and one transcode.
7. Confirm source media remains unchanged.

Recovery succeeds when a clean Jellyfin installation plus restored
configuration produces an equivalent server without modifying the original
media library.

## Security

- Source media is mounted read-only.
- The container runs as a configured non-root UID/GID.
- Only `/dev/dri/renderD128` is mapped for acceleration.
- No host ports, Docker socket, privileged mode or host networking are used.
- Anonymous access, plugins and external authentication are excluded.
- Administrator and daily-use accounts remain separate.
- Real endpoints and environment-specific values remain private.

## Related Sprint

See `sprints/SPRINT-007.md`.

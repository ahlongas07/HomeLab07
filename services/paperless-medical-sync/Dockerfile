# HomeLab07 medical exam sync (Sprint 015).
# Base image and qpdf are pinned; update them deliberately and rescan the image.
FROM python:3.13-alpine3.24@sha256:2d9aefe2fef018a7eb2c13064c89c71929800fd2e5dccdbf52ea5da5bb8d929a

# tzdata follows the pinned Alpine branch so TZ matches PAPERLESS_TIME_ZONE.
# hadolint ignore=DL3018
RUN apk add --no-cache qpdf=12.3.2-r0 tzdata

COPY --chmod=0755 medical_sync.py /usr/local/bin/medical-sync
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# The runtime UID/GID come from Compose so they can read the source folder.
USER 65534:65534

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Jellyfin Storage Check"
print_project_root

readonly JELLYFIN_ENV="${PRIVATE_ROOT}/env/jellyfin.env"

[[ -f "${JELLYFIN_ENV}" ]] || {
    echo "Missing required private environment file:"
    echo "  ${JELLYFIN_ENV}"
    exit 1
}

env_value() {
    local name="$1"

    awk -F= -v name="${name}" \
        '$1 == name { print substr($0, index($0, "=") + 1); exit }' \
        "${JELLYFIN_ENV}"
}

JELLYFIN_ROOT="$(env_value JELLYFIN_ROOT)"
JELLYFIN_UID="$(env_value JELLYFIN_UID)"
JELLYFIN_GID="$(env_value JELLYFIN_GID)"
JELLYFIN_RENDER_GID="$(env_value JELLYFIN_RENDER_GID)"
MEDIA_MOVIES_ROOT="$(env_value MEDIA_MOVIES_ROOT)"
MEDIA_SERIES_ROOT="$(env_value MEDIA_SERIES_ROOT)"

for variable in \
    JELLYFIN_ROOT \
    JELLYFIN_UID \
    JELLYFIN_GID \
    JELLYFIN_RENDER_GID \
    MEDIA_MOVIES_ROOT \
    MEDIA_SERIES_ROOT; do
    [[ -n "${!variable}" ]] || {
        echo "Missing required value: ${variable}"
        exit 1
    }
done

for variable in JELLYFIN_UID JELLYFIN_GID JELLYFIN_RENDER_GID; do
    [[ "${!variable}" =~ ^[0-9]+$ ]] || {
        echo "${variable} must be a numeric ID."
        exit 1
    }
done

for variable in JELLYFIN_ROOT MEDIA_MOVIES_ROOT MEDIA_SERIES_ROOT; do
    path="${!variable}"
    [[ "${path}" == /* ]] || { echo "${variable} must be an absolute path."; exit 1; }
    [[ "${path}" != "/" ]] || { echo "${variable} must not be the filesystem root."; exit 1; }
    [[ -d "${path}" ]] || { echo "Missing required directory: ${path}"; exit 1; }
done

[[ "${JELLYFIN_ROOT}" != "${PROJECT_ROOT}" ]] || {
    echo "JELLYFIN_ROOT must not be the repository root."
    exit 1
}

[[ "${MEDIA_MOVIES_ROOT}" != "${MEDIA_SERIES_ROOT}" ]] || {
    echo "Movie and series roots must be different directories."
    exit 1
}

for media_root in "${MEDIA_MOVIES_ROOT}" "${MEDIA_SERIES_ROOT}"; do
    case "${media_root}/" in
        "${JELLYFIN_ROOT}/"*)
            echo "Media roots must remain outside JELLYFIN_ROOT: ${media_root}"
            exit 1
            ;;
    esac
done

for directory in config cache; do
    path="${JELLYFIN_ROOT}/${directory}"
    [[ -d "${path}" ]] || { echo "Missing required directory: ${path}"; exit 1; }

    owner="$(stat -c '%u:%g' "${path}")"
    [[ "${owner}" == "${JELLYFIN_UID}:${JELLYFIN_GID}" ]] || {
        echo "Unexpected ownership for ${path}: ${owner}"
        echo "Expected: ${JELLYFIN_UID}:${JELLYFIN_GID}"
        exit 1
    }
done

readonly RENDER_DEVICE="/dev/dri/renderD128"

[[ -c "${RENDER_DEVICE}" ]] || {
    echo "Missing required render device: ${RENDER_DEVICE}"
    exit 1
}

device_gid="$(stat -c '%g' "${RENDER_DEVICE}")"
[[ "${device_gid}" == "${JELLYFIN_RENDER_GID}" ]] || {
    echo "Unexpected render-device group: ${device_gid}"
    echo "Expected JELLYFIN_RENDER_GID: ${JELLYFIN_RENDER_GID}"
    exit 1
}

echo "State ownership and permissions:"
ls -ldn \
    "${JELLYFIN_ROOT}" \
    "${JELLYFIN_ROOT}/config" \
    "${JELLYFIN_ROOT}/cache"

echo
echo "Read-only media sources (enforced by Compose mounts):"
ls -ldn "${MEDIA_MOVIES_ROOT}" "${MEDIA_SERIES_ROOT}"

echo
echo "Scoped render device:"
ls -ln "${RENDER_DEVICE}"

print_footer

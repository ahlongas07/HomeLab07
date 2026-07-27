#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Homebridge Storage Check"
print_project_root

readonly HOMEBRIDGE_ENV="${PRIVATE_ROOT}/env/homebridge.env"
readonly HOMEBRIDGE_CONTAINER="homelab07-homebridge"
readonly HOMEBRIDGE_ENV_EXAMPLE="${PROJECT_ROOT}/services/homebridge/.env.example"

grep -Fxq \
    'HOMEBRIDGE_IMAGE=homebridge/homebridge@sha256:replace-with-target-architecture-digest' \
    "${HOMEBRIDGE_ENV_EXAMPLE}" || {
    echo "The image example must retain its non-functional digest placeholder."
    exit 1
}

grep -Fxq \
    'HOMEBRIDGE_DATA_ROOT=/path/to/homelab07-homebridge' \
    "${HOMEBRIDGE_ENV_EXAMPLE}" || {
    echo "The storage example must retain its non-functional path placeholder."
    exit 1
}

grep -Fxq \
    'HOMEBRIDGE_UI_PORT=replace-with-homebridge-ui-port' \
    "${HOMEBRIDGE_ENV_EXAMPLE}" || {
    echo "The UI port example must retain its non-functional placeholder."
    exit 1
}

[[ -f "${HOMEBRIDGE_ENV}" ]] || {
    echo "Missing required private environment file:"
    echo "  ${HOMEBRIDGE_ENV}"
    exit 1
}

env_value() {
    local name="$1"

    awk -F= -v name="${name}" \
        '$1 == name { print substr($0, index($0, "=") + 1); exit }' \
        "${HOMEBRIDGE_ENV}"
}

HOMEBRIDGE_IMAGE="$(env_value HOMEBRIDGE_IMAGE)"
HOMEBRIDGE_DATA_ROOT="$(env_value HOMEBRIDGE_DATA_ROOT)"
HOMEBRIDGE_UI_PORT="$(env_value HOMEBRIDGE_UI_PORT)"

for variable in HOMEBRIDGE_IMAGE HOMEBRIDGE_DATA_ROOT HOMEBRIDGE_UI_PORT; do
    [[ -n "${!variable}" ]] || {
        echo "Missing required value: ${variable}"
        exit 1
    }
done

[[ "${HOMEBRIDGE_IMAGE}" =~ ^homebridge/homebridge@sha256:[a-f0-9]{64}$ ]] || {
    echo "HOMEBRIDGE_IMAGE must use the official repository and a sha256 digest."
    echo "Mutable tags and placeholder digests are not accepted."
    exit 1
}

[[ "${HOMEBRIDGE_UI_PORT}" =~ ^[0-9]+$ ]] || {
    echo "HOMEBRIDGE_UI_PORT must be numeric."
    exit 1
}

((HOMEBRIDGE_UI_PORT >= 1 && HOMEBRIDGE_UI_PORT <= 65535)) || {
    echo "HOMEBRIDGE_UI_PORT must be between 1 and 65535."
    exit 1
}

[[ "${HOMEBRIDGE_DATA_ROOT}" == /* ]] || {
    echo "HOMEBRIDGE_DATA_ROOT must be an absolute path."
    exit 1
}

case "${HOMEBRIDGE_DATA_ROOT}" in
    /|/home|/mnt|/srv|/var|/var/lib)
        echo "HOMEBRIDGE_DATA_ROOT is too broad: ${HOMEBRIDGE_DATA_ROOT}"
        exit 1
        ;;
esac

[[ "${HOMEBRIDGE_DATA_ROOT}" != "${PROJECT_ROOT}" ]] || {
    echo "HOMEBRIDGE_DATA_ROOT must not be the repository root."
    exit 1
}

[[ -d "${HOMEBRIDGE_DATA_ROOT}" ]] || {
    echo "Missing required directory: ${HOMEBRIDGE_DATA_ROOT}"
    exit 1
}

resolved_root="$(realpath -e "${HOMEBRIDGE_DATA_ROOT}")"
[[ "${resolved_root}" == "${HOMEBRIDGE_DATA_ROOT}" ]] || {
    echo "HOMEBRIDGE_DATA_ROOT must be the canonical path: ${resolved_root}"
    exit 1
}

for state_path in config.json persist accessories; do
    path="${HOMEBRIDGE_DATA_ROOT}/${state_path}"
    [[ -e "${path}" ]] || {
        echo "Missing critical Homebridge state: ${path}"
        exit 1
    }

    resolved_path="$(realpath -e "${path}")"
    case "${resolved_path}" in
        "${resolved_root}"|"${resolved_root}"/*) ;;
        *)
            echo "Critical state escapes HOMEBRIDGE_DATA_ROOT: ${path}"
            exit 1
            ;;
    esac
done

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    docker image inspect "${HOMEBRIDGE_IMAGE}" >/dev/null 2>&1 || {
        echo "The approved Homebridge image is not available locally:"
        echo "  ${HOMEBRIDGE_IMAGE}"
        echo "Pull the immutable reference before running this check."
        exit 1
    }

    conflicting_containers=()
    while IFS= read -r container_id; do
        [[ -n "${container_id}" ]] || continue

        container_name="$(docker inspect --format '{{.Name}}' "${container_id}")"
        container_name="${container_name#/}"
        [[ "${container_name}" == "${HOMEBRIDGE_CONTAINER}" ]] && continue

        while IFS= read -r mount_source; do
            [[ -n "${mount_source}" ]] || continue
            mount_source="$(realpath -m "${mount_source}")"
            if [[ \
                "${mount_source}" == "${resolved_root}" || \
                "${mount_source}" == "${resolved_root}"/* || \
                "${resolved_root}" == "${mount_source}"/* \
            ]]; then
                conflicting_containers+=("${container_name}")
            fi
        done < <(docker inspect \
            --format '{{range .Mounts}}{{println .Source}}{{end}}' \
            "${container_id}")
    done < <(docker ps -q)

    if ((${#conflicting_containers[@]} > 0)); then
        echo "Another container uses the Homebridge persistent root:"
        printf '  %s\n' "${conflicting_containers[@]}" | sort -u
        exit 1
    fi

    docker run --rm \
        --network none \
        --entrypoint /usr/bin/test \
        --volume "${resolved_root}:/homebridge" \
        "${HOMEBRIDGE_IMAGE}" \
        -w /homebridge || {
        echo "/homebridge is not writable by the image's effective runtime user."
        echo "Review ownership and permissions; do not use chmod 777."
        exit 1
    }
else
    echo "Docker daemon unavailable; container mount-conflict validation skipped."
    echo "Run this check again on the target host before cutover."
fi

echo "Validated Homebridge state boundary:"
ls -ldn \
    "${HOMEBRIDGE_DATA_ROOT}" \
    "${HOMEBRIDGE_DATA_ROOT}/config.json" \
    "${HOMEBRIDGE_DATA_ROOT}/persist" \
    "${HOMEBRIDGE_DATA_ROOT}/accessories"

echo
echo "The configured image uses an official immutable sha256 reference."

print_footer

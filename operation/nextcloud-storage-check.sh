#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Nextcloud Storage Check"
print_project_root

readonly NEXTCLOUD_ENV="${PRIVATE_ROOT}/env/nextcloud.env"

read_env_value() {
    local file="$1"
    local key="$2"
    awk -v key="${key}" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "${file}"
}

[[ -f "${NEXTCLOUD_ENV}" ]] || {
    echo "Missing required private environment file:"
    echo "  ${NEXTCLOUD_ENV}"
    exit 1
}

NEXTCLOUD_ROOT="$(read_env_value "${NEXTCLOUD_ENV}" "NEXTCLOUD_ROOT")"

[[ -n "${NEXTCLOUD_ROOT}" ]] || { echo "Missing required value: NEXTCLOUD_ROOT"; exit 1; }
[[ "${NEXTCLOUD_ROOT}" == /* ]] || {
    echo "NEXTCLOUD_ROOT must be an absolute path:"
    echo "  ${NEXTCLOUD_ROOT}"
    exit 1
}

echo "Nextcloud root:"
echo "  ${NEXTCLOUD_ROOT}"
echo

if [[ ! -d "${NEXTCLOUD_ROOT}" ]]; then
    echo "The dedicated Nextcloud root does not exist."
    exit 1
fi

for directory in html data; do
    path="${NEXTCLOUD_ROOT}/${directory}"
    if [[ ! -d "${path}" ]]; then
        echo "Missing required directory:"
        echo "  ${path}"
        exit 1
    fi
done

echo "Host path ownership and permissions:"
ls -ldn "${NEXTCLOUD_ROOT}" "${NEXTCLOUD_ROOT}/html" "${NEXTCLOUD_ROOT}/data"
echo

echo "Current top-level layout:"
find "${NEXTCLOUD_ROOT}" -maxdepth 2 -print
echo

if [[ -f "${NEXTCLOUD_ROOT}/data/.ocdata" ]]; then
    echo "Nextcloud data marker found:"
    echo "  ${NEXTCLOUD_ROOT}/data/.ocdata"
else
    echo "Nextcloud data marker not found yet (expected before initialization):"
    echo "  ${NEXTCLOUD_ROOT}/data/.ocdata"
fi

print_footer

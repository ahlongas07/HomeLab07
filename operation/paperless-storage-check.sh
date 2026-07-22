#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Paperless-ngx Storage Check"
print_project_root

readonly PAPERLESS_ENV="${PRIVATE_ROOT}/env/paperless-ngx.env"

[[ -f "${PAPERLESS_ENV}" ]] || {
    echo "Missing required private environment file:"
    echo "  ${PAPERLESS_ENV}"
    exit 1
}

PAPERLESS_ROOT="$(awk -F= '$1 == "PAPERLESS_ROOT" { print substr($0, index($0, "=") + 1); exit }' "${PAPERLESS_ENV}")"

[[ -n "${PAPERLESS_ROOT}" ]] || { echo "Missing required value: PAPERLESS_ROOT"; exit 1; }
[[ "${PAPERLESS_ROOT}" == /* ]] || { echo "PAPERLESS_ROOT must be an absolute path."; exit 1; }
[[ "${PAPERLESS_ROOT}" != "/" ]] || { echo "PAPERLESS_ROOT must not be the filesystem root."; exit 1; }
[[ -d "${PAPERLESS_ROOT}" ]] || { echo "Paperless-ngx root does not exist: ${PAPERLESS_ROOT}"; exit 1; }

for directory in data media media/trash consume export; do
    path="${PAPERLESS_ROOT}/${directory}"
    [[ -d "${path}" ]] || { echo "Missing required directory: ${path}"; exit 1; }
done

echo "Host path ownership and permissions:"
ls -ldn \
    "${PAPERLESS_ROOT}" \
    "${PAPERLESS_ROOT}/data" \
    "${PAPERLESS_ROOT}/media" \
    "${PAPERLESS_ROOT}/media/trash" \
    "${PAPERLESS_ROOT}/consume" \
    "${PAPERLESS_ROOT}/export"

print_footer

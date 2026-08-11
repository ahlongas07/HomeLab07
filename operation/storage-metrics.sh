#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"
source "${BASH_SOURCE%/*}/observability-metrics-lib.sh"

print_header "Rockstor Storage Metrics"
print_project_root

started_epoch="$(date +%s)"

if ! observability_load_metrics_environment; then
    echo "Observability metrics environment is unavailable or insecure."
    exit 1
fi

: "${HOMELAB07_STORAGE_INVENTORY_FILE:?HOMELAB07_STORAGE_INVENTORY_FILE is required}"

if [[ ! -s "${HOMELAB07_STORAGE_INVENTORY_FILE}" ]]; then
    echo "Private storage inventory is missing or empty."
    exit 1
fi

for command_name in findmnt df awk mktemp mv; do
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        echo "Required storage metric command is unavailable: ${command_name}"
        exit 1
    fi
done

metric_root="${HOMELAB07_OBSERVABILITY_METRICS_ROOT}"
final_file="${metric_root}/rockstor.prom"
temporary="$(mktemp "${metric_root}/.rockstor.prom.XXXXXX")"
chmod 0600 "${temporary}" 2>/dev/null || true
failure_count=0
storage_count=0

cleanup_storage_metric() {
    local exit_status=$?
    local failed_file failed_now failed_success

    trap - EXIT INT TERM
    rm -f -- "${temporary:-}"

    if ((exit_status != 0)); then
        failed_now="$(date +%s)"
        failed_success="$(observability_previous_metric \
            "${final_file}" homelab07_rockstor_last_success_timestamp_seconds)"
        [[ "${failed_success}" =~ ^[0-9]+$ ]] || failed_success=0
        failed_file="$(mktemp "${metric_root}/.rockstor-failure.prom.XXXXXX" 2>/dev/null || true)"

        if [[ -n "${failed_file}" ]]; then
            chmod 0600 "${failed_file}" 2>/dev/null || true
            if [[ -f "${final_file}" ]]; then
                awk '
                    !/^# (HELP|TYPE) homelab07_rockstor_last_/ &&
                    !/^homelab07_rockstor_last_/
                ' "${final_file}" >"${failed_file}"
            fi
            {
                echo '# HELP homelab07_rockstor_last_run_timestamp_seconds Unix time of the latest completed collection.'
                echo '# TYPE homelab07_rockstor_last_run_timestamp_seconds gauge'
                printf 'homelab07_rockstor_last_run_timestamp_seconds %s\n' "${failed_now}"
                echo '# HELP homelab07_rockstor_last_success_timestamp_seconds Unix time of the latest successful collection.'
                echo '# TYPE homelab07_rockstor_last_success_timestamp_seconds gauge'
                printf 'homelab07_rockstor_last_success_timestamp_seconds %s\n' "${failed_success}"
                echo '# HELP homelab07_rockstor_last_status Status of the latest completed collection, one for success.'
                echo '# TYPE homelab07_rockstor_last_status gauge'
                echo 'homelab07_rockstor_last_status 0'
                echo '# HELP homelab07_rockstor_last_duration_seconds Duration of the latest completed collection.'
                echo '# TYPE homelab07_rockstor_last_duration_seconds gauge'
                printf 'homelab07_rockstor_last_duration_seconds %s\n' "$((failed_now - started_epoch))"
            } >>"${failed_file}"
            mv -f -- "${failed_file}" "${final_file}" 2>/dev/null || rm -f -- "${failed_file}"
        fi
    fi

    exit "${exit_status}"
}
trap cleanup_storage_metric EXIT
trap 'exit 1' INT TERM

emit_metric() {
    local name="$1"
    local alias="$2"
    local value="$3"
    printf '%s{storage="%s"} %s\n' "${name}" "${alias}" "${value}" >>"${temporary}"
}

{
    echo '# HELP homelab07_storage_collection_timestamp_seconds Unix time of this storage collection.'
    echo '# TYPE homelab07_storage_collection_timestamp_seconds gauge'
    printf 'homelab07_storage_collection_timestamp_seconds %s\n' "$(date +%s)"
    echo '# HELP homelab07_storage_mount_ok Whether the expected path is an exact mount point.'
    echo '# TYPE homelab07_storage_mount_ok gauge'
    echo '# HELP homelab07_storage_fstype_ok Whether the mounted filesystem type matches policy.'
    echo '# TYPE homelab07_storage_fstype_ok gauge'
    echo '# HELP homelab07_storage_read_only Whether the filesystem is mounted read-only.'
    echo '# TYPE homelab07_storage_read_only gauge'
    echo '# HELP homelab07_storage_space_used_percent Filesystem space consumption percentage.'
    echo '# TYPE homelab07_storage_space_used_percent gauge'
    echo '# HELP homelab07_storage_inodes_used_percent Filesystem inode consumption percentage.'
    echo '# TYPE homelab07_storage_inodes_used_percent gauge'
    echo '# HELP homelab07_storage_device_errors_total Cumulative Btrfs device error counters.'
    echo '# TYPE homelab07_storage_device_errors_total counter'
    echo '# HELP homelab07_storage_btrfs_metrics_available Whether Btrfs extended metrics were readable.'
    echo '# TYPE homelab07_storage_btrfs_metrics_available gauge'
    echo '# HELP homelab07_storage_btrfs_data_used_percent Btrfs data allocation usage percentage.'
    echo '# TYPE homelab07_storage_btrfs_data_used_percent gauge'
    echo '# HELP homelab07_storage_btrfs_metadata_used_percent Btrfs metadata allocation usage percentage.'
    echo '# TYPE homelab07_storage_btrfs_metadata_used_percent gauge'
    echo '# HELP homelab07_storage_scrub_status Whether the latest Btrfs scrub finished successfully.'
    echo '# TYPE homelab07_storage_scrub_status gauge'
    echo '# HELP homelab07_storage_scrub_age_seconds Age of the latest Btrfs scrub start time.'
    echo '# TYPE homelab07_storage_scrub_age_seconds gauge'
} >"${temporary}"

while IFS=$'\t' read -r alias mount_path expected_fstype extra; do
    [[ -n "${alias}" ]] || continue
    [[ "${alias}" == \#* ]] && continue

    if [[ ! "${alias}" =~ ^[a-z][a-z0-9-]*$ ]] ||
        [[ "${mount_path}" != /* ]] ||
        [[ ! "${expected_fstype}" =~ ^[a-z0-9]+$ ]] ||
        [[ -n "${extra:-}" ]]; then
        echo "Invalid private storage inventory entry for an abstract alias." >&2
        failure_count=$((failure_count + 1))
        continue
    fi

    storage_count=$((storage_count + 1))
    target="$(findmnt -T "${mount_path}" -n -o TARGET 2>/dev/null || true)"
    fstype="$(findmnt -T "${mount_path}" -n -o FSTYPE 2>/dev/null || true)"
    options="$(findmnt -T "${mount_path}" -n -o OPTIONS 2>/dev/null || true)"

    mount_ok=0
    fstype_ok=0
    read_only=0
    [[ "${target}" == "${mount_path}" ]] && mount_ok=1
    [[ "${mount_ok}" == "1" && "${fstype}" == "${expected_fstype}" ]] && fstype_ok=1
    [[ ",${options}," == *,ro,* ]] && read_only=1

    emit_metric homelab07_storage_mount_ok "${alias}" "${mount_ok}"
    emit_metric homelab07_storage_fstype_ok "${alias}" "${fstype_ok}"
    emit_metric homelab07_storage_read_only "${alias}" "${read_only}"

    if [[ "${mount_ok}" == "1" ]]; then
        space_used="$(df -P "${mount_path}" | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')"
        inode_used="$(df -Pi "${mount_path}" | awk 'NR == 2 {gsub(/%/, "", $5); print $5}')"
        [[ "${space_used}" =~ ^[0-9]+$ ]] || space_used=0
        [[ "${inode_used}" =~ ^[0-9]+$ ]] || inode_used=0
        emit_metric homelab07_storage_space_used_percent "${alias}" "${space_used}"
        emit_metric homelab07_storage_inodes_used_percent "${alias}" "${inode_used}"
    fi

    btrfs_available=0
    device_errors=0
    btrfs_data_used=0
    btrfs_metadata_used=0
    scrub_status=0
    scrub_age=0
    if [[ "${fstype_ok}" == "1" ]] && command -v btrfs >/dev/null 2>&1; then
        if device_stats="$(btrfs device stats "${mount_path}" 2>/dev/null)"; then
            device_errors="$(awk '{sum += $NF} END {print sum + 0}' <<<"${device_stats}")"
            btrfs_available=1
        fi

        if usage_output="$(btrfs filesystem usage --raw "${mount_path}" 2>/dev/null)"; then
            btrfs_data_used="$(awk '
                /^Data,/ {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "Size:") {value = $(i + 1); gsub(/[^0-9]/, "", value); total_size += value}
                        if ($i == "Used:") {value = $(i + 1); gsub(/[^0-9]/, "", value); total_used += value}
                    }
                }
                END {if (total_size > 0) printf "%.2f", (total_used / total_size) * 100}
            ' <<<"${usage_output}")"
            btrfs_metadata_used="$(awk '
                /^Metadata,/ {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "Size:") {value = $(i + 1); gsub(/[^0-9]/, "", value); total_size += value}
                        if ($i == "Used:") {value = $(i + 1); gsub(/[^0-9]/, "", value); total_used += value}
                    }
                }
                END {if (total_size > 0) printf "%.2f", (total_used / total_size) * 100}
            ' <<<"${usage_output}")"
            [[ "${btrfs_data_used}" =~ ^[0-9]+([.][0-9]+)?$ ]] || btrfs_data_used=0
            [[ "${btrfs_metadata_used}" =~ ^[0-9]+([.][0-9]+)?$ ]] || btrfs_metadata_used=0
        fi

        if scrub_output="$(btrfs scrub status -d "${mount_path}" 2>/dev/null)"; then
            if grep -Eqi 'status:[[:space:]]*finished|finished after' <<<"${scrub_output}" &&
                ! grep -Eqi 'status:[[:space:]]*(abort|cancel)' <<<"${scrub_output}"; then
                scrub_status=1
            fi
            scrub_started="$(awk -F': ' 'tolower($1) ~ /start time/ {print $2; exit}' <<<"${scrub_output}")"
            if [[ -n "${scrub_started}" ]] &&
                scrub_epoch="$(date -d "${scrub_started}" +%s 2>/dev/null)"; then
                scrub_age="$(( $(date +%s) - scrub_epoch ))"
                ((scrub_age >= 0)) || scrub_age=0
            fi
        fi
    fi
    emit_metric homelab07_storage_device_errors_total "${alias}" "${device_errors}"
    emit_metric homelab07_storage_btrfs_metrics_available "${alias}" "${btrfs_available}"
    emit_metric homelab07_storage_btrfs_data_used_percent "${alias}" "${btrfs_data_used}"
    emit_metric homelab07_storage_btrfs_metadata_used_percent "${alias}" "${btrfs_metadata_used}"
    emit_metric homelab07_storage_scrub_status "${alias}" "${scrub_status}"
    emit_metric homelab07_storage_scrub_age_seconds "${alias}" "${scrub_age}"
done <"${HOMELAB07_STORAGE_INVENTORY_FILE}"

if ((storage_count == 0 || failure_count > 0)); then
    echo "Storage inventory did not produce a complete metric set."
    exit 1
fi

finished_epoch="$(date +%s)"
{
    echo '# HELP homelab07_rockstor_last_run_timestamp_seconds Unix time of the latest completed collection.'
    echo '# TYPE homelab07_rockstor_last_run_timestamp_seconds gauge'
    printf 'homelab07_rockstor_last_run_timestamp_seconds %s\n' "${finished_epoch}"
    echo '# HELP homelab07_rockstor_last_success_timestamp_seconds Unix time of the latest successful collection.'
    echo '# TYPE homelab07_rockstor_last_success_timestamp_seconds gauge'
    printf 'homelab07_rockstor_last_success_timestamp_seconds %s\n' "${finished_epoch}"
    echo '# HELP homelab07_rockstor_last_status Status of the latest completed collection, one for success.'
    echo '# TYPE homelab07_rockstor_last_status gauge'
    echo 'homelab07_rockstor_last_status 1'
    echo '# HELP homelab07_rockstor_last_duration_seconds Duration of the latest completed collection.'
    echo '# TYPE homelab07_rockstor_last_duration_seconds gauge'
    printf 'homelab07_rockstor_last_duration_seconds %s\n' "$((finished_epoch - started_epoch))"
} >>"${temporary}"

mv -f -- "${temporary}" "${final_file}"
trap - EXIT INT TERM

echo "Rockstor storage metrics published atomically for ${storage_count} abstract target(s)."
echo "Extended Btrfs counters may require the documented root-owned timer."

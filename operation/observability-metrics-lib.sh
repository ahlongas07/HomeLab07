#!/usr/bin/env bash

# Optional metric publication library. Callers must never fail their primary
# operation solely because observability is unavailable.

observability_file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || true
}

observability_load_metrics_environment() {
    local config_file="${PRIVATE_ROOT}/env/observability.env"
    local mode

    [[ -f "${config_file}" ]] || return 1
    mode="$(observability_file_mode "${config_file}")"
    [[ "${mode}" =~ ^[0-7]{3,4}$ ]] && ((10#${mode} % 100 == 0)) || return 1

    set -a
    # shellcheck disable=SC1090
    source "${config_file}"
    set +a

    [[ -n "${HOMELAB07_OBSERVABILITY_METRICS_ROOT:-}" ]] || return 1
    [[ -d "${HOMELAB07_OBSERVABILITY_METRICS_ROOT}" ]] || return 1
    [[ -w "${HOMELAB07_OBSERVABILITY_METRICS_ROOT}" ]] || return 1
}

observability_previous_metric() {
    local file="$1"
    local metric="$2"

    [[ -f "${file}" ]] || return 0
    awk -v metric="${metric}" '$1 == metric && NF == 2 {value = $2} END {print value}' "${file}"
}

observability_publish_batch_metrics() {
    local job="$1"
    local status="$2"
    local started_epoch="$3"
    shift 3

    local metric_root file temporary now last_success duration prefix extra
    local extra_pattern='^homelab07_[a-zA-Z0-9_:]+(\{[a-zA-Z0-9_=".,:-]+\})?[[:space:]]+[-+]?[0-9]+([.][0-9]+)?$'

    if [[ ! "${job}" =~ ^[a-z][a-z0-9_]*$ ]] ||
        [[ ! "${status}" =~ ^[01]$ ]] ||
        [[ ! "${started_epoch}" =~ ^[0-9]+$ ]]; then
        echo "WARNING: invalid observability batch metric arguments; metric not published." >&2
        return 0
    fi

    if ! observability_load_metrics_environment; then
        echo "WARNING: observability metrics are not configured; ${job} metric not published." >&2
        return 0
    fi

    metric_root="${HOMELAB07_OBSERVABILITY_METRICS_ROOT}"
    file="${metric_root}/${job}.prom"
    now="$(date +%s)"
    duration="$((now - started_epoch))"
    prefix="homelab07_${job}"

    if [[ "${status}" == "1" ]]; then
        last_success="${now}"
    else
        last_success="$(observability_previous_metric "${file}" "${prefix}_last_success_timestamp_seconds")"
        [[ "${last_success}" =~ ^[0-9]+$ ]] || last_success=0
    fi

    temporary="$(mktemp "${metric_root}/.${job}.prom.XXXXXX")" || {
        echo "WARNING: unable to create temporary ${job} metric file." >&2
        return 0
    }
    chmod 0644 "${temporary}" 2>/dev/null || true

    {
        printf '# HELP %s_last_run_timestamp_seconds Unix time of the latest completed attempt.\n' "${prefix}"
        printf '# TYPE %s_last_run_timestamp_seconds gauge\n' "${prefix}"
        printf '%s_last_run_timestamp_seconds %s\n' "${prefix}" "${now}"
        printf '# HELP %s_last_success_timestamp_seconds Unix time of the latest successful attempt.\n' "${prefix}"
        printf '# TYPE %s_last_success_timestamp_seconds gauge\n' "${prefix}"
        printf '%s_last_success_timestamp_seconds %s\n' "${prefix}" "${last_success}"
        printf '# HELP %s_last_status Status of the latest completed attempt, one for success.\n' "${prefix}"
        printf '# TYPE %s_last_status gauge\n' "${prefix}"
        printf '%s_last_status %s\n' "${prefix}" "${status}"
        printf '# HELP %s_last_duration_seconds Duration of the latest completed attempt.\n' "${prefix}"
        printf '# TYPE %s_last_duration_seconds gauge\n' "${prefix}"
        printf '%s_last_duration_seconds %s\n' "${prefix}" "${duration}"

        for extra in "$@"; do
            if [[ "${extra}" =~ ${extra_pattern} ]]; then
                printf '%s\n' "${extra}"
            else
                echo "WARNING: rejected invalid extra metric for ${job}." >&2
            fi
        done
    } >"${temporary}"

    if ! mv -f -- "${temporary}" "${file}"; then
        rm -f -- "${temporary}"
        echo "WARNING: unable to publish ${job} metrics atomically." >&2
    fi
}

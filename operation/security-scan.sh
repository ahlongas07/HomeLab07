#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"
source "${BASH_SOURCE%/*}/observability-metrics-lib.sh"

print_header "Vulnerability Management"
print_project_root

action="${1:-scan}"
config_file="${PRIVATE_ROOT}/env/security-scan.env"
targets_root="${PRIVATE_ROOT}/env/security-scan-targets"
platform_target="homelab07"

case "${action}" in
    preflight|scan) ;;
    *)
        echo "Usage: $0 [preflight|scan]"
        exit 2
        ;;
esac

pass_count=0
failure_count=0
target_failure_count=0

pass() {
    echo "[PASS] $1"
    pass_count=$((pass_count + 1))
}

fail() {
    echo "[FAIL] $1"
    failure_count=$((failure_count + 1))
}

file_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || true
}

canonical_directory() {
    (cd "$1" 2>/dev/null && pwd -P)
}

# Follows file symbolic links so a definition cannot point outside its root.
canonical_file() {
    local file="$1"
    local link directory hops=0

    while [[ -L "${file}" ]]; do
        ((hops++ < 40)) || return 1
        link="$(readlink "${file}")"
        [[ "${link}" == /* ]] || link="$(dirname "${file}")/${link}"
        file="${link}"
    done

    directory="$(canonical_directory "$(dirname "${file}")")" || return 1
    printf '%s/%s\n' "${directory}" "$(basename "${file}")"
}

is_within() {
    local candidate="$1"
    local boundary="$2"

    [[ "${candidate}" == "${boundary}" || "${candidate}" == "${boundary}/"* ]]
}

sha256_text() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | awk '{print $1}'
    else
        printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
    fi
}

if [[ ! -f "${config_file}" ]]; then
    fail "Private scanner configuration is missing"
    echo
    echo "Create it from:"
    echo "  operation/security-scan.env.example"
else
    config_mode="$(file_mode "${config_file}")"
    if [[ "${config_mode}" =~ ^[0-7]{3,4}$ ]] && ((10#${config_mode} % 100 == 0)); then
        pass "Private scanner configuration is owner-only"
    else
        fail "Private scanner configuration permissions are broader than owner-only"
    fi

    set -a
    # shellcheck disable=SC1090
    source "${config_file}"
    set +a
fi

required_commands=(docker git jq find sort awk)
for command_name in "${required_commands[@]}"; do
    if command -v "${command_name}" >/dev/null 2>&1; then
        pass "Required command is available: ${command_name}"
    else
        fail "Required command is unavailable: ${command_name}"
    fi
done

if command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1; then
    pass "SHA-256 command is available"
else
    fail "Neither sha256sum nor shasum is available"
fi

if docker info >/dev/null 2>&1; then
    pass "Docker daemon is available"
else
    fail "Docker daemon is unavailable"
fi

if docker compose version >/dev/null 2>&1; then
    pass "Docker Compose v2 is available"
else
    fail "Docker Compose v2 is unavailable"
fi

report_root="${HOMELAB07_SECURITY_REPORT_ROOT:-}"
cache_root="${HOMELAB07_TRIVY_CACHE_ROOT:-}"
trivy_image="${HOMELAB07_TRIVY_IMAGE:-docker.io/aquasec/trivy:0.72.0@sha256:cffe3f5161a47a6823fbd23d985795b3ed72a4c806da4c4df16266c02accdd6f}"
gitleaks_image="${HOMELAB07_GITLEAKS_IMAGE:-ghcr.io/gitleaks/gitleaks:v8.30.1@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f}"
severities="${HOMELAB07_SECURITY_SCAN_SEVERITIES:-HIGH,CRITICAL}"
scan_timeout="${HOMELAB07_SECURITY_SCAN_TIMEOUT:-20m}"
require_mount="${HOMELAB07_SECURITY_REPORT_REQUIRE_MOUNT:-true}"

for variable_name in HOMELAB07_SECURITY_REPORT_ROOT HOMELAB07_TRIVY_CACHE_ROOT; do
    if [[ -n "${!variable_name:-}" ]]; then
        pass "Required private setting is defined: ${variable_name}"
    else
        fail "Required private setting is missing: ${variable_name}"
    fi
done

if [[ "${trivy_image}" =~ ^[^[:space:]@]+:[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]]; then
    pass "Trivy runtime uses an immutable tagged digest"
else
    fail "HOMELAB07_TRIVY_IMAGE must use image:tag@sha256:<64 lowercase hex characters>"
fi

if [[ "${gitleaks_image}" =~ ^[^[:space:]@]+:[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]]; then
    pass "Gitleaks runtime uses an immutable tagged digest"
else
    fail "HOMELAB07_GITLEAKS_IMAGE must use image:tag@sha256:<64 lowercase hex characters>"
fi

report_real=""
cache_real=""

if [[ -n "${report_root}" ]]; then
    if [[ "${report_root}" != /* ]]; then
        fail "Report root must be an absolute path"
    elif [[ ! -d "${report_root}" ]]; then
        fail "Report root does not exist"
    elif [[ ! -w "${report_root}" || ! -x "${report_root}" ]]; then
        fail "Report root is not writable and traversable by the operator"
    else
        report_real="$(canonical_directory "${report_root}")"
        pass "Report root is available"
    fi
fi

if [[ "${require_mount}" == "true" && -n "${report_root}" ]]; then
    if ! command -v findmnt >/dev/null 2>&1; then
        fail "findmnt is required when report mount validation is enabled"
    else
        report_mount="$(findmnt -T "${report_root}" -n -o TARGET 2>/dev/null || true)"
        if [[ -z "${report_mount}" ]]; then
            fail "No mounted filesystem contains the report root"
        elif [[ "${report_mount}" == "/" ]]; then
            fail "Report root resolves to the operating-system root filesystem"
        elif is_within "${report_real}" "${report_mount}"; then
            pass "Report root is contained by a dedicated mounted filesystem"
        else
            fail "Report root cannot be validated against its mounted filesystem"
        fi
    fi
elif [[ "${require_mount}" != "false" && "${require_mount}" != "true" ]]; then
    fail "HOMELAB07_SECURITY_REPORT_REQUIRE_MOUNT must be true or false"
fi

if [[ -n "${cache_root}" ]]; then
    if [[ "${cache_root}" != /* ]]; then
        fail "Trivy cache root must be an absolute path"
    elif [[ ! -d "${cache_root}" ]]; then
        fail "Trivy cache root does not exist"
    elif [[ ! -w "${cache_root}" || ! -x "${cache_root}" ]]; then
        fail "Trivy cache root is not writable and traversable by the operator"
    else
        cache_real="$(canonical_directory "${cache_root}")"
        pass "Trivy cache root is available"
    fi
fi

if [[ -n "${report_real}" ]]; then
    if is_within "${report_real}" "${PROJECT_ROOT}" ||
        is_within "${report_real}" "${PRIVATE_ROOT}"; then
        fail "Report root overlaps a protected source or private configuration boundary"
    else
        pass "Report root is outside protected repository boundaries"
    fi
fi

if [[ -n "${cache_real}" ]]; then
    if is_within "${cache_real}" "${PROJECT_ROOT}" ||
        is_within "${cache_real}" "${PRIVATE_ROOT}"; then
        fail "Cache root overlaps a protected source or private configuration boundary"
    else
        pass "Cache root is outside protected repository boundaries"
    fi
fi

if [[ -n "${report_real}" && -n "${cache_real}" ]] &&
    { is_within "${report_real}" "${cache_real}" || is_within "${cache_real}" "${report_real}"; }; then
    fail "Report and cache roots must not overlap"
elif [[ -n "${report_real}" && -n "${cache_real}" ]]; then
    pass "Report and cache roots are separate"
fi

compose_files=("${PROJECT_ROOT}"/services/*/compose.yaml)
if ((${#compose_files[@]} == 0)); then
    fail "No service Compose definitions were discovered"
else
    pass "Service Compose definitions discovered: ${#compose_files[@]}"
fi

trivy_ignore_file="${PROJECT_ROOT}/security/trivyignore.yaml"
gitleaks_ignore_file="${PROJECT_ROOT}/security/gitleaksignore"

for exception_file in "${trivy_ignore_file}" "${gitleaks_ignore_file}"; do
    if [[ -f "${exception_file}" ]]; then
        pass "Reviewed exception file is present: ${exception_file#"${PROJECT_ROOT}/"}"
    else
        fail "Reviewed exception file is missing: ${exception_file#"${PROJECT_ROOT}/"}"
    fi
done

# Trivy stops applying an entry after its expired_at date. Gitleaks has no
# expiry, so a stale fingerprint exception blocks the scan until reviewed.
expired_gitleaks_dates() {
    { grep -oE 'expires: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$1" || true; } |
        awk -v today="$(date -u '+%Y-%m-%d')" '$2 < today { print $2 }'
}

if [[ -f "${gitleaks_ignore_file}" ]]; then
    expired_dates="$(expired_gitleaks_dates "${gitleaks_ignore_file}")"
    if [[ -z "${expired_dates}" ]]; then
        pass "Gitleaks exceptions are within their review dates"
    else
        fail "Gitleaks exceptions expired on: $(paste -sd ' ' - <<<"${expired_dates}")"
    fi
fi

# External application targets. Each private definition names a repository
# whose Compose definitions are discovered on every run, so services added to
# an application are scanned without changing HomeLab07. A target that fails
# here is recorded as failed by a scan; it never blocks HomeLab07 evidence.
project_real="$(canonical_directory "${PROJECT_ROOT}")"
private_real="$(canonical_directory "${PRIVATE_ROOT}" || printf '%s' "${PRIVATE_ROOT}")"

target_ids=()
target_repositories=()
target_env_roots=()
target_compose_lists=()
target_reasons=()

read_target_definition() {
    # Sourced in a subshell so target settings never reach the scanner.
    (
        # shellcheck disable=SC1090
        source "$1"
        printf '%s\n%s\n%s\n' \
            "${HOMELAB07_SECURITY_TARGET_REPOSITORY:-}" \
            "${HOMELAB07_SECURITY_TARGET_COMPOSE_PATTERN:-services/*/compose.yaml}" \
            "${HOMELAB07_SECURITY_TARGET_ENV_ROOT:-}"
    )
}

overlaps_protected_root() {
    local candidate="$1"
    local boundary

    for boundary in "${project_real}" "${private_real}" "${report_real}" "${cache_real}"; do
        [[ -n "${boundary}" ]] || continue
        if is_within "${candidate}" "${boundary}" || is_within "${boundary}" "${candidate}"; then
            return 0
        fi
    done
    return 1
}

# Sets checked_* globals; checked_reason explains a failure without paths.
check_target() {
    local definition="$1"
    local repository="" pattern="" env_root="" mode top_level compose_file compose_real expired
    local -a matches

    checked_repository=""
    checked_env_root=""
    checked_compose_list=""
    checked_compose_count=0
    checked_reason=""

    mode="$(file_mode "${definition}")"
    if [[ ! "${mode}" =~ ^[0-7]{3,4}$ ]] || ((10#${mode} % 100 != 0)); then
        checked_reason="definition permissions are broader than owner-only"
        return 1
    fi

    { read -r repository; read -r pattern; read -r env_root; } \
        < <(read_target_definition "${definition}") || true

    if [[ -z "${repository}" ]]; then
        checked_reason="HOMELAB07_SECURITY_TARGET_REPOSITORY is not defined"
        return 1
    elif [[ "${repository}" != /* ]]; then
        checked_reason="repository must be an absolute path"
        return 1
    elif ! checked_repository="$(canonical_directory "${repository}")"; then
        checked_reason="repository does not exist"
        return 1
    fi

    top_level="$(git -c "safe.directory=${checked_repository}" -C "${checked_repository}" \
        rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ -z "${top_level}" || "$(canonical_directory "${top_level}")" != "${checked_repository}" ]]; then
        checked_reason="repository is not the root of a Git work tree"
        return 1
    fi

    if [[ "$(git -c "safe.directory=${checked_repository}" -C "${checked_repository}" \
        rev-parse --is-shallow-repository)" != "false" ]]; then
        checked_reason="repository is a shallow clone; full history is required"
        return 1
    fi

    if overlaps_protected_root "${checked_repository}"; then
        checked_reason="repository overlaps HomeLab07, its private root, the report root or the cache"
        return 1
    fi

    if [[ "${pattern}" == /* || "/${pattern}/" == */../* ]]; then
        checked_reason="Compose discovery pattern must be relative to the repository"
        return 1
    fi

    if [[ -n "${env_root}" ]]; then
        if [[ "${env_root}" != /* ]] || ! checked_env_root="$(canonical_directory "${env_root}")"; then
            checked_reason="environment root must be an existing absolute path"
            return 1
        elif is_within "${checked_env_root}" "${checked_repository}" ||
            overlaps_protected_root "${checked_env_root}"; then
            checked_reason="environment root must stay outside the repository and protected roots"
            return 1
        fi
    fi

    shopt -s nullglob
    # shellcheck disable=SC2206
    matches=("${checked_repository}"/${pattern})
    shopt -u nullglob

    for compose_file in "${matches[@]}"; do
        [[ -f "${compose_file}" ]] || continue
        compose_real="$(canonical_file "${compose_file}")"
        if ! is_within "${compose_real}" "${checked_repository}"; then
            checked_reason="a Compose definition resolves outside the repository"
            return 1
        fi
        checked_compose_list+="${compose_real}"$'\n'
        checked_compose_count=$((checked_compose_count + 1))
    done

    if ((checked_compose_count == 0)); then
        checked_reason="no Compose definitions match the discovery pattern"
        return 1
    fi

    if [[ -f "${checked_repository}/security/gitleaksignore" ]]; then
        expired="$(expired_gitleaks_dates "${checked_repository}/security/gitleaksignore")"
        if [[ -n "${expired}" ]]; then
            checked_reason="Gitleaks exceptions expired on: $(paste -sd ' ' - <<<"${expired}")"
            return 1
        fi
    fi
}

if [[ -d "${targets_root}" ]]; then
    for definition in "${targets_root}"/*.env; do
        [[ -f "${definition}" ]] || continue
        target_id="$(basename "${definition}" .env)"

        if [[ ! "${target_id}" =~ ^[a-z][a-z0-9-]{0,62}$ || "${target_id}" == "${platform_target}" ]]; then
            echo "[FAIL] Security scan target definition has an invalid ID and is ignored: ${target_id}"
            target_failure_count=$((target_failure_count + 1))
            continue
        fi

        if check_target "${definition}"; then
            pass "Security scan target is ready: ${target_id} (${checked_compose_count} Compose definitions)"
        else
            echo "[FAIL] Security scan target ${target_id}: ${checked_reason}"
            target_failure_count=$((target_failure_count + 1))
        fi

        target_ids+=("${target_id}")
        target_repositories+=("${checked_repository}")
        target_env_roots+=("${checked_env_root}")
        target_compose_lists+=("${checked_compose_list}")
        target_reasons+=("${checked_reason}")
    done
fi

# Runtime coverage: report containers that were not created from a Compose
# definition in the inventory. The runtime never becomes the inventory.
inventory_compose_files="$(
    for compose_file in "${compose_files[@]}"; do
        canonical_file "${compose_file}" || true
    done
    printf '%s' "${target_compose_lists[@]}"
)"

uncovered_containers=()
while IFS=$'\t' read -r container_name container_image container_config_files; do
    [[ -n "${container_name}" ]] || continue
    if [[ "${container_image}" == "${trivy_image}" || "${container_image}" == "${gitleaks_image}" ]]; then
        continue
    fi

    container_covered=false
    IFS=',' read -r -a container_files <<<"${container_config_files}"
    for container_file in "${container_files[@]}"; do
        container_file="$(canonical_file "${container_file}" 2>/dev/null)" || continue
        if grep -Fxq -- "${container_file}" <<<"${inventory_compose_files}"; then
            container_covered=true
        fi
    done

    if [[ "${container_covered}" == "false" ]]; then
        uncovered_containers+=("${container_name}"$'\t'"${container_image}")
    fi
done < <(docker ps -a --format \
    '{{.Names}}{{"\t"}}{{.Image}}{{"\t"}}{{.Label "com.docker.compose.project.config_files"}}' \
    2>/dev/null || true)

if ((${#uncovered_containers[@]} == 0)); then
    pass "Every container was created from a scanned Compose definition"
else
    for entry in "${uncovered_containers[@]}"; do
        echo "[WARN] Container is not covered by a scanned Compose definition: ${entry%%$'\t'*} (${entry#*$'\t'})"
    done
fi

if ((failure_count > 0)); then
    echo
    echo "Preflight failed with ${failure_count} required-control failure(s)."
    exit 1
fi

if ! docker image inspect "${trivy_image}" >/dev/null 2>&1; then
    echo
    echo "Pulling the pinned Trivy runtime..."
    docker pull "${trivy_image}" >/dev/null
fi
pass "Pinned Trivy runtime is available"

trivy_version="$(docker run --rm "${trivy_image}" --version | head -n 1)"
pass "Trivy runtime responded: ${trivy_version}"
trivy_image_id="$(docker image inspect --format '{{.Id}}' "${trivy_image}")"
trivy_repo_digest="$(docker image inspect --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' "${trivy_image}")"
pass "Trivy runtime image identity is available"

if ! docker image inspect "${gitleaks_image}" >/dev/null 2>&1; then
    echo
    echo "Pulling the pinned Gitleaks runtime..."
    docker pull "${gitleaks_image}" >/dev/null
fi
pass "Pinned Gitleaks runtime is available"

gitleaks_version="$(docker run --rm "${gitleaks_image}" version | head -n 1)"
pass "Gitleaks runtime responded: ${gitleaks_version}"
gitleaks_image_id="$(docker image inspect --format '{{.Id}}' "${gitleaks_image}")"
gitleaks_repo_digest="$(docker image inspect --format '{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' "${gitleaks_image}")"
pass "Gitleaks runtime image identity is available"

if [[ "${action}" == "preflight" ]]; then
    echo
    echo "Summary"
    echo "  Pass                 : ${pass_count}"
    echo "  Failure              : ${failure_count}"
    echo "  Target failure       : ${target_failure_count}"
    echo "  Uncovered containers : ${#uncovered_containers[@]}"
    echo
    if ((target_failure_count > 0)); then
        echo "HomeLab07 is ready; a scan would record ${target_failure_count} external target failure(s)."
        exit 1
    fi
    echo "Security scan preflight completed successfully."
    exit 0
fi

run_id="$(date -u '+%Y-%m-%dT%H%M%SZ')"
scan_started_epoch="$(date +%s)"
runs_root="${report_real}/runs"
staging_root="${report_real}/.run-${run_id}-$$"
work_root="${staging_root}/.work"
final_root="${runs_root}/${run_id}"
lock_directory="${report_real}/.security-scan.lock"
trivy_tmp_root="${cache_real}/tmp-${run_id}-$$"

if ! mkdir "${lock_directory}" 2>/dev/null; then
    echo "Another security scan holds the report-share lock."
    exit 1
fi

# Target success times survive a failed run, so a later target failure still
# reports when that target last succeeded.
previous_target_success_metrics() {
    local file

    observability_load_metrics_environment || return 0
    file="${HOMELAB07_OBSERVABILITY_METRICS_ROOT}/security.prom"
    [[ -f "${file}" ]] || return 0
    grep -E '^homelab07_security_target_last_success_timestamp_seconds\{target="[a-z0-9-]+"\} [0-9]+$' \
        "${file}" || true
}

cleanup() {
    local exit_status=$?
    local -a carried_metrics=()
    rm -rf -- "${staging_root}"
    rm -rf -- "${trivy_tmp_root}"
    rmdir "${lock_directory}" 2>/dev/null || true
    mapfile -t carried_metrics < <(previous_target_success_metrics)
    observability_publish_batch_metrics security 0 "${scan_started_epoch}" \
        "${carried_metrics[@]}"
    exit "${exit_status}"
}
trap cleanup EXIT INT TERM

umask 0027
mkdir -p "${runs_root}" "${staging_root}/repository" \
    "${staging_root}/images" "${staging_root}/sbom" "${work_root}" "${trivy_tmp_root}"
chmod 0700 "${trivy_tmp_root}"

run_trivy() {
    local workspace="$1"
    shift

    docker run --rm \
        --user "$(id -u):$(id -g)" \
        --read-only \
        --cap-drop ALL \
        --security-opt no-new-privileges \
        --volume "${cache_real}:/cache" \
        --volume "${trivy_tmp_root}:/tmp" \
        --volume "${workspace}:/workspace:ro" \
        --volume "${staging_root}:/output" \
        "${trivy_image}" \
        --cache-dir /cache \
        --timeout "${scan_timeout}" \
        --quiet \
        "$@"
}

# HomeLab07 services use the private environment convention in lib.sh. An
# external service uses <env root>/<service>.env when that file exists.
target_compose() {
    local target="$1"
    local env_root="$2"
    local compose_file="$3"
    shift 3

    local service_id env_file
    service_id="$(basename "$(dirname "${compose_file}")")"

    if [[ "${target}" == "${platform_target}" ]]; then
        compose "${service_id}" "$@"
        return
    fi

    env_file="${env_root}/${service_id}.env"
    if [[ -n "${env_root}" && -f "${env_file}" ]]; then
        docker compose --env-file "${env_file}" -f "${compose_file}" "$@"
    else
        docker compose -f "${compose_file}" "$@"
    fi
}

# Scans one target into per-target report paths. External targets run it in a
# subshell, so a failure discards only that target's evidence.
scan_target() {
    local target="$1"
    local workspace="$2"
    local env_root="$3"
    local compose_list="$4"
    local work="${work_root}/${target}"
    local stage_file="${work_root}/${target}.stage"
    local compose_file service_id image_reference artifact_key local_entry
    local image_archive image_id image_source build_hint
    local -a image_target trivy_ignore_args=() gitleaks_ignore_args=()

    mkdir -p "${work}" "${staging_root}/repository/${target}" \
        "${staging_root}/images/${target}" "${staging_root}/sbom/${target}"
    : >"${work}/image-references.txt"
    : >"${work}/local-images.txt"
    : >"${work}/image-map.ndjson"

    echo "Compose rendering" >"${stage_file}"
    echo "Rendering ${target} Compose definitions and building the image inventory..."
    while IFS= read -r compose_file; do
        [[ -n "${compose_file}" ]] || continue
        service_id="$(basename "$(dirname "${compose_file}")")"
        target_compose "${target}" "${env_root}" "${compose_file}" config --quiet
        target_compose "${target}" "${env_root}" "${compose_file}" config --images \
            >>"${work}/image-references.txt"
        # Images built from a repository Dockerfile exist only in the local engine.
        # Only their names leave the pipe: the rendered JSON contains env_file values.
        target_compose "${target}" "${env_root}" "${compose_file}" config --format json |
            jq -r --arg service "${service_id}" --arg compose "${compose_file#"${workspace}/"}" \
                '.services[] | select(.build) | .image // empty | "\(.)|\($service)|\($compose)"' \
                >>"${work}/local-images.txt"
    done <<<"${compose_list}"

    sort -u "${work}/image-references.txt" -o "${work}/image-references.txt"

    if [[ "${target}" == "${platform_target}" ]]; then
        echo "Running the existing HomeLab07 security policy audit..."
        if ! "${PROJECT_ROOT}/operation/security-audit.sh" |
            tee "${staging_root}/platform-audit.txt"; then
            echo
            echo "The platform security audit failed; Trivy scanning was not started."
            echo "Correct the required-control failure and rerun the security scan."
            exit 1
        fi
    fi

    git -c "safe.directory=${workspace}" -C "${workspace}" rev-parse HEAD >"${work}/git-revision"

    if [[ -f "${workspace}/security/trivyignore.yaml" ]]; then
        trivy_ignore_args=(--ignorefile /workspace/security/trivyignore.yaml)
    fi
    if [[ -f "${workspace}/security/gitleaksignore" ]]; then
        gitleaks_ignore_args=(--gitleaks-ignore-path /workspace/security/gitleaksignore)
    fi

    echo "repository scan" >"${stage_file}"
    echo "Scanning ${target} repository files..."
    run_trivy "${workspace}" filesystem \
        --scanners vuln,secret,misconfig \
        --severity "${severities}" \
        "${trivy_ignore_args[@]}" \
        --format json \
        --output "/output/repository/${target}/trivy.json" \
        /workspace

    echo "Git history scan" >"${stage_file}"
    echo "Scanning ${target} Git history with fully redacted findings..."
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        --read-only \
        --cap-drop ALL \
        --security-opt no-new-privileges \
        --tmpfs /tmp:rw,noexec,nosuid,size=256m \
        --volume "${workspace}:/workspace:ro" \
        --volume "${staging_root}:/output" \
        "${gitleaks_image}" \
        git \
        --log-opts="--all --full-history" \
        --redact=100 \
        "${gitleaks_ignore_args[@]}" \
        --report-format json \
        --report-path "/output/repository/${target}/gitleaks-history.raw.json" \
        --exit-code 0 \
        --no-banner \
        /workspace

    local gitleaks_raw_report="${staging_root}/repository/${target}/gitleaks-history.raw.json"
    local gitleaks_safe_report="${staging_root}/repository/${target}/gitleaks-history.json"

    if [[ ! -f "${gitleaks_raw_report}" ]]; then
        printf '[]\n' >"${gitleaks_raw_report}"
    fi

    # Never publish matched lines, secret values, commit messages or author data.
    jq 'map({
        rule_id: .RuleID,
        description: .Description,
        file: .File,
        commit: .Commit,
        start_line: .StartLine,
        end_line: .EndLine,
        fingerprint: .Fingerprint
    })' "${gitleaks_raw_report}" >"${gitleaks_safe_report}"
    rm "${gitleaks_raw_report}"

    echo "image scan" >"${stage_file}"
    while IFS= read -r image_reference; do
        [[ -n "${image_reference}" ]] || continue
        artifact_key="$(sha256_text "${image_reference}")"
        local_entry="$(awk -F '|' -v image="${image_reference}" \
            '$1 == image { print $2 "|" $3; exit }' "${work}/local-images.txt")"
        image_archive=""
        image_id=""

        if [[ -n "${local_entry}" ]]; then
            image_source="local"
            if [[ "${target}" == "${platform_target}" ]]; then
                build_hint="./operation/compose.sh ${local_entry%%|*} build"
            else
                build_hint="docker compose -f ${local_entry#*|} build (in the ${target} repository, with its private environment)"
            fi
            if ! image_id="$(docker image inspect --format '{{.Id}}' "${image_reference}" 2>/dev/null)"; then
                echo "Locally built image is missing: ${image_reference}"
                echo "Build it with ${build_hint} and rerun the scan."
                exit 1
            fi
            # Exported into the private Trivy temporary root so the scanner still
            # receives no Docker socket.
            image_archive="local-${target}-${artifact_key}.tar"
            docker save --output "${trivy_tmp_root}/${image_archive}" "${image_reference}"
            image_target=(--input "/tmp/${image_archive}")
        else
            image_source="remote"
            image_target=(--image-src remote "${image_reference}")
        fi

        echo "Scanning ${target} ${image_source} image ${image_reference}..."
        run_trivy "${workspace}" image \
            --scanners vuln,misconfig,secret \
            --image-config-scanners misconfig,secret \
            --severity "${severities}" \
            "${trivy_ignore_args[@]}" \
            --format json \
            --output "/output/images/${target}/${artifact_key}.json" \
            "${image_target[@]}"

        echo "Generating SBOM for ${image_reference}..."
        run_trivy "${workspace}" image \
            --format cyclonedx \
            --output "/output/sbom/${target}/${artifact_key}.cdx.json" \
            "${image_target[@]}"

        [[ -z "${image_archive}" ]] || rm -f -- "${trivy_tmp_root}/${image_archive}"

        jq -cn \
            --arg target "${target}" \
            --arg image "${image_reference}" \
            --arg key "${artifact_key}" \
            --arg source "${image_source}" \
            --arg image_id "${image_id}" \
            '{target: $target, image: $image, artifact_key: $key, source: $source}
             + (if $image_id == "" then {} else {local_image_id: $image_id} end)' \
            >>"${work}/image-map.ndjson"
    done <"${work}/image-references.txt"
}

# Actionable view for dashboards: findings with a published fix, counted once
# per scanned artifact, CVE and package. Kernel header packages are excluded
# because containers run on the host kernel. Raw totals stay in the report.
fixable_filter='.Results[]? | .Vulnerabilities[]?
      | select((.FixedVersion // "") != "")
      | select(.PkgName | test("^linux-(libc-dev|headers)") | not)'

target_findings() {
    local target="$1"
    local report
    local -a reports=("${staging_root}/repository/${target}/trivy.json")

    while IFS= read -r report; do
        reports+=("${report}")
    done < <(find "${staging_root}/images/${target}" -type f -name '*.json' -print)

    {
        jq -s '
            [.[].Results[]?] as $results |
            {
              vulnerabilities: ([$results[].Vulnerabilities[]?] | length),
              misconfigurations: ([$results[].Misconfigurations[]?] | length),
              secrets: ([$results[].Secrets[]?] | length),
              critical: ([$results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length),
              high: ([$results[].Vulnerabilities[]? | select(.Severity == "HIGH")] | length)
            }' "${reports[@]}"
        jq -n "
            [inputs | input_filename as \$artifact | ${fixable_filter}
              | {artifact: \$artifact, id: .VulnerabilityID, package: .PkgName, severity: .Severity}]"'
            | unique_by([.artifact, .id, .package])
            | {
                fixable_critical: (map(select(.severity == "CRITICAL")) | length),
                fixable_high: (map(select(.severity == "HIGH")) | length)
              }' "${reports[@]}"
    } | jq -s 'add'
}

result_ids=()
result_statuses=()
result_reasons=()

echo
echo "Scanning target ${platform_target}..."
scan_target "${platform_target}" "${PROJECT_ROOT}" "" \
    "$(printf '%s\n' "${compose_files[@]}")"
result_ids+=("${platform_target}")
result_statuses+=("succeeded")
result_reasons+=("")

for ((index = 0; index < ${#target_ids[@]}; index++)); do
    target="${target_ids[index]}"
    echo

    if [[ -n "${target_reasons[index]}" ]]; then
        echo "External target ${target} failed preflight: ${target_reasons[index]}"
        result_ids+=("${target}")
        result_statuses+=("failed")
        result_reasons+=("preflight: ${target_reasons[index]}")
        continue
    fi

    echo "Scanning external target ${target}..."
    set +e
    (
        trap - EXIT INT TERM
        set -e
        scan_target "${target}" "${target_repositories[index]}" \
            "${target_env_roots[index]}" "${target_compose_lists[index]}"
    )
    target_exit=$?
    set -e

    result_ids+=("${target}")
    if ((target_exit == 0)); then
        result_statuses+=("succeeded")
        result_reasons+=("")
    else
        target_stage="$(cat "${work_root}/${target}.stage" 2>/dev/null || echo "setup")"
        echo "External target ${target} failed during ${target_stage}; its partial evidence was discarded."
        rm -rf -- "${staging_root}/repository/${target}" "${staging_root}/images/${target}" \
            "${staging_root}/sbom/${target}" "${work_root:?}/${target}"
        find "${trivy_tmp_root}" -maxdepth 1 -name "local-${target}-*.tar" -delete
        result_statuses+=("failed")
        result_reasons+=("failed during ${target_stage}")
    fi
done

previous_metrics_file=""
if observability_load_metrics_environment; then
    previous_metrics_file="${HOMELAB07_OBSERVABILITY_METRICS_ROOT}/security.prom"
fi

target_metrics=()
: >"${work_root}/image-map.ndjson"
: >"${work_root}/targets.ndjson"
published_epoch="$(date +%s)"

for ((index = 0; index < ${#result_ids[@]}; index++)); do
    target="${result_ids[index]}"
    label="{target=\"${target}\"}"

    if [[ "${result_statuses[index]}" == "succeeded" ]]; then
        cat "${work_root}/${target}/image-map.ndjson" >>"${work_root}/image-map.ndjson"
        target_finding_counts="$(target_findings "${target}")"
        target_gitleaks_findings="$(jq 'length' "${staging_root}/repository/${target}/gitleaks-history.json")"
        target_image_count="$(grep -c . "${work_root}/${target}/image-map.ndjson" || true)"

        jq -cn \
            --arg id "${target}" \
            --arg git_revision "$(cat "${work_root}/${target}/git-revision")" \
            --argjson images "${target_image_count}" \
            --argjson findings "${target_finding_counts}" \
            --argjson gitleaks "${target_gitleaks_findings}" \
            '{id: $id, status: "succeeded", git_revision: $git_revision, images: $images,
              findings: $findings, possible_secret_findings: $gitleaks}' \
            >>"${work_root}/targets.ndjson"

        target_metrics+=(
            "homelab07_security_target_last_status${label} 1"
            "homelab07_security_target_last_success_timestamp_seconds${label} ${published_epoch}"
            "homelab07_security_critical_findings${label} $(jq -r '.critical' <<<"${target_finding_counts}")"
            "homelab07_security_high_findings${label} $(jq -r '.high' <<<"${target_finding_counts}")"
            "homelab07_security_fixable_critical_findings${label} $(jq -r '.fixable_critical' <<<"${target_finding_counts}")"
            "homelab07_security_fixable_high_findings${label} $(jq -r '.fixable_high' <<<"${target_finding_counts}")"
            "homelab07_security_gitleaks_findings${label} ${target_gitleaks_findings}"
        )
    else
        jq -cn --arg id "${target}" --arg reason "${result_reasons[index]}" \
            '{id: $id, status: "failed", reason: $reason}' >>"${work_root}/targets.ndjson"

        # A failed target keeps the time of its previous successful scan and
        # publishes no finding series, so it never appears clean.
        target_last_success="$(observability_previous_metric "${previous_metrics_file}" \
            "homelab07_security_target_last_success_timestamp_seconds${label}")"
        [[ "${target_last_success}" =~ ^[0-9]+$ ]] || target_last_success=0
        target_metrics+=(
            "homelab07_security_target_last_status${label} 0"
            "homelab07_security_target_last_success_timestamp_seconds${label} ${target_last_success}"
        )
    fi
done

jq -s '.' "${work_root}/image-map.ndjson" >"${staging_root}/image-map.json"
jq -s '.' "${work_root}/targets.ndjson" >"${work_root}/targets.json"
image_count="$(jq 'length' "${staging_root}/image-map.json")"

finding_counts="$(jq '
    [.[] | select(.status == "succeeded") | .findings | to_entries[]]
    | group_by(.key)
    | map({key: .[0].key, value: (map(.value) | add)})
    | from_entries' "${work_root}/targets.json")"
gitleaks_history_findings="$(jq '[.[] | .possible_secret_findings // 0] | add' "${work_root}/targets.json")"
failed_target_count="$(jq '[.[] | select(.status == "failed")] | length' "${work_root}/targets.json")"

uncovered_json="$(printf '%s\n' "${uncovered_containers[@]}" |
    jq -R -s 'split("\n") | map(select(length > 0) | split("\t") | {name: .[0], image: .[1]})')"

# Same actionable rules per image. The label drops the digest so the
# dashboard stays readable; the manifest keeps the full reference.
image_metrics=()
while IFS=$'\t' read -r image_target_id image_label fixable_critical fixable_high; do
    image_metrics+=(
        "homelab07_security_image_fixable_findings{target=\"${image_target_id}\",image=\"${image_label}\",severity=\"critical\"} ${fixable_critical}"
        "homelab07_security_image_fixable_findings{target=\"${image_target_id}\",image=\"${image_label}\",severity=\"high\"} ${fixable_high}"
    )
done < <(jq -r '.[] | [.target, .image, .artifact_key] | @tsv' "${staging_root}/image-map.json" |
    while IFS=$'\t' read -r image_target_id image_reference artifact_key; do
        jq -r --arg target "${image_target_id}" --arg image "${image_reference%%@*}" "
            [${fixable_filter} | {id: .VulnerabilityID, package: .PkgName, severity: .Severity}]
            | unique_by([.id, .package])"'
            | [$target, $image,
               (map(select(.severity == "CRITICAL")) | length),
               (map(select(.severity == "HIGH")) | length)]
            | @tsv' "${staging_root}/images/${image_target_id}/${artifact_key}.json"
    done)

git_revision="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"

jq -n \
    --arg contract_version "1.4.0" \
    --arg run_id "${run_id}" \
    --arg git_revision "${git_revision}" \
    --arg trivy_runtime "${trivy_image}" \
    --arg trivy_version "${trivy_version}" \
    --arg trivy_image_id "${trivy_image_id}" \
    --arg trivy_repo_digest "${trivy_repo_digest}" \
    --arg gitleaks_runtime "${gitleaks_image}" \
    --arg gitleaks_version "${gitleaks_version}" \
    --arg gitleaks_image_id "${gitleaks_image_id}" \
    --arg gitleaks_repo_digest "${gitleaks_repo_digest}" \
    --arg policy_mode "report-only" \
    --arg severities "${severities}" \
    --argjson targets "$(cat "${work_root}/targets.json")" \
    --argjson images "$(cat "${staging_root}/image-map.json")" \
    --argjson findings "${finding_counts}" \
    --argjson gitleaks_history_findings "${gitleaks_history_findings}" \
    --argjson uncovered "${uncovered_json}" \
    '{
      contract_version: $contract_version,
      run_id: $run_id,
      git_revision: $git_revision,
      trivy_runtime: $trivy_runtime,
      trivy_version: $trivy_version,
      trivy_image_id: $trivy_image_id,
      trivy_repo_digest: $trivy_repo_digest,
      gitleaks_runtime: $gitleaks_runtime,
      gitleaks_version: $gitleaks_version,
      gitleaks_image_id: $gitleaks_image_id,
      gitleaks_repo_digest: $gitleaks_repo_digest,
      policy_mode: $policy_mode,
      severities: $severities,
      targets: $targets,
      images: $images,
      findings: $findings,
      git_history: {
        scope: "all refs and full history",
        evidence: "sanitized metadata only",
        possible_secret_findings: $gitleaks_history_findings
      },
      coverage: {uncovered_containers: $uncovered}
    }' >"${staging_root}/manifest.json"

{
    echo "# HomeLab07 Security Scan"
    echo
    echo "- Run ID: \`${run_id}\`"
    echo "- Policy: report-only"
    echo "- Git revision: \`${git_revision}\`"
    echo "- Images scanned: ${image_count}"
    echo "- Vulnerabilities: $(jq -r '.vulnerabilities' <<<"${finding_counts}")"
    echo "- Critical: $(jq -r '.critical' <<<"${finding_counts}")"
    echo "- High: $(jq -r '.high' <<<"${finding_counts}")"
    echo "- Critical with an available fix (unique, kernel headers excluded): $(jq -r '.fixable_critical' <<<"${finding_counts}")"
    echo "- High with an available fix (unique, kernel headers excluded): $(jq -r '.fixable_high' <<<"${finding_counts}")"
    echo "- Misconfigurations: $(jq -r '.misconfigurations' <<<"${finding_counts}")"
    echo "- Secret findings: $(jq -r '.secrets' <<<"${finding_counts}")"
    echo "- Git history possible-secret findings: ${gitleaks_history_findings}"
    echo "- Containers not covered by a scanned Compose definition: ${#uncovered_containers[@]}"
    echo
    echo "## Targets"
    echo
    echo "| Target | Status | Images | Critical with fix | High with fix | Git history findings |"
    echo "|---|---|---|---|---|---|"
    jq -r '.[] | if .status == "succeeded"
        then "| \(.id) | succeeded | \(.images) | \(.findings.fixable_critical) | \(.findings.fixable_high) | \(.possible_secret_findings) |"
        else "| \(.id) | failed: \(.reason) | - | - | - | - |" end' "${work_root}/targets.json"
    echo
    echo "Detailed evidence is restricted to this private report run."
} >"${staging_root}/summary.md"

rm -rf -- "${work_root:?}"

(
    cd "${staging_root}"
    if command -v sha256sum >/dev/null 2>&1; then
        find . -type f ! -name checksums.sha256 -print0 |
            sort -z |
            xargs -0 sha256sum >checksums.sha256
    else
        find . -type f ! -name checksums.sha256 -print0 |
            sort -z |
            xargs -0 shasum -a 256 >checksums.sha256
    fi
)

find "${staging_root}" -type d -exec chmod 0750 {} +
find "${staging_root}" -type f -exec chmod 0640 {} +

if [[ -e "${final_root}" ]]; then
    echo "A completed run already exists for ${run_id}; refusing to overwrite it."
    exit 1
fi

mv "${staging_root}" "${final_root}"
rm -rf -- "${trivy_tmp_root}"
rmdir "${lock_directory}"
observability_publish_batch_metrics security 1 "${scan_started_epoch}" \
    "${target_metrics[@]}" \
    "${image_metrics[@]}" \
    "homelab07_security_uncovered_containers ${#uncovered_containers[@]}"
trap - EXIT INT TERM

echo
echo "Security evidence published successfully."
echo "  Run ID               : ${run_id}"
echo "  Images scanned       : ${image_count}"
echo "  Failed targets       : ${failed_target_count}"
echo "  Uncovered containers : ${#uncovered_containers[@]}"
echo "  Policy               : report-only"
echo "  Report root          : configured private share"
echo
for ((index = 0; index < ${#result_ids[@]}; index++)); do
    printf '  %-20s : %s\n' "${result_ids[index]}" \
        "${result_statuses[index]}${result_reasons[index]:+ (${result_reasons[index]})}"
done
echo
echo "Review summary.md and manifest.json in the completed private run."

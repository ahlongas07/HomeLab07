#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Vulnerability Management"
print_project_root

action="${1:-scan}"
config_file="${PRIVATE_ROOT}/env/security-scan.env"

case "${action}" in
    preflight|scan) ;;
    *)
        echo "Usage: $0 [preflight|scan]"
        exit 2
        ;;
esac

pass_count=0
failure_count=0

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
    echo "  Pass    : ${pass_count}"
    echo "  Failure : ${failure_count}"
    echo
    echo "Security scan preflight completed successfully."
    exit 0
fi

run_id="$(date -u '+%Y-%m-%dT%H%M%SZ')"
runs_root="${report_real}/runs"
staging_root="${report_real}/.run-${run_id}-$$"
final_root="${runs_root}/${run_id}"
lock_directory="${report_real}/.security-scan.lock"
trivy_tmp_root="${cache_real}/tmp-${run_id}-$$"

if ! mkdir "${lock_directory}" 2>/dev/null; then
    echo "Another security scan holds the report-share lock."
    exit 1
fi

cleanup() {
    local exit_status=$?
    rm -rf -- "${staging_root}"
    rm -rf -- "${trivy_tmp_root}"
    rmdir "${lock_directory}" 2>/dev/null || true
    exit "${exit_status}"
}
trap cleanup EXIT INT TERM

umask 0027
mkdir -p "${runs_root}" "${staging_root}/repository" \
    "${staging_root}/images" "${staging_root}/sbom" "${trivy_tmp_root}"
chmod 0700 "${trivy_tmp_root}"

echo
echo "Rendering Compose definitions and building the image inventory..."
: >"${staging_root}/image-references.txt"

for compose_file in "${compose_files[@]}"; do
    service_id="$(basename "$(dirname "${compose_file}")")"
    compose "${service_id}" config --quiet
    compose "${service_id}" config --images >>"${staging_root}/image-references.txt"
done

sort -u "${staging_root}/image-references.txt" -o "${staging_root}/image-references.txt"
image_count="$(grep -cve '^[[:space:]]*$' "${staging_root}/image-references.txt")"

echo "Running the existing HomeLab07 security policy audit..."
if ! "${PROJECT_ROOT}/operation/security-audit.sh" |
    tee "${staging_root}/platform-audit.txt"; then
    echo
    echo "The platform security audit failed; Trivy scanning was not started."
    echo "Correct the required-control failure and rerun the security scan."
    exit 1
fi

run_trivy() {
    docker run --rm \
        --user "$(id -u):$(id -g)" \
        --read-only \
        --cap-drop ALL \
        --security-opt no-new-privileges \
        --volume "${cache_real}:/cache" \
        --volume "${trivy_tmp_root}:/tmp" \
        --volume "${PROJECT_ROOT}:/workspace:ro" \
        --volume "${staging_root}:/output" \
        "${trivy_image}" \
        --cache-dir /cache \
        --timeout "${scan_timeout}" \
        --quiet \
        "$@"
}

echo "Scanning repository files..."
run_trivy filesystem \
    --scanners vuln,secret,misconfig \
    --severity "${severities}" \
    --format json \
    --output /output/repository/trivy.json \
    /workspace

echo "Scanning complete Git history with fully redacted findings..."
docker run --rm \
    --user "$(id -u):$(id -g)" \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --tmpfs /tmp:rw,noexec,nosuid,size=256m \
    --volume "${PROJECT_ROOT}:/workspace:ro" \
    --volume "${staging_root}:/output" \
    "${gitleaks_image}" \
    git \
    --log-opts="--all --full-history" \
    --redact=100 \
    --report-format json \
    --report-path /output/repository/gitleaks-history.raw.json \
    --exit-code 0 \
    --no-banner \
    /workspace

gitleaks_raw_report="${staging_root}/repository/gitleaks-history.raw.json"
gitleaks_safe_report="${staging_root}/repository/gitleaks-history.json"

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
gitleaks_history_findings="$(jq 'length' "${gitleaks_safe_report}")"

: >"${staging_root}/image-map.ndjson"

while IFS= read -r image_reference; do
    [[ -n "${image_reference}" ]] || continue
    artifact_key="$(sha256_text "${image_reference}")"

    echo "Scanning image ${image_reference}..."
    run_trivy image \
        --image-src remote \
        --scanners vuln,misconfig,secret \
        --image-config-scanners misconfig,secret \
        --severity "${severities}" \
        --format json \
        --output "/output/images/${artifact_key}.json" \
        "${image_reference}"

    echo "Generating SBOM for ${image_reference}..."
    run_trivy image \
        --image-src remote \
        --format cyclonedx \
        --output "/output/sbom/${artifact_key}.cdx.json" \
        "${image_reference}"

    jq -cn \
        --arg image "${image_reference}" \
        --arg key "${artifact_key}" \
        '{image: $image, artifact_key: $key}' >>"${staging_root}/image-map.ndjson"
done <"${staging_root}/image-references.txt"

finding_counts="$({
    printf '%s\n' "${staging_root}/repository/trivy.json"
    find "${staging_root}/images" -type f -name '*.json' -print
} | xargs jq -s '
    [.[].Results[]?] as $results |
    {
      vulnerabilities: ([$results[].Vulnerabilities[]?] | length),
      misconfigurations: ([$results[].Misconfigurations[]?] | length),
      secrets: ([$results[].Secrets[]?] | length),
      critical: ([$results[].Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length),
      high: ([$results[].Vulnerabilities[]? | select(.Severity == "HIGH")] | length)
    }
')"

jq -s '.' "${staging_root}/image-map.ndjson" >"${staging_root}/image-map.json"
git_revision="$(git -C "${PROJECT_ROOT}" rev-parse HEAD)"

jq -n \
    --arg contract_version "1.1.0" \
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
    --argjson images "$(cat "${staging_root}/image-map.json")" \
    --argjson findings "${finding_counts}" \
    --argjson gitleaks_history_findings "${gitleaks_history_findings}" \
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
      images: $images,
      findings: $findings,
      git_history: {
        scope: "all refs and full history",
        evidence: "sanitized metadata only",
        possible_secret_findings: $gitleaks_history_findings
      }
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
    echo "- Misconfigurations: $(jq -r '.misconfigurations' <<<"${finding_counts}")"
    echo "- Secret findings: $(jq -r '.secrets' <<<"${finding_counts}")"
    echo "- Git history possible-secret findings: ${gitleaks_history_findings}"
    echo
    echo "Detailed evidence is restricted to this private report run."
} >"${staging_root}/summary.md"

rm "${staging_root}/image-map.ndjson"

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

chmod 0750 "${staging_root}" "${staging_root}/repository" \
    "${staging_root}/images" "${staging_root}/sbom"
find "${staging_root}" -type f -exec chmod 0640 {} +

if [[ -e "${final_root}" ]]; then
    echo "A completed run already exists for ${run_id}; refusing to overwrite it."
    exit 1
fi

mv "${staging_root}" "${final_root}"
rm -rf -- "${trivy_tmp_root}"
trap - EXIT INT TERM
rmdir "${lock_directory}"

echo
echo "Security evidence published successfully."
echo "  Run ID         : ${run_id}"
echo "  Images scanned : ${image_count}"
echo "  Policy          : report-only"
echo "  Report root     : configured private share"
echo
echo "Review summary.md and manifest.json in the completed private run."

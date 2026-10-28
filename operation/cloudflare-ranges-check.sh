#!/usr/bin/env bash
# Read-only comparison of the versioned Cloudflare ranges with the ranges
# Cloudflare publishes. Exits non-zero when they differ or cannot be fetched.

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Cloudflare Ranges Check"
print_project_root

readonly RANGES_FILE="${PROJECT_ROOT}/services/caddy/cloudflare-ranges.env"

versioned="$(awk -F= '$1 == "CLOUDFLARE_RANGES" { print $2 }' "${RANGES_FILE}" |
    tr ' ' '\n' | sed '/^$/d' | sort)"

if ! published="$(
    curl -fsS --max-time 20 https://www.cloudflare.com/ips-v4
    echo
    curl -fsS --max-time 20 https://www.cloudflare.com/ips-v6
)"; then
    echo "[FAIL] Published Cloudflare ranges could not be fetched"
    exit 1
fi
published="$(sed '/^$/d' <<<"${published}" | sort)"

added="$(comm -13 <(printf '%s\n' "${versioned}") <(printf '%s\n' "${published}"))"
removed="$(comm -23 <(printf '%s\n' "${versioned}") <(printf '%s\n' "${published}"))"

if [[ -z "${added}" && -z "${removed}" ]]; then
    echo "[PASS] Versioned ranges match the $(grep -c . <<<"${published}") published Cloudflare ranges"
    exit 0
fi

[[ -z "${added}" ]] || echo "[FAIL] Published but not versioned: $(paste -sd ' ' - <<<"${added}")"
[[ -z "${removed}" ]] || echo "[FAIL] Versioned but no longer published: $(paste -sd ' ' - <<<"${removed}")"
echo
echo "Update services/caddy/cloudflare-ranges.env through a reviewed change,"
echo "then recreate Caddy so the new ranges apply."
exit 1

#!/usr/bin/env bash

# Read-only audit of Nginx Proxy Manager access lists and SSL.
#
# Compares what the NPM database says each proxy host should enforce (access
# list rules, basic-auth users, certificate, forced HTTPS) with the Nginx
# configuration NPM actually rendered. Upstream issue #5919 can render a host
# without its allow/deny rules or SSL while the UI shows them as applied.
#
# Output identifies hosts, access lists and certificates by numeric ID only:
# no domain, address, user name, password or key material is printed.

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Nginx Proxy Manager Access Audit"
print_project_root

if (($# != 0)); then
    echo "Usage: $0"
    exit 1
fi

readonly NPM_ENV="${PRIVATE_ROOT}/env/nginx-proxy-manager.env"
readonly NPM_CONTAINER=homelab07-nginx-proxy-manager
readonly DB_CONTAINER=homelab07-mariadb
readonly EXPIRY_WARNING_SECONDS=1209600

pass_count=0
warning_count=0
failure_count=0

pass() {
    echo "[PASS] $1"
    pass_count=$((pass_count + 1))
}

warn() {
    echo "[WARN] $1"
    warning_count=$((warning_count + 1))
}

fail() {
    echo "[FAIL] $1"
    failure_count=$((failure_count + 1))
}

read_value() { awk -v key="$2" 'index($0, key "=") == 1 { print substr($0, length(key) + 2); exit }' "$1"; }

[[ -f "${NPM_ENV}" ]] || { echo "Missing private environment file for nginx-proxy-manager."; exit 1; }
db_name="$(read_value "${NPM_ENV}" NPM_DB_NAME)"
db_user="$(read_value "${NPM_ENV}" NPM_DB_USER)"
db_password="$(read_value "${NPM_ENV}" NPM_DB_PASSWORD)"
for identifier in "${db_name}" "${db_user}"; do
    [[ "${identifier}" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid NPM database name or user in the private configuration."; exit 1; }
done
[[ -n "${db_password}" ]] || { echo "Missing NPM_DB_PASSWORD in the private configuration."; exit 1; }

for container in "${NPM_CONTAINER}" "${DB_CONTAINER}"; do
    if [[ "$(docker inspect -f '{{.State.Running}}' "${container}" 2>/dev/null || true)" != "true" ]]; then
        echo "Required container is not running: ${container#homelab07-}"
        exit 1
    fi
done

# --- Expected state from the NPM database ------------------------------------
# Columns: host, enabled, access list, list missing, client rules, auth users,
# certificate, certificate provider, certificate missing, forced SSL,
# per-path access lists.
expected="$(MYSQL_PWD="${db_password}" docker exec -i -e MYSQL_PWD "${DB_CONTAINER}" \
    mariadb -u "${db_user}" -N -B "${db_name}" <<'SQL'
SELECT p.id,
       p.enabled,
       p.access_list_id,
       IF(p.access_list_id > 0 AND (a.id IS NULL OR a.is_deleted = 1), 1, 0),
       (SELECT COUNT(*) FROM access_list_client r WHERE r.access_list_id = p.access_list_id),
       (SELECT COUNT(*) FROM access_list_auth u WHERE u.access_list_id = p.access_list_id),
       p.certificate_id,
       COALESCE(c.provider, '-'),
       IF(p.certificate_id > 0 AND (c.id IS NULL OR c.is_deleted = 1), 1, 0),
       p.ssl_forced,
       IF(COALESCE(p.locations, '') REGEXP '"access_list_id": *[1-9]', 1, 0)
FROM proxy_host p
LEFT JOIN access_list a ON a.id = p.access_list_id
LEFT JOIN certificate c ON c.id = p.certificate_id
WHERE p.is_deleted = 0
ORDER BY p.id;
SQL
)"
unset db_password

# --- Rendered state from the NPM container -----------------------------------
# Only counts and numeric IDs leave the container; configuration text does not.
# Columns: host, server blocks, 443 listeners, certificate IDs, access rule
# totals, deny all, access blocks, basic-auth list IDs, force-SSL includes.
rendered="$(docker exec "${NPM_CONTAINER}" sh -c '
for f in /data/nginx/proxy_host/*.conf; do
    [ -f "$f" ] || continue
    id="$(basename "$f" .conf)"
    case "$id" in *[!0-9]*) continue ;; esac
    servers="$(grep -cE "^[[:space:]]*server[[:space:]]*\{" "$f")"
    listen443="$(grep -cE "^[[:space:]]*listen 443 ssl" "$f")"
    certs="$(grep -oE "ssl_certificate /(etc/letsencrypt/live|data/custom_ssl)/npm-[0-9]+/fullchain\.pem" "$f" \
        | grep -oE "npm-[0-9]+" | cut -d- -f2 | sort -u | paste -sd, -)"
    rules="$(grep -oE "# Access Rules: [0-9]+ total" "$f" | grep -oE "[0-9]+" | paste -sd, -)"
    deny_all="$(grep -cE "^[[:space:]]*deny all;" "$f")"
    access_blocks="$(grep -c "# Access checks must" "$f")"
    auth="$(grep -oE "auth_basic_user_file[[:space:]]+/data/access/[0-9]+" "$f" \
        | grep -oE "[0-9]+$" | sort -u | paste -sd, -)"
    force_ssl="$(grep -c "include conf.d/include/force-ssl.conf" "$f")"
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$id" "$servers" "$listen443" \
        "${certs:--}" "${rules:--}" "$deny_all" "$access_blocks" "${auth:--}" "$force_ssl"
done')"

# Certificate validity by numeric ID: valid, expiring (< 14 days) or expired.
certificate_state="$(docker exec "${NPM_CONTAINER}" sh -c '
for c in /etc/letsencrypt/live/npm-*/fullchain.pem /data/custom_ssl/npm-*/fullchain.pem; do
    [ -f "$c" ] || continue
    id="$(basename "$(dirname "$c")" | cut -d- -f2)"
    if ! openssl x509 -checkend 0 -noout -in "$c" >/dev/null 2>&1; then
        state=expired
    elif ! openssl x509 -checkend '"${EXPIRY_WARNING_SECONDS}"' -noout -in "$c" >/dev/null 2>&1; then
        state=expiring
    else
        state=valid
    fi
    printf "%s\t%s\n" "$id" "$state"
done')"

# Field of the row whose first column is the given ID, or the default.
lookup() {
    local table="$1" id="$2" column="$3" default="$4"
    awk -F '\t' -v id="${id}" -v column="${column}" -v default="${default}" \
        '$1 == id { print $column; found = 1; exit } END { if (!found) print default }' <<<"${table}"
}

if docker exec "${NPM_CONTAINER}" nginx -t >/dev/null 2>&1; then
    pass "Nginx configuration test passes"
else
    fail "Nginx configuration test fails"
fi

restricted_count=0
https_count=0

echo
echo "Proxy hosts"
echo

while IFS=$'\t' read -r id enabled list_id list_missing client_rules auth_users \
    cert_id cert_provider cert_missing ssl_forced per_path; do
    [[ -n "${id}" ]] || continue
    host="proxy host ${id}"
    servers="$(lookup "${rendered}" "${id}" 2 0)"
    listen443="$(lookup "${rendered}" "${id}" 3 0)"
    certs="$(lookup "${rendered}" "${id}" 4 -)"
    rules="$(lookup "${rendered}" "${id}" 5 -)"
    deny_all="$(lookup "${rendered}" "${id}" 6 0)"
    access_blocks="$(lookup "${rendered}" "${id}" 7 0)"
    auth="$(lookup "${rendered}" "${id}" 8 -)"
    force_ssl="$(lookup "${rendered}" "${id}" 9 0)"

    if [[ "${enabled}" != "1" ]]; then
        if ((servers > 0)); then
            fail "${host}: disabled in NPM but still rendered and served"
        else
            pass "${host}: disabled and not served"
        fi
        continue
    fi

    if ((servers == 0)); then
        fail "${host}: enabled but no rendered server block"
        continue
    fi

    # Access list: every rendered rule block must carry the stored rule count
    # and end in deny all; otherwise the host is open.
    if ((list_id > 0)); then
        restricted_count=$((restricted_count + 1))
        if ((list_missing == 1)); then
            fail "${host}: assigned access list ${list_id} no longer exists"
        elif ((client_rules == 0 && auth_users == 0)); then
            warn "${host}: access list ${list_id} has no rules or users and restricts nothing"
        else
            if ((access_blocks == 0)); then
                fail "${host}: access list ${list_id} assigned but not rendered; host is open"
            fi
            if ((client_rules > 0)); then
                rule_blocks=0
                stale=false
                if [[ "${rules}" != "-" ]]; then
                    IFS=, read -r -a totals <<<"${rules}"
                    rule_blocks=${#totals[@]}
                    for total in "${totals[@]}"; do
                        [[ "${total}" == "${client_rules}" ]] || stale=true
                    done
                fi
                if ((rule_blocks == 0)); then
                    fail "${host}: access list ${list_id} has ${client_rules} rule(s) but none rendered; host is open"
                elif [[ "${stale}" == true ]]; then
                    fail "${host}: access list ${list_id} rendered with a rule count other than ${client_rules}"
                elif ((deny_all < rule_blocks)); then
                    fail "${host}: access list ${list_id} rendered without deny all"
                else
                    pass "${host}: access list ${list_id} rendered (${client_rules} rule(s), deny all)"
                fi
            fi
            if ((auth_users > 0)); then
                if [[ ",${auth}," == *",${list_id},"* ]]; then
                    pass "${host}: access list ${list_id} basic authentication rendered"
                else
                    fail "${host}: access list ${list_id} has ${auth_users} user(s) but no basic authentication rendered"
                fi
            fi
        fi
    fi
    if ((per_path == 1)); then
        warn "${host}: per-path access lists in custom locations; review them manually"
    fi

    # HTTPS: an assigned certificate must be rendered with a 443 listener.
    if ((cert_id > 0)); then
        https_count=$((https_count + 1))
        if ((cert_missing == 1)); then
            fail "${host}: assigned certificate ${cert_id} no longer exists"
        elif ((listen443 == 0)) || [[ ",${certs}," != *",${cert_id},"* ]]; then
            fail "${host}: certificate ${cert_id} assigned but SSL not rendered"
        else
            case "$(lookup "${certificate_state}" "${cert_id}" 2 missing)" in
                valid) pass "${host}: SSL rendered with certificate ${cert_id} (${cert_provider})" ;;
                expiring) warn "${host}: certificate ${cert_id} expires within 14 days" ;;
                expired) fail "${host}: certificate ${cert_id} has expired" ;;
                *) fail "${host}: certificate ${cert_id} file is missing" ;;
            esac
        fi
        if ((ssl_forced == 1)); then
            if ((force_ssl > 0)); then
                pass "${host}: HTTPS redirect rendered"
            else
                fail "${host}: Force SSL enabled but HTTPS redirect not rendered"
            fi
        else
            warn "${host}: certificate assigned but Force SSL disabled; HTTP is also served"
        fi
    else
        warn "${host}: no certificate; served over HTTP only"
    fi
done <<<"${expected}"

while IFS=$'\t' read -r id servers _; do
    [[ -n "${id}" ]] || continue
    if ((servers > 0)) && [[ "$(lookup "${expected}" "${id}" 1 -)" == "-" ]]; then
        fail "proxy host ${id}: rendered configuration without an active host in the database"
    fi
done <<<"${rendered}"

echo
echo "Summary"
echo "  Hosts with access lists : ${restricted_count}"
echo "  Hosts with certificates : ${https_count}"
echo "  Pass                    : ${pass_count}"
echo "  Warning                 : ${warning_count}"
echo "  Failure                 : ${failure_count}"

if ((failure_count > 0)); then
    echo
    echo "Access or SSL enforcement differs from the NPM database."
    echo "Block the failing hosts before continuing; see the NPM README."
    exit 1
fi

echo
echo "Nginx Proxy Manager access audit completed successfully."

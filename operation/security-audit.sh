#!/usr/bin/env bash

source "${BASH_SOURCE%/*}/lib.sh"

print_header "Read-only Security Audit"
print_project_root

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

section() {
    echo
    echo "$1"
    echo
}

is_private_ipv4() {
    local address="$1"
    local first second third fourth octet

    [[ "${address}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS=. read -r first second third fourth <<<"${address}"
    for octet in "${first}" "${second}" "${third}" "${fourth}"; do
        ((10#${octet} >= 0 && 10#${octet} <= 255)) || return 1
    done

    ((10#${first} == 10)) ||
        ((10#${first} == 192 && 10#${second} == 168)) ||
        ((10#${first} == 172 && 10#${second} >= 16 && 10#${second} <= 31))
}

compose_files=("${PROJECT_ROOT}"/services/*/compose.yaml)

section "Repository policy"

if ((${#compose_files[@]} > 0)); then
    pass "Compose definitions discovered: ${#compose_files[@]}"
else
    fail "No service Compose definitions were discovered"
fi

port_files=()
host_network_files=()
mutable_image_count=0

for compose_file in "${compose_files[@]}"; do
    service_id="$(basename "$(dirname "${compose_file}")")"

    if grep -Eq '^[[:space:]]+ports:[[:space:]]*$' "${compose_file}"; then
        port_files+=("${service_id}")
    fi

    if grep -Eq '^[[:space:]]+network_mode:[[:space:]]+host[[:space:]]*$' "${compose_file}"; then
        host_network_files+=("${service_id}")
    fi

    while IFS= read -r image_reference; do
        image_reference="${image_reference#*image:}"
        image_reference="${image_reference#${image_reference%%[![:space:]]*}}"
        if [[ "${image_reference}" != *'@sha256:'* ]]; then
            mutable_image_count=$((mutable_image_count + 1))
        fi
    done < <(grep -E '^[[:space:]]+image:[[:space:]]+' "${compose_file}" || true)
done

if ((${#port_files[@]} == 2)) &&
    [[ " ${port_files[*]} " == *" nginx-proxy-manager "* ]] &&
    [[ " ${port_files[*]} " == *" observability "* ]]; then
    pass "Only Nginx Proxy Manager and LAN-only Grafana declare host port mappings"
else
    fail "Unexpected Compose host-port owner count: ${#port_files[@]}"
fi

npm_compose="${PROJECT_ROOT}/services/nginx-proxy-manager/compose.yaml"
for mapping in '80:80' '443:443'; do
    if grep -Fq "\"${mapping}\"" "${npm_compose}"; then
        pass "Nginx Proxy Manager declares approved mapping ${mapping}"
    else
        fail "Nginx Proxy Manager is missing approved mapping ${mapping}"
    fi
done

if grep -Fq '"${NPM_MANAGEMENT_BIND_ADDRESS:?NPM_MANAGEMENT_BIND_ADDRESS is required}:81:81"' "${npm_compose}"; then
    pass "Nginx Proxy Manager administration requires an explicit host bind address"
else
    fail "Nginx Proxy Manager administration is not bound through the required private setting"
fi

observability_compose="${PROJECT_ROOT}/services/observability/compose.yaml"
if grep -Fq '"${GRAFANA_LAN_BIND_ADDRESS:?GRAFANA_LAN_BIND_ADDRESS is required}:${GRAFANA_LAN_PORT:-3000}:3000"' "${observability_compose}"; then
    pass "Grafana requires an explicit host bind address"
else
    fail "Grafana is not bound through the required private LAN setting"
fi

if grep -Eq '^[[:space:]]+ports:[[:space:]]*$' "${observability_compose}" &&
    [[ "$(grep -Ec '^[[:space:]]+- .*:3000' "${observability_compose}")" == "1" ]]; then
    pass "Grafana is the sole host-port owner in the observability stack"
else
    fail "Observability host-port ownership differs from policy"
fi

if grep -A2 '^[[:space:]]*homelab07-observability:' "${observability_compose}" |
    grep -Eq '^[[:space:]]+internal:[[:space:]]+true[[:space:]]*$'; then
    pass "The dedicated observability network is internal"
else
    fail "The dedicated observability network is not marked internal"
fi

if ((${#host_network_files[@]} == 1)) && [[ "${host_network_files[0]}" == "homebridge" ]]; then
    pass "EXC-HB-HOST: Homebridge is the sole host-networking service"
else
    fail "Unexpected host-networking service count: ${#host_network_files[@]}"
fi

if grep -RqsE '^[[:space:]]+privileged:[[:space:]]+true[[:space:]]*$' \
    "${PROJECT_ROOT}/services"; then
    fail "A privileged service definition was detected"
else
    pass "No privileged service definition was detected"
fi

if grep -RqsE 'docker\.sock' "${PROJECT_ROOT}/services"; then
    fail "A Docker socket reference was detected"
else
    pass "No Docker socket reference was detected"
fi

if ((mutable_image_count == 0)); then
    pass "All image references declare immutable SHA-256 digests"
else
    warn "EXC-IMAGE-MUTABLE: ${mutable_image_count} version-pinned or unresolved image reference(s) do not declare an immutable SHA-256 digest"
fi

for service_id in mariadb valkey; do
    compose_file="${PROJECT_ROOT}/services/${service_id}/compose.yaml"
    if grep -Eq '^[[:space:]]+ports:[[:space:]]*$|^[[:space:]]+expose:[[:space:]]*$' "${compose_file}"; then
        fail "${service_id} declares an application or host port"
    else
        pass "${service_id} declares no application or host port"
    fi
done

for service_id in jellyfin landing-page nextcloud paperless-ngx; do
    compose_file="${PROJECT_ROOT}/services/${service_id}/compose.yaml"
    if grep -Eq '^[[:space:]]+ports:[[:space:]]*$' "${compose_file}"; then
        fail "${service_id} bypasses the reverse proxy with a host port"
    elif grep -q 'homelab07-proxy' "${compose_file}"; then
        pass "${service_id} reaches publication through the proxy network"
    else
        fail "${service_id} lacks the expected proxy-network membership"
    fi
done

if git -C "${PROJECT_ROOT}" ls-files | grep -Eq '(^|/)HomeLab07\.private/|(^|/)\.env$'; then
    fail "A private configuration path or environment file is tracked by Git"
else
    pass "No private configuration path or environment file is tracked by Git"
fi

section "Private configuration"

if [[ ! -d "${PRIVATE_ROOT}/env" || ! -d "${PRIVATE_ROOT}/secrets" ]]; then
    warn "Private env or secrets directory is unavailable; permission checks skipped"
else
    insecure_private_files=0
    while IFS= read -r -d '' private_file; do
        permissions="$(stat -c '%a' "${private_file}" 2>/dev/null || stat -f '%Lp' "${private_file}" 2>/dev/null || true)"
        if [[ "${permissions}" =~ ^[0-7]{3,4}$ ]] && ((10#${permissions} % 100 != 0)); then
            insecure_private_files=$((insecure_private_files + 1))
        fi
    done < <(find "${PRIVATE_ROOT}/env" "${PRIVATE_ROOT}/secrets" -type f -print0 2>/dev/null || true)

    if ((insecure_private_files == 0)); then
        pass "Private env and secret files are not accessible to group or other users"
    else
        fail "Private configuration files with broad permissions: ${insecure_private_files}"
    fi
fi

section "Runtime posture"

if ! command -v docker >/dev/null 2>&1; then
    warn "Docker CLI unavailable; runtime checks skipped"
elif ! docker info >/dev/null 2>&1; then
    warn "Docker daemon unavailable; runtime checks skipped"
else
    mapfile_supported=true
    if ! command -v mapfile >/dev/null 2>&1; then
        mapfile_supported=false
    fi

    container_names=()
    if [[ "${mapfile_supported}" == true ]]; then
        mapfile -t container_names < <(docker ps -a --filter 'name=homelab07-' --format '{{.Names}}')
    else
        while IFS= read -r container_name; do
            [[ -n "${container_name}" ]] && container_names+=("${container_name}")
        done < <(docker ps -a --filter 'name=homelab07-' --format '{{.Names}}')
    fi

    if ((${#container_names[@]} == 0)); then
        warn "No HomeLab07 runtime containers were detected"
    else
        pass "HomeLab07 runtime containers discovered: ${#container_names[@]}"

        runtime_failures=0
        unhealthy_count=0
        restarting_count=0
        runtime_host_network=0

        for container_name in "${container_names[@]}"; do
            privileged="$(docker inspect -f '{{.HostConfig.Privileged}}' "${container_name}")"
            network_mode="$(docker inspect -f '{{.HostConfig.NetworkMode}}' "${container_name}")"
            state="$(docker inspect -f '{{.State.Status}}' "${container_name}")"
            health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${container_name}")"
            socket_mount="$(docker inspect -f '{{range .Mounts}}{{if eq .Source "/var/run/docker.sock"}}yes{{end}}{{end}}' "${container_name}")"

            [[ "${privileged}" == "true" ]] && runtime_failures=$((runtime_failures + 1))
            [[ "${socket_mount}" == "yes" ]] && runtime_failures=$((runtime_failures + 1))
            [[ "${network_mode}" == "host" ]] && runtime_host_network=$((runtime_host_network + 1))
            [[ "${health}" == "unhealthy" ]] && unhealthy_count=$((unhealthy_count + 1))
            [[ "${state}" == "restarting" ]] && restarting_count=$((restarting_count + 1))
        done

        if ((runtime_failures == 0)); then
            pass "Running definitions use no privileged mode or Docker socket mount"
        else
            fail "Runtime privileged/socket violations detected: ${runtime_failures}"
        fi

        if ((runtime_host_network == 1)); then
            pass "Runtime host-network exception count matches policy"
        else
            fail "Runtime host-network exception count is ${runtime_host_network}; expected 1"
        fi

        if ((unhealthy_count == 0 && restarting_count == 0)); then
            pass "No unhealthy or restarting container was detected"
        else
            fail "Unhealthy containers: ${unhealthy_count}; restarting containers: ${restarting_count}"
        fi
    fi

    npm_container="homelab07-nginx-proxy-manager"
    if docker inspect "${npm_container}" >/dev/null 2>&1; then
        runtime_bindings="$(docker inspect -f '{{json .HostConfig.PortBindings}}' "${npm_container}")"
        npm_management_host_ip="$(jq -r '."81/tcp"[0].HostIp // empty' <<<"${runtime_bindings}")"
        if [[ "${runtime_bindings}" == *'80/tcp'* && "${runtime_bindings}" == *'443/tcp'* && "${runtime_bindings}" == *'81/tcp'* ]]; then
            pass "Runtime Nginx Proxy Manager mappings include 80, 443 and 81"
        else
            fail "Runtime Nginx Proxy Manager mappings differ from policy"
        fi

        if [[ -n "${npm_management_host_ip}" &&
            "${npm_management_host_ip}" != "0.0.0.0" &&
            "${npm_management_host_ip}" != "::" ]]; then
            pass "Runtime Nginx Proxy Manager administration is bound to an explicit host address"
        else
            fail "Runtime Nginx Proxy Manager administration uses a wildcard host binding"
        fi

        certificate_dates="$(docker exec "${npm_container}" sh -c \
            'for certificate in /etc/letsencrypt/live/*/fullchain.pem; do [ -f "$certificate" ] && openssl x509 -enddate -noout -in "$certificate" 2>/dev/null; done' \
            2>/dev/null || true)"
        certificate_count="$(printf '%s\n' "${certificate_dates}" | grep -c '^notAfter=' || true)"
        if ((certificate_count > 0)); then
            pass "Certificate expiry metadata is readable for ${certificate_count} certificate(s)"
        else
            warn "Certificate expiry metadata could not be read"
        fi
    else
        warn "Nginx Proxy Manager container is unavailable; mapping and certificate checks skipped"
    fi

    grafana_container="homelab07-grafana"
    if docker inspect "${grafana_container}" >/dev/null 2>&1; then
        grafana_bindings="$(docker inspect -f '{{json .HostConfig.PortBindings}}' "${grafana_container}")"
        grafana_host_ip="$(jq -r '."3000/tcp"[0].HostIp // empty' <<<"${grafana_bindings}")"
        if is_private_ipv4 "${grafana_host_ip}"; then
            pass "Runtime Grafana administration is bound to an RFC1918 host address"
        else
            fail "Runtime Grafana administration lacks the required RFC1918 host binding"
        fi

        observability_port_failure=0
        for internal_container in homelab07-prometheus homelab07-loki homelab07-alloy; do
            if docker inspect "${internal_container}" >/dev/null 2>&1 &&
                [[ -n "$(docker port "${internal_container}" 2>/dev/null || true)" ]]; then
                observability_port_failure=$((observability_port_failure + 1))
            fi
        done
        if ((observability_port_failure == 0)); then
            pass "Prometheus, Loki and Alloy publish no runtime host ports"
        else
            fail "Internal observability services publish host ports"
        fi
    else
        warn "Grafana container is unavailable; LAN binding checks skipped"
    fi
fi

section "External validation boundary"

warn "EXT-WAN: confirm externally that only approved gateway ports are reachable"
warn "EXT-NPM81: confirm port 81 is denied outside approved management networks"
warn "EXT-GRAFANA: confirm the Grafana port is reachable only from approved LANs"
warn "EXT-EDGE: confirm proxied routes use edge controls and direct-origin requests are denied"
warn "EXT-DNS-ONLY: validate DNS-only services independently; edge controls do not apply"

echo
echo "Summary"
echo "  Pass     : ${pass_count}"
echo "  Warning  : ${warning_count}"
echo "  Failure  : ${failure_count}"
echo

if ((failure_count > 0)); then
    echo "Security audit failed. No state was changed."
    exit 1
fi

echo "Security audit completed without required-control failures."
echo "Warnings identify documented exceptions or checks requiring external evidence."

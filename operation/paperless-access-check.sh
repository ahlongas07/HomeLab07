#!/usr/bin/env bash

# Read-only isolation checks for a Paperless-ngx API token (Sprint 019).
#
# Usage: ./operation/paperless-access-check.sh juanchoai|medical-reader
#
# The token is read from stdin (hidden prompt on a terminal), never from an
# argument, and is sent only to Paperless-ngx inside its own container. Only
# counts are printed: no titles, names or token.

source "${BASH_SOURCE%/*}/lib.sh"

readonly CONTAINER="homelab07-paperless-ngx"
readonly profile="${1:-}"

[[ "${profile}" == "juanchoai" || "${profile}" == "medical-reader" ]] || {
    echo "Usage: $0 juanchoai|medical-reader" >&2
    exit 2
}

print_header "Paperless Access Check (${profile})"

if [[ -t 0 ]]; then
    read -r -s -p "Paperless API token for the ${profile} user: " token
    echo
else
    read -r token || true
fi
[[ -n "${token}" ]] || { echo "An API token is required on stdin."; exit 1; }

CHECK="$(cat <<'PY'
import json, sys, urllib.error, urllib.request

profile, token = sys.argv[1], sys.stdin.readline().strip()
BASE = "http://localhost:8000"
HEADERS = {"Authorization": f"Token {token}", "Accept": "application/json; version=10"}
results = []


def get(path, **query):
    query = "&".join(f"{key}={value}" for key, value in query.items())
    request = urllib.request.Request(f"{BASE}{path}?{query}", headers=HEADERS)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, None


def items(path):
    """Every item of a list endpoint, or None when the request is refused."""
    found, page = [], 1
    while True:
        status, data = get(path, page=page, page_size=100)
        if status != 200:
            return None
        found += data.get("results", [])
        if not data.get("next"):
            return found
        page += 1


def count(path, **query):
    status, data = get(path, page_size=1, **query)
    return data.get("count") if status == 200 else f"HTTP {status}"


def check(check_id, text, ok, detail):
    results.append(ok)
    print(f"{'PASS' if ok else 'FAIL'} {check_id} {text}: {detail}")


if profile == "juanchoai":
    value = count("/api/documents/")
    check("ISO-02", "documents visible", value == 0, value)
    value = count("/api/documents/", query="examen")
    check("ISO-02", "documents matching 'examen'", value == 0, value)
    for path in ("/api/tags/", "/api/document_types/"):
        objects = items(path)
        # user_can_change is true only for the owner or an unowned object,
        # because juanchoai has no change permission on these models.
        foreign = None if objects is None else sum(
            1 for o in objects if o.get("owner") is None or not o.get("user_can_change"))
        check("ISO-03", f"{path} only its own", objects is not None and foreign == 0,
              "refused" if objects is None else f"{len(objects)} visible, {foreign} not its own")
    for path in ("/api/tasks/", "/api/correspondents/"):
        status, _ = get(path)
        check("ISO-04", f"{path} refused", status == 403, f"HTTP {status}")
else:
    tags = items("/api/tags/")
    medical = [t for t in tags or [] if t.get("name") == "medico"]
    owner = medical[0].get("owner") if len(medical) == 1 else None
    check("ISO-06", "medico tag visible", owner is not None,
          "refused" if tags is None else f"{len(medical)} found")
    for path in ("/api/tags/", "/api/correspondents/"):
        objects = tags if path == "/api/tags/" else items(path)
        foreign = None if objects is None else sum(
            1 for o in objects if o.get("owner") not in (owner, None))
        check("ISO-06", f"{path} only the exam owner", owner is not None and foreign == 0,
              "refused" if objects is None else f"{len(objects)} visible, {foreign} of another owner")
        unowned = sum(1 for o in objects or [] if o.get("owner") is None)
        if unowned:
            print(f"WARN {path}: {unowned} without owner, visible to every user with the model permission")
    value = count("/api/documents/")
    check("ISO-06", "exams still visible", isinstance(value, int) and value > 0, value)

print(f"{sum(results)}/{len(results)} checks passed")
sys.exit(0 if all(results) else 1)
PY
)"
readonly CHECK

status=0
printf '%s\n' "${token}" | docker exec -i "${CONTAINER}" python3 -c "${CHECK}" "${profile}" || status=$?
unset token

if [[ "${status}" -ne 0 ]]; then
    echo
    echo "Access check failed."
    exit "${status}"
fi
print_footer

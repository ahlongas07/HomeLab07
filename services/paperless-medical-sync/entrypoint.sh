#!/bin/sh
# HomeLab07 medical exam sync scheduler (Sprint 015).
#
# Without arguments: run the sync now, then once a day at SYNC_HOUR. A failed
# run never stops the loop, so the container cannot enter a restart loop.
# With arguments: run that command instead (for example model-init).

set -u

readonly heartbeat=/run/sync/heartbeat
readonly retry_seconds="${SYNC_RETRY_SECONDS:-3600}"

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# After a NAS reboot the sync may start before Paperless is ready.
medical-sync wait-ready

while :; do
    date +%s >"${heartbeat}"
    medical-sync sync
    status=$?
    date +%s >"${heartbeat}"

    if [ "${status}" -eq 75 ]; then
        delay="${retry_seconds}"
        echo "Paperless unreachable; next attempt in ${delay} seconds."
    else
        delay="$(medical-sync next-delay)" || delay=86400
        echo "Sync finished with status ${status}; next run in ${delay} seconds."
    fi

    sleep "${delay}"
done

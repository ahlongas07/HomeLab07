#!/bin/sh
# HomeLab07 quote archive sync scheduler (Sprint 020).
#
# Without arguments: run the sync now, then whenever the quotes folder changes
# and settles, and in any case once a day at QUOTE_SYNC_HOUR. While Paperless
# is unreachable (75), a run failed or an upload is still unconfirmed (4), the
# next attempt comes after QUOTE_RETRY_SECONDS instead. A failed run never
# stops the loop, so the container cannot enter a restart loop.
# With arguments: run that command instead (for example check-model).

set -u

readonly heartbeat=/run/sync/heartbeat
readonly retry_seconds="${QUOTE_RETRY_SECONDS:-120}"

if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# After a NAS reboot the sync may start before Paperless is ready.
quote-sync wait-ready

while :; do
    date +%s >"${heartbeat}"
    quote-sync sync
    status=$?
    date +%s >"${heartbeat}"

    if [ "${status}" -eq 75 ] || [ "${status}" -eq 4 ]; then
        delay="${retry_seconds}"
        echo "Sync finished with status ${status}; next attempt in ${delay} seconds."
    else
        delay="$(quote-sync next-delay)" || delay=86400
        echo "Sync finished with status ${status}; watching for changes, daily run in ${delay} seconds."
    fi
    # The watcher keeps the heartbeat fresh; the daily run is the fallback.
    quote-sync wait-change "${delay}" || sleep "${delay}"
done

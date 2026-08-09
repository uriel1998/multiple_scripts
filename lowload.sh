#!/bin/bash

##############################################################################
#
# lowload.sh
# Wait for system load to fall below a threshold, then submit a command
# to task-spooler.
#
##############################################################################

MAXLOAD=2.0
CHECK_INTERVAL=20

if (( $# < 2 )); then
    echo "Usage: $0 LABEL COMMAND [ARGS...]" >&2
    exit 2
fi

label="$1"
shift

lockfile="/tmp/lowload-${label}"
tsp=$(command -v tsp) || {
    echo "task-spooler (tsp) not found" >&2
    exit 1
}

if ! ( set -o noclobber; > "$lockfile" ) 2>/dev/null; then
    echo "Process '$label' is already waiting to execute." >&2
    exit 99
fi

cleanup()
{
    rm -f "$lockfile"
}

trap cleanup EXIT INT TERM HUP

while :; do
    load=$(awk '{print $1}' /proc/loadavg)

    if awk -v load="$load" -v max="$MAXLOAD" \
        'BEGIN { exit !(load <= max) }'
    then
        break
    fi

    echo "[$label] load is $load; waiting for load <= $MAXLOAD"
    sleep "$CHECK_INTERVAL"
done

echo "[$label] load is $load; submitting job"

"$tsp" -L "$label" -- "$@"

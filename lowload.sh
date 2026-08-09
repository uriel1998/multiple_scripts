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

tsp=$(command -v tsp) || {
    echo "task-spooler (tsp) not found" >&2
    exit 1
}

show_help()
{
    cat <<EOF
Usage: $0 LABEL COMMAND [ARGS...]

Wait until the 1-minute system load average is at or below ${MAXLOAD}, then
submit COMMAND to task-spooler using LABEL as the task-spooler label.

Arguments:
  LABEL           Name used for task-spooler locking and tsp -L.
                  A second lowload process with the same label will exit
                  instead of waiting in parallel. Slashes are sanitized for
                  the temporary lock filename.
  COMMAND [ARGS]  Command to enqueue once the load threshold is met.

Behavior:
  - Checks /proc/loadavg every ${CHECK_INTERVAL} seconds.
  - Uses the 1-minute load average only.
  - Requires task-spooler ('tsp') to be installed and available in PATH.
  - Exits with an error if current load cannot be read.

Examples:
  $0 nightly-updates updatedb
  $0 video-encode ffmpeg -i input.mkv output.mp4

Exit codes:
  1   Runtime failure such as missing tsp or unreadable /proc/loadavg
  2   Invalid usage
  99  Another lowload process with the same label is already waiting
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

if (( $# < 2 )); then
    echo "Usage: $0 LABEL COMMAND [ARGS...]" >&2
    exit 2
fi

label="$1"
shift

safe_label=${label//\//_}
lockfile="/tmp/lowload-${safe_label}"

if [[ -z "$label" ]]; then
    echo "Label must not be empty" >&2
    exit 2
fi

if ! ( set -o noclobber; : > "$lockfile" ) 2>/dev/null; then
    echo "Process '$label' is already waiting to execute." >&2
    exit 99
fi

cleanup()
{
    rm -f "$lockfile"
}

trap cleanup EXIT INT TERM HUP

while :; do
    current_load=$(awk '{print $1}' /proc/loadavg 2>/dev/null)

    if [[ -z "$current_load" ]]; then
        echo "[$label] unable to read current load from /proc/loadavg" >&2
        exit 1
    fi

    if awk -v current="$current_load" -v max="$MAXLOAD" \
        'BEGIN { exit !(current <= max) }'
    then
        break
    fi

    echo "[$label] load is $current_load; waiting for load <= $MAXLOAD"
    sleep "$CHECK_INTERVAL"
done

echo "[$label] load is $current_load; submitting job"

"$tsp" -L "$label" -- "$@"

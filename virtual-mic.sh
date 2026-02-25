#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/virtual-mic"
STATE_FILE="${STATE_DIR}/state.env"

SINK_NAME="virtual_mic_sink"
SINK_DESC="VirtualMic Sink"

SRC_NAME="virtual_mic_source"
SRC_DESC="VirtualMic Source"

# Delimiter preference (not strictly needed here, but kept consistent)
DELIM="§"

require_cmd() {
    local cmd="${1}"
    command -v "${cmd}" >/dev/null 2>&1 || {
        echo "ERROR: missing command: ${cmd}" >&2
        exit 1
    }
}

get_default_sink() {
    pactl get-default-sink 2>/dev/null || true
}

get_default_source() {
    pactl get-default-source 2>/dev/null || true
}

module_loaded() {
    local module_id="${1}"
    pactl list short modules | awk '{print $1}' | grep -Fxq "${module_id}"
}

sink_exists() {
    pactl list short sinks | awk '{print $2}' | grep -Fxq "${SINK_NAME}"
}

source_exists() {
    pactl list short sources | awk '{print $2}' | grep -Fxq "${SRC_NAME}"
}

save_state() {
    local prior_sink="${1}"
    local prior_source="${2}"
    local mod_null_sink="${3}"
    local mod_remap_source="${4}"
    local mod_loopback_mic="${5}"

    mkdir -p "${STATE_DIR}"

    cat > "${STATE_FILE}" <<EOF
PRIOR_DEFAULT_SINK="${prior_sink}"
PRIOR_DEFAULT_SOURCE="${prior_source}"
MOD_NULL_SINK="${mod_null_sink}"
MOD_REMAP_SOURCE="${mod_remap_source}"
MOD_LOOPBACK_MIC="${mod_loopback_mic}"
EOF
}

load_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        # shellcheck disable=SC1090
        source "${STATE_FILE}"
        return 0
    fi
    return 1
}

enable_virtual_mic() {
    require_cmd "pactl"

    if [[ -f "${STATE_FILE}" ]]; then
        echo "Already enabled (state file exists): ${STATE_FILE}"
        echo "Run: ${0} off"
        exit 0
    fi

    local prior_sink=""
    local prior_source=""
    prior_sink="$(get_default_sink)"
    prior_source="$(get_default_source)"

    if [[ -z "${prior_sink}" || -z "${prior_source}" ]]; then
        echo "ERROR: Could not determine current default sink/source." >&2
        echo "Check that pipewire-pulse is running and pactl works." >&2
        exit 1
    fi

    # 1) Create a null sink that apps can output to
    local mod_null_sink=""
    mod_null_sink="$(pactl load-module module-null-sink \
        sink_name="${SINK_NAME}" \
        sink_properties="device.description=${SINK_DESC}")"

    # 2) Create a virtual source from the null sink's monitor
    #    This becomes the "virtual mic" that conferencing apps should use
    local mod_remap_source=""
    mod_remap_source="$(pactl load-module module-remap-source \
        master="${SINK_NAME}.monitor" \
        source_name="${SRC_NAME}" \
        source_properties="device.description=${SRC_DESC}")"

    # 3) Loop your *current default mic* into the virtual sink so mic + app audio are mixed
    #    (If you want a specific mic instead of the default, edit "source=" below.)
    local mod_loopback_mic=""
    mod_loopback_mic="$(pactl load-module module-loopback \
        source="${prior_source}" \
        sink="${SINK_NAME}" \
        latency_msec=10)"

    # Set defaults so apps that just use defaults can “see” the virtual mic immediately.
    # We do NOT force the default sink to the virtual sink; you can route specific apps to it.
    pactl set-default-source "${SRC_NAME}"

    save_state "${prior_sink}" "${prior_source}" "${mod_null_sink}" "${mod_remap_source}" "${mod_loopback_mic}"

    echo "Enabled."
    echo "Playback sink (route apps to this):   ${SINK_DESC}  (${SINK_NAME})"
    echo "Recording source (select as mic):     ${SRC_DESC}   (${SRC_NAME})"
    echo
    echo "To revert:"
    echo "    ${0} off"
}

disable_virtual_mic() {
    require_cmd "pactl"

    if ! load_state; then
        echo "Not enabled (no state file found). Nothing to do."
        exit 0
    fi

    # Restore defaults first (best-effort)
    if [[ -n "${PRIOR_DEFAULT_SOURCE:-}" ]]; then
        pactl set-default-source "${PRIOR_DEFAULT_SOURCE}" || true
    fi
    if [[ -n "${PRIOR_DEFAULT_SINK:-}" ]]; then
        pactl set-default-sink "${PRIOR_DEFAULT_SINK}" || true
    fi

    # Unload modules (best-effort, tolerate partial teardown)
    for mid in "${MOD_LOOPBACK_MIC:-}" "${MOD_REMAP_SOURCE:-}" "${MOD_NULL_SINK:-}"; do
        if [[ -n "${mid}" ]]; then
            if pactl list short modules | awk '{print $1}' | grep -Fxq "${mid}"; then
                pactl unload-module "${mid}" || true
            fi
        fi
    done

    rm -f "${STATE_FILE}" || true

    echo "Disabled. Restored prior defaults."
}

status_virtual_mic() {
    require_cmd "pactl"

    if [[ -f "${STATE_FILE}" ]]; then
        echo "State: enabled (state file present)"
        load_state || true
        echo "    PRIOR_DEFAULT_SINK=${PRIOR_DEFAULT_SINK:-}"
        echo "    PRIOR_DEFAULT_SOURCE=${PRIOR_DEFAULT_SOURCE:-}"
        echo "    MOD_NULL_SINK=${MOD_NULL_SINK:-}"
        echo "    MOD_REMAP_SOURCE=${MOD_REMAP_SOURCE:-}"
        echo "    MOD_LOOPBACK_MIC=${MOD_LOOPBACK_MIC:-}"
    else
        echo "State: disabled (no state file)"
    fi

    echo
    echo "Current objects:"
    if sink_exists; then
        echo "    Sink exists: ${SINK_NAME}"
    else
        echo "    Sink missing: ${SINK_NAME}"
    fi

    if source_exists; then
        echo "    Source exists: ${SRC_NAME}"
    else
        echo "    Source missing: ${SRC_NAME}"
    fi
}

usage() {
    cat <<EOF
Usage:
    ${0} on
    ${0} off
    ${0} status

What it does:
    - Creates a virtual sink:   "${SINK_DESC}"
    - Creates a virtual source: "${SRC_DESC}" (from sink monitor)
    - Loops your prior default mic into the virtual sink (mixing mic + app audio)
    - Sets default source to the virtual source
    - Stores prior defaults + module IDs so "off" restores cleanly
EOF
}

main() {
    local action="${1:-}"
    case "${action}" in
        on)
            enable_virtual_mic
            ;;
        off)
            disable_virtual_mic
            ;;
        status)
            status_virtual_mic
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"

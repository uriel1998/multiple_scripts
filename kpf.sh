#!/bin/bash

##############################################################################
#
#  kpf
#  fzf for keepassxc-cli
#  (c) Steven Saus 2021
#  Licensed under the MIT license
#
#  BEFORE RUNNING - two environment variables
#  export KPPW="Your KeepassxC password"
#  export KPDB=/path/to/keepassxc.kdbx
#
##############################################################################

set -euo pipefail

find_bin="$(command -v fdfind || command -v fd || true)"
scriptname="$(realpath "$0")"

preview_entry() {
    local entry_name="$1"

    [ -n "$entry_name" ] || exit 0
    printf '%s' "$KPPW" | keepassxc-cli show -s "$KPDB" "$entry_name" 2>/dev/null || true
}

pick_database() {
    local selected_db=""

    if [ -n "$find_bin" ]; then
        selected_db="$(
            "$find_bin" -a -e kdbx . "$HOME" | \
                fzf --no-hscroll --height 50% --ansi --no-bold --border --header "Choose which database?"
        )"
    else
        selected_db="$(
            find "$HOME" -type f -iname "*.kdbx" 2>/dev/null | \
                fzf --no-hscroll --height 50% --ansi --no-bold --border --header "Choose which database?"
        )"
    fi

    printf '%s\n' "$selected_db"
}

if [ "${1:-}" = "__preview-entry" ]; then
    preview_entry "${2:-}"
    exit 0
fi

if [ ! -f "${KPDB:-}" ]; then
    KPDB="$(pick_database)"
    if [ -z "$KPDB" ]; then
        printf 'No KeepassXC database selected.\n' >&2
        exit 1
    fi
fi

if [ -z "${KPPW:-}" ]; then
    printf 'Please enter the password for the KeepassX database.\n'
    read -r KPPW
fi

clear
export KPPW="$KPPW"
export KPDB="$KPDB"

if [ -n "${1:-}" ]; then
    printf '%s' "$KPPW" | keepassxc-cli show -s "$KPDB" "$1" -a password 2>/dev/null
    exit 0
fi

preview_command="$(printf '%q __preview-entry {}' "$scriptname")"
KPVALUE="$(
    printf '%s' "$KPPW" | keepassxc-cli ls --recursive --flatten "$KPDB" | \
        fzf --no-hscroll --ansi --no-bold --preview "$preview_command"
)"

if [ -z "$KPVALUE" ]; then
    printf 'No entry selected.\n' >&2
    exit 0
fi

printf '%s' "$KPPW" | keepassxc-cli show -s "$KPDB" "$KPVALUE" -a password 2>/dev/null | xsel -p
xsel -o | xsel -b
printf '\nThe password is copied to the clipboard.\n'
printf 'Username is %s\n' "$(printf '%s' "$KPPW" | keepassxc-cli show -s "$KPDB" "$KPVALUE" -a username 2>/dev/null)"
printf 'TOTP (if existing) is %s' "$(printf '%s' "$KPPW" | keepassxc-cli show -s "$KPDB" "$KPVALUE" --totp 2>/dev/null)"

#!/bin/bash

# this is a small little utility to F'IN FINALLY CLIP THE DANG THING

set -euo pipefail

XCLIP_BIN="$(command -v xclip || true)"
COPYQ_BIN="$(command -v copyq || true)"

if [ -z "$XCLIP_BIN" ] && [ -z "$COPYQ_BIN" ]; then
    echo "Need xclip or copyq installed." >&2
    exit 1
fi

tmp_input="$(mktemp)"
trap 'rm -f "$tmp_input"' EXIT

if [ $# -eq 0 ]; then
    cat > "$tmp_input"
elif [ -f "$1" ]; then
    cat -- "$1" > "$tmp_input"
else
    printf '%s' "$1" > "$tmp_input"
fi

if [ -n "$XCLIP_BIN" ]; then
    "$XCLIP_BIN" -i -selection primary -r < "$tmp_input"
    "$XCLIP_BIN" -i -selection secondary -r < "$tmp_input"
    "$XCLIP_BIN" -i -selection clipboard -r < "$tmp_input"
fi

if [ -n "$COPYQ_BIN" ]; then
    "$COPYQ_BIN" write 0 - < "$tmp_input"
    "$COPYQ_BIN" select 0
fi

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
DICEBEAR_HELPER="${DICEBEAR_HELPER_PATH:-${SCRIPT_DIR}/dicebear_helper_generate_avatar.sh}"
DEFAULT_CONTACT_DIR="${VCF_CONTACT_DIR:-$PWD}"
DICEBEAR_AVATAR_DIR="${DICEBEAR_AVATAR_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/dicebear}"

usage() {
    cat <<'EOF'
Usage: vcf_add_missing_dicebear_avatars.sh [DIRECTORY]

Scans a directory of .vcf files, skips cards that already contain a PHOTO field,
builds a DiceBear seed from the available FN, EMAIL, TEL, and ORG values, calls
dicebear_helper_generate_avatar.sh, and inserts the generated PNG as a PHOTO
entry before END:VCARD.

If DIRECTORY is omitted, the script scans the current working directory.

Each generated avatar is also marked with:
X-DICEBEAR-GENERATED:TRUE
X-DICEBEAR-SOURCE:dicebear_helper_generate_avatar.sh

Examples:
  vcf_add_missing_dicebear_avatars.sh
  vcf_add_missing_dicebear_avatars.sh ./contacts

Optional environment overrides:
  DICEBEAR_HELPER_PATH=/path/to/dicebear_helper_generate_avatar.sh
  DICEBEAR_AVATAR_DIR=/path/to/avatar/cache
  VCF_CONTACT_DIR=/path/to/contacts
EOF
}

trim() {
    local value="${1:-}"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

unfold_vcard() {
    awk '
        /^[ \t]/ {
            sub(/^[ \t]/, "", $0)
            printf "%s", $0
            next
        }
        NR > 1 {
            printf "\n"
        }
        {
            printf "%s", $0
        }
    ' "$1"
}

extract_value() {
    local key="$1"
    local file="$2"

    awk -F ':' -v key="$key" '
        BEGIN {
            IGNORECASE = 1
        }
        $1 ~ ("^" key "([;]|$)") {
            print substr($0, index($0, ":") + 1)
            exit
        }
    ' "$file"
}

has_photo() {
    awk '
        BEGIN {
            IGNORECASE = 1
        }
        /^PHOTO([;:]|$)/ {
            found = 1
            exit
        }
        END {
            exit(found ? 0 : 1)
        }
    ' "$1"
}

build_photo_block() {
    local image_path="$1"
    local encoded

    encoded="$(base64 -w 0 "$image_path")"
    printf 'PHOTO;ENCODING=B;TYPE=PNG:%s\n' "${encoded:0:75}"
    encoded="${encoded:75}"

    while [ -n "$encoded" ]; do
        printf ' %s\n' "${encoded:0:74}"
        encoded="${encoded:74}"
    done
}

build_generated_marker_block() {
    cat <<'EOF'
X-DICEBEAR-GENERATED:TRUE
X-DICEBEAR-SOURCE:dicebear_helper_generate_avatar.sh
EOF
}

insert_photo() {
    local vcf_file="$1"
    local photo_block_file="$2"
    local marker_block_file="$3"
    local temp_file
    local newline=$'\n'
    local line
    local photo_line
    local marker_line
    local inserted=0

    temp_file="$(mktemp)"

    if LC_ALL=C grep -q $'\r$' "$vcf_file"; then
        newline=$'\r\n'
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = $'END:VCARD\r' ] || [ "$line" = 'END:VCARD' ]; then
            while IFS= read -r photo_line || [ -n "$photo_line" ]; do
                printf '%s%s' "$photo_line" "$newline"
            done < "$photo_block_file"
            while IFS= read -r marker_line || [ -n "$marker_line" ]; do
                printf '%s%s' "$marker_line" "$newline"
            done < "$marker_block_file"
            inserted=1
        fi

        printf '%s%s' "$line" "$newline"
    done < "$vcf_file" > "$temp_file"

    if [ "$inserted" -ne 1 ]; then
        rm -f "$temp_file"
        printf 'No END:VCARD line found in %s\n' "$vcf_file" >&2
        return 1
    fi

    mv "$temp_file" "$vcf_file"
}

process_vcf() {
    local vcf_file="$1"
    local unfolded_file
    local fn_value
    local email_value
    local tel_value
    local org_value
    local seed_parts=()
    local avatar_path
    local helper_stderr_file
    local photo_block_file
    local marker_block_file

    unfolded_file="$(mktemp)"
    unfold_vcard "$vcf_file" > "$unfolded_file"

    if has_photo "$unfolded_file"; then
        rm -f "$unfolded_file"
        printf 'skip-photo %s\n' "$vcf_file"
        return 0
    fi

    fn_value="$(trim "$(extract_value "FN" "$unfolded_file")")"
    email_value="$(trim "$(extract_value "EMAIL" "$unfolded_file")")"
    tel_value="$(trim "$(extract_value "TEL" "$unfolded_file")")"
    org_value="$(trim "$(extract_value "ORG" "$unfolded_file")")"
    rm -f "$unfolded_file"

    [ -n "$fn_value" ] && seed_parts+=("$fn_value")
    [ -n "$email_value" ] && seed_parts+=("$email_value")
    [ -n "$tel_value" ] && seed_parts+=("$tel_value")
    [ -n "$org_value" ] && seed_parts+=("$org_value")

    if [ "${#seed_parts[@]}" -eq 0 ]; then
        printf 'skip-empty %s\n' "$vcf_file"
        return 0
    fi

    helper_stderr_file="$(mktemp)"
    if ! avatar_path="$(
        DICEBEAR_AVATAR_DIR="$DICEBEAR_AVATAR_DIR" \
        DICEBEAR_NO_CLIPBOARD=1 \
        "$DICEBEAR_HELPER" "${seed_parts[@]}" 2>"$helper_stderr_file"
    )"; then
        printf 'helper-failed %s\n' "$vcf_file" >&2
        if [ -s "$helper_stderr_file" ]; then
            cat "$helper_stderr_file" >&2
        fi
        rm -f "$helper_stderr_file"
        return 1
    fi

    if [ -s "$helper_stderr_file" ]; then
        cat "$helper_stderr_file" >&2
    fi
    rm -f "$helper_stderr_file"

    avatar_path="$(trim "$avatar_path")"
    if [ -z "$avatar_path" ]; then
        printf 'helper-returned-no-avatar %s\n' "$vcf_file" >&2
        return 1
    fi
    if [ ! -f "$avatar_path" ]; then
        printf 'missing-avatar %s\n' "$vcf_file" >&2
        printf 'Expected avatar path: %s\n' "$avatar_path" >&2
        return 1
    fi

    photo_block_file="$(mktemp)"
    marker_block_file="$(mktemp)"
    build_photo_block "$avatar_path" > "$photo_block_file"
    build_generated_marker_block > "$marker_block_file"
    if ! insert_photo "$vcf_file" "$photo_block_file" "$marker_block_file"; then
        rm -f "$photo_block_file" "$marker_block_file"
        return 1
    fi
    rm -f "$photo_block_file" "$marker_block_file"

    printf 'updated %s\n' "$vcf_file"
}

main() {
    local contact_dir="${1:-$DEFAULT_CONTACT_DIR}"
    local file_found=0
    local updated_count=0
    local skipped_count=0
    local failed_count=0
    local output=""
    local process_status=0

    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        usage
        exit 0
    fi

    if [ ! -x "$DICEBEAR_HELPER" ]; then
        printf 'DiceBear helper is not executable: %s\n' "$DICEBEAR_HELPER" >&2
        exit 1
    fi

    if [ ! -d "$contact_dir" ]; then
        printf 'Directory not found: %s\n' "$contact_dir" >&2
        exit 1
    fi

    while IFS= read -r -d '' vcf_file; do
        file_found=1
        process_status=0
        output="$(process_vcf "$vcf_file" 2>&1)" || process_status=$?
        printf '%s\n' "$output"

        if [ "$process_status" -ne 0 ]; then
            failed_count=$((failed_count + 1))
        else
            case "$output" in
                skip-*\ *)
                    skipped_count=$((skipped_count + 1))
                    ;;
                *)
                    updated_count=$((updated_count + 1))
                    ;;
            esac
        fi
    done < <(find "$contact_dir" -type f \( -iname '*.vcf' -o -iname '*.vcard' \) -print0 | sort -z)

    if [ "$file_found" -eq 0 ]; then
        printf 'No vCard files found in %s\n' "$contact_dir" >&2
        exit 1
    fi

    printf 'Summary: updated=%d skipped=%d failed=%d\n' \
        "$updated_count" "$skipped_count" "$failed_count"

    if [ "$failed_count" -ne 0 ]; then
        exit 1
    fi
}

main "$@"

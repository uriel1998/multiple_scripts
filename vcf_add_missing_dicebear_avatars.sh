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
tries Libravatar and then Gravatar for any non-placeholder email addresses on
the card, and falls back to dicebear_helper_generate_avatar.sh only if no email
avatar is available. It then inserts the generated or downloaded image as a
PHOTO entry before END:VCARD.

If DIRECTORY is omitted, the script scans the current working directory.

The script marks inserted avatars with:
X-DICEBEAR-GENERATED:TRUE
X-DICEBEAR-SOURCE:dicebear|libravatar|gravatar

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

extract_values() {
    local key="$1"
    local file="$2"

    awk -F ':' -v key="$key" '
        BEGIN {
            IGNORECASE = 1
        }
        $1 ~ ("^" key "([;]|$)") {
            print substr($0, index($0, ":") + 1)
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
    local mime_type
    local photo_type

    mime_type="$(file --mime-type -b "$image_path")"
    case "$mime_type" in
        image/jpeg)
            photo_type="JPEG"
            ;;
        image/png)
            photo_type="PNG"
            ;;
        image/gif)
            photo_type="GIF"
            ;;
        *)
            printf 'Unsupported avatar mime type: %s\n' "$mime_type" >&2
            return 1
            ;;
    esac

    encoded="$(base64 -w 0 "$image_path")"
    printf 'PHOTO;ENCODING=B;TYPE=%s;VALUE=BINARY:%s\n' "$photo_type" "${encoded:0:75}"
    encoded="${encoded:75}"

    while [ -n "$encoded" ]; do
        printf ' %s\n' "${encoded:0:74}"
        encoded="${encoded:74}"
    done
}

build_generated_marker_block() {
    local source="${1:-}"

    [ -n "$source" ] || return 0

    printf 'X-DICEBEAR-GENERATED:TRUE\n'
    printf 'X-DICEBEAR-SOURCE:%s\n' "$source"
}

normalize_email() {
    local email_value="${1:-}"

    email_value="$(trim "$email_value")"
    email_value="${email_value,,}"
    printf '%s' "$email_value"
}

is_placeholder_email() {
    local email_value
    local local_part
    local domain_part

    email_value="$(normalize_email "${1:-}")"
    [ -n "$email_value" ] || return 0
    case "$email_value" in
        *"@"*)
            ;;
        *)
            return 0
            ;;
    esac

    local_part="${email_value%@*}"
    domain_part="${email_value#*@}"

    case "$local_part" in
        nobody*|no-reply|noreply|donotreply|do-not-reply)
            return 0
            ;;
    esac

    case "$domain_part" in
        nowhere.invalid|invalid|example.com|example.org|example.net|localhost|localdomain)
            return 0
            ;;
    esac

    return 1
}

email_avatar_hash() {
    local email_value

    email_value="$(normalize_email "${1:-}")"
    printf '%s' "$email_value" | md5sum | awk '{print $1}'
}

fetch_avatar_url() {
    local url="$1"
    local output_path="$2"
    local mime_type

    rm -f "$output_path"
    if ! wget -q --server-response --timeout=20 --tries=1 "$url" -O "$output_path" 2>/dev/null; then
        rm -f "$output_path"
        return 1
    fi

    if [ ! -s "$output_path" ]; then
        rm -f "$output_path"
        return 1
    fi

    mime_type="$(file --mime-type -b "$output_path")"
    case "$mime_type" in
        image/jpeg|image/png|image/gif)
            return 0
            ;;
        *)
            rm -f "$output_path"
            return 1
            ;;
    esac
}

fetch_avatar_from_email() {
    local email_value="$1"
    local avatar_hash
    local target_file

    avatar_hash="$(email_avatar_hash "$email_value")"
    target_file="$(mktemp)"

    if fetch_avatar_url "https://seccdn.libravatar.org/avatar/${avatar_hash}?d=404&s=512" "$target_file"; then
        printf 'libravatar %s\n' "$target_file"
        return 0
    fi

    if fetch_avatar_url "https://www.gravatar.com/avatar/${avatar_hash}?d=404&s=512" "$target_file"; then
        printf 'gravatar %s\n' "$target_file"
        return 0
    fi

    rm -f "$target_file"
    return 1
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
    local -a email_values=()
    local avatar_source=""
    local avatar_path
    local avatar_lookup_result=""
    local helper_stderr_file
    local photo_block_file
    local marker_block_file
    local email_candidate

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
    while IFS= read -r email_candidate; do
        email_candidate="$(normalize_email "$email_candidate")"
        [ -n "$email_candidate" ] && email_values+=("$email_candidate")
    done < <(extract_values "EMAIL" "$unfolded_file")
    rm -f "$unfolded_file"

    [ -n "$fn_value" ] && seed_parts+=("$fn_value")
    [ -n "$email_value" ] && seed_parts+=("$email_value")
    [ -n "$tel_value" ] && seed_parts+=("$tel_value")
    [ -n "$org_value" ] && seed_parts+=("$org_value")

    if [ "${#seed_parts[@]}" -eq 0 ]; then
        printf 'skip-empty %s\n' "$vcf_file"
        return 0
    fi

    for email_candidate in "${email_values[@]}"; do
        if is_placeholder_email "$email_candidate"; then
            continue
        fi

        if avatar_lookup_result="$(fetch_avatar_from_email "$email_candidate")"; then
            avatar_source="${avatar_lookup_result%% *}"
            avatar_path="${avatar_lookup_result#* }"
            break
        fi
    done

    if [ -z "$avatar_source" ]; then
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
        avatar_source="dicebear"
    fi

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
    if ! build_photo_block "$avatar_path" > "$photo_block_file"; then
        rm -f "$photo_block_file" "$marker_block_file"
        case "$avatar_source" in
            libravatar|gravatar) rm -f "$avatar_path" ;;
        esac
        return 1
    fi
    build_generated_marker_block "$avatar_source" > "$marker_block_file"
    if ! insert_photo "$vcf_file" "$photo_block_file" "$marker_block_file"; then
        rm -f "$photo_block_file" "$marker_block_file"
        case "$avatar_source" in
            libravatar|gravatar) rm -f "$avatar_path" ;;
        esac
        return 1
    fi
    rm -f "$photo_block_file" "$marker_block_file"
    case "$avatar_source" in
        libravatar|gravatar) rm -f "$avatar_path" ;;
    esac

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

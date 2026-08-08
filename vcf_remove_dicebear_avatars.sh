#!/usr/bin/env bash

set -euo pipefail

DEFAULT_CONTACT_DIR="${VCF_CONTACT_DIR:-$PWD}"

usage() {
    cat <<'EOF'
Usage: vcf_remove_dicebear_avatars.sh [DIRECTORY]

Scans a directory of .vcf files and removes embedded PHOTO fields only from
cards marked with:
X-DICEBEAR-GENERATED:TRUE
X-DICEBEAR-SOURCE:dicebear_helper_generate_avatar.sh

It also removes those marker fields from the updated cards.

If DIRECTORY is omitted, the script scans the current working directory.

Examples:
  vcf_remove_dicebear_avatars.sh
  vcf_remove_dicebear_avatars.sh ./contacts

Optional environment override:
  VCF_CONTACT_DIR=/path/to/contacts
EOF
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

has_dicebear_markers() {
    awk '
        BEGIN {
            IGNORECASE = 1
        }
        /^X-DICEBEAR-GENERATED:TRUE$/ {
            generated = 1
        }
        /^X-DICEBEAR-SOURCE:dicebear_helper_generate_avatar\.sh$/ {
            source = 1
        }
        END {
            exit(generated && source ? 0 : 1)
        }
    ' "$1"
}

rewrite_without_dicebear_avatar() {
    local vcf_file="$1"
    local temp_file
    local newline=$'\n'
    local line
    local skip_continuations=0

    temp_file="$(mktemp)"

    if LC_ALL=C grep -q $'\r$' "$vcf_file"; then
        newline=$'\r\n'
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$skip_continuations" -eq 1 ]; then
            case "$line" in
                " "*|$'\t'*)
                    continue
                    ;;
                *)
                    skip_continuations=0
                    ;;
            esac
        fi

        case "$line" in
            X-DICEBEAR-GENERATED:TRUE|$'X-DICEBEAR-GENERATED:TRUE\r')
                continue
                ;;
            X-DICEBEAR-SOURCE:dicebear_helper_generate_avatar.sh|$'X-DICEBEAR-SOURCE:dicebear_helper_generate_avatar.sh\r')
                continue
                ;;
            PHOTO*|$'PHOTO'*)
                skip_continuations=1
                continue
                ;;
        esac

        printf '%s%s' "$line" "$newline"
    done < "$vcf_file" > "$temp_file"

    mv "$temp_file" "$vcf_file"
}

process_vcf() {
    local vcf_file="$1"
    local unfolded_file

    unfolded_file="$(mktemp)"
    unfold_vcard "$vcf_file" > "$unfolded_file"

    if ! has_dicebear_markers "$unfolded_file"; then
        rm -f "$unfolded_file"
        printf 'skip-unmarked %s\n' "$vcf_file"
        return 0
    fi

    rm -f "$unfolded_file"
    rewrite_without_dicebear_avatar "$vcf_file"
    printf 'updated %s\n' "$vcf_file"
}

main() {
    local contact_dir="${1:-$DEFAULT_CONTACT_DIR}"
    local file_found=0

    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        usage
        exit 0
    fi

    if [ ! -d "$contact_dir" ]; then
        printf 'Directory not found: %s\n' "$contact_dir" >&2
        exit 1
    fi

    while IFS= read -r -d '' vcf_file; do
        file_found=1
        process_vcf "$vcf_file"
    done < <(find "$contact_dir" -type f \( -iname '*.vcf' -o -iname '*.vcard' \) -print0 | sort -z)

    if [ "$file_found" -eq 0 ]; then
        printf 'No vCard files found in %s\n' "$contact_dir" >&2
        exit 1
    fi
}

main "$@"

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
OUTPUT_DIR="${SCRIPT_DIR}/output"
MANIFEST_FILE="${OUTPUT_DIR}/likely_placeholder_avatars.tsv"
MAX_DIMENSION="${VCF_PLACEHOLDER_MAX_DIMENSION:-96}"
MAX_COLORS="${VCF_PLACEHOLDER_MAX_COLORS:-4000}"
MAX_MIRROR_RMSE="${VCF_PLACEHOLDER_MAX_MIRROR_RMSE:-0.18}"

usage() {
    cat <<'EOF'
Usage:
  clean_identicons_vcards.sh DIRECTORY
  clean_identicons_vcards.sh --clean

Scan mode:
  Scans DIRECTORY for .vcf/.vcard files, extracts embedded PHOTO images that
  look like likely geometric placeholder avatars, and writes:
    ./output/likely_placeholder_*.{jpg,png,gif}
    ./output/likely_placeholder_avatars.tsv
  While scanning, it also standardizes any embedded PHOTO field it finds to the
  explicit form:
    PHOTO;ENCODING=B;TYPE=...;VALUE=BINARY:...
  The output directory is created underneath the script itself.

Review workflow:
  1. Run scan mode on a contacts directory.
  2. Manually review ./output and delete any false-hit exported images.
  3. Run --clean.

Clean mode:
  Reads ./output/likely_placeholder_avatars.tsv and removes embedded PHOTO
  fields only from VCFs whose exported review image still exists in ./output.
  It also verifies that the currently embedded image hash still matches the
  recorded hash before removing it.

Heuristic tuning:
  VCF_PLACEHOLDER_MAX_DIMENSION=96
  VCF_PLACEHOLDER_MAX_COLORS=4000
  VCF_PLACEHOLDER_MAX_MIRROR_RMSE=0.18
EOF
}

extract_photo() {
    local vcf_file="$1"
    local output_file="$2"

    perl -ne '
        if (/^PHOTO/../^END:VCARD/) {
            if (/^PHOTO/) {
                s/^PHOTO[^:]*://;
            } elsif (/^[ \t]/) {
                s/^[ \t]//;
            } else {
                next;
            }
            s/[\r\n]//g;
            print;
        }
    ' "$vcf_file" | base64 -d > "$output_file" 2>/dev/null
}

extract_field() {
    local key="$1"
    local vcf_file="$2"

    awk -F ':' -v key="$key" '
        BEGIN {
            IGNORECASE = 1
        }
        $1 ~ ("^" key "([;]|$)") {
            print substr($0, index($0, ":") + 1)
            exit
        }
    ' "$vcf_file"
}

metric_rmse() {
    local image_file="$1"
    local mode="$2"
    local raw=""

    case "$mode" in
        flop)
            raw="$(compare -metric RMSE "$image_file" <(convert "$image_file" -flop jpg:-) null: 2>&1 || true)"
            ;;
        flip)
            raw="$(compare -metric RMSE "$image_file" <(convert "$image_file" -flip jpg:-) null: 2>&1 || true)"
            ;;
        *)
            return 1
            ;;
    esac

    printf '%s\n' "$raw" | awk -F'[()]' '{print $2}'
}

image_stats() {
    local image_file="$1"
    local width height colors horizontal_rmse vertical_rmse mime_type sha256

    width="$(identify -format '%w' "$image_file" 2>/dev/null || echo 0)"
    height="$(identify -format '%h' "$image_file" 2>/dev/null || echo 0)"
    colors="$(convert "$image_file" -format %k info: 2>/dev/null || echo 999999)"
    horizontal_rmse="$(metric_rmse "$image_file" flop)"
    vertical_rmse="$(metric_rmse "$image_file" flip)"
    mime_type="$(file --mime-type -b "$image_file" 2>/dev/null || echo '')"
    sha256="$(sha256sum "$image_file" | awk '{print $1}')"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$width" "$height" "$colors" "$horizontal_rmse" "$vertical_rmse" "$mime_type" "$sha256"
}

is_supported_image() {
    local mime_type="$1"

    case "$mime_type" in
        image/jpeg|image/png|image/gif)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

build_photo_block() {
    local image_file="$1"
    local mime_type="$2"
    local encoded
    local photo_type

    case "$mime_type" in
        image/jpeg) photo_type="JPEG" ;;
        image/png) photo_type="PNG" ;;
        image/gif) photo_type="GIF" ;;
        *) return 1 ;;
    esac

    encoded="$(base64 -w 0 "$image_file")"
    printf 'PHOTO;ENCODING=B;TYPE=%s;VALUE=BINARY:%s\n' "$photo_type" "${encoded:0:75}"
    encoded="${encoded:75}"

    while [ -n "$encoded" ]; do
        printf ' %s\n' "${encoded:0:74}"
        encoded="${encoded:74}"
    done
}

is_likely_placeholder() {
    local width="$1"
    local height="$2"
    local colors="$3"
    local horizontal_rmse="$4"
    local vertical_rmse="$5"

    awk -v width="$width" \
        -v height="$height" \
        -v max_dimension="$MAX_DIMENSION" \
        -v colors="$colors" \
        -v max_colors="$MAX_COLORS" \
        -v horizontal_rmse="$horizontal_rmse" \
        -v vertical_rmse="$vertical_rmse" \
        -v max_rmse="$MAX_MIRROR_RMSE" '
        BEGIN {
            if (width > 0 && height > 0 && width <= max_dimension &&
                height <= max_dimension && colors <= max_colors &&
                horizontal_rmse <= max_rmse && vertical_rmse <= max_rmse) {
                exit 0
            }
            exit 1
        }
    '
}

rewrite_vcf_photo() {
    local vcf_file="$1"
    local photo_block_file="$2"
    local temp_file
    local newline=$'\n'
    local line
    local skip_photo=0
    local inserted=0
    local photo_line

    temp_file="$(mktemp)"

    if LC_ALL=C grep -q $'\r$' "$vcf_file"; then
        newline=$'\r\n'
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$skip_photo" -eq 1 ]; then
            case "$line" in
                " "*|$'\t'*)
                    continue
                    ;;
                *)
                    skip_photo=0
                    ;;
            esac
        fi

        case "$line" in
            PHOTO*|$'PHOTO'*)
                skip_photo=1
                continue
                ;;
        esac

        if [ "$line" = $'END:VCARD\r' ] || [ "$line" = 'END:VCARD' ]; then
            while IFS= read -r photo_line || [ -n "$photo_line" ]; do
                printf '%s%s' "$photo_line" "$newline"
            done < "$photo_block_file"
            inserted=1
        fi

        printf '%s%s' "$line" "$newline"
    done < "$vcf_file" > "$temp_file"

    if [ "$inserted" -ne 1 ]; then
        rm -f "$temp_file"
        return 1
    fi

    mv "$temp_file" "$vcf_file"
}

standardize_photo_in_vcf() {
    local vcf_file="$1"
    local image_file="$2"
    local mime_type="$3"
    local photo_block_file

    photo_block_file="$(mktemp)"
    build_photo_block "$image_file" "$mime_type" > "$photo_block_file"
    rewrite_vcf_photo "$vcf_file" "$photo_block_file"
    rm -f "$photo_block_file"
}

extension_for_mime() {
    local mime_type="$1"

    case "$mime_type" in
        image/jpeg) printf 'jpg\n' ;;
        image/png) printf 'png\n' ;;
        image/gif) printf 'gif\n' ;;
        *) return 1 ;;
    esac
}

remove_photo_from_vcf() {
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
            PHOTO*|$'PHOTO'*)
                skip_continuations=1
                continue
                ;;
        esac

        printf '%s%s' "$line" "$newline"
    done < "$vcf_file" > "$temp_file"

    mv "$temp_file" "$vcf_file"
}

run_scan() {
    local contact_dir="$1"
    local staging_dir
    local file_found=0
    local match_count=0
    local vcf_file base_name image_file mime_type extension dest_file fn_value email_value
    local width height colors horizontal_rmse vertical_rmse sha256
    local stats

    if [ ! -d "$contact_dir" ]; then
        printf 'Directory not found: %s\n' "$contact_dir" >&2
        exit 1
    fi

    mkdir -p "$OUTPUT_DIR"
    rm -f "$OUTPUT_DIR"/likely_placeholder_avatars.tsv
    rm -f "$OUTPUT_DIR"/likely_placeholder_*.jpg "$OUTPUT_DIR"/likely_placeholder_*.jpeg "$OUTPUT_DIR"/likely_placeholder_*.png "$OUTPUT_DIR"/likely_placeholder_*.gif

    printf 'vcf_file\tfn\temail\texport_file\tdimensions\tcolors\thorizontal_rmse\tvertical_rmse\tsha256\n' > "$MANIFEST_FILE"
    staging_dir="$(mktemp -d)"

    while IFS= read -r -d '' vcf_file; do
        file_found=1
        base_name="$(basename "$vcf_file" .vcf)"
        image_file="$staging_dir/$base_name.bin"

        if ! extract_photo "$vcf_file" "$image_file"; then
            continue
        fi

        stats="$(image_stats "$image_file")"
        IFS=$'\t' read -r width height colors horizontal_rmse vertical_rmse mime_type sha256 <<< "$stats"

        if ! is_supported_image "$mime_type"; then
            continue
        fi

        standardize_photo_in_vcf "$vcf_file" "$image_file" "$mime_type"

        if ! is_likely_placeholder "$width" "$height" "$colors" "$horizontal_rmse" "$vertical_rmse"; then
            continue
        fi

        extension="$(extension_for_mime "$mime_type")"
        match_count=$((match_count + 1))
        dest_file="$OUTPUT_DIR/likely_placeholder_${match_count}_${base_name}.${extension}"
        cp "$image_file" "$dest_file"

        fn_value="$(extract_field "FN" "$vcf_file" | tr '\t' ' ' | tr '\n' ' ')"
        email_value="$(extract_field "EMAIL" "$vcf_file" | tr '\t' ' ' | tr '\n' ' ')"

        printf '%s\t%s\t%s\t%s\t%sx%s\t%s\t%s\t%s\t%s\n' \
            "$vcf_file" "$fn_value" "$email_value" "$(basename "$dest_file")" \
            "$width" "$height" "$colors" "$horizontal_rmse" "$vertical_rmse" "$sha256" >> "$MANIFEST_FILE"
    done < <(find "$contact_dir" -type f \( -iname '*.vcf' -o -iname '*.vcard' \) -print0 | sort -z)

    rm -rf "$staging_dir"

    if [ "$file_found" -eq 0 ]; then
        printf 'No vCard files found in %s\n' "$contact_dir" >&2
        exit 1
    fi

    printf 'Extracted %d likely geometric placeholders into %s\n' "$match_count" "$OUTPUT_DIR"
    printf 'Manifest written to %s\n' "$MANIFEST_FILE"
}

run_clean() {
    local manifest_line
    local vcf_file fn_value email_value export_file _dimensions _colors _horizontal_rmse _vertical_rmse sha256
    local current_image current_sha
    local cleaned_count=0
    local skipped_count=0

    if [ ! -f "$MANIFEST_FILE" ]; then
        printf 'Manifest not found: %s\n' "$MANIFEST_FILE" >&2
        exit 1
    fi

    while IFS= read -r manifest_line; do
        [ -n "$manifest_line" ] || continue
        if [ "$manifest_line" = $'vcf_file\tfn\temail\texport_file\tdimensions\tcolors\thorizontal_rmse\tvertical_rmse\tsha256' ]; then
            continue
        fi

        IFS=$'\t' read -r vcf_file fn_value email_value export_file _dimensions _colors _horizontal_rmse _vertical_rmse sha256 <<< "$manifest_line"

        if [ ! -f "$OUTPUT_DIR/$export_file" ]; then
            skipped_count=$((skipped_count + 1))
            continue
        fi

        if [ ! -f "$vcf_file" ]; then
            printf 'skip-missing-vcf %s\n' "$vcf_file"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        current_image="$(mktemp)"
        if ! extract_photo "$vcf_file" "$current_image"; then
            rm -f "$current_image"
            printf 'skip-no-photo %s\n' "$vcf_file"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        current_sha="$(sha256sum "$current_image" | awk '{print $1}')"
        rm -f "$current_image"

        if [ "$current_sha" != "$sha256" ]; then
            printf 'skip-hash-mismatch %s\n' "$vcf_file"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        remove_photo_from_vcf "$vcf_file"
        printf 'cleaned %s\n' "$vcf_file"
        cleaned_count=$((cleaned_count + 1))
    done < "$MANIFEST_FILE"

    printf 'Summary: cleaned=%d skipped=%d\n' "$cleaned_count" "$skipped_count"
}

main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        usage
        exit 0
    fi

    if [ "${1:-}" = "--clean" ]; then
        run_clean
        exit 0
    fi

    if [ "$#" -ne 1 ]; then
        usage
        exit 1
    fi

    run_scan "$1"
}

main "$@"

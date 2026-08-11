#!/bin/bash

##############################################################################
#
#  clipimg.sh
#  By Steven Saus
#  (c) 2020; licensed under the MIT license
#
#  Uses fzf or rofi to choose an image from configured stickerpack lists,
#  then copies it to the clipboard and selects it for pasting.
##############################################################################

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CLIPIMG_ENV_FILE=""
CLIPIMG_CACHE_FILE="${SCRIPT_DIR}/.clipimg.cache"

FD_FIND="$(command -v fdfind || true)"
FD_ALT="$(command -v fd || true)"
TIMG_BIN="$(command -v timg || true)"
CHAFA_BIN="$(command -v chafa || true)"
DRAGON_BIN="$(command -v dragon || true)"
XCLIP_BIN="$(command -v xclip || true)"
COPYQ_BIN="$(command -v copyq || true)"

if [ -x "${HOME}/.local/bin/dragon" ]; then
    DRAGON_BIN="${HOME}/.local/bin/dragon"
fi

CliOnly="true"
PreferredPreview="auto"
PreferKittyPreview="false"
CreateCacheOnly="false"
PathOnly="false"
NoDragon="false"
Choices=()
StickerPackNames=()
StickerPackPaths=()
RequestedStickerPacks=()
OverrideStickerNames=()
OverrideStickerDirs=()

find_clipimg_config() {
    local -a candidates=()
    local candidate

    if [ "$CreateCacheOnly" = "true" ]; then
        candidates=(
            "${SCRIPT_DIR}/.clipimg.env"
            "${SCRIPT_DIR}/clipimg.ini"
            "${SCRIPT_DIR}/.clipimg.ini"
            "${PWD}/.clipimg.env"
            "${PWD}/clipimg.ini"
            "${PWD}/.clipimg.ini"
        )
    else
        candidates=(
            "${PWD}/.clipimg.env"
            "${PWD}/clipimg.ini"
            "${PWD}/.clipimg.ini"
            "${SCRIPT_DIR}/.clipimg.env"
            "${SCRIPT_DIR}/clipimg.ini"
            "${SCRIPT_DIR}/.clipimg.ini"
        )
    fi

    for candidate in "${candidates[@]}"; do
        if [ -f "$candidate" ]; then
            printf '%s' "$candidate"
            return 0
        fi
    done

    return 1
}

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

strip_surrounding_quotes() {
    local value="$1"

    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
        value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
        value="${value:1:${#value}-2}"
    fi

    printf '%s' "$value"
}

is_supported_image_file() {
    local path="$1"
    local extension="${path##*.}"

    extension="${extension,,}"

    case "$extension" in
        png|jpg|jpeg|gif|webp)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

display_help() {
    echo "###################################################################"
    echo "#  clipimg.sh [-h|--help] [--sticker pack-or-dir ...] [stickerpack ...]"
    echo "# -h, --help  show help"
    echo "# -g GUI interface only. Default is CLI/TUI."
    echo "# --chafa prefer chafa for previews."
    echo "# --timg prefer timg for previews."
    echo "# --kitty use kitty graphics previews when running in kitty."
    echo "# Falls back to normal previews when not in kitty or inside tmux."
    echo "# --sticker NAME|DIR can be used multiple times."
    echo "# If used, it replaces env-defined stickerpacks and only uses the"
    echo "# named packs or directories passed on the command line."
    echo "# --create-cache build ${CLIPIMG_CACHE_FILE} and exit."
    echo "# --path-only copy the selected file path as text instead of"
    echo "# image data to xclip and copyq."
    echo "# --no-dragon do not launch dragon even in normal image mode."
    echo "# By default, uncommented entries under [StickerPacks] are used."
    echo "# If you want old icon or clipart directories included, point a"
    echo "# stickerpack entry at those directories in the env file."
    echo "# Positional stickerpack names restrict selection to matching packs."
    echo "# Example: clipimg.sh blob blob2"
    echo "# Example: clipimg.sh --sticker blob --sticker /path/to/stickers"
    echo "# Config is read from .clipimg.env, clipimg.ini, or .clipimg.ini"
    echo "# in the current directory or the script directory."
    echo "# Clipboard output uses any available combination of dragon,"
    echo "# xclip, and copyq."
    echo "# Dragon is looked up in \$HOME/.local/bin/dragon before PATH."
    echo "###################################################################"
}

is_kitty_terminal() {
    [ -n "${KITTY_WINDOW_ID:-}" ] && return 0

    case "${TERM:-}" in
        *kitty*)
            return 0
            ;;
    esac

    return 1
}

is_tmux_session() {
    [ -n "${TMUX:-}" ]
}

stickerpack_requested() {
    local pack_name="$1"
    local requested_name

    [ "${#RequestedStickerPacks[@]}" -gt 0 ] || return 0

    for requested_name in "${RequestedStickerPacks[@]}"; do
        if [[ "${requested_name,,}" == "${pack_name,,}" ]]; then
            return 0
        fi
    done

    return 1
}

add_stickerpack_entry() {
    local entry_name="$1"
    local entry_path="$2"

    entry_name="$(trim_whitespace "$entry_name")"
    entry_path="$(trim_whitespace "$entry_path")"
    entry_path="$(strip_surrounding_quotes "$entry_path")"

    [ -n "$entry_name" ] || return 0
    [ -n "$entry_path" ] || return 0

    StickerPackNames+=("$entry_name")
    StickerPackPaths+=("$entry_path")
}

add_override_sticker_name() {
    local requested_name="$1"
    local existing_name

    requested_name="$(trim_whitespace "$requested_name")"
    [ -n "$requested_name" ] || return 0

    for existing_name in "${OverrideStickerNames[@]}"; do
        if [[ "${existing_name,,}" == "${requested_name,,}" ]]; then
            return 0
        fi
    done

    OverrideStickerNames+=("$requested_name")
}

add_override_sticker_dir() {
    local requested_dir="$1"
    local resolved_dir
    local existing_dir

    requested_dir="$(trim_whitespace "$requested_dir")"
    requested_dir="$(strip_surrounding_quotes "$requested_dir")"
    [ -n "$requested_dir" ] || return 0

    if ! resolved_dir="$(realpath -e "$requested_dir" 2>/dev/null)"; then
        return 0
    fi

    [ -d "$resolved_dir" ] || return 0

    for existing_dir in "${OverrideStickerDirs[@]}"; do
        if [ "$existing_dir" = "$resolved_dir" ]; then
            return 0
        fi
    done

    OverrideStickerDirs+=("$resolved_dir")
}

queue_override_sticker() {
    local requested_entry="$1"
    local pack_name

    requested_entry="$(trim_whitespace "$requested_entry")"
    requested_entry="$(strip_surrounding_quotes "$requested_entry")"
    [ -n "$requested_entry" ] || return 0

    for pack_name in "${StickerPackNames[@]}"; do
        if [[ "${pack_name,,}" == "${requested_entry,,}" ]]; then
            add_override_sticker_name "$pack_name"
            return 0
        fi
    done

    add_override_sticker_dir "$requested_entry"
}

launch_dragon() {
    local image_path="$1"

    [ -n "$DRAGON_BIN" ] || return 0

    nohup "$DRAGON_BIN" -a -x "$image_path" </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
}

load_clipimg_env() {
    local current_section=""
    local raw_line
    local trimmed_line
    local key
    local value

    [ -n "$CLIPIMG_ENV_FILE" ] || return 0
    [ -f "$CLIPIMG_ENV_FILE" ] || return 0

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        trimmed_line="$(trim_whitespace "$raw_line")"

        [ -n "$trimmed_line" ] || continue
        [[ "$trimmed_line" == \#* ]] && continue

        if [[ "$trimmed_line" =~ ^\[(.+)\]$ ]]; then
            current_section="${BASH_REMATCH[1],,}"
            continue
        fi

        case "$current_section" in
            stickerpacks)
                if [[ "$trimmed_line" == *:* ]]; then
                    key="${trimmed_line%%:*}"
                    value="${trimmed_line#*:}"
                    add_stickerpack_entry "$key" "$value"
                fi
                ;;
        esac
    done < "$CLIPIMG_ENV_FILE"
}

build_search_items() {
    local search_label="$1"
    local search_path="$2"
    local display_mode="$3"
    local cache_output_file="${4:-}"
    local -a extensions=()
    local -a finder_args=()
    local path
    local display_path
    local filename_only
    local search_root

    if ! search_root="$(realpath -e "$search_path" 2>/dev/null)"; then
        return 0
    fi

    extensions=(png jpg jpeg gif webp)

    for path in "${extensions[@]}"; do
        finder_args+=(-e "$path")
    done

    while IFS= read -r path; do
        [ -n "$path" ] || continue
        is_supported_image_file "$path" || continue
        filename_only="$(basename "$path")"
        filename_only="${filename_only%.*}"

        case "$display_mode" in
            stickerpack)
                display_path="${search_label}:${filename_only}"
                ;;
            *)
                display_path="${search_label}: ${filename_only}"
                ;;
        esac

        if [ -n "$cache_output_file" ]; then
            printf '%s\t%s\t%s\t%s\n' "$path" "$display_path" "$display_mode" "$search_label" >> "$cache_output_file"
        else
            Choices+=("${path}"$'\t'"${display_path}")
        fi
    done < <(
        if [ -n "$FD_FIND" ]; then
            "$FD_FIND" -a "${finder_args[@]}" . "$search_root"
        elif [ -n "$FD_ALT" ]; then
            "$FD_ALT" -a "${finder_args[@]}" . "$search_root"
        else
            find -H "$search_root" -type f \( \
                -iname "*.png" -o \
                -iname "*.jpg" -o \
                -iname "*.jpeg" -o \
                -iname "*.gif" -o \
                -iname "*.webp" \
            \)
        fi
    )
}

choice_allowed() {
    local display_mode="$1"
    local search_label="$2"

    case "$display_mode" in
        stickerpack)
            stickerpack_requested "$search_label"
            return $?
            ;;
    esac

    return 1
}

load_choices_from_cache() {
    local cache_file="$1"
    local cache_path
    local cache_display
    local cache_mode
    local cache_label

    [ -f "$cache_file" ] || return 1

    while IFS=$'\t' read -r cache_path cache_display cache_mode cache_label; do
        [ -n "$cache_path" ] || continue
        [ -f "$cache_path" ] || continue
        choice_allowed "$cache_mode" "$cache_label" || continue
        Choices+=("${cache_path}"$'\t'"${cache_display}")
    done < "$cache_file"
}

create_cache() {
    local cache_file="$CLIPIMG_CACHE_FILE"
    local cache_dir
    local temp_cache_file

    cache_dir="$(dirname "$cache_file")"
    mkdir -p "$cache_dir"
    temp_cache_file="$(mktemp "${cache_dir}/.clipimg.cache.tmp.XXXXXX")"

    for i in "${!StickerPackNames[@]}"; do
        build_search_items "${StickerPackNames[$i]}" "${StickerPackPaths[$i]}" "stickerpack" "$temp_cache_file"
    done

    mv -f "$temp_cache_file" "$cache_file"
    printf 'Wrote cache to %s\n' "$cache_file"
}

build_override_choices() {
    local requested_name
    local requested_dir
    local i

    for requested_name in "${OverrideStickerNames[@]}"; do
        for i in "${!StickerPackNames[@]}"; do
            if [[ "${StickerPackNames[$i],,}" == "${requested_name,,}" ]]; then
                build_search_items "${StickerPackNames[$i]}" "${StickerPackPaths[$i]}" "stickerpack"
            fi
        done
    done

    for requested_dir in "${OverrideStickerDirs[@]}"; do
        build_search_items "$(basename "$requested_dir")" "$requested_dir" "stickerpack"
    done
}

select_image() {
    local preview_command=""
    local preview_script=""
    local kitty_size_preamble=""
    local selected_row=""
    local selected_label=""
    local choice_row=""
    local timg_escaped=""
    local chafa_escaped=""
    local preview_order=""
    local use_kitty_graphics="false"
    local preview_prefix=""

    [ "${#Choices[@]}" -gt 0 ] || return 0

    if [ "$PreferKittyPreview" = "true" ] && is_kitty_terminal && ! is_tmux_session; then
        use_kitty_graphics="true"
    fi

    if [ "$use_kitty_graphics" = "true" ]; then
        preview_prefix="printf '\033_Ga=d,d=A;\033\\' >/dev/tty 2>/dev/null || true; printf '\033[2J\033[H'; "
        # shellcheck disable=SC2016
        kitty_size_preamble='preview_cols="${FZF_PREVIEW_COLUMNS:-60}"; preview_lines="${FZF_PREVIEW_LINES:-60}"; preview_max_lines=$(( preview_lines * 80 / 100 )); if [ "$preview_max_lines" -lt 1 ]; then preview_max_lines=1; fi; '
    else
        preview_prefix="printf '\033[2J\033[H'; "
    fi

    case "$PreferredPreview" in
        chafa) preview_order="chafa-first" ;;
        timg) preview_order="timg-first" ;;
        *) preview_order="chafa-first" ;;
    esac

    if [ "$preview_order" = "timg-first" ] && [ -n "$TIMG_BIN" ] && [ "$use_kitty_graphics" = "true" ]; then
        printf -v timg_escaped '%q' "$TIMG_BIN"
        preview_script="${preview_prefix}${kitty_size_preamble}exec ${timg_escaped} -pk -g \"\${preview_cols}x\${preview_max_lines}\" --frames=1 -- \"\$1\""
    elif [ "$preview_order" = "timg-first" ] && [ -n "$TIMG_BIN" ]; then
        printf -v timg_escaped '%q' "$TIMG_BIN"
        preview_script="${preview_prefix}exec ${timg_escaped} -pq -g 60x60 --frames=1 -- \"\$1\""
    elif [ "$preview_order" = "timg-first" ] && [ -n "$CHAFA_BIN" ] && [ "$use_kitty_graphics" = "true" ]; then
        printf -v chafa_escaped '%q' "$CHAFA_BIN"
        preview_script="${preview_prefix}${kitty_size_preamble}exec ${chafa_escaped} --format kitty --animate off --size \"\${preview_cols}x\${preview_max_lines}\" -- \"\$1\""
    elif [ "$preview_order" = "timg-first" ] && [ -n "$CHAFA_BIN" ]; then
        printf -v chafa_escaped '%q' "$CHAFA_BIN"
        preview_script="${preview_prefix}exec ${chafa_escaped} --format symbols --animate off --size 60x60 -- \"\$1\""
    elif [ -n "$CHAFA_BIN" ] && [ "$use_kitty_graphics" = "true" ]; then
        printf -v chafa_escaped '%q' "$CHAFA_BIN"
        preview_script="${preview_prefix}${kitty_size_preamble}exec ${chafa_escaped} --format kitty --animate off --size \"\${preview_cols}x\${preview_max_lines}\" -- \"\$1\""
    elif [ -n "$CHAFA_BIN" ]; then
        printf -v chafa_escaped '%q' "$CHAFA_BIN"
        preview_script="${preview_prefix}exec ${chafa_escaped} --format symbols --animate off --size 60x60 -- \"\$1\""
    elif [ -n "$TIMG_BIN" ] && [ "$use_kitty_graphics" = "true" ]; then
        printf -v timg_escaped '%q' "$TIMG_BIN"
        preview_script="${preview_prefix}${kitty_size_preamble}exec ${timg_escaped} -pk -g \"\${preview_cols}x\${preview_max_lines}\" --frames=1 -- \"\$1\""
    elif [ -n "$TIMG_BIN" ]; then
        printf -v timg_escaped '%q' "$TIMG_BIN"
        preview_script="${preview_prefix}exec ${timg_escaped} -pq -g 60x60 --frames=1 -- \"\$1\""
    else
        preview_script="${preview_prefix}printf '%s\n' \"\$1\""
    fi

    printf -v preview_command 'bash -c %q _ {1}' "$preview_script"

    if [ "$CliOnly" == "true" ]; then
        selected_row="$(
            printf '%s\n' "${Choices[@]}" | fzf \
                --exact \
                --no-hscroll \
                --height 100% \
                --border \
                --ansi \
                --no-bold \
                --header "Which image?" \
                --delimiter=$'\t' \
                --with-nth=2 \
                --preview "$preview_command"
        )"
    else
        selected_label="$(
            printf '%s\n' "${Choices[@]}" | awk -F '\t' '{print $2}' | rofi -i -dmenu -p "Which image?" -theme DarkBlue
        )"
        if [ -n "$selected_label" ]; then
            for choice_row in "${Choices[@]}"; do
                if [ "${choice_row#*$'\t'}" = "$selected_label" ]; then
                    selected_row="$choice_row"
                    break
                fi
            done
        fi
    fi

    printf '%s\n' "$selected_row"
}

CLIPIMG_ENV_FILE="$(find_clipimg_config || true)"
load_clipimg_env

while [ $# -gt 0 ]; do
    option="$1"
    case "$option" in
        -h|--help)
            display_help
            exit 0
            ;;
        -g)
            CliOnly="false"
            shift
            ;;
        --chafa)
            PreferredPreview="chafa"
            shift
            ;;
        --timg)
            PreferredPreview="timg"
            shift
            ;;
        --kitty)
            PreferKittyPreview="true"
            shift
            ;;
        --sticker)
            if [ $# -lt 2 ]; then
                printf 'Missing argument for %s\n' "$option" >&2
                display_help >&2
                exit 2
            fi
            queue_override_sticker "$2"
            shift 2
            ;;
        --create-cache)
            CreateCacheOnly="true"
            shift
            ;;
        --path-only)
            PathOnly="true"
            shift
            ;;
        --no-dragon)
            NoDragon="true"
            shift
            ;;
        *)
            if [[ "$option" == -* ]]; then
                printf 'Unknown option: %s\n' "$option" >&2
                display_help >&2
                exit 2
            fi
            RequestedStickerPacks+=("$option")
            shift
            ;;
    esac
done

if [ "$CreateCacheOnly" = "true" ]; then
    create_cache
    exit 0
fi

if [ "${#OverrideStickerNames[@]}" -gt 0 ] || [ "${#OverrideStickerDirs[@]}" -gt 0 ]; then
    build_override_choices
elif [ -f "$CLIPIMG_CACHE_FILE" ]; then
    load_choices_from_cache "$CLIPIMG_CACHE_FILE"
else
    for i in "${!StickerPackNames[@]}"; do
        stickerpack_requested "${StickerPackNames[$i]}" || continue
        build_search_items "${StickerPackNames[$i]}" "${StickerPackPaths[$i]}" "stickerpack"
    done
fi

mapfile -t Choices < <(printf '%s\n' "${Choices[@]}" | awk 'NF')

SelectedRow="$(select_image)"

if [ "$PreferKittyPreview" = "true" ] && is_kitty_terminal && ! is_tmux_session; then
    printf '\033_Ga=d,d=A;\033\\\033[2J\033[H' >/dev/tty 2>/dev/null || true
fi
SelectedImage="$(printf '%s' "$SelectedRow" | awk -F $'\t' '{print $1}')"

if [ -f "$SelectedImage" ]; then
    if [ "$PathOnly" != "true" ] && [ "$NoDragon" != "true" ] && [ -n "$DRAGON_BIN" ]; then
        launch_dragon "$SelectedImage"
    fi

    if [ "$PathOnly" != "true" ] && { [ -n "$XCLIP_BIN" ] || [ -n "$COPYQ_BIN" ]; }; then
        mime="$(mimetype -- "$SelectedImage" | awk -F ': ' '{print $2}')"
    fi

    if [ -n "$XCLIP_BIN" ]; then
        if [ "$PathOnly" = "true" ]; then
            printf '%s' "$SelectedImage" | "$XCLIP_BIN" -i -selection primary -t text/plain > /dev/null
            printf '%s' "$SelectedImage" | "$XCLIP_BIN" -i -selection clipboard -t text/plain > /dev/null
        else
            "$XCLIP_BIN" -i -selection primary -t "$mime" < "$SelectedImage" > /dev/null
            "$XCLIP_BIN" -i -selection clipboard -t "$mime" < "$SelectedImage" > /dev/null
        fi
    fi

    if [ -n "$COPYQ_BIN" ]; then
        if [ "$PathOnly" = "true" ]; then
            "$COPYQ_BIN" write 0 text/plain "$SelectedImage"
        else
            "$COPYQ_BIN" write 0 "$mime" - < "$SelectedImage"
            "$COPYQ_BIN" write 1 "$SelectedImage"
        fi
        "$COPYQ_BIN" select 0
    fi
fi

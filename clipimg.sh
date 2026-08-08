#!/bin/bash

##############################################################################
#
#  clipimg.sh
#  By Steven Saus
#  (c) 2020; licensed under the MIT license
#
#  Uses fzf or rofi to choose a sticker, icon, or clipart image from a list,
#  then copies it to the clipboard and selects it for pasting.
##############################################################################

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CLIPIMG_ENV_FILE=""

FD_FIND="$(command -v fdfind || true)"
FD_ALT="$(command -v fd || true)"
TIMG_BIN="$(command -v timg || true)"
CHAFA_BIN="$(command -v chafa || true)"
DRAGON_BIN="$(command -v dragon || true)"

IconPath=""
ClipartPath=""
CliOnly="true"
UseStickerPacks="true"
UseIcons="false"
UseClipart="false"
Choices=()
StickerPackNames=()
StickerPackPaths=()

find_clipimg_config() {
    local -a candidates=(
        "${PWD}/.clipimg.env"
        "${PWD}/clipimg.ini"
        "${PWD}/.clipimg.ini"
        "${SCRIPT_DIR}/.clipimg.env"
        "${SCRIPT_DIR}/clipimg.ini"
        "${SCRIPT_DIR}/.clipimg.ini"
    )
    local candidate

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
    echo "#  clipimg.sh [-h|--help]"
    echo "# -h, --help  show help"
    echo "# -g GUI interface only. Default is CLI/TUI."
    echo "# -a select clipart only. Not selected by default."
    echo "# -i select icon only. Not selected by default."
    echo "# By default, uncommented entries under [StickerPacks] are used."
    echo "###################################################################"
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
            icons)
                if [[ "$trimmed_line" == *=* ]]; then
                    key="$(trim_whitespace "${trimmed_line%%=*}")"
                    value="$(trim_whitespace "${trimmed_line#*=}")"
                    value="$(strip_surrounding_quotes "$value")"
                    if [[ "${key,,}" == "iconpath" ]]; then
                        IconPath="$value"
                    fi
                fi
                ;;
            clipart)
                if [[ "$trimmed_line" == *=* ]]; then
                    key="$(trim_whitespace "${trimmed_line%%=*}")"
                    value="$(trim_whitespace "${trimmed_line#*=}")"
                    value="$(strip_surrounding_quotes "$value")"
                    if [[ "${key,,}" == "clipartpath" ]]; then
                        ClipartPath="$value"
                    fi
                fi
                ;;
        esac
    done < "$CLIPIMG_ENV_FILE"
}

build_search_items() {
    local search_label="$1"
    local search_path="$2"
    local display_mode="$3"
    local -a extensions=()
    local -a finder_args=()
    local path
    local display_path
    local filename_only
    local search_root

    if ! search_root="$(realpath -e "$search_path" 2>/dev/null)"; then
        return 0
    fi

    if [ -n "$DRAGON_BIN" ]; then
        extensions=(png jpg jpeg gif webp)
    else
        extensions=(png jpg jpeg webp)
    fi

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

        Choices+=("${path}"$'\t'"${display_path}")
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

select_image() {
    local choices_file
    local preview_command=""
    local selected_row=""
    local selected_label=""
    local timg_escaped=""
    local chafa_escaped=""

    [ "${#Choices[@]}" -gt 0 ] || return 0

    choices_file="$(mktemp)"
    printf '%s\n' "${Choices[@]}" > "$choices_file"

    if [ -n "$TIMG_BIN" ]; then
        printf -v timg_escaped '%q' "$TIMG_BIN"
        preview_command="bash -c 'exec ${timg_escaped} -g 80x40 -- \"\$1\"' _ {1}"
    elif [ -n "$CHAFA_BIN" ]; then
        printf -v chafa_escaped '%q' "$CHAFA_BIN"
        preview_command="bash -c 'exec ${chafa_escaped} -- \"\$1\"' _ {1}"
    else
        preview_command="bash -c 'printf \"%s\n\" \"\$1\"' _ {1}"
    fi

    if [ "$CliOnly" == "true" ]; then
        selected_row="$(
            fzf \
                --no-hscroll \
                --height 60% \
                --border \
                --ansi \
                --no-bold \
                --header "Which image?" \
                --delimiter=$'\t' \
                --with-nth=2 \
                --preview "$preview_command" < "$choices_file"
        )"
    else
        selected_label="$(
            cut -f2- "$choices_file" | rofi -i -dmenu -p "Which image?" -theme DarkBlue
        )"
        if [ -n "$selected_label" ]; then
            selected_row="$(awk -F '\t' -v label="$selected_label" '$2 == label { print; exit }' "$choices_file")"
        fi
    fi

    rm -f "$choices_file"
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
        -a)
            UseStickerPacks="false"
            UseIcons="false"
            UseClipart="true"
            shift
            ;;
        -i)
            UseStickerPacks="false"
            UseIcons="true"
            UseClipart="false"
            shift
            ;;
        -g)
            CliOnly="false"
            shift
            ;;
        *)
            printf 'Unknown option: %s\n' "$option" >&2
            display_help >&2
            exit 2
            ;;
    esac
done

if [ "$UseStickerPacks" == "true" ]; then
    for i in "${!StickerPackNames[@]}"; do
        build_search_items "${StickerPackNames[$i]}" "${StickerPackPaths[$i]}" "stickerpack"
    done
fi

if [ "$UseClipart" == "true" ] && [ -n "$ClipartPath" ]; then
    build_search_items "clipart" "$ClipartPath" "clipart"
fi

if [ "$UseIcons" == "true" ] && [ -n "$IconPath" ]; then
    build_search_items "icon" "$IconPath" "icon"
fi

mapfile -t Choices < <(printf '%s\n' "${Choices[@]}" | awk 'NF' | sort -t $'\t' -k 2,2)

SelectedRow="$(select_image)"
SelectedImage="$(printf '%s' "$SelectedRow" | awk -F $'\t' '{print $1}')"

if [ -f "$SelectedImage" ]; then
    if [ -n "$DRAGON_BIN" ]; then
        "$DRAGON_BIN" -a -x "$SelectedImage" &
    else
        mime="$(mimetype "$SelectedImage" | awk -F ': ' '{print $2}')"
        xclip -i -selection primary -t "$mime" < "$SelectedImage" > /dev/null
        xclip -i -selection clipboard -t "$mime" < "$SelectedImage" > /dev/null
        /usr/bin/copyq write 0 "$mime" - < "$SelectedImage"
        /usr/bin/copyq select 0
        if [ "$UseIcons" == "true" ] || [ "$UseClipart" == "true" ]; then
            /usr/bin/copyq insert 1 "$SelectedImage"
            /usr/bin/copyq select 0
        fi
    fi
fi

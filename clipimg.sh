#!/bin/bash

##############################################################################
#  
#  clipimg.sh 
#  By Steven Saus 
#  (c) 2020; licensed under the MIT license
#
#  Uses fzf or rofi to choose a clipart emoji (or reaction image) from a list,
#  then copies it to the clipboard (using xclip) and selects it for pasting.
##############################################################################

#https://bbs.archlinux.org/viewtopic.php?id=144741

#Example of how to copy image to clipboard from sxiv:

# Add to config.h of sxiv
#{ true, XK_c, it_shell_cmd, (arg_t)"xcmenu -bwi image/png < \"$SXIV_IMG\"; xcmenu -bi text/uri-list \"$SXIV_IMG\"" },

#Even though, it stores it in image/png. At least sxiv itself and gimp will open the file fine in any file format you copy to the buffer for some reason (even animated gifs work).

#Add files to text/uri-list copy buffer:

#echo "file:///home/user/README\nfile:///home/user/video.mkv" | xcmenu -bi text/uri-list

#This works at least with qtfm which is the only graphical fm I have installed for testing atm.
#It should be possible to integrate this with ranger for example I think.

#does this not work for gif?

# this does work with gifs if you have DRAGON installed:
# https://github.com/mwh/dragon
# and will preferentially use DRAGON if it is in your path

##############################################################################
# Init
##############################################################################
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CLIPIMG_ENV_FILE="${SCRIPT_DIR}/.clipimg.env"

EmojiPath="/home/steven/Documents/images/emojis/"
ReactionPath="/home/steven/Documents/images/all_reactions/"
IconPath="/home/steven/.icons/"
ClipartPath="/home/steven/documents/resources/"
FD_FIND="$(command -v fdfind || true)"
FD_ALT="$(command -v fd || true)"
TIMG_BIN="$(command -v timg || true)"
CHAFA_BIN="$(command -v chafa || true)"
TempSearchPath=""
TempSearchLabel=""
Emoji="false"
Reaction="true"
Icon="false"
Clipart="false"
CliOnly="true"
Choices=()
DRAGON_bin="$(command -v dragon || true)"

if [ -f "$CLIPIMG_ENV_FILE" ]; then
    # shellcheck disable=SC1090,SC1091
    . "$CLIPIMG_ENV_FILE"
fi


##############################################################################
# Show the Help
##############################################################################
display_help(){
    echo "###################################################################"
    echo "#  copyimage.sh [-h|-c]"
    echo "# -h show help "
    echo "# -g GUI interface only. Default is CLI/TUI. "
    echo "# -a select clipart only. Not selected by default. "
    echo "# -a select icon only. Not selected by default. "
    echo "# -e select emoji only. Default is both. "      
    echo "# -r select reaction only. Default is both. "
    echo "###################################################################"
}

##############################################################################
# So that you can join two (or more) directories worth of choices
# If fdfind (what "fd" is called on Debian) is installed, it will be used 
##############################################################################

build_search_items() {
    local -a extensions=()
    local -a finder_args=()
    local path
    local relative_path
    local display_path

    if [ -n "$DRAGON_bin" ]; then
        extensions=(png jpg gif)
    else
        extensions=(png jpg)
    fi

    for path in "${extensions[@]}"; do
        finder_args+=(-e "$path")
    done

    if [ -n "$FD_FIND" ]; then
        while IFS= read -r path; do
            [ -n "$path" ] || continue
            relative_path="${path#"${TempSearchPath}"/}"
            display_path="${TempSearchLabel}: ${relative_path}"
            Choices+=("${path}"$'\t'"${display_path}")
        done < <("$FD_FIND" -a "${finder_args[@]}" . "$TempSearchPath")
    elif [ -n "$FD_ALT" ]; then
        while IFS= read -r path; do
            [ -n "$path" ] || continue
            relative_path="${path#"${TempSearchPath}"/}"
            display_path="${TempSearchLabel}: ${relative_path}"
            Choices+=("${path}"$'\t'"${display_path}")
        done < <("$FD_ALT" -a "${finder_args[@]}" . "$TempSearchPath")
    else
        while IFS= read -r path; do
            [ -n "$path" ] || continue
            relative_path="${path#"${TempSearchPath}"/}"
            display_path="${TempSearchLabel}: ${relative_path}"
            Choices+=("${path}"$'\t'"${display_path}")
        done < <(
            find -H "$TempSearchPath" -type f \( \
                -iname "*.png" -o \
                -iname "*.jpg" -o \
                -iname "*.gif" \
            \)
        )
    fi

    TempSearchPath=""
    TempSearchLabel=""
}
    #uses copyq to select image and copy it to clipboard for pasting
    while [ $# -gt 0 ]; do
    option="$1"
        case $option in
        -h) display_help
            exit
            ;;      
             #this is actually a negative selector
        -r) Emoji="false" 
            shift ;;      
        -e) Reaction="false"
            shift ;;
            # these are positive selectors, since they're not default
        -a) Clipart="true"
            Emoji="false"
            Reaction="false"
            Icon="false"
            shift ;;
        -i) Clipart="false"
            Emoji="false"
            Reaction="false"
            Icon="true"
            shift ;;            
        -g) CliOnly="false"
            shift ;;      
        esac
    done    

    
    # Creating the search items by just adding more. You can see how more 
    # switches and directories can be added here.
    # This could maybe be fancier, but it would be more complicated
    if [ "$Emoji" == "true" ];then
        TempSearchPath="$EmojiPath"
        TempSearchLabel="emoji"
        build_search_items
    fi
    if [ "$Reaction" == "true" ];then
        TempSearchPath="$ReactionPath"
        TempSearchLabel="reaction"
        build_search_items
    fi
    if [ "$Clipart" == "true" ];then
        TempSearchPath="$ClipartPath"
        TempSearchLabel="clipart"
        build_search_items
    fi
    if [ "$Icon" == "true" ];then
        TempSearchPath="$IconPath"
        TempSearchLabel="icon"
        build_search_items
    fi

    mapfile -t Choices < <(printf '%s\n' "${Choices[@]}" | sort -t $'\t' -k 2,2)


##############################################################################
# Select that Image!
#    
# add 
# --preview 'chafa {}' 
# to the fzf string to get the preview window
#    
# AFAIK there's no way to preview with rofi 
##############################################################################

select_image() {
    local choices_file
    local preview_command=""
    local selected_row=""
    local selected_label=""

    choices_file="$(mktemp)"
    printf '%s\n' "${Choices[@]}" > "$choices_file"

    if [ -n "$TIMG_BIN" ]; then
        preview_command="$TIMG_BIN -g 80x40 -- {1}"
    elif [ -n "$CHAFA_BIN" ]; then
        preview_command="$CHAFA_BIN -- {1}"
    else
        preview_command="printf '%s\n' {1}"
    fi

    if [ "$CliOnly" == "true" ]; then
        selected_row="$(
            fzf \
                --no-hscroll \
                --height 60% \
                --border \
                --ansi \
                --no-bold \
                --header "Which Reaction?" \
                --delimiter=$'\t' \
                --with-nth=2 \
                --preview "$preview_command" < "$choices_file"
        )"
    else
        selected_label="$(
            cut -f2- "$choices_file" | rofi -i -dmenu -p "Which Reaction?" -theme DarkBlue
        )"
        if [ -n "$selected_label" ]; then
            selected_row="$(awk -F '\t' -v label="$selected_label" '$2 == label { print; exit }' "$choices_file")"
        fi
    fi

    rm -f "$choices_file"

    printf '%s\n' "$selected_row"
}

SelectedRow="$(select_image)"
SelectedImage="$(printf '%s' "$SelectedRow" | awk -F $'\t' '{print $1}')"


##############################################################################
# Slap that sucker on the clipboard and select it
##############################################################################

if [ -f "$SelectedImage" ];then
    if [ -n "$DRAGON_bin" ];then
        "$DRAGON_bin" -a -x "$SelectedImage" &
    else
        mime=$(mimetype "$SelectedImage" | awk -F ': ' '{print $2}')
        # Tee does not seem to like binary data...
        xclip -i -selection primary -t "$mime" < "$SelectedImage" > /dev/null
        xclip -i -selection clipboard -t "$mime" < "$SelectedImage" > /dev/null
        #if you use copyq you need these lines to have it offer up the selection
        /usr/bin/copyq write 0 "$mime" - < "$SelectedImage"
        /usr/bin/copyq select 0
        # putting the filename in the second position
        if [ "$Icon" == "true" ] || [ "$Clipart" == "true" ];then
            /usr/bin/copyq insert 1 "$SelectedImage"
            /usr/bin/copyq select 0
        fi
    fi
fi

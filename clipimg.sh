#!/bin/bash

##############################################################################
#  Uses fzf or rofi to choose a clipart emoji (or reaction image) from a list,
#  then copies it to the clipboard (using xclip) and selects it for pasting.
##############################################################################

#does this not work for gif?

##############################################################################
# Init
##############################################################################
EmojiPath="/home/steven/images2/emojis/"
ReactionPath="/home/steven/images2/static_reaction/"
FD_FIND=$(which fdfind)
TempSearchPath=""
Emoji="true"
Reaction="true"
Choices=""

##############################################################################
# Show the Help
##############################################################################
display_help(){
    echo "###################################################################"
    echo "#  copyimage.sh [-h|-c]"
    echo "# -h show help "
    echo "# -c cli/tui interface only. Default is GUI. "
    echo "# -e select emoji only. Default is both. "      
    echo "# -r select reaction only. Default is both. "
    echo "###################################################################"
}

##############################################################################
# So that you can join two (or more) directories worth of choices
# If fdfind (what "fd" is called on Debian) is installed, it will be used 
##############################################################################

build_search_items() {
    if [ -f "$FD_FIND" ];then
        Choices+=$(fdfind -a -e png -e jpg . "$TempSearchPath")
    else
        Choices+=$(find -H "$SearchPath" -type f -iname "*.png" -or -iname "*.jpg")
    fi
    Choices+="\n"
    TempSearchPath=""
}


    #uses copyq to select image and copy it to clipboard for pasting
    while [ $# -gt 0 ]; do
    option="$1"
        case $option in
        -h) display_help
            exit
            shift ;;         
        -r) Emoji="false"  #this is actually a negative selector
            shift ;;      
        -e) Reaction="false"
            shift ;;
        -c) CliOnly="true"
            shift ;;      
        esac
    done    

    
    # Creating the search items by just adding more. You can see how more 
    # switches and directories can be added here.
    if [ "$Emoji" == "true" ];then
        TempSearchPath="$EmojiPath"
        build_search_items
    fi
    if [ "$Reaction" == "true" ];then
        TempSearchPath="$ReactionPath"
        build_search_items
    fi

##############################################################################
# Select that Image!
#    
# add 
# --preview 'chafa {}' 
# to the fzf string to get the preview window
#    
# AFAIK there's no way to preview with rofi 
##############################################################################

    
    if [ "$CliOnly" == "true" ];then
        SelectedImage=$(echo -e "$Choices" | fzf --no-hscroll -m --height 60% --border --ansi --no-bold --header "Which Reaction?" --preview 'chafa {}'  | realpath -p )
    else
        #use ROFI, not zenity 
        SelectedImage=$(echo -e "$Choices" | rofi -i -dmenu -p "Which Reaction?" -theme DarkBlue | realpath -p)
    fi

##############################################################################
# Slap that sucker on the clipboard and select it
##############################################################################

if [ -f "$SelectedImage" ];then
    mime=$(mimetype "$SelectedImage" | awk -F ': ' '{print $2}')
    # Tee does not seem to like binary data...
    xclip -i -selection primary -t "$mime" < "$SelectedImage" > /dev/null
    xclip -i -selection clipboard -t "$mime" < "$SelectedImage" > /dev/null
    #/usr/bin/copyq write 0 "$mime" - < "$SelectedImage"
    #/usr/bin/copyq select 0
fi
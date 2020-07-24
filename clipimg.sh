#!/bin/bash

##############################################################################
#  Uses fzf or rofi to choose a clipart emoji (or reaction image) from a list,
#  then copies it to the clipboard (using CopyQ) and selects it for pasting.
##############################################################################

##############################################################################
# Init
##############################################################################
EmojiPath="/home/steven/images2/emojis/"
ReactionPath="/home/steven/images2/all_reactions/"
FD_FIND=$(which fdfind)

##############################################################################
# Show the Help
##############################################################################
display_help(){
    echo "###################################################################"
    echo "#  copyimage.sh [-h|-c]"
    echo "# -h show help "
    echo "# -c cli/tui interface only. Default is GUI. "
    echo "# -e select emoji. Default is reaction. "    
    echo "###################################################################"
}


    #uses copyq to select image and copy it to clipboard for pasting
    while [ $# -gt 0 ]; do
    option="$1"
        case $option in
        -h) display_help
            exit
            shift ;;         
        -e) Emoji="true"
            shift ;;      
        -c) CliOnly="true"
            shift ;;      
        esac
    done    

    # If you have a lot of options, you could use a case statement here
    if [ "$Emoji" == "true" ];then
        SearchPath="$EmojiPath"
    else
        SearchPath="$ReactionPath"
    fi

##############################################################################
# Select that Image!
#    
# add 
# --preview 'chafa {}' 
# to the fzf string to get the preview window
#    
# If fdfind (what "fd" is called on Debian) is installed, it will be used preferentially
#
##############################################################################

    if [ -f "$FD_FIND" ];then
        if [ "$CliOnly" == "true" ];then
            SelectedImage=$(fdfind -a -e png -e jpg -e gif . "$SearchPath" | fzf --no-hscroll -m --height 50% --border --ansi --no-bold --header "Which Reaction?" | realpath -p )
        else
            #use ROFI, not zenity 
            SelectedImage=$(fdfind -a -e png -e jpg -e gif . "$SearchPath"  | rofi -i -dmenu -p "Which Reaction?" -theme DarkBlue | realpath -p)
        fi
    else
        if [ "$CliOnly" == "true" ];then
            SelectedImage=$(find -H "$SearchPath" -type f -iname "*.png" -or -iname "*.gif" -or -iname "*.jpg"  | fzf --no-hscroll -m --height 50% --border --ansi --no-bold --header "Which Reaction?" | realpath -p )
        else
            #use ROFI, not zenity 
            SelectedImage=$(find -H "$SearchPath" -type f -iname "*.png" -or -iname "*.gif" -or -iname "*.jpg"  | rofi -i -dmenu -p "Which Reaction?" -theme DarkBlue | realpath -p)
        fi
    fi

##############################################################################
# Slap that sucker on the clipboard and select it
##############################################################################

if [ -f "$SelectedImage" ];then
    mime=$(mimetype "$SelectedImage" | awk -F ': ' '{print $2}')
    /usr/bin/copyq write 0 "$mime" - < "$SelectedImage"
    /usr/bin/copyq select 0
fi
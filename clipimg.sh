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
EmojiPath="/home/steven/Documents/images/emojis/"
ReactionPath="/home/steven/Documents/images/all_reactions/"
IconPath="/home/steven/.icons/"
ClipartPath="/home/steven/documents/resources/"
FD_FIND=$(which fdfind)
TempSearchPath=""
Emoji="false"
Reaction="true"
Icon="false"
Clipart="false"
CliOnly="true"
Choices=""
DRAGON_bin=$(which dragon)


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
    if [ ! -z "$DRAGON_bin" ];then
        if [ -f "$FD_FIND" ];then
            Choices+=$(fdfind -a -e png -e jpg -e gif . "$TempSearchPath")
        else
            Choices+=$(find -H "$SearchPath" -type f -iname "*.png" -or -iname "*.jpg" -or -iname "*.gif")
        fi        
    else
        if [ -f "$FD_FIND" ];then
            Choices+=$(fdfind -a -e png -e jpg . "$TempSearchPath")
        else
            Choices+=$(find -H "$SearchPath" -type f -iname "*.png" -or -iname "*.jpg")
        fi
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
        build_search_items
    fi
    if [ "$Reaction" == "true" ];then
        TempSearchPath="$ReactionPath"
        build_search_items
    fi
    if [ "$Clipart" == "true" ];then
        TempSearchPath="$ClipartPath"
        build_search_items
    fi
    if [ "$Icon" == "true" ];then
        TempSearchPath="$IconPath"
        build_search_items
    fi
    
    if [ "$Reaction" == "true" ] || [ "$Emjoi" == "true" ] || [ "$Clipart" == "true" ];then
        SortTemp=$(echo -e "$Choices" | sort -t '/' -k 6)
    elif [ "$Icon" == "true" ];then
        SortTemp=$(echo -e "$Choices" | sort -t '/' -k 5)    
    fi
    
    Choices="$SortTemp"


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
        SelectedImage=$(echo -e "$Choices" | fzf --no-hscroll -m --height 60% --border --ansi --no-bold --header "Which Reaction?" --preview 'chafa {}'  | xargs realpath )
    else
        #use ROFI, not zenity 
        SelectedImage=$(echo -e "$Choices" | rofi -i -dmenu -p "Which Reaction?" -theme DarkBlue | xargs realpath )
    fi


##############################################################################
# Slap that sucker on the clipboard and select it
##############################################################################

if [ -f "$SelectedImage" ];then
    if [ ! -z "$DRAGON_bin" ];then
        `$DRAGON_bin -a -x "$SelectedImage" &`
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



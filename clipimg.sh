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

#does this not work for gif?

##############################################################################
# Init
##############################################################################
EmojiPath="/home/steven/images2/emojis/"
ReactionPath="/home/steven/images2/static_reaction/"
IconPath="/home/steven/.icons/"
ClipartPath="/home/steven/documents/resources/"
FD_FIND=$(which fdfind)
TempSearchPath=""
Emoji="true"
Reaction="true"
Icon="false"
Clipart="false"
CliOnly="true"
Choices=""

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
    #if you use copyq you need these lines to have it offer up the selection
    /usr/bin/copyq write 0 "$mime" - < "$SelectedImage"
    /usr/bin/copyq select 0
fi

# putting the filename in the second position
if [ "$Icon" == "true" ] || [ "$Clipart" == "true" ];then
    /usr/bin/copyq insert 1 "$SelectedImage"
    /usr/bin/copyq select 0
fi

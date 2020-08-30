#!/usr/bin/env bash


##############################################################################
#  
# Find and open an ebook from your Calibre library without, ahem, opening your 
# Calibre library. Feeds in format, author, and title to fzf / rofi for you 
# to choose, then uses epy/epr/conversion for TUI/CLI and xdg-open for GUI.
#
# Originally inspired by a script by [Miroslav Vidovic](https://github.com/miroslavvidovic/rofi-scripts)
# though rewritten, expanded, and changed quite a freaking lot.
#
# Requires Calibre books be stored in the default structure of 
# /AUTHOR/TITLE (NUBMER)/BOOKFILE
#
# For example, an example is 
# /home/steven/documents/Calibre Library/Douglas Adams/So Long, and Thanks for All the Fish (362)/So Long, and Thanks for All the Fish - Douglas Adams.epub
#
# Creates a flat file "database" on first run in $HOME/.cache/book_search_cache 
# which can be regenerated (cronjob, etc) by running this script with the -e 
# switch. 
#
# You can also regenerate it immediately before a run by using the -r switch
##############################################################################


#TODO: Get file info without relying on Calibre structure

# Books directory
BOOKS_DIR="/home/steven/documents/Calibre Library/"
FD_FIND=$(which fdfind)
EPY=$(which epy) #https://github.com/wustho/epy
EPR=$(which epr) #https://github.com/wustho/epr
declare -a FILES
REGEN="false"
CliOnly="true"
CacheFile="$HOME/.cache/book_search_cache"
# So that I don't have to worry about the structure of the path too hard
SLASHES=$(echo "$BOOKS_DIR" | grep -o '/' | wc -l)
((SLASHES++))


gen_list (){
    
    # I guess this could be done with a do-while loop and process substitution 
    # instead, but I'm on call and it's 0318 and I don't want to tear it apart.
    
    if [ -f "$FD_FIND" ];then
        mapfile FILES < <(fdfind -a -e epub -e pdf -e mobi -e azw3 . "$BOOKS_DIR")
    else
        mapfile FILES < <(find -H "$BOOKS_DIR" -type f -iname "*.pdf" -or -iname "*.epub" -or -iname "*.mobi" -or -iname "*.azw3")
    fi

    echo "" > $CacheFile
    for ((i = 0; i < ${#FILES[@]}; i++));do
        FILES[$i]=$(echo "${FILES[$i]}" | tr -d '\n')
        shortfile=$(basename "${FILES[$i]}")
        EXT=${shortfile##*.}
        PATH0=$(dirname "${FILES[$i]}")
        PATH1=$(echo "$PATH0" | cut -d '/' -f ${SLASHES}- )
        #echo "$PATH1 @"
        AUTHOR=$(echo "$PATH1" | awk -F '/' '{print $1}')
        TITLE=$(echo "$PATH1" | awk -F '/' '{print $2}' | awk -F '(' '{print $1}')
        printf "%s | %s | %s | %s \n" "${EXT}" "${AUTHOR}" "${TITLE}" "${FILES[$i]}" >> $CacheFile
    done

}



main() {

    if [ "$REGEN" != "false" ];then
        gen_list
    fi
    if [ ! -f $CacheFile ];then
        gen_list
    fi

    if [ "$CliOnly" == "true" ];then
        SelectedBook=$(cat $CacheFile | fzf --no-hscroll -m --height 60% --border --ansi --no-bold --header "Which Book?" )
    else
        #use ROFI, not zenity 
        SelectedBook=$(cat $CacheFile | rofi -i -dmenu -p "Which Book?" -theme DarkBlue)
    fi

    #extra xargs to strip newlines and whitespace
    book=$( echo "$SelectedBook" | awk -F '|' '{print $4}' | xargs)
    type=$( echo "$SelectedBook" | awk -F '|' '{print $1}' | xargs)
    echo "$book"
    read
    if [ -n "$book" ]; then
        if [ "$CliOnly" == "true" ];then
            case "$type" in
                pdf)
                    ;;
                mobi|azw3)
                    ;;
                
        
        
            if [ -f "$EPY" ];then
                executeme=$(printf "%s \"%s\"" "$EPY" "$book")
                eval "$executeme"
            elif [ -f "$EPR" ];then
                executeme=$(printf "%s \"%s\"" "$EPR" "$book")
                eval "$executeme"
            else
                xdg-open "${book}"
            fi
        else
            xdg-open "${book}"
        fi
        
    #
    else
        echo "Book file not found!"  1>&2
        exit 1
    fi

}


##############################################################################
# Show the Help
##############################################################################
display_help(){
    echo "###################################################################"
    echo "#  booksearch.sh [-h|-r]"
    echo "# -h show help "
    echo "# -r regenerate booklist (and run) "
    echo "# -e regenerate booklist (and exit) "
    echo "# -g use GUI (rofi) "
    echo "###################################################################"
}


    # Read in variables
    
    while [ $# -gt 0 ]; do
    option="$1"
        case $option in
        -h) display_help
            exit
            shift ;;      
        -r) REGEN="true"            
            shift ;;      
        -e) gen_list
            exit
            shift ;;
        -g) CliOnly="false"
            shift ;;      
        esac
    done    

main   

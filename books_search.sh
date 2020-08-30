#!/usr/bin/env bash


##############################################################################
#  
#  books_search.sh 
#  By Steven Saus 
#  (c) 2020; licensed under the MIT license
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
#
# Use -m to utilize ebook metadata instead of the file structure mentioned above.
##############################################################################


# Books directory
BOOKS_DIR="/home/steven/documents/Calibre Library/"
EXIFTOOL=$(which exiftool)
FD_FIND=$(which fdfind)
EPY=$(which epy) #https://github.com/wustho/epy
EPR=$(which epr) #https://github.com/wustho/epr
declare -a FILES
REGEN="false"
CliOnly="true"
CacheFile="$HOME/.cache/book_search_cache"
CALIBRE_STRUCTURE="true"
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
    if [ "$CALIBRE_STRUCTURE" == "true" ];then
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
    else
        for ((i = 0; i < ${#FILES[@]}; i++));do
            metadata=""
            FILES[$i]=$(echo "${FILES[$i]}" | tr -d '\n')
            metadata=$(exiftool "${FILES[$i]}")
            AUTHOR=$(echo "$metadata" | grep -e "^Creator" | grep -v "Creator Id" | awk -F ':' '{print $2}'| xargs)
            TITLE=$(echo "$metadata" | grep -e "^Title" | grep -v "Title Id" | awk -F ':' '{print $2}'| xargs)
            EXT=$(echo "$metadata" | grep -e "^File Type Extension" | awk -F ':' '{print $2}' | xargs)
            printf "%s | %s | %s | %s \n" "${EXT}" "${AUTHOR}" "${TITLE}" "${FILES[$i]}" >> $CacheFile
        done
    fi
    
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

    if [ -n "$book" ]; then
        if [ "$CliOnly" == "false" ];then
             xdg-open "${book}"
        else
            if [ ! -f "$EPY" ] && [ ! -f "$EPR" ];then
                # there is no sense doing extra processing if xdg-open is just 
                # going to handle it.
                xdg-open "${book}"
            else
                case "$type" in
                    pdf)    
                        tmpfile=$(mktemp)
                        ## Pick the one you like!
                        pdftotext -nopgbrk -layout "${book}" "$tmpfile"; bat "$tmpfile"; rm "$tmpfile"
                        #pdftohtml -c -i -s -zoom 1 "${book}" "$tmpfile"; www-browser "$tmpfile"; rm "$tmpfile"
                        exit 0
                        ;;
                    mobi|azw3)
                        tmpdir=$(mktemp -d)
                        # You hopefully have calibre?
                        ebook-convert "${book}" "$tmpdir/out.epub"  
                        book=$(echo "$tmpdir/out.epub")
                        ;;
                    *) echo "Calling reader"
                        ;;
                esac
                if [ -f "$EPY" ];then
                    executeme=$(printf "%s \"%s\"" "$EPY" "$book")
                    eval "$executeme"
                elif [ -f "$EPR" ];then
                    executeme=$(printf "%s \"%s\"" "$EPR" "$book")
                    eval "$executeme"
                fi
            fi
        fi
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
    echo "# -m Use ebook metadata, not file structure"
    echo "# FAIR WARNING: PDF METADATA IS OFTEN BORKED BEYOND RECOGNITION!"
    echo "###################################################################"
}


    # Read in variables
    
    while [ $# -gt 0 ]; do
    option="$1"
        case $option in
        -m) CALIBRE_STRUCTURE="false"
            shift ;;      
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

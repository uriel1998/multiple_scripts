#!/usr/bin/env bash

# TO SEARCH IN EPUB 
# zipgrep -ihw -C2 STRING FILE | unhtml
#
# Can multi-tag from fzf!  Search multiple books for a string!
#
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
#
# add in subject from exiftool (may need to add cpan install Activity::Zip (I think?) for tags 
#
#
# Why wasn't I using this??? 
# calibredb list -f authors,formats,cover,tags,series,series_index,title --separator §
# id is first row, so can run multiple times to attach id to each of these. Or maybe feed into 
# memory dynamically for fzf? That's probably better, innit?
# calibredb list -f authors,formats,cover,tags,series,series_index,title --separator §
# # need check for multi-format
# # preview window for cover and/or summary?
     #With Preview


#  
# use both so can use whatever backend, even without calibre at all.
##############################################################################

SCRIPTDIR="$( cd "$(dirname "$0")" ; pwd -P )"
# Books directory
BOOKS_DIR="${HOME}/documents/Calibre Library/"
EXIFTOOL=$(which exiftool)
FD_FIND=$(which fdfind)
EPY=$(which epy) #https://github.com/wustho/epy
EPR=$(which epr) #https://github.com/wustho/epr
declare -a FILES
REGEN="false"
CliOnly="true"
CacheFile="$HOME/.cache/book_search_cache"
CALIBRE_STRUCTURE="true"
CALIBREDB="true"
GUIOUTPUT="true"
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
    # using calibre db data
    if [ "$CALIBREDB" != "false" ];then
        if [ "$CliOnly" == "true" ];then
            SelectedBook=$(calibredb list -f title,authors |  awk '/^[1-9]/' | fzf +x -e -i --no-hscroll -m --height 80% --border --ansi --no-bold --preview="$SCRIPTDIR/book_search_preview.sh {}"|awk '{print $1}')
        else
            #use ROFI, not zenity 
            SelectedBook=$(calibredb list -f title,authors |  awk '/^[1-9]/' | rofi -i -dmenu -p "Which Book?" -theme DarkBlue |awk '{print $1}')
        fi
        # TODO - handle multiple selections here
        # TODO - strip out ROFI; make cli only
        # TODO - redo handling opening of books
        # TODO - searching text of ebooks
        echo "${SelectedBook}"
        exit
        NumFormats=$(calibredb list --search id:"${SelectedBook}" -f formats --for-machine 2>/dev/null | grep -c -e \"\/)
        echo "$NumFormats"
        if [ $NumFormats -gt 1 ];then
            echo "HI ${SelectedBook}"
            book=$(calibredb list --search id:"${SelectedBook}" -f formats --for-machine 2>/dev/null | grep -e \"\/ | sed 's/\"\,$/"/' | fzf | xargs)
        else
            book=$(calibredb list --search id:"${SelectedBook}" -f formats --for-machine 2>/dev/null | grep -e \"\/ | sed 's/\"\,$/"/' | xargs)
        fi
        type="${book##*.}"
                
        
    else
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
    fi

    if [ -n "$book" ]; then
        if [ "${GUIOutput}" == "true" ];then
            CliOnly="false"
        fi
        if [ "$CliOnly" == "false" ];then
             xdg-open "${book}"
        else
            if [ ! -f "$EPY" ] && [ ! -f "$EPR" ];then
                # there is no sense doing extra processing if xdg-open is just 
                # going to handle it.
                xdg-open \""${book}"\"
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
    echo "# -x use xdg-open for output (but fzf for selection) "
    echo "# -f do NOT use Calibre's database "
    echo "# -m Use ebook metadata, not file structure"
    echo "# FAIR WARNING: PDF METADATA IS OFTEN BORKED BEYOND RECOGNITION!"
    echo "###################################################################"
}

# sanity check
if [ ! -f $(which calibredb) ];then
    CALIBREDB="false"
fi

    # Read in variables
    
    while [ $# -gt 0 ]; do
    option="$1"
        case $option in
        -f) CALIBREDB="false"
            shift ;;
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
        -x) GUIOutput="true"
            shift ;;      
        -g) CliOnly="false"
            GUIOutput="false"
            shift ;;      
        esac
    done    

main   

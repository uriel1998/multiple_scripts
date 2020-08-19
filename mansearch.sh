#!/bin/bash

CacheFile=$HOME/.config/mansearch_cachefile
TempFile=$(mktemp)
Long=0
NumResults=0
declare -a ManName
declare -a ManDescription
declare -a TldrName
declare -a TldrDescription
declare -a CheatName
declare -a CheatDescription
SearchTerm="$@"
CliOnly="true"
Rebuild="false"
Run="true"
SCRIPTDIR="$( cd "$(dirname "$0")" ; pwd -P )"

building_our_database (){
    #do this first
    RawResults=""
    echo "§ Reading in manpages"
    RawResults=$(apropos . | grep -v -E '^.+ \(0\)')
    #zsoelim (1)          - satisfy .so requests in roff input
    mapfile -t ManName < <(echo "$RawResults" | awk -F ' - ' '{print $1 }' | sed 's/[[:space:]]*$//')
    mapfile -t ManDescription < <(echo "$RawResults" | awk -F ' - ' '{print $2 }' | sed 's/[[:space:]]*$//')

    #Now for cheatsheets
    #Follow the same template for any other 
    echo "§ Reading in cheatsheets"
    mapfile -t CheatName < <(cheat -l | cat | awk '{print $1 }'| sed 's/[[:space:]]*$//')
    echo "§ Reading in tldr"
    mapfile -t TldrName < <(tldr -l 2>/dev/null | awk '{print $1 }'| sed 's/[[:space:]]*$//')
    echo "§ Adding descriptions to cheats"
    # Now we're going to add descriptions to the cheatsheets...
    for ((i = 0; i < ${#CheatName[@]}; i++));do
        CheatDescription[$i]=$(echo "$RawResults" | rg -e "^${CheatName[$i]} "| awk -F '-' '{print $2 }'|head -1)
    done
    echo "§ Adding descriptions to tldr"
    for ((i = 0; i < ${#TldrName[@]}; i++));do
        TldrDescription[$i]=$(echo "$RawResults" | rg -e "^${TldrName[$i]} "| awk -F '-' '{print $2 }'|head -1)        
    done
    echo "§ Finished supplementing cheatsheets and tldr"
} 

make_choices () {
    echo "§ Compiling options"
    for ((i = 0; i < ${#TldrName[@]}; i++));do
        echo -e "${TldrName[$i]} :tldr: ${TldrDescription[$i]}" >> "$TempFile"
    done
    for ((i = 0; i < ${#CheatName[@]}; i++));do
        echo -e "${CheatName[$i]} :cheats: ${CheatDescription[$i]}" >> "$TempFile"
    done
    for ((i = 0; i < ${#ManName[@]}; i++));do
        echo -e "${ManName[$i]} :man: ${ManDescription[$i]}" >> "$TempFile"
    done
    echo "§ Sorting options"
    cat "$TempFile" | sort | uniq -u > "$CacheFile"
    rm -rf "$TempFile"
}

##############################################################################
# Show the Help
##############################################################################
display_help(){
    echo "###################################################################"
    echo "#  mansearch.sh [-h|-c]"
    echo "# -h show help "
    echo "# -g GUI interface only. Default is CLI/TUI. "
    echo "# NOTE: gui display is a bit wonky for some reason. "
    echo "# -p Prefetch and compile options. "
    echo "# -r Rebuild available options and run (raw mode). "
    echo "###################################################################"
}

choose_page (){

     #cat mansearch_cachefile | fzf --no-hscroll -m --height 60% --border --ansi --no-bold --preview="/home/steven/documents/programming/multiple_scripts/mansearch-fzf-preview {}"
    if [ "$CliOnly" == "true" ];then
        #No Preview
        #SelectedFile=$(cat "$CacheFile" | fzf --no-hscroll -m --height 60% --border --ansi --no-bold)
        #With Preview
        SelectedFile=$(cat "$CacheFile" | fzf --no-hscroll -m --height 60% --border --ansi --no-bold --preview="$SCRIPTDIR/mansearch-fzf-preview {}" | sed 's/ (/./g' | sed 's/)//g' | sed 's/:man:/:man -Pcat:/g' | awk -F ':' '{print $2 " " $1}')
        if [ -z "$SelectedFile" ];then
            exit 0
        else
            eval "$SelectedFile"
        fi
    else
        #use ROFI, not zenity 
        SelectedFile=$(cat "$CacheFile"  | rofi -i -dmenu -p "Which manual?" -theme DarkBlue | sed 's/ (/./g' | sed 's/)//g' | sed 's/:man:/:man -Pcat:/g' | awk -F ':' '{print $2 " " $1}')
        if [ -z "$SelectedFile" ];then
            exit 0
        else
            OutPut=$(eval "$SelectedFile")
            rofi -location 1 -click-to-exit -lines 15 -fixed-num-lines -theme DarkBlue -e "$OutPut"
        fi
    fi   
}
 

#TODO: Have some way to annotate cheatsheets yourself?
#TODO: have preview helper put in with the rest of this file
#TODO: GUI output formatted properly
##############################################################################
# Get options
##############################################################################
    while [ $# -gt 0 ]; do
    option="$1"
        case $option in
        -h) display_help
            exit
            shift ;;      
        -r) echo "§ Rebuilding cache before run; please be patient."
            Rebuild="true"
            Run="true"
            shift ;;      
        -p) echo "§ Rebuilding cache only."
            Rebuild="true"
            Run="false"
            shift ;;
        -g) CliOnly="false"
            shift ;;      
        esac
    done    
if [ ! -f "$CacheFile" ];then 
    echo "§ Cachefile not found; rebuilding."
    Rebuild="true"
fi
if [ "$Rebuild" == "true" ];then
    building_our_database
    make_choices
fi
if [ "$Run" == "true" ];then
    choose_page
else
    exit 0
fi

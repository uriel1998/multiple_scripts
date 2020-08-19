#!/bin/bash

Long=0
NumResults=0
declare -a short_array
SearchTerm="$@"

function print_header {
printf "%s" "<html><head></head><body>"
printf "%s%s%s" "<h2>" "$SearchTerm" "</h2><table><tr>"
}

function print_first_short {
printf "%s%s%s" "<td width=50% style=\"vertical-align: top;\">" "${short_array[0]}" "</td>"
}


function print_long {
    if [ "${#short_array[@]}" -gt 0 ];then 
        ColSpanning="${#short_array[@]}"
        ((ColSpanning++))
        printf "%s%s%s" "<td rowspan=\"" "$ColSpanning" "\">"
    else
        printf "%s" "<td>"
    fi
    printf "%s%s" "$ManResult" "</td></tr>"
}

function print_rest_short {
    
    for ((i = 1; i < ${#short_array[@]}; i++));do
        printf "%s%s%s" "<tr><td style=\"vertical-align: top;\">" "${short_array[$i]}" "</td></tr>"
    done

}

function print_end {
    printf "%s" "</table></body></html>"
}


#yes, I could do this in an array as well, I guess.
CheatResult=$(cheat "$@" 2> /dev/null)
if [ "$?" != "0" ];then
    CheatResult=""
else
    short_array[${#short_array[@]}]="$CheatResult"
fi
TldrResult=$(tldr "$@" 2> /dev/null)
if [ "$?" != "0" ];then
    TldrResult=""
else
    short_array[${#short_array[@]}]="$TldrResult"
fi
HelpResult=$(help "$@" 2> /dev/null)
if [ "$?" != "0" ];then
    HelpResult=""
else
    short_array[${#short_array[@]}]="$HelpResult"
fi
ManResult=$(/usr/bin/man $@ | mandoc -T html -O fragment  2> /dev/null)
if [ "$?" != "0" ];then
    ManResult=""
else
    ((Long++))
fi


print_header
if [ "${#short_array[@]}" -gt 0 ];then
    print_first_short
fi
if [ "$Long" -gt 0 ];then
    print_long
fi
print_rest_short
print_end

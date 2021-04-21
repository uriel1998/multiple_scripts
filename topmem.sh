#!/bin/bash

ps aux | awk '{ for (i=11; i<=NF; i++) printf("%s ",$i)} {print ""}' |\
while read i
do
    STRING=$(echo "$i" | awk -F ' ' '{print $1}' )
    STRING=${STRING##*( )}
    case "$STRING" in
    [*) 
        string2=$(echo "$STRING" | cut -c 2- | rev | cut -c 2- | rev)
        ;;
    -*)
        string2=$(echo "$STRING" | cut -c 2- )
        ;;
    *)
        string2=$(basename "$STRING")
        ;;
    esac
    
    case "$string2" in
    bash*|python*)
        string3=$(echo "$i" | awk -F ' ' '{print $2}' )
        if [ -n "$string3" ];then
            tmpcmd=$(basename $string2)
        else
            tmpcmd=$(echo $string2)
        fi
        ;;
    *)
        tmpcmd=$(echo $string2)
        ;;
    esac
    echo "$tmpcmd"
    
done | sort | awk '!_[$0]++' |\
while read q
do
    if [ -n "$q" ];then
    cmdmem=$(ps -C "$q" --no-headers -o pmem | xargs | sed -e 's/ /+/g' | bc)
    cmdcpu=$(ps -C "$q" --no-headers -o pcpu | xargs | sed -e 's/ /+/g' | bc)
    echo "CPU $cmdcpu MEM $cmdmem CMD $q"
    fi
done | sort -r -s -n -k 4 | head -5

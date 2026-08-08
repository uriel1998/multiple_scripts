#!/bin/bash


# switch - Stop/Cont/Kill
# string 
# Get running processes

#command #PID #CPU #ARGS
ps ax --user "$USER" -o "%c %p %C %a" |\
while read i
do
        #STRING=$(echo "$i" | awk '{ for (i=11; i<=NF; i++) printf(" %s ",$i)} {print ""}' | sed 's/^[[:space:]]*//')
        #echo "$c_PID $c_CPU $c_MEM $STRING"
        #echo "####"
        #STRING=$(echo "$i" | cut -d ' ' -f 4- )
        #STRING=${STRING##*( )}
        case "$i" in
        [*) 
            #string2=$(echo "$STRING" | cut -c 2- | rev | cut -c 2- | rev)
            continue
            ;;
        -*)
            #string2=$(echo "$STRING" | cut -c 2- )
            continue
            ;;
        *)
            #TODO
            #This continually mis-chooses columns!! FUCK
        
            c_PID=$(echo "$i" | awk '{print $2}')
            c_CPU=$(echo "$i" | awk '{print $3}')
            STRING=$(echo "$i" | awk -F ' ' '{ for (i=4; i<=NF; i++) printf(" %s ",$i)} {print ""}' | sed 's/^[[:space:]]*//') 
            string2=$(basename "$STRING")
            echo "#### $string2"
            case "$string2" in
            bash*|python*|java*|/bin/bash*|/bin/sh*)
                echo "YES"
                string3=$(echo "$i" | awk -F ' ' '{print $2}' )
                if [ -n "$string3" ];then
                    tmpcmd=$(basename $string2)
                else
                    tmpcmd=$(echo $string2)
                fi
                ;;
            *)
                echo "NO"
                tmpcmd=$(echo $string2)
                ;;
            esac
            echo "${tmpcmd} @ ${c_PID} @ ${c_CPU} @ ${c_MEM} "

            ;;
        esac
    
done 

exit

while read q
do
    if [ -n "$q" ];then
    cmdmem=$(ps -C "$q" --no-headers -o pmem | xargs | sed -e 's/ /+/g' | bc)
    cmdcpu=$(ps -C "$q" --no-headers -o pcpu | xargs | sed -e 's/ /+/g' | bc)
    echo "CPU $cmdcpu MEM $cmdmem CMD $q"
    fi
done | sort -r -s -n -k 2 | head -5

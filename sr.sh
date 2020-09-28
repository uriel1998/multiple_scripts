#!/bin/bash

##############################################################################
#
#  sr.sh
#  Wrapper for surfraw using fzf but able to be dropped inline
#  (c) Steven Saus 2020
#  Licensed under the MIT license
#
##############################################################################


AllVars="${@}"
FirstVar="${1}"
SecondVar="${2}"
Binary=$(which surfraw)

# Check if -g was passed to it for graphical browser

if [[ "${FirstVar}" == "-g" ]];then 
    FirstVar="${SecondVar}"
fi

# read in array of elvi
readarray -t sr_elvi < <(sr -elvi | awk '{print $1}')

# Was the elvi specified on the command line?
if [[ " ${sr_elvi[@]} " =~ " ${FirstVar} " ]]; then
    CommandString=$(echo "${Binary} ${AllVars}")
    eval "${CommandString}"

fi

# use fzf to determine which elvi to use
if [[ ! " ${sr_elvi[@]} " =~ " ${FirstVar} " ]]; then
    Elvi=$(sr -elvi | fzf --multi | awk '{print $1}')
    
    # If nothing selected, assume it's the default and pass it all to sr
    if [ -z "${Elvi}" ];then
        CommandString=$(echo "${Binary} ${AllVars}")
        eval "${CommandString}"
    else
        for e in $Elvi;do
            echo "Searching ${e%}..."
            CommandString=$(echo "${Binary} ${e} ${AllVars}")
            eval "${CommandString}"
        done    
    fi
fi

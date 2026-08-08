#!/bin/bash

##############################################################################
#
#  lowload.sh
#  Get the functionality of atd and task-spooler together 
#  (c) Steven Saus 2021
#  Licensed under the MIT license
#
##############################################################################

# first var is command to run
# second var is for task-spooler/process label

AllVars="${@}"
FirstVar="${1}"
SecondVar="${2}"
Binary=$(which tsp)

if [ -f "/tmp/${SecondVar}" ]; then
    echo "Process ${SecondVar} still waiting to execute from last run" >&2
    exit 99
fi

touch "/tmp/${SecondVar}"

MyLoad=$(cat /proc/loadavg | awk '{print $1}')
    while [[ "$MyLoad" > 2 ]];do                      ####EDIT THIS LINE FOR LOAD CHANGES
        echo "Waiting for load to drop below 2"
        sleep 20s
        echo "."
        MyLoad=$(cat /proc/loadavg | awk '{print $1}')
    done

rm "/tmp/${SecondVar}"

tsp -L "${SecondVar}" -d "${FirstVar}"

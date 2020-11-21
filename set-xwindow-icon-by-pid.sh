#!/bin/bash

##############################################################################
#  set-xwindow-icon-by-pid 
#  (c) Steven Saus 2020
#  Licensed under the MIT license
#
##############################################################################

ProgramToSearchFor=${1}
IconToUse=$(realpath ${2})

# Icon themes in ~/.gtkrc-2.0  and ~/.config/gtk-3.0/settings.ini

if [ $# -lt 2 ]; then
	echo "You must specify a process and FULL PATH to an icon"
    exit 1
else
    if [ -f ${IconToUse} ];then

        psx=$(ps aux | grep $1)
        num=$(echo "$psx"|grep --color=auto -c -v -e grep -e $0)
        if [ $num -gt 0 ];then
            MyPID=$(echo "$psx" | awk '{print $2}')
            MyWindowID=$(xdotool search --pid "${MyPID}")
            xseticon -id ${MyWindowID} ${IconToUse}
        fi
    else
        echo "There was no icon present!"
        exit 1
	fi  
fi

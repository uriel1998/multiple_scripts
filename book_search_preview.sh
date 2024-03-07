#!/bin/bash

Instring="$@" 
ID=$(echo "${Instring}" | awk '{print $1}')
#Command=$(echo "$Instring" | sed 's/ (/./g' | sed 's/)//g' | sed 's/:man:/:man -Pcat:/g' | awk -F ':' '{print $2 " " $1}')
# install unhtml from pacakage manager
if [ -f $(which unhtml) ];then 
    calibredb show_metadata "${ID}" | unhtml 
else
    calibredb show_metadata "${ID}" 
fi

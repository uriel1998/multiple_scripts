#!/bin/bash

##############################################################################
#
#  sbagen_select
#  Wrapper for searching and quickly viewing sbagen files using fzf,rg, and bat 
#  (c) Steven Saus 2021
#  Licensed under the MIT license
#
##############################################################################

SBAGenDir="/home/steven/apps/sbagen-1.4.4/"
OGGDir="/home/steven/apps/sbagen-1.4.4/"
sbgfile=""
sbgfile=$(fdfind . ${SBAGenDir} --follow --type file --extension sbg | fzf --no-hscroll -m --height 90% --border --ansi --no-bold --header="Choose SBA file" --preview='sed -n "/^#/p" {}')
oggfile=""
oggfile=$(fdfind . ${SBAGenDir} --follow --type file --extension ogg | fzf --no-hscroll -m --height 90% --border --ansi --no-bold --header="Choose background" )

if [ -z "${oggfile}" ];then
    /usr/bin/xterm -e /usr/bin/padsp_32 /home/steven/apps/sbagen-1.4.4/sbagen "${sbgfile}" &
else
    /usr/bin/xterm -e /usr/bin/padsp_32 /home/steven/apps/sbagen-1.4.4/sbagen -m "${oggfile}" "${sbgfile}" &
fi

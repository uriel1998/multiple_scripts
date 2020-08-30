#!/bin/bash

##############################################################################
#  
#  tmux_topbar.sh
#  By Steven Saus 
#  (c) 2020; licensed under the MIT license
#
##############################################################################
    c_tmux=$(env | grep -c TMUX)
    if [ $c_tmux -gt 0 ];then
        command=$(echo "$@")
        tmux split-window -v 
        #"$command"
        c_pane=$(tmux ls -F "#D")
        printf '\033]2;%s\033\\' 'topbar'
        tmux resize-pane -t "$c_pane" -R 20
        tmux select-pane -m -t "$c_pane"
        #echo "$c_pane"
        tmux send-keys -t "$c_pane" "$command && exit" C-m
    fi
    
    
#    if [ $c_tmux -gt 0 ];then
#        tmux kill-pane -t "$c_pane"
#    fi



# Is it tmux?
# Does the sidebar already exist in this window?
#   if not, create sidebar and export variable

#!/bin/bash


#maybe use this as a setup for those programs and have a permanent sidebar?
#tmux send-keys -t "%74" "chafa " "/home/steven/downloads/images/big_keys_for_logo.jpg" "C-m"
# See the space!!!
#replaces man command - makes help a fallback
# use pick to deal with the output better
#TOD

    c_tmux=$(env | grep -c TMUX)
    if [ $c_tmux -gt 0 ];then
        command=$(echo "$@")
        o_pane=$(tmux ls -F "#D")
        tmux split-window -v 
        #"$command"
        c_pane=$(tmux ls -F "#D")
        tmux swap-pane -s "$o_pane" -t "$c_pane"
        printf '\033]2;%s\033\\' 'topbar'
        tmux resize-pane -t "$c_pane" -U 14
        #tmux select-pane -m -t "$c_pane"
        command2=$(echo "$command ; tmux kill-pane -t ${c_pane}")
        tmux send-keys -t "$c_pane" "$command2" C-m
        tmux last-pane
        #tmux send-keys -t "$o_pane" C-o C-m
    fi
    
    
#    if [ $c_tmux -gt 0 ];then
#        tmux kill-pane -t "$c_pane"
#    fi



# Is it tmux?
# Does the sidebar already exist in this window?
#   if not, create sidebar and export variable

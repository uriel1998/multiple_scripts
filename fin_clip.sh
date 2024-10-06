#!/bin/bash

# this is a small little utility to F'IN FINALLY CLIP THE DANG THING

if [ $# -eq 0 ]; then                                                 
    # no arguments passed, use stdin
    input=$(cat)
else
    if [ -f "${1}" ];then
        input=$(cat "${1}")    
    fi
fi
    
    echo "${input}" | xclip -i -selection primary -r 
    echo "${input}" | xclip -i -selection secondary -r 
    echo "${input}" | xclip -i -selection clipboard -r 
    echo "${input}" | tr -d '/n' | /usr/bin/copyq write 0  - 
    /usr/bin/copyq select 0

#!/bin/bash

##############################################################################
#  
#  to_clipboards
#  By Steven Saus 
#  (c) 2020; licensed under the MIT license

    if [ "$#" -gt 0 ]; then
        # concatenated arguments fed via a pipe.
        MyData=$(printf %s "${@}")
    else
        MyData=$(</dev/stdin)
    fi

    echo "${MyData}" | xclip -i -selection primary -r 
    echo "${MyData}" | xclip -i -selection secondary -r 
    echo "${MyData}" | xclip -i -selection clipboard -r 
    echo "${MyData}" | tr -d '/n' | /usr/bin/copyq write 0  - 
    /usr/bin/copyq select 0

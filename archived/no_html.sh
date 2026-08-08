#!/bin/bash

# as argument, takes either URL or FILE
# from stdin, takes URL, FILE, or raw HTML
# dumps it all to stdout


# Read from first argument if present, else from stdin
if [ -n "$1" ]; then
    INPUT="$1"
else
    # Read from stdin into variable
    INPUT="$(cat)"
fi

# Check if input is a URL
if [[ "$INPUT" =~ ^https?:// ]]; then
    URL="${INPUT}"
    # urlencode back part of url for safety
    INPUT=$(wget -e robots=off https://$(urlencode -m $(echo "${URL}" | sed 's|^https\?://||')) -O-)
   
# Check if input is a valid file or path
elif [ -e "$INPUT" ]; then
    FILE="$INPUT"
    INPUT=$(cat "${FILE}")
fi

# If it were neither of the others, it's raw input to be piped in.


echo "${INPUT}" | lynx -dump -nolist -assume_charset=UTF-8 -force_empty_hrefless_a -hiddenlinks=ignore -html5_charsets -dont_wrap_pre -width=130 -collapse_br_tags -stdin

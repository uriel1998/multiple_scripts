#!/bin/bash

##############################################################################
#  
#  books_search_preview.sh 
#  By Steven Saus 
#  (c) 2024; licensed under the MIT license
#
###############################################################################

Instring="$@" 
ID=$(echo "${Instring}" | awk '{print $1}')

# if the first bit is an ID, I'm assuming it's from calibredb and in that format
# otherwise, it's my "old" filename-based format, which would still be useful if 
# you are NOT using Calibre, but are using something else to manage your library
# but have tagged your ebooks.
#

if [ "$ID" -eq "$ID" ] 2>/dev/null
then
    # install unhtml from pacakage manager
    if [ -f $(which unhtml) ];then 
        calibredb show_metadata "${ID}" | unhtml 
    else
        calibredb show_metadata "${ID}" 
    fi
else
    # xargs to trim whitespace
    FILENAME=$(echo "${Instring}" | awk -F '|' '{print $4}' | xargs )
    if [ -f $(which unhtml) ];then 
        exiftool "${FILENAME}" | unhtml 
    else
        exiftool "${FILENAME}"
    fi
fi

#!/bin/bash

#uses copyq to select image and copy it to clipboard for pasting

filename=$(realpath $1)
if [ -f "$filename" ];then
    mime=$(mimetype "$filename" | awk -F ': ' '{print $2}')
    /usr/bin/copyq write 0 "$mime" - < "$filename"
    /usr/bin/copyq select 0
fi
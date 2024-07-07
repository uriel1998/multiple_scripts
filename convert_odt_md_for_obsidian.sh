#!/bin/bash


# This is a simple thing to ease conversion to Obsidian by making ODT files
# into markdown. Will be adding DOCX, etc, shortly
# Run through your vault directory, find ODT files, convert to md
# copy OG file to an archive directory, 
# create file:// link in each md note to OG file

INDIR=""
ARCDIR=""
LOUD=0

function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@"
    fi
}

# STARTUP
# get start path & archive directory

if [ ! -d "${1}" ];then
    echo "Input directory does not exist"
    exit 99
else
    INDIR="${1}"
fi

if [ ! -d "${2}" ];then
    mkdir -p "${2}"
fi
ARCDIR="${2}"
    
# find odt files
odtfiles=$(find "${INDIR}" -name '*.odt' -printf '"%p"\n' | xargs -I {} realpath {})
# loop
while read -r line; do
    # split to path, filename, extension
    # convert to markdown with pandoc
    filedir=$(dirname "${line}")
    filename=$(basename "${line}")
    filename_only="${filename%.*}"
    extension="${line##*.}"
    file_and_path="${line%.*}"
    outfile_path=$(printf "%s.md" "${file_and_path}")


    echo "${line}"
    echo "${filename}"
    echo "${filename_only}"
    echo "#${file_and_path}"
    echo "${extension}"
    echo "${filedir}"
    echo "${outfile_path}"
    echo "####" 
    
        pandoc -f odt -t markdown "${file_and_path}.${extension}" -o "${outfile_path}"
        # if successful copy odt file to archive directory
        mv "${line}" "${ARCDIR}"
        printf "\n[Original File:](file://%s/%s)\n" "${ARCDIR}" "${filename}" >> "${file_and_path}.md"

done < <(echo "${odtfiles}")


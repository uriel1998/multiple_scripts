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


process_a_path () {
    # take in the string, read it into array
    IFS=/ read -a arr <<< "${1}"
    i=0
    seglen=0
    while [ $i -lt "${#arr[@]}" ]; do 
        seglen="${#arr[$i]}"
        arr[$i]=$(printf '%s\n' "${arr[$i]}" | iconv -t ASCII//TRANSLIT - | inline-detox)  
        if [ ${#arr[$i]} -eq 0 ];then 
            arr[$i]=$(printf '%*s' "$seglen" | tr ' ' "%20")
        fi
        let i=i+1
    done
    # stitch it back together
    processed_path=$(printf '/%s' "${arr[@]}")
    # remove EXTRA leading slash from printf above
    processed_path="${processed_path:1}"
    # remove condition where there's an empty portion of PATH
    processed_path=$(printf "%s" "${processed_path}" | sed 's@\/\/@\/_\/@g')
    echo "${processed_path}"
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
ESCAPED_ARCDIR=$(printf '%s' "$ARCDIR" | sed 's/\ /%20/g')
echo "${ESCAPED_ARCDIR}"
 

    
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
    pandoc -f odt -t markdown "${file_and_path}.${extension}" -o "${outfile_path}"
    # if successful copy odt file to archive directory
    NOBASE_SOURCE=${1#"file://"}
    bob=$(process_a_path "${filename}")
    echo "${ARCDIR}/${bob}"        
    mv "${line}" "${ARCDIR}/${bob}"
    printf "\n[Original File:](file://%s%s)\n" "${ESCAPED_ARCDIR}" "${bob}" >> "${file_and_path}.md"
done < <(echo "${odtfiles}")


# rtf is done through using UNRTF -- pandoc by itself will sometimes choke!
# find rtf files
rtffiles=$(find "${INDIR}" -name '*.rtf' -printf '"%p"\n' | xargs -I {} realpath {})
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
    echo "$line"
    echo "$file_and_path.$extension"
    unrtf --html "${file_and_path}.${extension}" | pandoc -f html -t markdown -o "${outfile_path}"
    # if successful copy odt file to archive directory
    NOBASE_SOURCE=${1#"file://"}
    bob=$(process_a_path "${filename}")
    echo "${ARCDIR}/${bob}"        
    mv "${line}" "${ARCDIR}/${bob}"
    printf "\n[Original File:](file://%s%s)\n" "${ESCAPED_ARCDIR}" "${bob}" >> "${file_and_path}.md"
done < <(echo "${rtffiles}")


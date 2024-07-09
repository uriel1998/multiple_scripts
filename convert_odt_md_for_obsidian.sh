#!/bin/bash


# This is a simple thing to ease conversion to Obsidian by making ODT files
# and RTF files into markdown and moving the original files to an archive directory.

# usage: bash ./convert_odt_md_for_obsidian.sh /full/path/to/vault /full/path/to/archive/directory

# ARCHIVE DIRECTORY MUST BE OUTSIDE OF YOUR VAULT TO AVOID LOOPING
# Checks for and renames (by adding # to the end of the filename) if existing 
# markdown or ODT/RTF file exists. That said, backup before use! 
# Run through your vault directory, find ODT files, convert to md
# Do the same for RTF
# copy OG file to an archive directory
# create file:// link in each md note to OG file

#  (c) Steven Saus 2024
#  Licensed under the MIT license

# FRAK - it needs to chdir to the source directory so the extracted jpgs etc
# are in the right place


INDIR=""
ARCDIR=""
LOUD=1

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
loud "Archive Dir Will Be: ${ESCAPED_ARCDIR}"
 

    
# find odt files
odtfiles=$(find "${INDIR}" -name '*.odt' -printf '"%p"\n' | xargs -I {} realpath {})
# loop
while read -r line; do
    if [ -f "${line}" ];then
        # split to path, filename, extension
        # convert to markdown with pandoc
        filedir=$(dirname "${line}")
        filename=$(basename "${line}")
        filename_only="${filename%.*}"
        extension="${line##*.}"
        file_and_path="${line%.*}"
        outfile_path=$(printf "%s.md" "${file_and_path}")
        i=0
        while : ; do
            ((i++))
            [[ -f "${outfile_path}" ]] || break
            outfile_path=$(printf "%s%s.md" "${file_and_path}" ${i})
        done
        loud "${outfile_path}"        
        pandoc -f odt -t markdown "${file_and_path}.${extension}" -o "${outfile_path}"
        # if successful copy odt file to archive directory
        NOBASE_SOURCE=${1#"file://"}
        bob=$(process_a_path "${filename}")
        i=0
        while : ; do
            ((i++))
            [[ -f "${ARCDIR}/${bob}" ]] || break
            bob=$(process_a_path "${filename_only}$i.${extension}")
        done
        echo "${ARCDIR}/${bob}"        
        mv "${line}" "${ARCDIR}/${bob}"
        printf "\n[Original File:](file://%s%s)\n" "${ESCAPED_ARCDIR}" "${bob}" >> "${file_and_path}.md"
    fi
done < <(echo "${odtfiles}")


# rtf is done through using UNRTF -- pandoc by itself will sometimes choke!
# find rtf files
rtffiles=$(find "${INDIR}" -name '*.rtf' -printf '"%p"\n' | xargs -I {} realpath {})
# loop
while read -r line; do
    # split to path, filename, extension
    # convert to markdown with pandoc
    if [ -f "${line}" ];then
        filedir=$(dirname "${line}")
        filename=$(basename "${line}")
        filename_only="${filename%.*}"
        extension="${line##*.}"
        file_and_path="${line%.*}"
        outfile_path=$(printf "%s.md" "${file_and_path}")
        i=0
        while : ; do
            ((i++))
            [[ -f "${outfile_path}" ]] || break
            outfile_path=$(printf "%s%s.md" "${file_and_path}" ${i})
        done
        loud "${outfile_path}"
        unrtf --html "${file_and_path}.${extension}" | pandoc -f html -t markdown -o "${outfile_path}"
        # if successful copy odt file to archive directory
        NOBASE_SOURCE=${1#"file://"}
        bob=$(process_a_path "${filename}")
        i=0
        while : ; do
            ((i++))
            [[ -f "${ARCDIR}/${bob}" ]] || break
            bob=$(process_a_path "${filename_only}$i.${extension}")
        done
        loud "${ARCDIR}/${bob}"        
        mv "${line}" "${ARCDIR}/${bob}"
        printf "\n[Original File:](file://%s%s)\n" "${ESCAPED_ARCDIR}" "${bob}" >> "${file_and_path}.md"
    fi
done < <(echo "${rtffiles}")


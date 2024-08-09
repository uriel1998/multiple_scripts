#!/bin/bash

# initializing arrays
export ImageFile=()
export ImageBright=()

if [ -d "${1}" ];then
    DIRECTORY="${1}"
else
    DIRECTORY="${PWD}"
fi

cd "${DIRECTORY}"
imgfiles=$(fdfind -a -0 -e jpg -e jpeg -e png | xargs --null -I {} realpath {} )

rm ~/imagebright.csv

while read -r line; do
    # echo "${line}"
    if [ -f "${line}" ];then 
        filename=$(basename "${line}")
        OIFS=$IFS
        IFS=$'\n'; set -f
        brightcolor=$(timeout 10 convert "${line}" -colorspace Gray -format "%[fx:quantumrange*image.mean]" info:)
        ImageFile+=("${line}")
        ImageBright+=("${brightcolor}")
        printf "%60s%10s\n" "${filename}" "${brightcolor}"
        printf "%s,%s\n" "${line}" "${brightcolor}" >> ~/imagebright.csv
        IFS=OIFS
    fi
done < <(echo "${imgfiles}")

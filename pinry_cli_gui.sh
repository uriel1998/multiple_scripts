#!/bin/bash


# Create the YAD form
process_file () {
    local file="${1}"
    
    TEMPFILE3=$(mktemp)    
    convert "${file}" -resize "600x600" "${TEMPFILE3}"
    result=$(yad --form --title="Enter Information" \
        --geometry=650x610 \
        --image="${TEMPFILE3}" \
        --field="Tags":TXT "" \
        --field="Board":TXT "maps" \
        --columns=2 \
        --width=650 \
        --height=620)
    # Check if the form was canceled or closed
    if [[ -z "$result" ]]; then
        echo "Dialog was canceled."
    else
        # Parse the result
        board=$(echo "$result" | awk -F '|' '{print $2}')
        tags=$(echo "$result" | awk -F '|' '{print $1}')

        # Display the entered values
        echo "Board: $board"
        echo "Tags: $tags"
        file=$(echo $(realpath "${file}"))
        /home/steven/.local/bin/pinry add "${file}" --board "${board}" --tags "${tags}"
    fi
    rm "${TEMPFILE3}"
}


# Check if $1 is passed
if [[ -z "$1" ]]; then
    echo "Usage: $0 <directory_or_file>"
    exit 1
fi

 
# Check if $1 is a directory
if [[ -d "$1" ]]; then
    echo "$1 is a directory."
    
    # Loop over files with extensions .webp, .gif, .jpg, .png
find "$1" -type f \( -iname "*.webp" -o -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | while read -r file; do
        # Check if the file exists (to avoid cases with no matching files)
        if [[ -e "$file" ]]; then
            process_file "$file"
        fi
    done

# Check if $1 is a file
elif [[ -f "$1" ]]; then
    echo "$1 is a file."
    process_file "$1"

else
    echo "$1 is not a valid file or directory."
    exit 1
fi

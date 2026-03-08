#!/bin/bash


# Create the YAD form
process_file () {
    local file="${1}"
    exists=$(grep -i "${HOME}/.local/share/pinrycli/uploaded_to_pinry" -e "${file}" -c)
    if [[ "$exists" == "0" ]];then
		if [ -f $(which exiftool) ];then
			taglist=""
			taglist=$(exiftool "${1}" | grep Subject | awk -F ':' '{print $2}' | xargs )
			# xargs trims beginning, ending whitespace from tags
			description=$(exiftool "${1}" | grep Comment | awk -F ':' '{print $2}')
		fi
		# skip assets
		if [[ "$taglist" != *"asset"* ]];then 
			TEMPFILE3=$(mktemp)    
			convert "${file}" -resize "600x600" "${TEMPFILE3}"
			if [ -f $(which ai_gen_alt_text.sh) ] && [[ "${description}" == "" ]];then 
				description=$(ai_gen_alt_text.sh "${TEMPFILE3}" "Describe this in one sentence using no punctuation and not mentioning it is an image" | sed -e 's/ "/ “/g' -e 's/" /” /g' -e 's/"\./”\./g' -e 's/"\,/”\,/g' -e 's/\."/\.”/g' -e 's/\,"/\,”/g' -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/(/❲/g' -e 's/)/❳/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g' | hxunent -f)
			fi
			if [[ "$taglist" == "" ]] && [[ "$description" != "" ]];then
				result=$(yad --form --title="Enter Information" \
					--geometry=650x610 \
					--columns=2 \
					--width=650 \
					--height=620 \
					--image="${TEMPFILE3}" \
					--field="Tags":TXT "${taglist}" \
					--field="Board":TXT "maps" \
					--field="Description":TXT "${description}" )
			else
				result="${taglist}|maps|${description}"
			fi
			# Check if the form was canceled or closed
			if [[ -z "$result" ]]; then
				echo "Dialog was canceled."
			else
				# Parse the result
				if [[ "${file}" == *"[D|d]ay"* ]];then
					taglist=echo "day,${taglist}"
				fi
				if [[ "${file}" == *"[N|n]ight"* ]];then
					taglist=echo "night,${taglist}"
				fi			
				board=$(echo "$result" | awk -F '|' '{print $2}')
				tags=$(echo "$result" | awk -F '|' '{print $1}')
				desc=$(echo "${result}" | awk -F '|' '{print $3}'| sed -e 's/ "/ “/g' -e 's/" /” /g' -e 's/"\./”\./g' -e 's/"\,/”\,/g' -e 's/\."/\.”/g' -e 's/\,"/\,”/g' -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/(/❲/g' -e 's/)/❳/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g' | hxunent -f)
				# Display the entered values
				echo "Board: ${board}"
				echo "Tags: ${tags}"
				echo "Description: ${desc}"
				if [ -f $(which exiftool) ] && [[ "${desc}" != "" ]];then
					exiftool -preserve -overwrite_original_in_place -comment="${desc}" "${file}"
				fi
				file=$(echo $(realpath "${file}")) 
				outstring=$(printf "/home/steven/.local/bin/pinry add \"%s\" --board %s --tags \"%s\" --description \"%s\"" "${file}" "${board}" "${tags}" "${desc}")
				echo "${outstring}"
				eval "${outstring}"
				echo "${file}" >> "${HOME}/.local/share/pinrycli/uploaded_to_pinry"
			fi
			rm "${TEMPFILE3}"
		fi
	else
		echo "Already uploaded."
	fi
}


### INPOINT


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

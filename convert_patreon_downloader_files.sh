#!/bin/bash


##############################################################################
#
#  Script to take output from Patreon Downloader and turn it into usable 
#  markdown, open document, DOCX, and HTML (with linked local images) files.
#  
#  Patreon Downloader = https://github.com/AlexCSDev/PatreonDownloader
#  Pandoc = https://pandoc.org
#
#  Don't be a jerk with this, support independent artists and creators.
#
#  (c) Steven Saus 2023
#  Licensed under the MIT license
#
#  You will get a LOT of "cannot determine media type" warnings; ignore them.
#
##############################################################################

#convert to usable

if [ -d "${1}" ];then
    DIRECTORY="${1}"
else
    DIRECTORY="${PWD}"
fi

IFS=$'\n'; set -f
for f in $(find "${DIRECTORY}" -name 'description.html'); do 
    currdir=$(dirname "${f}")
    echo "${currdir}"
    
    titlestring=$(dirname "$(echo "${f}")" | awk -F '] ' '{print $2}')
    date_posted=$(echo "${titlestring}" | awk '{print $1}')
    title=$(echo "${titlestring}" | awk -F "$date_posted " '{print $2}')
    fixed_title=$(echo "${title}" | sed -e 's/ "/ “/g' -e 's/" /” /g' -e 's/"\./”\./g' -e 's/"\,/”\,/g' -e 's/\."/\.”/g' -e 's/\,"/\,”/g' -e 's/"/“/g' -e "s/'/’/g")    
    echo "${fixed_title} Beginning"
    # proper detox for filename
    filename=$(echo "${fixed_title}" | detox --inline)
    pandoc "${f}" -f html -s -o "${currdir}/${filename}.odt" 
    pandoc "${f}" -f html -s -t markdown -o "${currdir}/${filename}.md" 

    echo "${currdir}/${filename}.md"
    
# detox of file INLINE
    sed -i -e 's/ "/ “/g' -e 's/" /” /g' -e 's/"\./”\./g' -e 's/"\,/”\,/g' -e 's/\."/\.”/g' -e 's/\,"/\,”/g' -e 's/"/“/g' -e "s/'/’/g" "${currdir}/${filename}.md"
    
    sed -i -e 's/\\“/“/g' "${currdir}/${filename}.md"
    sed -i -e 's/\\”/”/g' "${currdir}/${filename}.md"
    sed -i -e 's/\\’/’/g' "${currdir}/${filename}.md"
    
    # add header
    sed -i "1s/^/# ${fixed_title}\n \n/" "${currdir}/${filename}.md"
    # To see if images are more properly embedded here now
    pandoc "${currdir}/${filename}.md" -t odt -o "${currdir}/${filename}_alt.odt"
    
    # Now to make the epub 
    
    echo "---" > "${currdir}/title.txt"
    echo "title: ${fixed_title}" >> "${currdir}/title.txt"
    echo "language: en-US" >> "${currdir}/title.txt"
    echo "..." >> "${currdir}/title.txt"
    pandoc -o "${currdir}/${filename}.epub" "${currdir}/title.txt" "${currdir}/${filename}.md"
    
    # TRUST ME; if you have more than a few files with a few images, do NOT use 
    # pandoc's ability to merge all these into a single epub. Instead use a 
    # tool like Calibre to handle them, otherwise you may run out of memory.
        
    # Now to bring it back to HTML with images linked properly locally.
    
    pandoc "${currdir}/${filename}.epub" -f epub -t html -o "${currdir}/${filename}_final.html"
    cp "${currdir}/${filename}.epub" "${currdir}/${filename}.zip"
    unzip -j "${currdir}/${filename}.zip" "EPUB/media/*" -d "${currdir}/media"
    rm "${currdir}/${filename}.zip"
    
    #echo "${f}"
    echo "${fixed_title} ending"
    #echo "${date_posted}"

done
unset IFS; set +f

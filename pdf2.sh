#!/usr/bin/bash

########################################################################
#
#	Because I want to be able to utilize PDF files.
#	by Steven Saus
#	It's just a wrapper around a bunch of PDF extraction and conversion
#   things that I tied together, but you might find it useful.  Also 
#   potentially useful as part of a mailcap style opener file
#
########################################################################

if [[ -z "$1" ]]; then
    echo "Usage: $0 FILE.pdf" >&2
    exit 1
fi


filepath=$(realpath "${1}")

if [[ "${filepath,,}" != *.pdf ]]; then
    echo "Not a PDF file: $filepath" >&2
    exit 1
fi

f_name=$(basename "${filepath}" .pdf)
f_path=$(dirname "${filepath}")

# make output path under pdf file
out_path="${f_path}/${f_name}_conversion"
mkdir -p "${out_path}"

# extract images from pdf
/usr/bin/pdfimages -all "${filepath}" "${out_path}/image"

# convert pdf to actual images (I need it more often than you'd think)
/usr/bin/convert -density 300 "${filepath}" -background white -alpha remove -alpha off -resize 25% -quality 95 "${out_path}/${f_name}-%03d.jpg"
/usr/bin/convert -density 300 "${filepath}" -background white -alpha remove -alpha off -resize 25% -quality 95 "${out_path}/${f_name}-%03d.png"

(
    cd "$out_path" || exit
    zip "${f_name}.cbz" "${f_name}"-*.png
    rar a "${f_name}.cbr" "${f_name}"-*.png
)


# Get the text to HTML, and from there to text, markdown, and ODT.
if [ -f /usr/bin/pdftotext ];then
	/usr/bin/pdftotext -layout "${filepath}" "${out_path}/${f_name}_layout.txt"
fi
/usr/bin/pdftohtml -i -s -noframes -nomerge "${filepath}" "${out_path}/${f_name}.html"
if [ -f /usr/bin/lynx ];then
	/usr/bin/lynx "${out_path}/${f_name}.html" --dump > "${out_path}/${f_name}.txt"
else
	if [ -f /usr/bin/elinks ];then
		/usr/bin/elinks "${out_path}/${f_name}.html" --dump > "${out_path}/${f_name}.txt"
	fi
fi
	
/usr/bin/pandoc -f html -t odt "${out_path}/${f_name}.html" -o "${out_path}/${f_name}.odt"
/usr/bin/pandoc -f html -t gfm --wrap=none "${out_path}/${f_name}.html" -o "${out_path}/${f_name}.md"

notify-send --icon=AdobeReader "Extraction and conversion of ${f_name} complete" 

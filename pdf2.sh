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

explain_convert_pdf_failure() {
    cat >&2 <<'EOF'
PDF-to-image conversion via ImageMagick failed.

If the error mentions a security policy for PDF, ImageMagick is blocking
Ghostscript-backed PDF reads. On many systems the fix is to allow PDF in
ImageMagick's policy file, often in one of these locations:

  /etc/ImageMagick-6/policy.xml
  /etc/ImageMagick-7/policy.xml

Look for a line similar to:

  <policy domain="coder" rights="none" pattern="PDF" />

and change it to allow reading, for example:

  <policy domain="coder" rights="read|write" pattern="PDF" />

Then retry the script. Image extraction and text conversion can still continue
without the page-image and archive outputs.
EOF
}

if [[ -z "$1" ]]; then
    echo "Usage: $0 FILE.pdf" >&2
    exit 1
fi

if [[ ! -f "$1" ]]; then
    echo "File not found: $1" >&2
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

page_images_generated=0
html_output="${out_path}/${f_name}.html"

# extract images from pdf
/usr/bin/pdfimages -all "${filepath}" "${out_path}/image"

# convert pdf to actual images (I need it more often than you'd think)
if /usr/bin/convert -density 300 "${filepath}" -background white -alpha remove -alpha off -resize 25% -quality 95 "${out_path}/${f_name}-%03d.jpg" \
    && /usr/bin/convert -density 300 "${filepath}" -background white -alpha remove -alpha off -resize 25% -quality 95 "${out_path}/${f_name}-%03d.png"; then
    page_images_generated=1
else
    explain_convert_pdf_failure
fi

if [[ "$page_images_generated" -eq 1 ]] && compgen -G "${out_path}/${f_name}-*.png" > /dev/null; then
    (
        cd "$out_path" || exit
        zip "${f_name}.cbz" "${f_name}"-*.png
        rar a "${f_name}.cbr" "${f_name}"-*.png
    )
fi


# Get the text to HTML, and from there to text, markdown, and ODT.
if [ -f /usr/bin/pdftotext ];then
	/usr/bin/pdftotext -layout "${filepath}" "${out_path}/${f_name}_layout.txt"
fi

if /usr/bin/pdftohtml -i -s -noframes -nomerge "${filepath}" "${html_output}"; then
	if [ -f /usr/bin/lynx ];then
		/usr/bin/lynx "${html_output}" --dump > "${out_path}/${f_name}.txt"
	else
		if [ -f /usr/bin/elinks ];then
			/usr/bin/elinks "${html_output}" --dump > "${out_path}/${f_name}.txt"
		fi
	fi

	/usr/bin/pandoc -f html -t odt "${html_output}" -o "${out_path}/${f_name}.odt"
	/usr/bin/pandoc -f html -t gfm --wrap=none "${html_output}" -o "${out_path}/${f_name}.md"
else
	echo "pdftohtml failed for ${filepath}; skipping HTML-derived text, ODT, and Markdown outputs." >&2
fi

notify-send --icon=AdobeReader "Extraction and conversion of ${f_name} complete" 

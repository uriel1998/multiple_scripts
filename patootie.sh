 #!/bin/bash

##############################################################################
#
#  Patootie
#  Using YAD and toot to have a GUI for sending a quick toot (with possible
#  images, content warnings, etc)
#  YAD = https://sourceforge.net/projects/yad-dialog/
#  toot = https://toot.bezdomni.net/
#  (c) Steven Saus 2023
#  Licensed under the MIT license
#
##############################################################################

# Patootie uses the environment variable TOOTACCT to specify the tooting account
# otherwise it uses whichever one is currently active in toot. 

# TODO - Start with image select, drop?
# move sections to functions so I can swap order

binary=$(which toot)
if [ ! -f "${binary}" ];then
    echo "Exiting -- toot binary is not on \$PATH" 1>&2
    exit 99
fi

ANSWER=$(yad --form --separator="±" --item-separator="," --columns=2 --title "patootie" \
--field="What to toot?:TXT" "" \
--field="ContentWarning:CBE" none,discrimination,bigot,uspol,medicine,violence,reproduction,healthcare,LGBTQIA,climate,SocialMedia \
--field="Attachment?:CHK" \
--item-separator="," --button=Cancel:99 --button=Post:0)


TootText=$(echo "${ANSWER}" | awk -F '±' '{print $1}' | sed -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g')
ContentWarning=$(echo "${ANSWER}" | awk -F '±' '{print $2}' | sed -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/(/—/g' -e 's/)/—/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g')
if [ "$ContentWarning" == "none" ];then 
    ContentWarning=""
fi

# to see if need to select image
Need_Image=$(echo "$ANSWER" | awk -F '±' '{print $3}')

if [ "${Need_Image}" == "TRUE" ];then 
    IMAGE_FILE=$(yad --title "Select image to add" --width=500 --height=400 --file --file-filter "Graphic files | *.jpg *.png *.webp *.jpeg")
    if [ ! -f "${IMAGE_FILE}" ];then
        SendImage=""
    else
        if [ -f /usr/bin/convert ];then
            SendImage=$(mktemp --suffix=.png)
            /usr/bin/convert -resize 800x512\! "$IMAGE_FILE" "$SendImage"
        else
            filename=$(basename -- "$IMAGE_FILE")
            extension="${filename##*.}"
            SendImage=$(mktemp --suffix=.${extension})
            cp "${IMAGE_FILE}" "${SendImage}"
        fi
        ALT_TEXT=$(yad --window-icon=musique --on-top --skip-taskbar --image-on-top --borders=5 --title "Choose your alt text" --image "${SendImage}" --form --separator="" --item-separator="," --text-align=center --field="Alt text to use?:TXT" "I was too lazy to put alt text" --item-separator="," --separator="")
        echo "$ALT_TEXT"
        if [ ! -z "$ALT_TEXT" ];then 
            # parens changed here because otherwise eval chokes
            AltText=$(echo "${ALT_TEXT}" | sed -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/(/—/g' -e 's/)/—/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g')
            AltText=" --description \"${AltText}\""
        else
            AltText=""
        fi
        echo "$AltText"
        # now adding the beginning part to the SendImage string for binary usage        
        SendImage=" --media ${SendImage}"
    fi
fi 


if [ ! -z "$ContentWarning" ];then
    if [ -f "$SendImage" ];then
        #if there is an image, and it's a CW'd post, the image should be sensitive
        ContentWarning=$(echo "--sensitive -p \"${ContentWarning}\"")
    else
        ContentWarning=$(echo "-p \"${ContentWarning}\"")
    fi
fi
    

if [ -z "$TOOTACCT" ];then 
    echo "hi"
    postme=$(printf "%s post \"%s\" %s %s --quiet" "$binary" "${TootText}" "${SendImage}" "${ContentWarning}")
    echo "${postme}"
    echo "$postme"
    echo ${postme}
    #eval "${postme}"
else
    

    postme=$(printf "echo -e \"${TootText}\" | %s post %s %s %s -u %s --quiet" "$binary" "${SendImage}" "${AltText}" "${ContentWarning}" "${TOOTACCT}")
    echo ${postme}
    eval "${postme}"
fi

if [ -f "$SendImage" ];then
    rm -rf "${SendImage}"
fi

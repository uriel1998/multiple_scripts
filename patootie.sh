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

# If an argument is passed, it is assumed to be the image file to attach. 

Need_Image=""
IMAGE_FILE=""
TOOTVAR=TRUE
BSKYVAR=TRUE


binary=$(which toot)
if [ ! -f "${binary}" ];then
    TOOTVAR=FALSE
fi


bsky_binary=$(which bsky)
if [ ! -f "${binary}" ];then
    BSKYVAR=FALSE
fi


if [ -f "${1}" ];then
    IMAGE_FILE="${1}"
    Need_Image="TRUE"
fi

ANSWER=$( 

yad --geometry=+200+200 --form --separator="±" --item-separator="," --on-top --title "patootie" --field="What to post?:TXT" "" --field="ContentWarning:CBE" none,discrimination,bigot,uspol,medicine,violence,reproduction,healthcare,LGBTQIA,climate,SocialMedia -columns=2  --field="Attachment?":CHK "FALSE" --field="masto":CHK "$TOOTVAR" --field="bsky":CHK "$BSKYVAR" --item-separator="," --button=Cancel:99 --button=Post:0)


TootText=$(echo "${ANSWER}" | awk -F '±' '{print $1}' | sed -e 's/ "/ “/g' -e 's/" /” /g' -e 's/"\./”\./g' -e 's/"\,/”\,/g' -e 's/\."/\.”/g' -e 's/\,"/\,”/g' -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/(/—/g' -e 's/)/—/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g')
if [ "${TootText}" == "" ];then
    echo "Nothing entered, exiting"
    exit 99
fi
ContentWarning=$(echo "${ANSWER}" | awk -F '±' '{print $2}' | sed -e 's/ "/ “/g' -e 's/" /” /g' -e 's/"\./”\./g' -e 's/"\,/”\,/g' -e 's/\."/\.”/g' -e 's/\,"/\,”/g' -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/(/—/g' -e 's/)/—/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g')
if [ "$ContentWarning" == "none" ];then 
    ContentWarning=""
fi

TOOTVAR=$(echo "${ANSWER}" | awk -F '±' '{print $4}' )
BSKYVAR=$(echo "${ANSWER}" | awk -F '±' '{print $5}' )

if [ "$IMAGE_FILE" == "" ];then  # if there wasn't one by command line
    # to see if need to select image
    Need_Image=$(echo "$ANSWER" | awk -F '±' '{print $3}')
fi

if [ "${Need_Image}" == "TRUE" ];then 
    if [ "${IMAGE_FILE}" == "" ]; then # if there wasn't one by command line
        IMAGE_FILE=$(yad --geometry=+200+200  --on-top --title "Select image to add" --width=500 --height=400 --file --file-filter "Graphic files | *.jpg *.png *.webp *.jpeg")
    fi
    if [ ! -f "${IMAGE_FILE}" ];then
        SendImage=""
        BSendImage=""
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
        ALT_TEXT=$(yad --geometry=+200+200 --window-icon=musique --on-top --skip-taskbar --image-on-top --borders=5 --title "Choose your alt text" --image "${SendImage}" --form --separator="" --item-separator="," --text-align=center --field="Alt text to use?:TXT" "I was too lazy to put alt text" --item-separator="," --separator="")
        echo "$ALT_TEXT"
        if [ ! -z "$ALT_TEXT" ];then 
            # parens changed here because otherwise eval chokes
            AltText=$(echo "${ALT_TEXT}" | sed -e 's/ "/ “/g' -e 's/" /” /g' -e 's/"\./”\./g' -e 's/"\,/”\,/g' -e 's/\."/\.”/g' -e 's/\,"/\,”/g' -e 's/"/“/g' -e "s/'/’/g" -e 's/ -- /—/g' -e 's/(/—/g' -e 's/)/—/g' -e 's/ — /—/g' -e 's/ - /—/g'  -e 's/ – /—/g' -e 's/ – /—/g')
            AltBsky=" --alt \"${AltText}\""
            AltText=" --description \"${AltText}\""
        else
            AltText=""
            AltBsky=""
        fi
        # echo "$AltText"
        # now adding the beginning part to the SendImage string for binary usage        
        BSendImage=" --image ${SendImage}"
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



if [ "$BSKYVAR" == "TRUE" ];then
    if [ -f $(which loginbsky) ];then
        loginbsky
    fi


    postme=$(printf "%s post --text \"%s\" %s %s" "${bsky_binary}" "${TootText}" "${BSendImage}" "${AltBsky}" | sed 's/\\n/ /g')
    eval "${postme}"
    if [ "$?" == "0" ];then 
        notify-send "Post sent"
    else
        notify-send "Error!"
    fi    

fi

if [ "$TOOTVAR"  == "TRUE" ];then
    if [ -z "$TOOTACCT" ];then 
        postme=$(printf "%s post --text \"%s\" %s %s" "${binary}" "${TootText}" "${SendImage}" "${AltText}" "${ContentWarning}")
        
       eval "${postme}"
        if [ "$?" == "0" ];then 
            notify-send "Toot sent"
        else
            notify-send "Error!"
        fi
    else
        postme=$(printf "echo -e \"${TootText}\" | %s post %s %s %s -u %s" "$binary" "${SendImage}" "${AltText}" "${ContentWarning}" "${TOOTACCT}")
        eval "${postme}"
        if [ "$?" == "0" ];then 
            notify-send "Toot sent"
        else
            notify-send "Error!"
        fi
    fi
fi
if [ -f "$SendImage" ];then
    rm -rf "${SendImage}"
fi

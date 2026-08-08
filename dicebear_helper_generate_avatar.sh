#!/usr/bin/bash

#
# https://www.dicebear.com/playground/
#
# This is a silly wrapper around a silly tool to make avatars. Feed it a seed, or not.

seed=""
SAVE_AVATARS=1
# If you feed dicebear the same input, you'll get the same result.

if [ "$#" -eq 0 ];then
	#no input given, get random
    seed=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head | /usr/bin/shasum | awk '{print $1}' )
else
	seed=$(printf "%s\n" "${@}" | /usr/bin/shasum | awk '{print $1}')
fi

avatar_dir="/home/steven/vault/icons/dicebear"
mkdir -p "${avatar_dir}"

# If you already did it once, don't do it again

if [ ! -f "${avatar_dir}/${seed}.png" ];then
	# Try the online source with "clay" 

	wget "https://api.dicebear.com/10.x/clay/svg?animationVariant=&backgroundColor=5e5c64,813d9c,613583,1c71d8,1a5fb4,26a269&borderRadius=23&backgroundColorAngle=-67&backgroundColorFillStops=2&size=512&seed=${seed}" -O "${avatar_dir}/${seed}.png"

	# Okay, if that didn't work, then the local install with the robots one

	if [ ! -f "${avatar_dir}/${seed}.png" ];then
		if [ -f $(which dicebear) ];then
			$(which dicebear) bottts "${avatar_dir}" --animationVariant --backgroundColor '5e5c64' '813d9c' '613583' '1c71d8' '1a5fb4' '26a269' --format png --seed "${seed}"
			# note the name needs to match
			mv "${avatar_dir}/bottts-0.png" "${avatar_dir}/${seed}.png"
		fi
	fi
fi


if [ -f "${avatar_dir}/${seed}.png" ];then
	mime=$(mimetype "${avatar_dir}/${seed}.png" | awk -F ': ' '{print $2}')
	# Tee does not seem to like binary data...
	xclip -i -selection primary -t "$mime" < "${avatar_dir}/${seed}.png" > /dev/null
	xclip -i -selection clipboard -t "$mime" < "${avatar_dir}/${seed}.png" > /dev/null
	#if you use copyq you need these lines to have it offer up the selection
	/usr/bin/copyq write 0 "$mime" - < "${avatar_dir}/${seed}.png"
	/usr/bin/copyq select 0
	# Put the path in the second position with copyq
	/usr/bin/copyq write 1 "${avatar_dir}/${seed}.png"
fi


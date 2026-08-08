#!/usr/bin/bash

#
# https://www.dicebear.com/playground/
#
# This is a silly wrapper around a silly tool to make avatars. Feed it a seed, or not.

usage() {
	cat <<'EOF'
Usage:
  dicebear_helper_generate_avatar.sh [TEXT ...]
  dicebear_helper_generate_avatar.sh --help

Generates or reuses a cached avatar PNG and prints its path.

Behavior:
  - With no arguments, generates a random seed.
  - With arguments, hashes the provided text into a deterministic seed.
  - For new cached avatars, the online DiceBear API randomly uses either the
    clay or critters style.
  - If the API fetch fails and the local `dicebear` CLI is available, it falls
    back to a local `bottts` render.

Environment:
  DICEBEAR_AVATAR_DIR
    Cache directory for generated PNGs.

  DICEBEAR_NO_CLIPBOARD=1
    Skip clipboard and CopyQ updates.

Output:
  Prints the final PNG path on success.
EOF
}

seed=""
avatar_dir="${DICEBEAR_AVATAR_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/dicebear}"
skip_clipboard="${DICEBEAR_NO_CLIPBOARD:-0}"
api_style=""

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
	usage
	exit 0
fi


if [ "$#" -eq 0 ];then
	#no input given, get random
    seed=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 32 | head | /usr/bin/shasum | awk '{print $1}' )
else
	seed=$(printf "%s\n" "${@}" | /usr/bin/shasum | awk '{print $1}')
fi

mkdir -p "${avatar_dir}"

# If you already did it once, don't do it again

if [ ! -f "${avatar_dir}/${seed}.png" ];then
	# Randomize the online DiceBear style for new cached avatars.
	if [ $((RANDOM % 2)) -eq 0 ]; then
		api_style="clay"
	else
		api_style="critters"
	fi

		if ! wget -q "https://api.dicebear.com/10.x/${api_style}/png?animationVariant=&backgroundColor=5e5c64,813d9c,613583,1c71d8,1a5fb4,26a269&backgroundColorAngle=-67&backgroundColorFillStops=2&size=512&seed=${seed}" -O "${avatar_dir}/${seed}.png"; then
		rm -f "${avatar_dir}/${seed}.png"
	fi

	# Okay, if that didn't work, then the local install with the robots one

	if [ ! -f "${avatar_dir}/${seed}.png" ];then
		if command -v dicebear >/dev/null 2>&1; then
			dicebear bottts "${avatar_dir}" --animationVariant --backgroundColor '5e5c64' '813d9c' '613583' '1c71d8' '1a5fb4' '26a269' --format png --seed "${seed}"
			# note the name needs to match
			mv "${avatar_dir}/bottts-0.png" "${avatar_dir}/${seed}.png"
		fi
	fi
fi


if [ -f "${avatar_dir}/${seed}.png" ];then
	if [ "${skip_clipboard}" != "1" ]; then
		mime=$(mimetype "${avatar_dir}/${seed}.png" | awk -F ': ' '{print $2}')
		# Tee does not seem to like binary data...
		if command -v xclip >/dev/null 2>&1; then
			xclip -i -selection primary -t "$mime" < "${avatar_dir}/${seed}.png" > /dev/null
			xclip -i -selection clipboard -t "$mime" < "${avatar_dir}/${seed}.png" > /dev/null
		fi
		#if you use copyq you need these lines to have it offer up the selection
		if command -v /usr/bin/copyq >/dev/null 2>&1; then
			/usr/bin/copyq write 0 "$mime" - < "${avatar_dir}/${seed}.png"
			/usr/bin/copyq select 0
			# Put the path in the second position with copyq
			/usr/bin/copyq write 1 "${avatar_dir}/${seed}.png"
		fi
	fi

	printf '%s\n' "${avatar_dir}/${seed}.png"
fi

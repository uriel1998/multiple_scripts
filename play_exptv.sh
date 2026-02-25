#!/usr/bin/env bash

# Get current day/hour/minute/second
day=$(date +%u) # 1 = Monday
hour=$(date +%H)
minute=$(date +%M)
second=$(date +%S)

# Map day number to JS prefix and file
case "${day}" in
  1) js_day="monday-3.js"; js_prefix="mon" ;;
  2) js_day="tuesday-3.js"; js_prefix="tue" ;;
  3) js_day="wednesday-3.js"; js_prefix="wed" ;;
  4) js_day="thursday-3.js"; js_prefix="thu" ;;
  5) js_day="friday-3.js"; js_prefix="fri" ;;
  6) js_day="saturday-3.js"; js_prefix="sat" ;;
  7) js_day="sunday-3.js"; js_prefix="sun" ;;
esac

# Pick block
if [ "${minute}" -lt 30 ]; then
  block="b1"
else
  block="b2"
fi

# Download the day JS file
curl -s -o "${js_day}" "https://exptv.org/js/${js_day}"

# Extract the variable name like VIDEOBREAKS24
varname=$(grep "var ${js_prefix}_${hour}_${block}" "${js_day}" | awk -F '=' '{print $2}' | tr -d ' ;')
grep "var ${js_prefix}_${hour}_${block}" "${js_day}" | awk -F '= ' '{print $2}' 

# Remove any trailing semicolon
varname=$(echo "${varname}" | tr -d ';')

# Build file name
filename="${varname}.mp4"

# Compute time offset in seconds
time_offset=$(( minute * 60 + second ))

# Build base URL
video_url="https://exptv.org/content2/${filename}"

echo "Playing: ${video_url} (seek to ${time_offset}s)"

# Run mpv with explicit --start
mpv --force-seekable=yes --start="${time_offset}" "${video_url}"

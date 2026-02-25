# Process mp4, mkv, avi in the current dir
# Requires: ffmpeg (with loudnorm) and jq
shopt -s nullglob nocaseglob

for file in *.mp4 *.mkv *.avi; do
    [[ -e "${file}" ]] || continue

    base="${file%.*}"
    ext="${file##*.}"
    ext_lc="${ext,,}"

    echo "Processing: ${file}"

    # First pass: measure loudness, capture JSON block
    loudnorm_json="$(ffmpeg -hide_banner -nostdin -i "${file}" \
        -af "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" \
        -f null - 2>&1 | sed -n '/^{/,/^}/p')"

    if [[ -z "${loudnorm_json}" ]]; then
        echo "Failed to extract loudnorm stats for ${file}"
        continue
    fi

    # Extract measured values
    I="$(echo "${loudnorm_json}" | jq -r '.input_i')"
    TP="$(echo "${loudnorm_json}" | jq -r '.input_tp')"
    LRA="$(echo "${loudnorm_json}" | jq -r '.input_lra')"
    THRESH="$(echo "${loudnorm_json}" | jq -r '.input_thresh')"
    OFFSET="$(echo "${loudnorm_json}" | jq -r '.target_offset')"

    if [[ -z "${I}" || -z "${TP}" || -z "${LRA}" || -z "${THRESH}" || -z "${OFFSET}" || \
          "${I}" == "null" || "${TP}" == "null" || "${LRA}" == "null" || "${THRESH}" == "null" || "${OFFSET}" == "null" ]]; then
        echo "Missing loudnorm data for ${file}, skipping..."
        continue
    fi

    # Decide output container/filename
    case "${ext_lc}" in
        mp4) out="${base}_normalized.mp4" ;;
        mkv) out="${base}_normalized.mkv" ;;
        avi) out="${base}_normalized.mkv" ;;  # avoid AAC-in-AVI; remux to MKV
        *)   out="${base}_normalized.${ext_lc}" ;;
    esac

    # Second pass: apply normalization; copy video/subs/other streams, re-encode audio to AAC
    ffmpeg -hide_banner -nostdin -i "${file}" \
        -map 0 -c copy -c:a aac -b:a 192k \
        -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=${I}:measured_TP=${TP}:measured_LRA=${LRA}:measured_thresh=${THRESH}:offset=${OFFSET}:linear=true:print_format=summary" \
        "${out}"
done

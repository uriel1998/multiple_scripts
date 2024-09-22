#!/bin/bash

#!/bin/bash
export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

package=$(echo "${@}" | awk -F '/' '{ print $1 }')
echo "${package}"
echo " "
apt show "${package}" 2>/dev/null
echo " "
dpkg -S "${package}"


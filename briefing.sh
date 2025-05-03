#!/bin/bash

##############################################################################
#
#  To create an automated news briefing using a command line downloader.
#  uses a fork of podfox at https://github.com/uriel1998/podfox
#  that version has had the dependencies updated,
#  But needs to have a manual venv created instead of just pipx install.
#
#  (c) Steven Saus 2025
#  Licensed under the MIT license
#
##############################################################################


export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/maubot_vars.env"

##############################################################################
# loud outputs on stderr 
##############################################################################    
 function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@" 1>&2
    fi
}


cd ${HOME}/apps/podfox
source bin/activate
loud "[info] Running podfox to get news."
${HOME}/apps/podfox/bin/podfox -c ${SCRIPT_DIR}/podfox.json update
${HOME}/apps/podfox/bin/podfox -c ${SCRIPT_DIR}/podfox.json download

deactivate

cd "${SCRIPT_DIR}"
loud "[info] Organizing briefing"
# prune old stuff
rm -rf ${HOME}/briefing/*

today=`date +%Y%m%d`
if [ ! -d "${HOME}/briefing/${today}" ];then 
    mkdir -p ${HOME}/briefing/${today}
fi


# Moving podcasts to central directory.
find ${HOME}/podcasts -name '*.mp3' -exec mv {} ${HOME}/briefing/${today} \;


#https://askubuntu.com/questions/259726/how-can-i-generate-an-m3u-playlist-from-the-terminal

loud "[info] Creating playlist"

playlist="${HOME}/briefing/play.m3u"
if [ -f "${playlist}" ]; then 
    rm "${playlist}" 
fi 

for f in ${HOME}/briefing/${today}/*.mp3; do echo "$f" >> "${playlist}"; done
loud "[info] Playing briefing"

# This will be blocking, however, I'm calling this program from a subshell.
mplayer -playlist "${playlist}"

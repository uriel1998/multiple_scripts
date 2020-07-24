#!/bin/bash


/usr/local/bin/podfox -c ~/.podfox.json update
/usr/local/bin/podfox -c ~/.podfox.json download

today=`date +%Y%m%d`
mkdir -p ~/briefing/$today

#Uncomment to remove all old briefings
#rm -rf ~/briefing/*

# Moving podcasts to central directory.
find ~/podcasts -name '*.mp3' -exec mv {} ~/briefing/$today \;


#https://askubuntu.com/questions/259726/how-can-i-generate-an-m3u-playlist-from-the-terminal

# This does not seem to work with ~/ for $HOME, so I've put the full user
# path here.
playlist='/home/user/briefing/play.m3u' ; if [ -f $playlist ]; then rm $playlist ; fi ; for f in /home/user/briefing/$today/*.mp3; do echo "$f" >> "$playlist"; done
mplayer -playlist "$playlist"

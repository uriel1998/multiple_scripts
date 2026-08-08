#!/bin/bash

# A simple script to take the downloaded audiobooks from OpenBookshelf 
# and to copy them into a directory structure that audiobookshelf expects.
# Instead of copying, you can use either 
# mv --
# or 
# ln -s 
# depending on your directory structure and desire

OpenAudibleLibrary=/media/_Audiobooks/OpenAudible
AudioBookShelfLibrary=/media/_Audiobooks/audiobookshelf

cd ${OpenAudibleLibrary}/art

for f in *.jpg; do mkdir -p "$f" "${AudioBookShelfLibrary}/${f%.jpg}"; done
for f in *.jpg; do cp "$f" "${AudioBookShelfLibrary}/${f%.jpg}/${f%}"; done

cd ${OpenAudibleLibrary}/books

for f in *.pdf; do mkdir -p "$f" "${AudioBookShelfLibrary}/${f%.pdf}"; done
for f in *.pdf; do cp "$f" "${AudioBookShelfLibrary}/${f%.pdf}/${f%}"; done
for f in *.m4b; do mkdir -p "$f" "${AudioBookShelfLibrary}/${f%.m4b}"; done
for f in *.m4b; do cp "$f" "${AudioBookShelfLibrary}/${f%.m4b}/${f%}"; done
for f in *.mp3; do mkdir -p "$f" "${AudioBookShelfLibrary}/${f%.mp3}"; done
for f in *.mp3; do cp "$f" "${AudioBookShelfLibrary}/${f%.mp3}/${f%}"; done

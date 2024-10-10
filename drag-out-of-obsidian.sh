#!/bin/bash

##############################################################################
#
#  A little utility to be able to drag and drop FROM Obsidian
#  (c) Steven Saus 2024
#  Licensed under the MIT license
#
##############################################################################

# There are a lot of ways to get content *into* Obsidian, but sometimes I want 
# to pull an image or file and drag-and-drop it into Element, Discord, whatever. 
# This uses [Dragon](https://github.com/mwh/dragon) to provide the drag and drop
# target.

# Usage - call this script (there's a shell command plugin that should work), then 
# drag from Obsidian to the target. It will then process the provided Obsidian 
# URL, provide the file name to a SECOND instance of Dragon (after making sure it 
# is escaped to deal with spaces), which will give you a target to drop on 
# your other application.

# The root of my vaults are symlinked into ${HOME}/vault, e.g.
#   /vault/Brain
#   /vault/DnD5e
#   /vault/Writing
# thus allowing for consistent rewriting even though they live in very different
# parts of my file structure. See below for the string to modify for your system.

# Use the Shell Commands plugin to invoke, optionally use Commander plugin to add 
# an icon to the ribbon or somesuch.


# sed 's|obsidian:\/\/open?vault=|\/home\/steven\/vault\/|g' | sed -e 's/%2F/\//g' -e 's/%20/ /g'

if [ -f ! $(which dragon) ];then
    echo "This requires dragon to work."
    echo " https://github.com/mwh/dragon "
    exit 99
fi
dragon_bin=$(which dragon)
bob=$(${dragon_bin} --print-path --target -x)

# replace \/home\/steven\/vault\/ in the line below to the directory where you symlinked
# all of your vaults to.

bob2=$(echo -e "${bob}" | sed 's|obsidian:\/\/open?vault=|\/home\/steven\/vault\/|g' | sed -e 's/%2F/\//g' -e 's/%20/ /g' | sed 's@&file=@/@g')
if [ -f "${bob2}" ];then 
    bob3=$(basename "${bob2}")
    if [[ "${bob3}" == *.* ]]; then
        echo "Filename '$filename' has an extension."
    else
        # Obsidian does not export md extension, even though it's there, for md files.
        # :: shrug ::
        echo "Adding markdown extension"
        bob2=$(echo -e "${bob2}.md")
    fi
    ${dragon_bin} "${bob2}"
else
    echo "This is not a file; you cannot share a directory."
    exit 98
fi


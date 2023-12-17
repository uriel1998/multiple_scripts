#!/bin/bash
#   openbox_VirtualBox_pipemenu.sh - VirtualBox launcher for openbox
#   initially created 2013 - Ryan Fantus for PlayOnLinux
#

# command to launch VirtualBox
#VBox_launcher_command='VBoxHeadless -startvm'
VBox_launcher_command='VBoxManage startvm'

function generate_vbox_menu {

VBoxManage list vms | awk -F '"' '{print $2}' | while read; do

    echo '<item label="'"${REPLY}"'">'
    echo -n '<action name="Execute"><execute>'
    echo -n "$VBox_launcher_command '${REPLY}'"
    echo '</execute></action>'
    echo '</item>'
   done

}

echo '<openbox_pipe_menu>'
echo '<separator label="VirtualBox" />'
# First, we'll create a launcher specifically for PlayOnLinux

echo '<item label="VirtualBox">'
echo -n '<action name="Execute"><execute>'
echo -n "virtualbox"
echo '</execute></action>'
echo '</item>'

generate_vbox_menu

echo '</openbox_pipe_menu>'

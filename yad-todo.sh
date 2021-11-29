#!/bin/bash
    
########################################################################
#	Using YAD to make a quick todo-txt entry GUI
#   by Steven Saus (c)2021
#   Licensed under the MIT license
#
#   First argument is the path to todo.txt if it's not already exported 
#   as TODO_FILE.  Simply designed for quick entry.
#   
#   If the program is not running, ensure that it is getting the todo.txt 
#   file passed to it!
#
########################################################################

ToDoTxtFile="$1"

if [ ! -f "${ToDoTxtFile}" ];then
    if [ -f "$TODO_FILE" ];then
        ToDoTxtFile="$TODO_FILE"
    else
        exit 99
    fi
fi

projects=$(cat "$ToDoTxtFile" | grep -e '\+' | awk -F '+' '{print $2}' | awk '{print $1}' | sort | uniq | tr '\n' '!' | sed 's/!/\\!/g')
contexts=$(cat "$ToDoTxtFile" | grep -e '\@' | awk -F '@' '{print $2}' | awk '{print $1}' | sort | uniq | tr '\n' '!' | sed 's/!/\\!/g')
projects=$(echo " \!${projects::-2}")
contexts=$(echo " \!${contexts::-2}")
priority=" \!A\!B\!C\!D\!E\!F\!G\!H\!I\!J\!K\!L\!M\!N\!O\!P\!Q\!R\!S\!T\!U\!V\!W\!X\!Y\!Z"
blankentry=" \!"

OutString=$(yad --form --title="todo.txt entry" --date-format="%Y-%m-%d" --width=400 --center --window-icon=gtk-info --borders 3 --field="Task" New_Task --field="Context:CBE" ${contexts} --field="Project:CBE" ${projects} --field="Priority:CBE" ${priority} --field="Due Date::DT" )


NewTask=$(echo "$OutString" | sed "s/'/’/g" | sed 's/"/”/g' | awk -F '|' '{print $1}') 
if [ "$NewTask" == "New_Task" ];then
    echo "Task not edited; exiting"
    exit 88
fi
if [ "$NewTask" == "" ];then
    echo "Empty task; exiting"
    exit 88
fi

NewContext=$(echo "$OutString" | awk -F '|' '{print $2}') 
if [ "$NewContext" != "" ];then
    NewContext=$(echo "@$NewContext")
fi
NewProject=$(echo "$OutString" | awk -F '|' '{print $3}')
if [ "$NewProject" != "" ];then
    NewProject=$(echo "+$NewProject")
fi
NewPriority=$(echo "$OutString" | awk -F '|' '{print $4}') 
echo "$NewPriority"
if [ "$NewPriority" != "" ];then
    NewPriority=$(echo "($NewPriority)")
fi
NewDate=$(echo "$OutString" | awk -F '|' '{print $5}') 
		
TaskString=$(printf "/usr/bin/todo-txt add \"%s %s %s %s due:%s\"" "$NewPriority" "$NewTask" "$NewContext" "$NewProject"  "$NewDate")
eval "${TaskString}"

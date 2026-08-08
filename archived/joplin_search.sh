#!/bin/bash

##############################################################################
#
#  joplin_search.sh
#  Wrapper for searching and quickly viewing Joplin notes using fzf,rg, and bat 
#  (c) Steven Saus 2021
#  Licensed under the MIT license
#
##############################################################################

JoplinSearchDir="/home/steven/documents/cloud_nextcloud/joplin"
#SearchTerm=$(echo ${@} | sed '/^$/!s/[^ ]* */| -e &/g' |  tail -c +2)
SearchTerm=${@}
#SearchString=$(printf "rg %s -l -f $(rg --files-without-match \"_diff:\" %s)" "${SearchTerm}" "${JoplinSearchDir}") 
#cat "$SearchString"
#eval "$SearchString" 
#rg -l -w "${SearchTerm}" $(rg --files-without-match "title_diff:" ${JoplinSearchDir}) | fzf --no-hscroll -m --height 90% --border --ansi --no-bold --preview='bat {}'
#| rg --files-without-match -e "_diff:" -f - | fzf --no-hscroll -m --height 90% --border --ansi --no-bold --preview="bat {}"

/home/steven/bin/showdocs -g $(grep -l -i "${SearchTerm}" $(grep -l -x "type_: 1" ${JoplinSearchDir}/*.md) | fzf --no-hscroll -m --height 90% --border --ansi --no-bold --preview='bat {}')

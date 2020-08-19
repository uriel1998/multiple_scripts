
#do this first
apropos . | grep -v -E '^.+ \(0\)' 
#feed into array.  Split on '-' everything to right is description with left side's $1 in awk
#then get 
cheat -l | cat
#then run through array, see if any match from apropos array, and append definition array
#then do the same with 
tldr -l 
# then present them with the source available (man|cheat|tldr)
# if there was argv then pre-grep via that as well
# get howto do preview from macho

#if nothing selected
#then use help to see if there's a return 
=$(help "$@" 2> /dev/null)


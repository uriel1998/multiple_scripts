# multiple_scripts
Multiple scripts that are useful but don't deserve their own repository.  

## ytube.sh

A wrapper for youtube-dl to make easier (and automate) some things.


## briefing.sh  

Used along with Podfox to create a daily briefing without involving 
Google or Amazon or Apple.  The post detailing this is at 
[ideatrash](https://ideatrash.net/?p=69528).

## virtualbox-openbox

To dynamically create a list of virtualbox VM's (and allow you to run them) 
as an OpenBox pipe menu

## topmem.sh and topcpu.sh

While these aren't exactly *speedy* or *optimized*, they do what I want;
they show me the top five memory using (or CPU using, respectively) 
*commands*.  That is, it lumps all `vivaldi-bin` or `firefox-bin` 
processes together before doing the calculation and sort. That way I can 
see what commands are eating up everything.

A small note - processes from bash, python, and java (at present) are 
not *excluded*, but the command they're *running* is what is counted. So 
for example, these three commands:

`/usr/bin/python /usr/share/kupfer/kupfer.py --no-splash`  
`/usr/bin/python /usr/bin/autokey-gtk`  
`/usr/bin/python /usr/bin/dstat -c -C 0,1,total -d -s -n -y -r`  

are *not* lumped together, but are treated as separate commands.

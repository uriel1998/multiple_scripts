# multiple_scripts
Multiple scripts that are useful but don't deserve their own repository.  

This is often a repository when I work on small ideas until they're big enough 
to deserve thier own repo and README.  This readme may very well be outdated 
or inaccurate!  

## drag-out-of-obsidian.sh

 There are a lot of ways to get content *into* Obsidian, but sometimes I want 
 to pull an image or file and drag-and-drop it into Element, Discord, whatever. 
 However, that reveals the Obsidian URI to some (all?) applications, not the 
 filename, making the operation fail. This is a workaround.
 
 This uses [Dragon](https://github.com/mwh/dragon) to provide the drag and drop
 target.

 Usage - call `drag-out-of-obsidian.sh` (using the Shell Commands plugin), then 
 drag whatever from Obsidian to the target. It will then process the provided Obsidian 
 URL, provide the file name to a SECOND instance of Dragon (after making sure it 
 is escaped to deal with spaces), which will give you a target to drop on 
 your other application.

 The root of my vaults are symlinked into ${HOME}/vault, e.g.

   /vault/Brain
   /vault/DnD5e
   /vault/Writing
 
 thus allowing for consistent rewriting even though they live in very different
 parts of my file structure. You will want to replace the `\/home\/steven\/vault\/` 
 with the *equally escaped* directory that you moved or symlinked all your vaults to.
 
`sed 's|obsidian:\/\/open?vault=|\/home\/steven\/vault\/|g' | sed -e 's/%2F/\//g' -e 's/%20/ /g'`

 Use the Shell Commands plugin to invoke, optionally use Commander plugin to add 
 an icon to the ribbon or somesuch.



## convert_patreon_downloader_files.sh

See [this post on my blog](https://ideatrash.net/2023/12/how-to-back-up-your-patreon-posts-and-photos-to-multiple-formats-automatically-using-linux-in-december-2023.html) for a full description of how to use this script.

## isobash

A simple script using zenity and pkexec to allow for interactive mounting of ISO files with a GUI interface.

## aptlist

Because sometimes I want to see what packages are installed or available quickly.  Use -i to have it auto-sub in [installed] to the fzf search string. Also uses dpkg search to list what the package installs.


## video-fzf-config and pulse-fzf-autoconf

Scripts for moving and manipulating video and pulse streams easily.  See https://ideatrash.net/2022/02/manipulating-audio-and-video-streams-for-streaming-on-linux.html

# patootie.sh

  Because sometimes you want a GUI *and* the speed of a command line, and just want to say something stupid on Mastodon without firing up a browser or Sengi or grabbing your phone, or or or...

  Uses [YAD](https://sourceforge.net/projects/yad-dialog/) and [toot](https://toot.bezdomni.net/) to have a GUI for sending a quick toot (with possible
  image attachments, content warnings, and alt text. Includes interactive image selector and *displaying* the image while you are presented with a dialogue box to enter alt text.
  
  Patootie uses the environment variable TOOTACCT to specify the tooting account otherwise it uses whichever one is currently active in toot. 
  
  You may specify the full path to an image file as the first (and only) command-line variable to "pre-load" the image attachment portion of the script.
  
![patootie first dialogue box](https://raw.githubusercontent.com/uriel1998/multiple_scripts/master/patootie_1.jpg)

![patootie alt text dialogue box](https://raw.githubusercontent.com/uriel1998/multiple_scripts/master/patootie_2.jpg)

## yad-todo.sh

Uses [yad](https://smokey01.com/yad/) to present a simple GUI for adding 
entries to todo.txt file.  See the yad-todo.png file for what it might look like.
If the program is not running, ensure that it is getting the `todo.txt` file passed to it!

## kpf.sh

Uses [fd](https://github.com/sharkdp/fd), [fzf](https://github.com/junegunn/fzf), 
and [keepassxc-cli](https://www.mankier.com/1/keepassxc-cli) to provide a quick 
and easy way to *retrieve* passwords from the command line.  By default copies 
the password to the clipboard.  If you don't want to type your password (or select 
your database location) every time, you can set them as environment variables. 

See [this post](https://ideatrash.net/2021/05/kpf-keepassxc-with-fzf-in-bash.html) for details.

## set-xwindow-icon-by-pid.sh

Does exactly what it says on the tin. $1 is the string to search, $2 is the path to the icon file

## sr.sh

A transparent wrapper for surfraw that utilizes fzf 
https://terminalizer.com/view/4d1fd3b34309

## ytube.sh

A wrapper for youtube-dl to make easier (and automate) some things.

## clipimg.sh

Uses fzf, rofi, fd (optional), and xclip to choose an image, get it onto the 
clipboard, and select it for pasting.  Works for JPG and PNG, does NOT work for 
GIF, sadly.

## tmux_devour.sh

Launch a process in a new pane, zoom the pane, kill the pane when done.

## tmux_sidebar.sh

Create a sidebar (e.g. for reading manpages) and kill when done.

## tmux_topbar.sh

Create a vertical split and kill when done.

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

#books_search

#joplin_search






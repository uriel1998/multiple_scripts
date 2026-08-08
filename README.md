# multiple_scripts
Multiple scripts that are useful but don't deserve their own repository.

This is often a repository where I work on small ideas until they're big enough
to deserve their own repo and README. This README may still lag behind the code,
but it now covers the scripts that currently live at the root of this repository.

Annotated git tags in this repository are used as historical audit markers.
While the project is still pre-1.0, tags follow semantic-version ordering:
minor releases mark root-level script additions, removals, or fundamental
workflow changes, while patch releases are reserved for follow-up maintenance
or documentation-only milestones when they are tagged at all.

## aptlist

Because sometimes I want to see what packages are installed or available quickly.
Use `-i` to have it auto-sub in `[installed]` to the `fzf` search string. It also
shows package metadata and, when the package is installed, the file list from
`dpkg -L`.

`aptlist-preview.sh` remains as a small compatibility shim, but the preview logic
now lives directly in `aptlist`.

## books_search.sh

Interactive helper for searching a local book collection from the terminal.
Superceded by [books_browse](https://github.com/uriel1998/books_browse).

## briefing.sh

Used along with Podfox to create a daily briefing without involving Google or
Amazon or Apple. The post detailing this is at
[ideatrash](https://ideatrash.net/?p=69528).

## clipimg.sh

Uses `fzf` or `rofi` to choose a sticker, icon, or clipart image, then puts it
onto the clipboard for pasting. By default it builds its list from uncommented
entries under `[StickerPacks]` in `clipimg` config, with each pack defined as
`Name:/full/path/to/pack`.

The script will look for config in the current working directory or in the same
directory as the script, using `.clipimg.env`, `clipimg.ini`, or `.clipimg.ini`.
Icons and clipart are configured separately under `[Icons]` and `[ClipArt]`.

You can pass sticker-pack names on the command line to limit the picker to those
packs only, for example `clipimg.sh blob` or `clipimg.sh blob blob2`. If you do
not name any packs, it includes every uncommented sticker pack from the config.

Sticker selections are shown as `PackName:filename`, such as `Blob2:angry mad`,
and only supported image files are presented. Terminal previews currently prefer
`chafa` in symbols mode with animation disabled, and fall back to `timg` in
quarter-block mode; `--chafa` and `--timg` let you choose which previewer to
prefer.

For output, the script will use any available combination of `dragon`, `xclip`,
and `copyq`. When present, `copyq` receives both the image payload and the file
path in slot 1.

## cont-stop.sh

Process workbench script for inspecting running processes and preparing stop,
continue, or kill style actions. This one looks more experimental than polished,
but it is kept here because it is still part of the root script set.

## convert_odt_md_for_obsidian.sh

Converts ODT and RTF files into Markdown and moves the original files into an
archive directory. It is intended to make importing documents into Obsidian less
annoying.

## convert_patreon_downloader_files.sh

See [this post on my blog](https://ideatrash.net/2023/12/how-to-back-up-your-patreon-posts-and-photos-to-multiple-formats-automatically-using-linux-in-december-2023.html)
for a full description of how to use this script.

## dicebear_helper_generate_avatar.sh

Small helper for generating a deterministic avatar from a seed using DiceBear.
It prefers the online DiceBear API, can fall back to a local `dicebear` CLI, and
then copies the resulting avatar into the clipboard and CopyQ for easy reuse.
Set `DICEBEAR_AVATAR_DIR` if you want the cached PNGs written somewhere other
than the default cache directory.

## vcf_add_missing_dicebear_avatars.sh

Scans a directory of `.vcf` files, skips cards that already have a `PHOTO`,
tries Libravatar first and then Gravatar for any non-placeholder email
addresses on the card, and only falls back to DiceBear if no email-based avatar
is available.

When it uses DiceBear, it adds `X-DICEBEAR-GENERATED:TRUE` and
`X-DICEBEAR-SOURCE:dicebear_helper_generate_avatar.sh` so those generated
avatars can be identified and removed later. Pass a contacts directory
explicitly, or let it scan the current working directory. `--help` shows the
current options.

## vcf_remove_dicebear_avatars.sh

Reverses the generated-avatar workflow for marked vCards. It looks for the
DiceBear marker fields, removes them, and strips the embedded `PHOTO` block
from those cards only. Pass a contacts directory explicitly, or let it scan the
current working directory. `--help` shows the current options.

## drag-out-of-obsidian.sh

There are a lot of ways to get content *into* Obsidian, but sometimes I want to
pull an image or file and drag-and-drop it into Element, Discord, whatever.
However, that reveals the Obsidian URI to some or all applications, not the
filename, making the operation fail. This is a workaround.

This uses [Dragon](https://github.com/mwh/dragon) to provide the drag and drop
target.

Usage: call `drag-out-of-obsidian.sh` from the Shell Commands plugin, then drag
whatever from Obsidian to the target. It will process the provided Obsidian URL,
provide the file name to a second instance of Dragon after making sure it is
escaped to deal with spaces, and then give you a target to drop on your other
application.

The root of my vaults are symlinked into `${HOME}/vault`, for example:

`/vault/Brain`
`/vault/DnD5e`
`/vault/Writing`

That allows for consistent rewriting even though they live in very different
parts of my file structure. You will want to replace the escaped vault root
with the equally escaped directory that you moved or symlinked all your vaults
to.

`sed 's|obsidian:\/\/open?vault=|\/path\/to\/vault\/|g' | sed -e 's/%2F/\//g' -e 's/%20/ /g'`

Use the Shell Commands plugin to invoke it, and optionally the Commander plugin
to add an icon to the ribbon or similar.

You may need to add the `$PATH` variables to Shell Commands, depending on where
you have the Dragon binary located.

Examples:
I can drag to Thunar, not Discord, but this script fixes it.

![Example 1](https://i.imgur.com/YPNV1Xd.gif "What it looks like")

I can't drag to upload to imgur, but this script fixes it.

![Example 2](https://i.imgur.com/uxWb9sM.gif "What it looks like")

## dtcopy.sh

Provides a way to copy filenames with complex characters to an older filesystem,
such as NTFS. It can copy or move files, preserve part of the directory layout,
and transliterate path segments so the target filesystem has an easier time with
them.

## fin_clip.sh

Small clipboard utility for forcing the current selection or provided content into
the clipboard when the normal copy path is being obnoxious.

## fix_tags_from_old_comments.sh

Bulk cleanup helper for Markdown and text files. It fixes old tag markers that
were written without the expected spacing.

## isobash

A simple script using `zenity` and `pkexec` to allow for interactive mounting of
ISO files with a GUI interface.

## kpf.sh

Uses [fd](https://github.com/sharkdp/fd), [fzf](https://github.com/junegunn/fzf),
and [keepassxc-cli](https://www.mankier.com/1/keepassxc-cli) to provide a quick
and easy way to *retrieve* passwords from the command line. By default it copies
the password to the clipboard. If you don't want to type your password or select
your database location every time, you can set them as environment variables.

See [this post](https://ideatrash.net/2021/05/kpf-keepassxc-with-fzf-in-bash.html)
for details.

## lowload.sh

Gets some of the functionality of `atd` and task-spooler together. It waits until
system load drops below a configured threshold and then runs the labeled job via
`tsp`.

## mu-search.sh

Interactive front-end for `mu` mail searches. It prompts for the query and then
helps normalize the common `subject:`, `from:`, `to:`, `body:`, and similar field
patterns before running the search.

## openaudible_to_audiobookshelf.sh

Takes downloaded audiobooks from OpenAudible and copies or links them into the
directory structure that Audiobookshelf expects.

## patootie.sh

Because sometimes you want a GUI *and* the speed of a command line, and just want
to say something stupid on Mastodon or Bluesky without firing up a browser or
Sengi or grabbing your phone.

Uses [YAD](https://sourceforge.net/projects/yad-dialog/),
[toot](https://toot.bezdomni.net/), and
[bsky-sh-cli](https://github.com/bills-appworks/bsky-sh-cli) to provide a GUI
for sending a quick post with possible image attachments, content warnings, and
alt text. It includes an interactive image selector and displays the image while
you are presented with a dialogue box to enter alt text.

Because `bsky-sh-cli` tends to log out of the session, create a short script
somewhere in `$PATH` called `loginbsky`. Mine, for example, looks something like
this:

```bash
#!/usr/bin/bash

export BSKYSHCLI_SELFHOSTED_DOMAIN=sky.example.com
bsky login --handle example_username --password example_password
PATH=$PATH:/home/USER/.local/bsky_sh_cli/bin
export PATH
```

You could also put any other `bsky-sh-cli` environment variables you like in
there, and it should be called immediately before posting.

You must set up both `toot` and `bsky-sh-cli` independently to use this script.

Patootie uses the environment variable `TOOTACCT` to specify the tooting account;
otherwise it uses whichever one is currently active in `toot`.

You may specify the full path to an image file as the first and only
command-line variable to pre-load the image attachment portion of the script.

![patootie first dialogue box](https://raw.githubusercontent.com/uriel1998/multiple_scripts/master/patootie_1.jpg)

![patootie alt text dialogue box](https://raw.githubusercontent.com/uriel1998/multiple_scripts/master/patootie_2.jpg)

## pdf2.sh

Wrapper around a handful of PDF extraction and conversion tools. It can extract
embedded images, rasterize pages, turn the PDF into HTML and text-oriented
formats, and build comic-book style archives from generated page images.

## pinry_cli_gui.sh

YAD-based helper for feeding files into Pinry from the command line. It can read
existing EXIF tags and comments, prompt for board, tags, and description, and
record which files have already been uploaded.

## play_exptv.sh

Looks up the current EXP TV schedule block, builds the corresponding media URL,
and opens it in `mpv` with the correct current seek offset.

## PS1_functions

Very simple PS1 helper functions to show when a git directory needs work and to
shorten the home path shown in the prompt.

## set-xwindow-icon-by-pid.sh

Does exactly what it says on the tin. `$1` is the string to search and `$2` is
the path to the icon file.

## sr.sh

A transparent wrapper for `surfraw` that utilizes `fzf`.
https://terminalizer.com/view/4d1fd3b34309

## topcpu.sh

While these aren't exactly *speedy* or *optimized*, they do what I want. They
show me the top CPU-using commands. That is, they lump all `vivaldi-bin` or
`firefox-bin` processes together before doing the calculation and sort, so I can
see what commands are eating up everything.

A small note: processes from bash, python, and java are not excluded, but the
command they're running is what is counted. So for example, these three commands:

`/usr/bin/python /usr/share/kupfer/kupfer.py --no-splash`
`/usr/bin/python /usr/bin/autokey-gtk`
`/usr/bin/python /usr/bin/dstat -c -C 0,1,total -d -s -n -y -r`

are not lumped together, but are treated as separate commands.

## topmem.sh

Same basic idea as `topcpu.sh`, but for memory usage instead of CPU usage. It
groups usage by command so you can see what is actually consuming memory overall.

## video-fzf-config

Script for moving and manipulating video streams easily. It can help choose real
and fake cameras, use `fzf` to pick devices and files, and supports fake
background or replacement-stream workflows. See
https://ideatrash.net/2022/02/manipulating-audio-and-video-streams-for-streaming-on-linux.html

## video_volume_normalization.sh

Processes MP4, MKV, and AVI files in the current directory with `ffmpeg`
loudness normalization so their playback volume is more consistent.

## virtualbox-openbox.sh

Dynamically creates a list of VirtualBox VMs and allows you to run them as an
Openbox pipe menu.

## yad-todo.sh

Uses [yad](https://smokey01.com/yad/) to present a simple GUI for adding tasks.
It now supports both legacy `todo.txt` file usage and `todoman` multi-list setups.
See `yad-todo.png` for what it might look like.

If the program is not running in legacy mode, ensure that it is getting the
`todo.txt` file passed to it. In `todoman` mode it will use your configured task
lists instead.

## ytube

A wrapper for `youtube-dl` to make downloading or playing things easier and more
automated. It can take a URL directly, pull one from the clipboard, or prompt
through `zenity`, and supports video download, audio download, or playback.

## Some AI/LLM Use

![button_some-ai-used](https://i.imgur.com/rmiLFDD.png)

The code in this repository has been to some degree written or altered by an AI tool with human supervision.  This may include one or more of the following: documentation, locating bugs, or commit messages; in this repository it's been used for bug squashing and reorganizing and updating the documentation.  

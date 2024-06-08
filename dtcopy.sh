#!/bin/bash

##############################################################################
#
#  dtcopy
#  To provide a way to copy filenames with complex characters to an older 
#  filesystem, such as NTFS. 
#  (c) Steven Saus 2024
#  Licensed under the MIT license
#
##############################################################################

  

# Some choices:
# If source is a DIR and dest is a DIR, then copy all files in SOURCE to DEST
# If dest is a FILE, then error
# If source is a FILE and dest is a DIR, then copy the file into DEST
# If DEST does not exist, assume it's a directory that needs created


export SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOUD=0
MOVE=""  #off, so copy by default
SOURCE=""
SOURCE_TYPE=""
DEST=""
DEST_TYPE=""
CLOBBER="TRUE"
BASE=""
DRYRUN=""

function loud() {
    if [ $LOUD -eq 1 ];then
        echo "$@"
    fi
}

display_help() {   
    echo "USAGE: dtcopy [OPTIONS] SOURCE DESTINATION"
    echo " -b | --basedir (from what point to copy the path)"
    echo " -r | --recurse (recurse into directories)"
    echo " -m | --move (delete file after copy)"
    echo " -n | --no-clobber (do not clobber existing files "
    echo " -l | --loud (additional output"
    echo " -d | --dry-run (just output what the resulting command would be)"
    echo " -h | --help  (this)"
}


process_a_path () {
    # take in the string, read it into array
    IFS=/ read -a arr <<< "${1}"
    i=0
    while [ $i -lt "${#arr[@]}" ]; do 
        arr[$i]=$(printf '%s\n' "${arr[$i]}" | iconv -t ASCII//TRANSLIT - | inline-detox)    
        let i=i+1
    done
    # stitch it back together
    processed_path=$(printf '/%s' "${arr[@]}")
    # remove EXTRA leading slash from printf above
    processed_path="${processed_path:1}"
    #emit our processed path
    echo "${processed_path}"
}
    



    # processing our commandline variables
    while [ $# -gt 0 ]; do
    option="$1"
    case $option in

        -m|--move) MOVE="TRUE" #effectively means delete source
            shift
            ;;
        -d|--dry-run) DRYRUN="TRUE" #just output stuff
            shift
            ;;            
        -l|--loud) LOUD=1
            shift
            ;;
        -n|--no-clobber) 
            CLOBBER="FALSE"
            shift
            ;;
        -b|--base) 
            # gets the base dir to remove from pathname when copying
            # e.g.  /home/steven/music/album/artist/file
            # with a BASE of /home/steven/music
            # would result in the path /album/artist/file being copied
            # as the path of the copied file
            BASE="${1}"
            shift
            ;;
        -h|--help) display_help
            exit
            ;;      
        # if it's none of these, it should be source, then destination
        *)  if [ -z "$SOURCE" ];then
                #if no source, set source
                if [ -d "${1}" ];then
                    SOURCE_TYPE="DIR"
                    SOURCE="${1}"
                    shift
                else
                    if [ -f "${1}" ];then
                        SOURCE_TYPE="FILE"
                        SOURCE="${1}"
                        shift
                    else
                        loud "Source is neither file nor directory; exiting"
                        exit 98
                    fi
                fi
            else
                if [ -z "$DEST" ];then
                    #if no source, set source
                    if [ -d "${1}" ];then
                        DEST_TYPE="DIR"
                        DEST="${1}"
                        shift
                    else
                        if [ -f "${1}" ];then
                            loud "Specified file destination exists and is not a directory, exiting."
                            exit 98
                        fi
                    fi
                else
                    loud "SOURCE and DESTINATION already set; ignoring variable"
                    loud "${1}"
                    shift
                fi
            fi
            ;;
        esac
    done   

    # Checking the destination directory
    case $DEST_TYPE in
        DIR)
            loud "Files will be placed within ${DEST}" 
            # directory to copy SOURCE into
            # don't actually have to do anything here
            ;;
        EMPTY|*)
            # the directory to copy SOURCE into does not exist, 
            # so let's make it. Could technically just do this, but still.
            # I'm sure there's a reason I'll need this later for some functionality
            mkdir -p "${DEST}"
            ;;
    esac

    # Processing single input file   
    if [ "$SOURCE_TYPE"="FILE" ];then
        # remove base
        NOBASE_SOURCE=""
        NOBASE_SOURCE=${SOURCE#"$BASE"}
        TX_PATH=""
        TX_PATH=$(process_a_path "${NOBASE_SOURCE}")
        if [ "$DRYRUN" = "TRUE" ];then 
            echo "cp -n ${SOURCE} ${DEST}${TX_PATH}"
        else
            if [ "$CLOBBER" = "FALSE" ];then
                cp -n "${SOURCE}" "${DEST}${TX_PATH}"
                if [ $? -eq 0 ] && [ "$MOVE" = "TRUE" ];then
                    rm "$SOURCE"
                fi
            else 
                cp "${SOURCE}" "${DEST}${TX_PATH}"
                if [ $? -eq 0 ] && [ "$MOVE" = "TRUE" ];then
                    rm "$SOURCE"
                fi
            fi
        fi
    fi

    
    #Processing input directory of files   
    if [ "$SOURCE_TYPE"="DIR" ];then
        # get all filenames in that directory (recursively) into array        
        in_array=()
        while IFS=  read -r -d $'\0'; do
            in_array+=("$REPLY")
        done < <(find "${SOURCE}" -print0)
        # now loop over array and do the things from single input file. :) 
        a=0
        while [ $a -lt "${#in_array[@]}" ]; do 
            SOURCE="${in_array[$a]}"
            NOBASE_SOURCE=""
            NOBASE_SOURCE=${SOURCE#"$BASE"}
            TX_PATH=""
            TX_PATH=$(process_a_path "${NOBASE_SOURCE}")
            if [ "$DRYRUN" = "TRUE" ];then 
                echo "cp -n ${SOURCE} ${DEST}${TX_PATH}"
            else
                if [ "$CLOBBER" = "FALSE" ];then
                    cp -n "${SOURCE}" "${DEST}${TX_PATH}"
                    if [ $? -eq 0 ] && [ "$MOVE" = "TRUE" ];then
                        rm "$SOURCE"
                    fi
                else 
                    cp "${SOURCE}" "${DEST}${TX_PATH}"
                    if [ $? -eq 0 ] && [ "$MOVE" = "TRUE" ];then
                        rm "$SOURCE"
                    fi
                fi
            fi
            let a=a+1
        done
    fi



# todo - clobber only if size/date differs?        
# todo - conversion for old 8.3 formats? Would require extra deduplication code tho    


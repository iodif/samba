#!/usr/bin/env bash

set -x 

#===============================================================================
#          FILE: samba.sh
#
#         USAGE: ./samba.sh
#
#   DESCRIPTION: Entrypoint for samba docker container
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: David Personette (dperson@gmail.com),
#  ORGANIZATION:
#       CREATED: 09/28/2014 12:11
#      REVISION: 1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error

### charmap: setup character mapping for file/directory names
# Arguments:
#   chars) from:to character mappings separated by ','
# Return: configured character mapings
charmap() { local chars="$1" file=/etc/samba/smb.conf
    grep -q catia $file || sed -i '/TCP_NODELAY/a \
\
    vfs objects = catia\
    catia:mappings =\

                ' $file

    sed -i '/catia:mappings/s/ =.*/ = '"$chars" $file
}

### global: set a global config option
# Arguments:
#   option) raw option
# Return: line added to smb.conf (replaces existing line with same key)
global() { local key="${1%%=*}" value="${1#*=}" file=/etc/samba/smb.conf
    if grep -qE '^;*\s*'"$key" "$file"; then
        sed -i 's|^;*\s*'"$key"'.*|   '"${key% } = ${value# }"'|' "$file"
    else
        sed -i '/\[global\]/a \   '"${key% } = ${value# }" "$file"
    fi
}

### include: add a samba config file include
# Arguments:
#   file) file to import
include() { local includefile="$1" file=/etc/samba/smb.conf
    sed -i "\\|include = $includefile|d" "$file"
    echo "include = $includefile" >> "$file"
}

### import: import a smbpasswd file
# Arguments:
#   file) file to import
# Return: user(s) added to container
import() { local file="$1" name id
    while read name id; do
        grep -q "^$name:" /etc/passwd || adduser -D -h "/home/$name" -u "$id" -s /bin/false "$name"
    done < <(cut -d: -f1,2 $file | sed 's/:/ /')
    pdbedit -i smbpasswd:$file
}

### perms: fix ownership and permissions of share paths
# Arguments:
#   none)
# Return: result
perms() { local i h file=/etc/samba/smb.conf
    for i in $(awk -F ' = ' '/   path = / {print $2}' $file); do
        chown -Rh smbuser. $i
        find $i -type d ! -perm 770 -exec chmod 770 {} \;
        find $i -type f ! -perm 0660 -exec chmod 0660 {} \;
    done
    for i in $(pdbedit -L | cut -d: -f1); do
        h="/home/$i"
        chown -Rh smbuser. $h
        find $h -type d ! -perm 700 -exec chmod 700 {} \;
        find $h -type f ! -perm 0600 -exec chmod 0600 {} \;
    done
}

### recycle: disable recycle bin
# Arguments:
#   none)
# Return: result
recycle() { local file=/etc/samba/smb.conf
    sed -i '/recycle/d; /vfs/d' $file
}

### share: Add share
# Arguments:
#   share) share name
#   path) path to share
#   browsable) 'yes' or 'no'
#   readonly) 'yes' or 'no'
#   guest) 'yes' or 'no'
#   users) list of allowed users
#   admins) list of admin users
#   writelist) list of users that can write to a RO share
#   comment) description of share
# Return: result
share() { local share="$1" path="$2" browsable="${3:-yes}" ro="${4:-yes}" \
                guest="${5:-yes}" users="${6:-""}" admins="${7:-""}" \
                writelist="${8:-""}" comment="${9:-""}" file=/etc/samba/smb.conf
    sed -i "/\\[$share\\]/,/^\$/d" $file
    echo "[$share]" >>$file
    echo "   path = $path" >>$file
    echo "   browsable = $browsable" >>$file
    echo "   read only = $ro" >>$file
    echo "   guest ok = $guest" >>$file
    echo -n "   veto files = /._*/.apdisk/.AppleDouble/.DS_Store/" >>$file
    echo -n ".TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/" >>$file
    echo "Network Trash Folder/Temporary Items/Thumbs.db/" >>$file
    echo "   delete veto files = yes" >>$file
    [[ ${users:-""} && ! ${users:-""} =~ all ]] &&
        echo "   valid users = $(tr ',' ' ' <<< $users)" >>$file
    [[ ${admins:-""} && ! ${admins:-""} =~ none ]] &&
        echo "   admin users = $(tr ',' ' ' <<< $admins)" >>$file
    [[ ${writelist:-""} && ! ${writelist:-""} =~ none ]] &&
        echo "   write list = $(tr ',' ' ' <<< $writelist)" >>$file
    [[ ${comment:-""} && ! ${comment:-""} =~ none ]] &&
        echo "   comment = $(tr ',' ' ' <<< $comment)" >>$file
    echo "" >>$file
    [[ -d $path ]] || mkdir -p $path
}

### smb: disable SMB2 minimum
# Arguments:
#   none)
# Return: result
smb() { local file=/etc/samba/smb.conf
    sed -i '/min protocol/d' $file
}

### user: add a user
# Arguments:
#   name) for user
#   password) for user
#   id) for user
#   group) for user
# Return: user added to container
user() { local name="$1" passwd="$2" id="${3:-""}" group="${4:-""}"
    [[ "$group" ]] && { grep -q "^$group:" /etc/group || addgroup "$group"; }
    grep -q "^$name:" /etc/passwd ||
        adduser -D -h "/home/$name" ${group:+-G $group} ${id:+-u $id} -s /bin/false "$name"
    echo -e "$passwd\n$passwd" | smbpasswd -s -a "$name"
}

### workgroup: set the workgroup
# Arguments:
#   workgroup) the name to set
# Return: configure the correct workgroup
workgroup() { local workgroup="$1" file=/etc/samba/smb.conf
    sed -i 's|^\( *workgroup = \).*|\1'"$workgroup"'|' $file
}

### widelinks: allow access wide symbolic links
# Arguments:
#   none)
# Return: result
widelinks() { local file=/etc/samba/smb.conf \
            replace='\1\n   wide links = yes\n   unix extensions = no'
    sed -i 's/\(follow symlinks = yes\)/'"$replace"'/' $file
}

### home: enable access to personal home directories
# Arguments:
#   none)
# Return: result
home() { 
  local file=/etc/samba/smb.conf
  [[ -f /home/NOT_A_VOLUME_INDICATOR ]] \
    && echo 'WARNING: /home/ is not a Docker volume, files created in personal home directories will get lost during shutdown...!'
  {
    echo "[homes]"
    echo "   comment = Home Directories"
    echo "   browseable = no"
    echo "   read only = no"
    echo "   create mask = 0600"
    echo "   force create mode = 0700"
    echo "   directory mask = 0700"
    echo "   force directory mode = 0700"
    echo "   valid users = %S"
    echo -n "   veto files = /._*/.apdisk/.AppleDouble/.DS_Store/"
    echo -n ".TemporaryItems/.Trashes/desktop.ini/ehthumbs.db/"
    echo "Network Trash Folder/Temporary Items/Thumbs.db/"
    echo "   delete veto files = yes"
    echo
  } >> $file
}


### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC="${1:-0}"
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -H          Enable personal home directories
    -c \"<from:to>\" setup character mapping for file/directory names
                required arg: \"<from:to>\" character mappings separated by ','
    -g \"<parameter>\" Provide global option for smb.conf
                    required arg: \"<parameter>\" - IE: -g \"log level = 2\"
    -i \"<path>\" Import smbpassword file
                required arg: \"<path>\" - full file path in container
    -n          Start the 'nmbd' daemon to advertise the shares
    -p          Set ownership and permissions on the shares
    -r          Disable recycle bin for shares
    -S          Disable SMB2 minimum version
    -s \"<name;/path>[;browse;readonly;guest;users;admins;writelist;comment]\"
                Configure a share
                required arg: \"<name>;</path>\"
                <name> is how it's called for clients
                <path> path to share
                NOTE: for the default value, just leave blank
                [browsable] default:'yes' or 'no'
                [readonly] default:'yes' or 'no'
                [guest] allowed default:'yes' or 'no'
                [users] allowed default:'all' or list of allowed users
                [admins] allowed default:'none' or list of admin users
                [writelist] list of users that can write to a RO share
                [comment] description of share
    -u \"<username;password>[;ID;group]\"       Add a user
                required arg: \"<username>;<passwd>\"
                <username> for user
                <password> for user
                [ID] for user
                [group] for user
    -w \"<workgroup>\"       Configure the workgroup (domain) samba should use
                required arg: \"<workgroup>\"
                <workgroup> for samba
    -W          Allow access wide symbolic links
    -x \"<path>\" export passwords to file (in smbpasswd style)
                required arg: \"<path>\" - full file path in container
    -I          Add an include option at the end of the smb.conf
                required arg: \"<include file path>\"
                <include file path> in the container, e.g. a bind mount

The 'command' (if provided and valid) will be run instead of samba
" >&2
    exit $RC
}

### stop: gracefully stop and cleanup
# Arguments:
#   none)
# Return: result
stop() { 
  set -x
  [[ ${NMBD:-""} ]] && killall nmbd
  [[ "${EXPORTPASSDB:-""}" ]] && pdbedit -Lw > "${EXPORTPASSDB}"
  set +x
}

[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u $USERID -o smbuser
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]] && groupmod -g $GROUPID -o users

while getopts ":hHc:g:i:nprs:Su:Ww:I:x:" opt; do
    case "$opt" in
        h) usage ;;
        H) home ;;
        c) charmap "$OPTARG" ;;
        g) global "$OPTARG" ;;
        i) import "$OPTARG" ;;
        I) include "$OPTARG" ;;
        n) NMBD="true" ;;
        p) PERMISSIONS="true" ;;
        r) recycle ;;
        s) eval share $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        S) smb ;;
        u) eval user $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $OPTARG) ;;
        w) workgroup "$OPTARG" ;;
        W) widelinks ;;
        x) EXPORTPASSDB="$OPTARG" ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${CHARMAP:-""}" ]] && charmap "$CHARMAP"
[[ "${GLOBAL:-""}" ]] && global "$GLOBAL"
[[ "${IMPORT:-""}" ]] && import "$IMPORT"
[[ "${PERMISSIONS:-""}" ]] && perms
[[ "${RECYCLE:-""}" ]] && recycle
[[ "${SHARE:-""}" ]] && eval share $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $SHARE)
[[ "${SMB:-""}" ]] && smb
[[ "${USER:-""}" ]] && eval user $(sed 's/^/"/; s/$/"/; s/;/" "/g' <<< $USER)
[[ "${WORKGROUP:-""}" ]] && workgroup "$WORKGROUP"
[[ "${WIDELINKS:-""}" ]] && widelinks
[[ "${HOMEDIRS:-""}" ]] && home 
[[ "${INCLUDE:-""}" ]] && include "$INCLUDE"

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v grep | grep -q smbd; then
    echo "Service already running, please restart container to apply changes"
else
    [[ ${NMBD:-""} ]] && ionice -c 3 nmbd -D
    trap 'stop' SIGTERM SIGQUIT SIGINT
    ionice -c 3 smbd -FS --no-process-group </dev/null
fi


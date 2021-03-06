[![logo](https://raw.githubusercontent.com/iodif/samba/master/logo.jpg)](https://www.samba.org)

# Samba

Samba docker container

# Credits

This repo is a clone from https://github.com/dperson/samba and adapted to my personal needs. Feel free to use it but I would strongly suggest to give David Personettes original image a try: he is doing a good job there! Thanks!

# What is Samba?

Since 1992, Samba has provided secure, stable and fast file and print services
for all clients using the SMB/CIFS protocol, such as all versions of DOS and
Windows, OS/2, Linux and many others.

# How to use this image

By default there are no shares configured, additional ones can be added.

## Hosting a Samba instance

    sudo docker run -it -p 139:139 -p 445:445 -d iodif/samba

OR set local storage:

    sudo docker run -it --name samba -p 139:139 -p 445:445 \
                -v /path/to/directory:/mount \
                -v /path/to/another/directory:/home \
                -d iodif/samba

## Configuration

    sudo docker run -it --rm iodif/samba -h
    Usage: samba.sh [-opt] [command]
    Options (fields in '[]' are optional, '<>' are required):
        -h          This help
        -H          Enable personal home directories
        -c "<from:to>" setup character mapping for file/directory names
                    required arg: "<from:to>" character mappings separated by ','
        -g "<parameter>" Provide global option for smb.conf
                    required arg: "<parameter>" - IE: -g "log level = 2"
        -i "<path>" Import smbpasswd file
                    required arg: "<path>" - full file path in container
        -n          Start the 'nmbd' daemon to advertise the shares
        -p          Set ownership and permissions on the shares
        -r          Disable recycle bin for shares
        -S          Disable SMB2 minimum version
        -s "<name;/path>[;browse;readonly;guest;users;admins;writelist;comment]"
                    Configure a share
                    required arg: "<name>;</path>"
                    <name> is how it's called for clients
                    <path> path to share
                    NOTE: for the default values, just leave blank
                    [browsable] default:'yes' or 'no'
                    [readonly] default:'yes' or 'no'
                    [guest] allowed default:'yes' or 'no'
                    [users] allowed default:'all' or list of allowed users
                    [admins] allowed default:'none' or list of admin users
                    [writelist] list of users that can write to a RO share
                    [comment] description of share
        -u "<username;password>[;ID;group]"       Add a user
                    required arg: "<username>;<passwd>"
                    <username> for user
                    <password> for user
                    [ID] for user
                    [group] for user
        -w "<workgroup>"       Configure the workgroup (domain) samba should use
                    required arg: "<workgroup>"
                    <workgroup> for samba
        -W          Allow access wide symbolic links
        -I          Add an include option at the end of the smb.conf
                    required arg: "<include file path>"
                    <include file path> in the container, e.g. a bind mount
        -x "<path>" export smbpasswd file
                    required arg: "<path>" - full file path in container

    The 'command' (if provided and valid) will be run instead of samba

ENVIRONMENT VARIABLES

 * `CHARMAP` - As above, configure character mapping
 * `GLOBAL` - As above, configure a global option
 * `IMPORT` - As above, import a smbpassword file
 * `NMBD` - As above, enable nmbd
 * `PERMISSIONS` - As above, set file permissions on all shares
 * `RECYCLE` - As above, disable recycle bin
 * `SHARE` - As above, setup a share
 * `SMB` - As above, disable SMB2 minimum version
 * `TZ` - Set a timezone, IE `EST5EDT`
 * `USER` - As above, setup a user
 * `WIDELINKS` - As above, allow access wide symbolic links
 * `WORKGROUP` - As above, set workgroup
 * `USERID` - Set the UID for the samba server/stored files
 * `GROUPID` - Set the GID for the samba server/stored files
 * `HOMEDIRS` - As above, activate personal home directories
 * `INCLUDE` - As above, add a smb.conf include

**NOTE**: if you enable nmbd (via `-n` or the `NMBD` environment variable), you
will also want to expose port 137 and 138 with `-p 137:137/udp -p 138:138/udp`
and run the container on the host network via `--network host` (otherwise service
discovery in the network neighborhood does not work).

## Examples

Any of the commands can be run at creation with `docker run` or later with
`docker exec -it samba samba.sh` (as of version 1.3 of docker).

### Setting the Timezone

    sudo docker run -it -e TZ=EST5EDT -p 139:139 -p 445:445 -d iodif/samba

### Start an instance creating users and shares:

    sudo docker run -it -p 139:139 -p 445:445 -d -e USERID=1000 -e GROUPID=1000 iodif/samba \
                -u "example1;badpass" \
                -u "example2;badpass" \
                -s "public;/share" \
                -s "users;/srv;no;no;no;example1,example2" \
                -s "example1 private share;/example1;no;no;no;example1" \
                -s "example2 private share;/example2;no;no;no;example2"

# User Feedback

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/iodif/samba/issues).

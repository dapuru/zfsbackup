#!/bin/bash

set -e

# Copy devd-Config files from root-scripts folder to
# in /usr/local/etc/devd/ , as files there don't survive a reboot
# so copy it to /usr/local/etc/devd/ with cronjob and this script

##################################################################
# This script is for FreeBSD and the devd-Rules
# For Linux use the script truenas-copy-udevconf.sh
##################################################################

force_copy=0

while getopts "fh" opt; do
	case $opt in
		f)	force_copy=1
		;;
		h) echo "point devd to a user config dir an copy over the .conf file"
	 	  	echo "usage: $0 [-fh]"
	    	echo "Options: -f force copy (replace existing config)"
	 		echo "         -h print this help and exit"
			exit 0 ;;
	esac
done

if [ -f /usr/local/etc/devd/devd-backuphdd.conf ];
    then
        echo "devd-Config found in /usr/local/etc/devd"
        if [ $force_copy -eq 1 ];
            then
                echo "force_copy option is used. Overwriting config..."
        else
            echo "Use '-f' option to overwrite if needed."
            exit 0
        fi
fi


SCRIPT_PATH="`dirname \"$0\"`"
SCRIPT_PATH="`( cd \"$SCRIPT_PATH\" && pwd )`"


# Add Config dir if not set
if [ ! -d /usr/local/etc/devd ];
    then
        mkdir -p /usr/local/etc/devd
fi
if [ $(grep -c 'directory "/usr/local/etc/devd";' /conf/base/etc/devd.conf) -eq 0 ];
    then
        sed -i'.backup' '/pid-file.*/i \   
        directory "/usr/local/etc/devd";
' /conf/base/etc/devd.conf
fi

# Copy Config
cp ${SCRIPT_PATH}/devd-backuphdd.conf /usr/local/etc/devd/
/etc/rc.d/devd restart

#!/bin/bash

# Copy udev-Config file from script location to
# /etc/udev/rules.d/80-local-homebackup.rules
# this is a one time task here for me... 

##################################################################
# This script is for Linux and the devd-Rules
# For FreeBSD use the script truenas-copy-udevconf.sh
##################################################################

force_copy=0

while getopts "fh" opt; do
	case $opt in
		f)	force_copy=1
		;;
		h) echo "point udev to a user config dir an copy over the .conf file"
	 	  	echo "usage: $0 [-fh]"
	    	echo "Options: -f force copy (replace existing config)"
	 		echo "         -h print this help and exit"
			exit 0 ;;
	esac
done

if [ -f /etc/udev/rules.d/80-local-homebackup.rules ];
    then
        echo "udev-Rule found in /etc/udev/rules.d/"
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

## not needed
## Add Config dir if not set
#if [ ! -d /usr/local/etc/devd ];
#    then
#        mkdir -p /usr/local/etc/devd
#fi
#if [ $(grep -c 'directory "/usr/local/etc/devd";' /conf/base/etc/devd.conf) -eq 0 ];
#    then
#        sed -i'.backup' '/pid-file.*/i \   
#        directory "/usr/local/etc/devd";
#' /conf/base/etc/devd.conf
#fi

# Copy Config
cp ${SCRIPT_PATH}/udev-homebackup.conf /etc/udev/rules.d/80-local-homebackup.rules
udevadm control --reload

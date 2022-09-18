#!/bin/bash

# wrapper-script to start the actual backup script for desktop-environments:
# - start only once
# - provide different config-file
# - show notifications

SUBJECT="Home-Directory"
LOCK_FILE="/tmp/homebackup.lock"
CONFIG_FILE="/home/daniel/Documents/scripts/zfsbackup/homebackup/homebackup-conf.env"
SCRIPT_LOCATION="/home/daniel/Documents/scripts/zfsbackup/truenas-poolbackup.sh"
SCRIPT_RUN="$SCRIPT_LOCATION -c $CONFIG_FILE"


# run only once, check if lock-file exists
# this is due to udev-rules is to unspecific and fired several times
# i'm getting crazy trying to figure out how to get this rule more specific
# so doing it the dirty way..

if [ -f "$LOCK_FILE" ]; then
    echo "Lock file present. Aborting..."
	exit
else
	echo "Locking"
	touch $LOCK_FILE
fi


# test, if file config-exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Using config file $CONFIG_FILE"
else 
    echo "Config file $CONFIG_FILE does not exist. Aborting..."
    rm $LOCK_FILE
    exit
fi

# TODO
# see if some kind of key on HDD should be checked
# even if keyfile for HDD-Pool is sufficient actually.


# Start notificaton
notify-send "Starting Backup of $SUBJECT"

# Run script - i know :)
eval "$SCRIPT_RUN"

# Finished notification
notify-send "Finished Backup of $SUBJECT"

# remove lockfile
echo "Unlocking"
rm $LOCK_FILE

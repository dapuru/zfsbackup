#!/bin/bash

# Get all config from file homebackup-conf.env in same directory
SCRIPT_PATH="`dirname \"$0\"`"
SCRIPT_PATH="`( cd \"$SCRIPT_PATH\" && pwd )`"

set -o allexport
source ${SCRIPT_PATH}/homebackup-conf.env
set +o allexport

DATASET="home"

sudo zpool import $BACKUPPOOL
sudo zfs load-key -r $BACKUPPOOL $BACKUPKEY
zpool status $BACKUPPOOL

sudo zfs set mountpoint=$MOUNTPOINT $BACKUPPOOL
sudo zfs mount -o ro $BACKUPPOOL/$DATASET

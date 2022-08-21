#!/bin/bash

# Mounts Backup-HD for TrueNas server on local Linux maschine
# All Datasets are mounted read only.
# This is not (!) for the actual restore, but just for browsing the data.
# Prerequisite: Key-Location mounted.
#
# Author: dapuru (https://github.com/dapuru/zfsbackup/)
#
# Version: 0.1
# Date: 21.08.2022
# Initially Published: 21.08.2022
#
# Modifications:
# - none -
#
# ####################################################################
# ####################### Config ## ####################################

# Get all config from file mount-Ext-Backup-conf.env in same directory
# Example file "mount-Ext-Backup-conf-example.env" provided - rename to mount-Ext-Backup-conf.env
set -o allexport
source mount-Ext-Backup-conf.env
set +o allexport

# ####################### Logic ## ####################################

# check if key-location is available/mounted
if [ -f "$BACKUPKEY" ]; then
    echo "$BACKUPKEY exists. Continue..."
else 
    echo "$BACKUPKEY does not exists. Aborting..."
    exit
fi


# Import Backup-Pool
sudo zpool import $BACKUPPOOL
# Unlock Pool
sudo zfs load-key -r $BACKUPPOOL < $BACKUPKEY
# Status
sudo zpool status $BACKUPPOOL
# Mountpoint
sudo zfs set mountpoint=$MOUNTPOINT $BACKUPPOOL


## Get recursive sub-dataasets --> Save in new array: DATASETS
for MAINDATASET in ${MAINDATASETS[@]}
do
        # Add root element to new array
        DATASETS=("${DATASETS[@]}" ${MAINDATASET})
        # Get DataSet Information
        length=${#BACKUPPOOL}
        length=$((length + 2))
        tmp_sub=$(zfs list -r -o name "${BACKUPPOOL}/${MAINDATASET}" | grep "${BACKUPPOOL}/" | awk '{print substr($1,'$length'); }')
        #echo ${tmp_sub}
        #get sub-datasets
        readarray -t <<<$tmp_sub #MAPFILE is default array

# add all sub-datasets to main array
for (( i=1; i<${#MAPFILE[@]}; i++ ))
do
    #echo "$i: ${MAPFILE[$i]}"
    DATASETS=("${DATASETS[@]}" ${MAPFILE[i]})
done
done

# Mount all datasets read-only
for DATASET in ${DATASETS[@]}
do
	echo $BACKUPPOOL/$DATASET
	sudo zfs mount -o ro $BACKUPPOOL/$DATASET
done

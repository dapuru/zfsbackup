#!/bin/bash

# Backup of TrueNas Pools to external HardDisk
# This will backup the DATA in TrueNAS
#
# Author: dapuru (https://github.com/dapuru/zfsbackup/)
# based on the script by Jörg Binnewald
# initial Source: https://esc-now.de/_/zfs-offsite-backup-auf-eine-externe-festplatte/?lang=en
# License: https://creativecommons.org/licenses/by-nc-sa/4.0/
# https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.txt
# Infos: 
# ZFS: https://www.freebsd.org/cgi/man.cgi?query=zfs&sektion=8&manpath=FreeBSD+11.1-RELEASE+and+Ports
# Zpool: https://www.freebsd.org/cgi/man.cgi?query=zpool&sektion=8&manpath=FreeBSD+11.1-RELEASE+and+Ports
# Scrubbing: https://pthree.org/2012/12/11/zfs-administration-part-vi-scrub-and-resilver/
#
# Script is run through devd when USB HDD is attached
# configuration in: devd-backuphdd.conf
# see: https://www.freebsd.org/cgi/man.cgi?devd.conf
#
# Version: 0.6.1
# Date: 03.04.2022
# Initially Published: 05.06.2021
#
# Modifications:
# Support for encrypted Backup-Pool using load-key
# All Live Data-Sets and Sub-DataSets
# Scrub for Backup-Pool
# Email-Notification
# Cleansing #here
# .env-file for config
# Regex for Scrub-Date & Command line parameter for Dry-run (-d) and forced scrub (-f)
#
# #####################################################################
# ####################### Config## ####################################

# Get all config from file conf-truenas-poolbackup.env in same directory
# Example file "truenas-poolbackup-conf-example.env" provided - rename to truenas-poolbackup-conf.env
SCRIPT_PATH="`dirname \"$0\"`"
SCRIPT_PATH="`( cd \"$SCRIPT_PATH\" && pwd )`"

set -o allexport
source ${SCRIPT_PATH}/truenas-poolbackup-conf.env
set +o allexport

# Exit on Error
set -e

# --------------- Check command line parameter --------------

dry_run=0
force_scrub=0
yes_all=0

while getopts "hdfy" opt; do
	case $opt in
		d)	dry_run=1
		;;
		f)	force_scrub=1
		;;
		y)	yes_all=1
		;;
		h) echo "run poolbackup using zfs. Config file in truenas-poolbackup-conf.env"
	 	  	echo 'usage: truenas-poolbackup [-dfhy]'
	    	echo "Options: -d dryrun (no backup done)"
	    	echo "         -f force scrub (even condition is not met)"
	 		echo "         -h print this help and exit"
	 		echo "         -y don't ask when creating/overwriting folders in backup"
			echo "            (caution: intended to be used on initial backups)"
			exit 0 ;;
	esac
done

# --------------- wait to be able to kill process  --------------
secs=0
while [ ! 60 -eq $secs ]; do
    sleep 1
    ((secs=secs+1))
	echo -ne "Sleeping for 60 sec. - so you can kill me ($secs) "\\r
done
echo
echo "Starting..."

# ######################################################################
# ####################### Variables ####################################

# Scrub only once a month (30 days * 24h * 3600sec = 2592000)
# from https://gist.github.com/petervanderdoes/bd6660302404ed5b094d
currentDate=$(date +%s)
scrubExpire=2592000

# Init variables
problems=0
freenashost=$(hostname -s | tr '[:lower:]' '[:upper:]')
mailfile="/tmp/backup_email.tmp"
subject="TrueNas - SUCC Backup to $BACKUPPOOL $TIMESTAMP"

# human readable
scrubExpireShow=$(($scrubExpire / 60 / 60 / 24)) # in days

# --------------------- Email function ---------------------
function prepareMailContent(){
	mailSubject="$1"
	mailBody="$2"
	printf "%s\n" "To: ${email}
Subject: ${mailSubject}
Mime-Version: 1.0
Content-Type: multipart/mixed; boundary=\"$boundary\"
--${boundary}
Content-Type: text/html; charset=\"US-ASCII\"
Content-Transfer-Encoding: 7bit
Content-Disposition: inline
<html><head></head><body><pre style=\"font-size:14px; white-space:pre\">" >> $mailfile

	if [ -f "${mailBody}" ];
		then
		less ${BACKUPLOG} >> $mailfile
	else
		echo "${mailBody}" >> $mailfile
	fi

	printf "%s\n" "</pre></body></html>
--${boundary}--" >> $mailfile
}

# --------------------- Create Backup Snapshot function ---------------------
function initBackupSnap(){
	# Initialize Backup
	# Form: Pool/Dataset@Snapshot
	NEWSNAP="$1"
	echo "Initializing Snapshot.. $NEWSNAP" >> ${BACKUPLOG}
	
	# Create Snapshot (not incremental, as it's the very first snapshot)
	# zfs snapshot: Creates sanpshot with the given names
	# -r = recursively for all descendent datasets
	# zfs send: Creates a stream representation of the	last snapshot argument
	# -v = verbose
	# zfs recv: Creates a snapshot whose contents are as specified in the stream provided on standard input.
	# s the pipe sends the snapshot from TrueNas to the Backup-Pool (initial, thats why no additional naming)
	# -F = Force a rollback of the file system to	the most recent snapshot before performing	the receive operation.
	
	# Create Snapshot (on TrueNas, should show up in .zfs/snapshot subfolder of DataSet)
	zfs snapshot -r $NEWSNAP >> ${BACKUPLOG} 
	zfs send -v $NEWSNAP | zfs recv -F "${BACKUPPOOL}/${DATASET}"
}


# --------------------- Notification email ---------------------
if [ $notification_onstart -eq 1 ];
	then
		prepareMailContent "TrueNas - START Backup to $BACKUPPOOL $TIMESTAMP" "Start notification of backup script $0"
		sendmail -t -oi < ${mailfile}
		rm ${mailfile} # important, otherwiese emails are sent all over again
fi

# ########################################################################
# ####################### LOGIC starts here ##############################

## Get recursive sub-dataasets --> Save in new array: DATASETS
for MAINDATASET in ${MAINDATASETS[@]}
do
        # Add root element to new array
        DATASETS=("${DATASETS[@]}" ${MAINDATASET})
        # Get DataSet Information
        length=${#MASTERPOOL}
        length=$((length + 2))
        tmp_sub=$(zfs list -r -o name "${MASTERPOOL}/${MAINDATASET}" | grep "${MASTERPOOL}/" | awk '{print substr($1,'$length'); }')
        #echo ${tmp_sub}
        #get sub-datasets
        readarray -t <<<$tmp_sub #MAPFILE is default array

# add all sub-datasets to main array
for (( i=1; i<${#MAPFILE[@]}; i++ ))
do
#    echo "$i: ${MAPFILE[$i]}"
    DATASETS=("${DATASETS[@]}" ${MAPFILE[i]})
done
done


# Logfile
if [ $dry_run -eq 1 ]; then
 echo "########## DRYRUN ##########" >> ${BACKUPLOG}
 echo "########## DRYRUN ##########"
fi
 echo "########## Backup of pools on server ${freenashost} ##########" >> ${BACKUPLOG}
 echo "Started Backup-job: $TIMESTAMP" >> ${BACKUPLOG}

(
  echo ""
  echo "+--------------+--------+------------+--------+"
  echo "|Dataset       |Size    |Snapcount   |SnapSize |"
  echo "+--------------+--------+------------+--------+"
) >> ${BACKUPLOG}

for DATASET in ${DATASETS[@]}
do
	# Get DataSet Information (| sed -n '2p' = get second line)
	# https://docs.oracle.com/cd/E18752_01/html/819-5461/gazsu.html
	USED=$(zfs list -o used,usedbysnapshots "${MASTERPOOL}/${DATASET}" | sed -n '2p' | awk '{print $1}')
	USEDSNAP=$(zfs list -o used,usedbysnapshots "${MASTERPOOL}/${DATASET}" | sed -n '2p' | awk '{print $2}')
	SNAPCOUNT=$(zfs list -o snapshot_count "${MASTERPOOL}/${DATASET}" | sed -n '2p' | awk '{print $1}')

	# Logfile
  echo "| ${DATASET} | ${USED} | ${SNAPCOUNT} | ${USEDSNAP} |" >> ${BACKUPLOG}
  echo "+--------------+--------+------------+--------+" >> ${BACKUPLOG}
done


# Import Backup-Pool
zpool import $BACKUPPOOL

# Unlock Pool (if Keyfile is provideds)
if [ ! -z $BACKUPKEY ];
	then
		zfs load-key -r $BACKUPPOOL < $BACKUPKEY
fi

# Log Status pf Backup-Pool
zpool status $BACKUPPOOL >> ${BACKUPLOG}

# Check if one of the pools has problems
set +e
condition=$(zpool status | egrep -i '(DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED|FAIL|DESTROYED|corrupt|cannot|unrecover)' | grep -v "features are unavailable")
if [ "${condition}" ]; then
  problems=1
  subject="TrueNas - ERR Backup to $BACKUPPOOL $TIMESTAMP"
fi
set -e

KEEPOLD=$(($KEEPOLD + 1))

# Only contiune if pool are in good shape
if [ ${problems} -eq 0 ]; then

# No backup in Dryrun
if [ $dry_run -eq 0 ]; then
for DATASET in ${DATASETS[@]}
do
    # Logging
    echo "" >> ${BACKUPLOG}
    echo "****************** $MASTERPOOL / $DATASET ******************" >> ${BACKUPLOG}
    # Get name of the most current snaphot from the backup (on HD, if empty -> initialize Backup)
    # zfslist = Lists the property informtion of the given dataset in tabular form
    # -r = recursively (child-datasets)
    # -t = type: snap
    # -H = scripting mode, do not print header
    # -o name = Display dataset name
    # Snapshot name: ${BACKUPPOOL}/${DATASET}
    
	recentBSnap=$(zfs list -rt snap -H -o name "${BACKUPPOOL}/${DATASET}" | grep "${DATASET}@${PREFIX}-" | tail -1 | cut -d@ -f2)
	if [ -z "$recentBSnap" ] 
		then
			echo "ERROR - No snapshot found..." >> ${BACKUPLOG}
			set +e
			if [ ! $yes_all -eq 1 ];
				then
					dialog --title "No snapshot found" --yesno "There is no backup-snapshot in ${BACKUPPOOL}/${DATASET}. Should a new backup be created? (Existing data in ${BACKUPPOOL}/${DATASET} will be overwritten.)" 15 60
					ANTWORT=${?}
			else
				ANTWORT="0"
			fi
			set -e
			if [ "$ANTWORT" -eq "0" ]
				then
					# Initialize Backup
					NEWSNAP="${MASTERPOOL}/${DATASET}@${PREFIX}-$(date '+%Y%m%d-%H%M%S')"
					initBackupSnap "$NEWSNAP"
			fi
			continue
	fi
	
	# Check if corresponding snapshot does exist in Master-Pool
	origBSnap=$(zfs list -rt snap -H -o name "${MASTERPOOL}/${DATASET}" | grep "${DATASET}@${recentBSnap}" | cut -d@ -f2)
	if [ "$recentBSnap" != "$origBSnap" ]
		then
			#TODO: Do sth. against it ! (Pick another Snap, create an intermediate one, ask user ...) - Issue #10
			echo "Error: For the last backup snaphot ${recentBSnap} there is no corresponding snapshot in the master-pool." >> ${BACKUPLOG}
			echo "Error: $recentBSnap != $origBSnap" >> ${BACKUPLOG}
			subject="TrueNas - ERR Backup to $BACKUPPOOL $TIMESTAMP"
			set +e
			if [ ! $yes_all -eq 1 ];
				then
					dialog --title "Backup Snapshot not found in Master" --yesno "The last Backup Snapshot $recentBSnap was not found on Master in ${BACKUPPOOL}/${DATASET} anymore. You could delete the whole dataset in Backup and recreate it from Master. Delete this Dataset and all of its childs and Snapshots?" 15 60
					ANTWORT=${?}
			else
				ANTWORT="0"
			fi
			set -e
			if [ "$ANTWORT" -eq "0" ]
				then
				# Delete complete Dataset
				echo "Deleting Backup Dataset.. ${DATASET}" >> ${BACKUPLOG}
				zfs destroy -R ${BACKUPPOOL}/${DATASET}
				# Initialize Backup
				NEWSNAP="${MASTERPOOL}/${DATASET}@${PREFIX}-$(date '+%Y%m%d-%H%M%S')"
				initBackupSnap "$NEWSNAP"
			fi
			continue
	fi
	
	echo "most current snapshot in Backup: ${BACKUPPOOL}/${DATASET}@${recentBSnap}" >> ${BACKUPLOG}
	
	# Name for new Snapshot
	NEWSNAP="${MASTERPOOL}/${DATASET}@${PREFIX}-$(date '+%Y%m%d-%H%M%S')"
	# create new snapshot
	zfs snapshot -r $NEWSNAP
	echo "new snapshot created: ${NEWSNAP}" >> ${BACKUPLOG}
	
	# send new snapshot
	# zfs send: Creates a stream representation of the last snapshot argument
	# -v = verbose
	# -i = incremental (The incremental source must be an earlier snapshot in	the destination's history.  It
	#			will commonly be an earlier snapshot in the destination's filesystem
	# -F force, needed when target has been modified, this could even be the case, when just accessing the files in the Backup-Pool (atime)
	#			see: https://www.kernel-error.de/kernel-error-blog/372-zfs-send-recv-schlaegt-mit-cannot-receive-incremental-stream-destination-has-been-modified-fehl
	zfs send -v -i @$recentBSnap $NEWSNAP | zfs recv -F "${BACKUPPOOL}/${DATASET}" >> ${BACKUPLOG}
	echo "Send: $NEWSNAP to ${BACKUPPOOL}/${DATASET}" >> ${BACKUPLOG}
	
	# delete old snapshots
	# zfs destroy: The given snapshot is destroyed
	# -r = recursively, all children
	echo "Destroying Snapshots:" >> ${BACKUPLOG}
	#Log
	zfs list -rt snap -H -o name "${BACKUPPOOL}/${DATASET}" | grep "${BACKUPPOOL}/${DATASET}@${PREFIX}-" | tail -r | tail +$KEEPOLD >> ${BACKUPLOG}
	zfs list -rt snap -H -o name "${MASTERPOOL}/${DATASET}" | grep "${MASTERPOOL}/${DATASET}@${PREFIX}-" | tail -r | tail +$KEEPOLD >> ${BACKUPLOG}
	#Destroy
	zfs list -rt snap -H -o name "${BACKUPPOOL}/${DATASET}" | grep "${BACKUPPOOL}/${DATASET}@${PREFIX}-" | tail -r | tail +$KEEPOLD | xargs -n 1 zfs destroy #-r 
	zfs list -rt snap -H -o name "${MASTERPOOL}/${DATASET}" | grep "${MASTERPOOL}/${DATASET}@${PREFIX}-" | tail -r | tail +$KEEPOLD | xargs -n 1 zfs destroy #-r
 
done
fi # not in dry-run

# #########################################################
# ####################### Scrub  #############################
# Be aware: Scrub run may take some time, up to days... so chosse the scrub-limit carefully... #

echo "" >> ${BACKUPLOG}
echo "****************** $BACKUPPOOL - Cleanup ******************" >> ${BACKUPLOG}
# Scrub Pool - Only once a month
# Get last Scrub
# https://pthree.org/2012/12/11/zfs-administration-part-vi-scrub-and-resilver/
# from https://gist.github.com/petervanderdoes/bd6660302404ed5b094d

# assuming external HD and long scrub-time more than one day (two versions)
scrubRawDate1=$(zpool status $BACKUPPOOL | grep "scan:" | grep "scrub" | rev | cut -f1-5 -d ' ' | rev | awk '{print $4 $1 $2}')
scrubRawDate2=$(zpool status $BACKUPPOOL | grep "scan:" | grep "scrub" | rev | cut -f1-5 -d ' ' | rev | awk '{print $5 $2 $3}')
echo "scrubRawDate is ${scrubRawDate1} or ${scrubRawDate2}"

re='^[0-9]+[A-Z]{1}[a-z]{1,3}[0-9]{1,2}$' # check format like 2021Feb7
if (echo "$scrubRawDate1" | grep -Eq "$re"); then
	scrubRawDate="$scrubRawDate1"
elif (echo "$scrubRawDate2" | grep -Eq "$re"); then
	scrubRawDate="$scrubRawDate2"
else
	scrubRawDate=
fi
if [[ $scrubRawDate ]];
	then
		scrubDate=$(date -j -f '%Y%b%e-%H%M%S' $scrubRawDate'-000000' +%s)
		scrubDiff=$(($currentDate-$scrubDate))
		scrubShow=$(($scrubDiff / 60 / 60 / 24)) # in days
else
	echo "ERROR: Scrub raw dates $scrubRawDate1 and $scrubRawDate2 could not be parsed. Try running manual scrub first." >> ${BACKUPLOG} 
fi

# do the real scrub
	# https://stackoverflow.com/questions/8941874/bad-number-on-the-bash-script
	if [ "0$(echo $scrubDiff|tr -d ' ')" -gt "0$(echo $scrubExpire|tr -d ' ')" ] || [ $force_scrub -eq 1 ]; then
		if [ $force_scrub -eq 1 ]; then
			echo "Last Scrub for $BACKUPPOOL was on $scrubRawDate ($scrubShow days ago) forced-Flag - SCRUB forced..." >> ${BACKUPLOG}
		else
			echo "Last Scrub for $BACKUPPOOL was on $scrubRawDate ($scrubShow days ago, beyond $scrubExpireShow days-limit) - SCRUB needed..." >> ${BACKUPLOG}
		fi
		TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`
		echo "scrub started: $TIMESTAMP"
		echo "scrub started: $TIMESTAMP" >> ${BACKUPLOG}
		
		zpool scrub $BACKUPPOOL
		# wait until scrub is finished
		while zpool status $BACKUPPOOL | grep 'scan:  *scrub in progress' > /dev/null; do
			echo -n '.'
			sleep 10
		done
		TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`
		echo "scrub finished: $TIMESTAMP"
		echo "scrub finished: $TIMESTAMP" >> ${BACKUPLOG}
		
	else
		echo "No Scrub needed"
		echo "Last Scrub for $BACKUPPOOL was on $scrubDate ($scrubShow days ago, below $scrubExpireShow days-limit) - NO scrub needed..." >> ${BACKUPLOG}
	fi

# #################################################################
# ####################### End ################################

# Unmount Backup Pool
echo "Unmount $BACKUPPOOL"
zpool export $BACKUPPOOL >> ${BACKUPLOG}

# Write Log
TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`
echo "Finished Backup-job: $TIMESTAMP" >> ${BACKUPLOG}

else # Pools are not in good shape
	subject="TrueNas - CRITICAL Backup to $BACKUPPOOL $TIMESTAMP"
	echo "########## ERROR - ERROR - ERROR -- Pools are not in good shape ########"  >> ${BACKUPLOG}
fi # Only contiune if pool are in good shape


# ##################################################################
# ####################### Send Email  ##############################

### Send report ###
if [ -z "${email}" ]; then
	echo "No email address specified, information available in ${mailfile}"
elif [ $notification_onend -eq 1 ]; then
	prepareMailContent "${subject}" ${BACKUPLOG}
	sendmail -t -oi < ${mailfile}
	rm ${mailfile} # important, otherwiese emails are sent all over again
fi

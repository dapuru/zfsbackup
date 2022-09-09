#!/bin/bash
BACKUPPOOL="Ext-Backup"

# Unmount Backup Pool
echo "Unmount $BACKUPPOOL"
zpool export $BACKUPPOOL

# zfsbackup

As described in <a href="https://blog.daniel-purucker.com/data-backup-strategy-for-zfs-pool-on-truenas/">this post post</a>, i modified the awesome script from <a href="https://esc-now.de/_/zfs-offsite-backup-auf-eine-externe-festplatte/?lang=en">Jörg Binnewald @ https://esc-now.de/</a> to suit my needs.

The script is automatically triggered, when the backup-HDD is attached to the TrueNAS-Server. The Datasets (and child-Datasets) are incrementally backed-up via send/receive (ZFS feature).

## content
- truenas.poolbackup.sh (Backup script, triggert by devd rule)
- Example file "truenas-poolbackup-conf-example.env" provided - rename to truenas-poolbackup-conf.env
- devd-backuphdd.conf (devd rule, connecting HDD)
- truenas-copy-devdconf.sh (Workaround, because TrueNas keeps killing the devd rule)

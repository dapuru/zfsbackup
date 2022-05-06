# zfsbackup

As described in <a href="https://blog.daniel-purucker.com/data-backup-strategy-for-zfs-pool-on-truenas/">this post post</a>, i modified the awesome script from <a href="https://esc-now.de/_/zfs-offsite-backup-auf-eine-externe-festplatte/?lang=en">Jörg Binnewald @ https://esc-now.de/</a> to suit my needs.

The script is automatically triggered, when the backup-HDD is attached to the TrueNAS-Server. The Datasets (and child-Datasets) are incrementally backed-up via send/receive (ZFS feature).

## Content
- truenas.poolbackup.sh (Backup script, triggert by devd rule)
- Example file "truenas-poolbackup-conf-example.env" provided - rename to truenas-poolbackup-conf.env
- devd-backuphdd.conf (devd rule, connecting HDD)
- truenas-copy-devdconf.sh (Workaround, because TrueNas keeps killing the devd rule)

## Usage
- configure the devd-rule, and change the config in truenas-poolbackup-conf.env to suit your needs
- place the script on a safe place in your datapool (as the system partition is not upgrade safe)
- you may run the script manually, there are parameters available:
  - -h show help
  - -f force scrub (even if the condition, number of passed days) is not met
  - -d dry run (do not do the actual backup)
  - -y don't ask when creating/overwriting/deleting folders in backup (caution: intended to be used on initial backups; could cause data loss on existing backup data)
- execute truenas-copy-devdconf.sh to enable auto backup when configured HDD is attached
#!/bin/bash

# Copy devd-Config files from root-scripts folder to
# in /usr/local/etc/devd/ , as files thered don't survive a reboot
# so copy it from /root/scripts/devd/ to /usr/local/etc/devd/ with cronjob and this script

cp /root/scripts/devd/* /usr/local/etc/devd/
/etc/rc.d/devd restart

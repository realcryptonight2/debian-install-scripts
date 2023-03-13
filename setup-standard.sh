#!/bin/bash

installdir=$(pwd)
log_file="${installdir}/install.log"

echo "Installing standard configurations..." >> $log_file

echo "Configuring new motd..." >> $log_file
apt update
apt -y upgrade
apt -y install figlet
rm /etc/motd
mv ./files/00-header /etc/update-motd.d/
mv ./files/10-sysinfo /etc/update-motd.d/
mv ./files/10-uname /etc/update-motd.d/
mv ./files/90-footer /etc/update-motd.d/
chmod 777 /etc/update-motd.d/*
echo "Configured new motd." >> $log_file

echo "Reconfiguring sshd service config file..." >> $log_file
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
service sshd restart
echo "Reconfigured sshd service config file." >> $log_file

echo "Installed standard configurations." >> $log_file

exit 0
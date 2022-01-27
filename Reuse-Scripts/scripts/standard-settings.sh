#!/bin/bash

# Setup SSH keys authentication.
mkdir .ssh
chmod 700 .ssh
mv ./../keys/authorized_keys /root/.ssh/
chmod 600 /root/.ssh/authorized_keys

# Remove default motd and replace it with an usefull one.
rm /etc/motd
mv ./../banners/00-header /etc/update-motd.d/
mv ./../banners/10-sysinfo /etc/update-motd.d/
mv ./../banners/10-uname /etc/update-motd.d/
mv ./../banners/90-footer /etc/update-motd.d/
chmod 777 /etc/update-motd.d/*

# Update the server if needed and setup the SSH server.
apt update
apt -y upgrade
apt -y install figlet vim zip unzip openssh-server
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
service sshd restart
#!/bin/bash

# Check if a license key is given.
if [ -z "$1" ]
  then
    echo "./setup-directadmin.sh <DirectAdmin license key> <admin username>"
	exit 1
fi

# Check if a admin username is given.
if [ -z "$2" ]
  then
    echo "./setup-directadmin.sh <DirectAdmin license key> <admin username>"
	exit 1
fi

# Run apt install commands
apt -y update
apt -y upgrade
apt -y install git curl

# Run the default install.
chmod 755 setup-standard.sh
./setup-standard.sh

# Get the server IP for reverse DNS lookup.
serverip=`hostname -I | awk '{print $1}'`

# Get server hostname from reverse DNS lookup.
serverhostname=`dig -x ${serverip} +short | sed 's/\.[^.]*$//'`

# Get just the domain name.
domainhostname=`echo $serverhostname | sed 's/^[^.]*.//g'`

# NS hostnames.
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

# Set some variables to let DirectAdmin install correctly.
export DA_CHANNEL=current
export DA_HOSTNAME=$serverhostname
export DA_ADMIN_USER=$2
export DA_NS1=$ns1host
export DA_NS2=$ns2host
export DA_SKIP_CSF=true
export DA_FOREGROUND_CUSTOMBUILD=yes
export mysql_inst=mysql
export mysql=8.0

# Download and run the DirectAdmin install script.
wget -O directadmin.sh https://download.directadmin.com/setup.sh
chmod 755 directadmin.sh
./directadmin.sh $1

# Add the mysql script that allows MySQL to use the same SSL Certificate as the host.
cp ./files/mysql_update_cert.sh /usr/local/directadmin/scripts/custom/
chmod 755 /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
chown root:root /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
echo "0 3	* * 1	root	/usr/local/directadmin/scripts/custom/mysql_update_cert.sh" >> /etc/crontab
systemctl restart cron.service

# Change the installed PHP versions.
cd /usr/local/directadmin/custombuild
./build update
./build set php1_release 8.1
./build set php2_release 8.0
./build set php3_release 7.4
./build set php1_mode php-fpm
./build set php2_mode php-fpm
./build set php3_mode php-fpm
./build php n
./build rewrite_confs

# Install and request LetsEncrypt Certificates for the directadmin domain itself.
cd /usr/local/directadmin/custombuild
./build letsencrypt
/usr/local/directadmin/scripts/letsencrypt.sh request_single $serverhostname 4096
systemctl restart directadmin.service

# Enable multi SSL support for the mail server.
echo "mail_sni=1" >> /usr/local/directadmin/conf/directadmin.conf
systemctl restart directadmin.service
cd /usr/local/directadmin/custombuild
./build clean
./build update
./build set eximconf yes
./build set dovecot_conf yes
./build exim_conf
./build dovecot_conf
echo "action=rewrite&value=mail_sni" >> /usr/local/directadmin/data/task.queue

# Install everything needed for the Pro Pack.
cd /usr/local/directadmin/custombuild
./build composer
./build wp

# Setup SSO for PHPMyAdmin.
cd /usr/local/directadmin/
./directadmin set one_click_pma_login 1
service directadmin restart
cd custombuild
./build update
./build phpmyadmin

# Force SSL Certificate match.
#/usr/local/directadmin/scripts/custom/mysql_update_cert.sh

# Clear the screen and display the login data.
clear
. /usr/local/directadmin/scripts/setup.txt
echo "Username: $adminname"
echo "Password: $adminpass"
echo "Domain: $serverhostname"

exit 0
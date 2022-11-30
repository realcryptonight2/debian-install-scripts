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

# Run the install commands that install the packages required for this script and DirectAdmin.
apt -y update
apt -y upgrade
apt -y install git curl dnsutils

# Store current directory location for later.
installdir=$(pwd)

# Get the hostname and domain name for NS records.
serverip=$(hostname -I | awk '{print $1}')
serverhostname=$(dig -x $serverip +short | sed 's/\.[^.]*$//')
domainhostname=$(echo $serverhostname | sed 's/^[^.]*.//g')
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

# Set variables to let DirectAdmin install correctly.
export DA_CHANNEL=current
export DA_ADMIN_USER=$2
export DA_HOSTNAME=$serverhostname
export DA_NS1=$ns1host
export DA_NS2=$ns2host
export DA_FOREGROUND_CUSTOMBUILD=yes
export DA_SKIP_CSF=true
export mysql_inst=mysql
export mysql=8.0
export php1_release=8.1
export php2_release=8.0
export php3_release=7.4
export php1_mode=php-fpm
export php2_mode=php-fpm
export php3_mode=php-fpm

if [[ -z "${DA_HOSTNAME}" ]]; then
  echo "DA_HOSTNAME not set!"
  exit 1
fi

if [[ -z "${DA_NS1}" ]]; then
  echo "DA_NS1 not set!"
  exit 1
fi

if [[ -z "${DA_NS2}" ]]; then
  echo "DA_NS2 not set!"
  exit 1
fi

# Run the default install.
chmod 755 setup-standard.sh
./setup-standard.sh

# Download and run the DirectAdmin install script.
wget -O directadmin.sh https://download.directadmin.com/setup.sh
chmod 755 directadmin.sh
./directadmin.sh $1

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

# Add the mysql script that allows MySQL to use the same SSL Certificate as the host.
cp "${installdir}/files/mysql_update_cert.sh" /usr/local/directadmin/scripts/custom/
chmod 755 /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
chown root:root /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
echo "0 3	* * 1	root	/usr/local/directadmin/scripts/custom/mysql_update_cert.sh" >> /etc/crontab
systemctl restart cron.service
/usr/local/directadmin/scripts/custom/mysql_update_cert.sh

# Clear the screen and display the login data.
clear
. /usr/local/directadmin/scripts/setup.txt
onetimelogin=`/usr/local/directadmin/directadmin --create-login-url user=$2`
echo "\033[0;31mDO NOT FORGET INSTALL CSF!\033[0m"
echo "Hostname: $serverhostname"
echo "Admin account username: $adminname"
echo "Admin account password: $adminpass"
echo "One-Time login URL: $onetimelogin"

exit 0
#!/bin/bash

userid=`id -u`

# Check if the script is run by the root user.
if [ "$userid" -ne 0 ]
  then
	echo "Please only run this script as root."
	echo "Users are not allowed to run this script."
	exit 1
fi

# Check if the config file exist.
if [ ! -f "config.cnf" ];
then
	echo "config.cnf does not exist."
	exit 1
fi

. ./config.cnf

# Check if a license key is provided in the config file.
if [ -z "$directadmin_license_key" ]
  then
    echo "config.cnf is not configured correctly. Missing directadmin_license_key variable."
	exit 1
fi

# Run the default install.
chmod 755 setup-standard.sh
./setup-standard.sh

# Run the install commands that install the packages required for this script and DirectAdmin.
apt update
apt -y upgrade
apt -y install git curl dnsutils rclone zip unzip

# Store current directory location for later.
installdir=$(pwd)

# Get the hostname and domain name for NS records.
serverip=$(hostname -I | awk '{print $1}')
serverhostname=$(dig -x $serverip +short | sed 's/\.[^.]*$//')
domainhostname=$(echo $serverhostname | sed 's/^[^.]*.//g')
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

# Set variables to let DirectAdmin install correctly.
export DA_CHANNEL=stable
if [ ! -z ${directadmin_admin_username} ] && [ ! ${#directadmin_admin_username} -gt 10 ]
	then
		export DA_ADMIN_USER=$directadmin_admin_username
fi
export DA_HOSTNAME=$serverhostname
export DA_NS1=$ns1host
export DA_NS2=$ns2host
export DA_FOREGROUND_CUSTOMBUILD=yes
export mysql_inst=mysql
export mysql=8.0
export php1_release=8.2
export php2_release=8.1
export php1_mode=php-fpm
export php2_mode=php-fpm

# Download and run the DirectAdmin install script.
wget -O directadmin.sh https://download.directadmin.com/setup.sh
chmod 755 directadmin.sh
./directadmin.sh $directadmin_license_key

# Change some DirectAdmin settings that should be the default.
/usr/local/directadmin/directadmin config-set allow_backup_encryption 1
/usr/local/directadmin/directadmin config-set backup_ftp_md5 1
/usr/local/directadmin/directadmin config-set mail_sni 1
/usr/local/directadmin/directadmin set one_click_pma_login 1
systemctl restart directadmin
/usr/local/directadmin/custombuild/build clean
/usr/local/directadmin/custombuild/build update
/usr/local/directadmin/custombuild/build set eximconf yes
/usr/local/directadmin/custombuild/build set dovecot_conf yes
/usr/local/directadmin/custombuild/build exim_conf
/usr/local/directadmin/custombuild/build dovecot_conf
/usr/local/directadmin/custombuild/build phpmyadmin
/usr/local/directadmin/custombuild/build composer
/usr/local/directadmin/custombuild/build wp
echo "action=rewrite&value=mail_sni" >> /usr/local/directadmin/data/task.queue

# Check if the custom ns script variable is set and is set to 1.
if [ ! -z ${directadmin_custom_config_ns} ] && [ ${directadmin_custom_config_ns} = "1" ]
	then
		mkdir /usr/local/directadmin/data/templates/custom
		cp "${installdir}/files/dns_ns.conf" /usr/local/directadmin/data/templates/custom/
		chmod 644 /usr/local/directadmin/data/templates/custom/dns_ns.conf
		chown diradmin:diradmin /usr/local/directadmin/data/templates/custom/dns_ns.conf
fi

# Check if the custom mysql script variable is set and is set to 1.
if [ ! -z ${directadmin_custom_config_mysql} ] && [ ${directadmin_custom_config_mysql} = "1" ]
	then
		cp "${installdir}/files/mysql_update_cert.sh" /usr/local/directadmin/scripts/custom/
		chmod 755 /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
		chown root:root /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
		echo "0 3	* * 1	root	/usr/local/directadmin/scripts/custom/mysql_update_cert.sh" >> /etc/crontab
		systemctl restart cron
		/usr/local/directadmin/scripts/custom/mysql_update_cert.sh
fi

# Check if the custom ftp script variable is set and is set to 1.
if [ ! -z ${directadmin_custom_config_ftp} ] && [ ${directadmin_custom_config_ftp} = "1" ]
	then
		cp "${installdir}/files/ftp_upload.php" /usr/local/directadmin/scripts/custom/
		cp "${installdir}/files/ftp_download.php" /usr/local/directadmin/scripts/custom/
		cp "${installdir}/files/ftp_list.php" /usr/local/directadmin/scripts/custom/
		chmod 700 /usr/local/directadmin/scripts/custom/ftp_upload.php
		chmod 700 /usr/local/directadmin/scripts/custom/ftp_download.php
		chmod 700 /usr/local/directadmin/scripts/custom/ftp_list.php
		chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_upload.php
		chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_download.php
		chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_list.php
fi

# Clear the screen and display the login data.
clear
. /usr/local/directadmin/scripts/setup.txt
onetimelogin=`/usr/local/directadmin/directadmin --create-login-url user=$directadmin_admin_username`
echo "Hostname: $serverhostname"
echo "Admin account username: $adminname"
echo "Admin account password: $adminpass"
echo "One-Time login URL: $onetimelogin"

exit 0
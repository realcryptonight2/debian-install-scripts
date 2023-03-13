#!/bin/bash

installdir=$(pwd)
log_file="${installdir}/install.log"
echo "Installing DirectAdmin..." >> $log_file

# Check if the config file exist.
if [ ! -f "config.cnf" ];
then
	echo "Failed to install DirectAdmin." >> $log_file
	echo "config.cnf does not exist." >> $log_file
	echo "Failed to install DirectAdmin."
	echo "config.cnf does not exist."
	exit 1
fi

. ./config.cnf

userid=`id -u`

# Check if the script is run by the root user.
if [ "$userid" -ne 0 ]
  then
	echo "Failed to install DirectAdmin." >> $log_file
	echo "Install script was not called by root." >> $log_file
	echo "Please only run this script as root."
	echo "Users are not allowed to run this script."
	exit 1
fi

# Check if a license key is provided in the config file.
if [ -z "$directadmin_setup_license_key" ] && [ "${#directadmin_setup_admin_username}" -gt 10 ]
  then
	echo "Failed to install DirectAdmin." >> $log_file
	echo "directadmin_setup_license_key variable is not correctly defined in config.cnf." >> $log_file
	echo "directadmin_setup_license_key variable is not correctly defined in config.cnf."
	exit 1
fi

# Run the default install.
chmod 755 setup-standard.sh
./setup-standard.sh

echo "Installing git, curl, dnsutils, rclone, zip, unzip with apt..." >> $log_file

# Run the install commands that install the packages required for this script and DirectAdmin.
apt update
apt -y upgrade
apt -y install git curl dnsutils rclone zip unzip

echo "Installed git, curl, dnsutils, rclone, zip, unzip with apt." >> $log_file
echo "Setting all variables for directadmin install script..." >> $log_file

# Get the hostname and domain name for NS records.
serverip=$(hostname -I | awk '{print $1}')
serverhostname=$(dig -x $serverip +short | sed 's/\.[^.]*$//')
domainhostname=$(echo $serverhostname | sed 's/^[^.]*.//g')
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

# Set variables to let DirectAdmin install correctly.
export DA_CHANNEL=stable
if [ ! -z "${directadmin_setup_admin_username}" ] && [ ! "${#directadmin_setup_admin_username}" -gt 10 ]
	then
		export DA_ADMIN_USER=$directadmin_setup_admin_username
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

echo "Set all variables for directadmin install script." >> $log_file
echo "Downloading install script from download.directadmin.com..." >> $log_file

wget -O directadmin.sh https://download.directadmin.com/setup.sh
chmod 755 directadmin.sh

echo "Downloaded install script from download.directadmin.com." >> $log_file
echo "Running install script from download.directadmin.com..." >> $log_file

./directadmin.sh $directadmin_setup_license_key

echo "Runned install script from download.directadmin.com." >> $log_file
echo "Changing CustomBuild settings..." >> $log_file

# Change some DirectAdmin settings that should be the default.
/usr/local/directadmin/directadmin config-set allow_backup_encryption 1
/usr/local/directadmin/directadmin config-set backup_ftp_md5 1
/usr/local/directadmin/directadmin config-set mail_sni 1
/usr/local/directadmin/directadmin set one_click_pma_login 1
echo "Changed CustomBuild settings." >> $log_file
echo "Applying changed CustomBuild settings..." >> $log_file
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
echo "Applied changed CustomBuild settings." >> $log_file

# Check if the custom ns script variable is set and is set to 1.
if [ ! -z "${directadmin_custom_config_ns}" ] && [ "${directadmin_custom_config_ns}" = "1" ]
	then
		echo "Adding custom NS config..." >> $log_file
		mkdir /usr/local/directadmin/data/templates/custom
		cp "${installdir}/files/dns_ns.conf" /usr/local/directadmin/data/templates/custom/
		chmod 644 /usr/local/directadmin/data/templates/custom/dns_ns.conf
		chown diradmin:diradmin /usr/local/directadmin/data/templates/custom/dns_ns.conf
		echo "Added custom NS config." >> $log_file
	else
		echo "Custom NS config not set in config. Skipping custom NS config." >> $log_file
fi

# Check if the custom mysql script variable is set and is set to 1.
if [ ! -z "${directadmin_custom_config_mysql}" ] && [ "${directadmin_custom_config_mysql}" = "1" ]
	then
		echo "Adding custom mysql script..." >> $log_file
		cp "${installdir}/files/mysql_update_cert.sh" /usr/local/directadmin/scripts/custom/
		chmod 755 /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
		chown root:root /usr/local/directadmin/scripts/custom/mysql_update_cert.sh
		echo "0 3	* * 1	root	/usr/local/directadmin/scripts/custom/mysql_update_cert.sh" >> /etc/crontab
		systemctl restart cron
		/usr/local/directadmin/scripts/custom/mysql_update_cert.sh
		echo "Added custom mysql script." >> $log_file
	else
		echo "Custom mysql script not set in config. Skipping custom mysql script." >> $log_file
fi

# Check if the custom ftp script variable is set and is set to 1.
if [ ! -z "${directadmin_custom_config_ftp}" ] && [ "${directadmin_custom_config_ftp}" = "1" ]
	then
		echo "Adding custom ftp scripts..." >> $log_file
		cp "${installdir}/files/ftp_upload.php" /usr/local/directadmin/scripts/custom/
		cp "${installdir}/files/ftp_download.php" /usr/local/directadmin/scripts/custom/
		cp "${installdir}/files/ftp_list.php" /usr/local/directadmin/scripts/custom/
		chmod 700 /usr/local/directadmin/scripts/custom/ftp_upload.php
		chmod 700 /usr/local/directadmin/scripts/custom/ftp_download.php
		chmod 700 /usr/local/directadmin/scripts/custom/ftp_list.php
		chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_upload.php
		chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_download.php
		chown diradmin:diradmin /usr/local/directadmin/scripts/custom/ftp_list.php
		echo "Added custom ftp scripts." >> $log_file
	else
		echo "Custom ftp scripts not set in config. Skipping custom mysql script." >> $log_file
fi

echo "Installed DirectAdmin." >> $log_file

. /usr/local/directadmin/scripts/setup.txt
onetimelogin=`/usr/local/directadmin/directadmin --create-login-url user=$directadmin_setup_admin_username`

# Check if the headless install email address variable is set.
if [ ! -z "${directadmin_setup_headless_email}" ]
	then
		echo "Headless install is set. Sending email with login data..." >> $log_file
		echo "{\"hostname\" : \"$serverhostname\", \"admin_username\" : \"$adminname\", \"admin_password\" : \"$adminpass\", \"login_url\" : \"$onetimelogin\", \"headless_email\" : \"$directadmin_setup_headless_email\"}" > "${installdir}/files/login.json"
		composer require phpmailer/phpmailer --no-interaction
		php "${installdir}/files/mailer.php"
		#rm "${installdir}/files/login.json"
		echo "Headless install is set. Email with login data has been send." >> $log_file
	else
		echo "Headless install is not set." >> $log_file
		clear
		echo "Hostname: $serverhostname"
		echo "Admin account username: $adminname"
		echo "Admin account password: $adminpass"
		echo "One-Time login URL: $onetimelogin"
fi

exit 0
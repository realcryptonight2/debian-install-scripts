#!/bin/bash

installdir=$(pwd)
log_file="/root/install.log"

# Check if the config file exist.
if [ ! -f "config.cnf" ];
then
	echo "Failed to install DirectAdmin." >> $log_file
	echo "config.cnf does not exist." >> $log_file
	exit 1
fi

. ./config.cnf

# Check if the config file contains the DirectAdmin license key.
if [ -z "${directadmin_setup_license_key}" ]
	then
		echo "Failed to install DirectAdmin." >> $log_file
		echo "No DirectAdmin license key was set in the config.cnf file." >> $log_file
		exit 1
fi

# Check if there is a headless email.
if [ -z "${directadmin_setup_headless_email}" ]
	then
		echo "Failed to install DirectAdmin." >> $log_file
		echo "No headless email was set in the config.cnf file." >> $log_file
		exit 1
fi

# Get the hostname and domain name for NS records.
serverip=$(hostname -I | awk '{print $1}')
serverhostname=$(dig -x $serverip +short | sed 's/\.[^.]*$//')
domainhostname=$(echo $serverhostname | sed 's/^[^.]*.//g')
ns1host="ns1.${domainhostname}"
ns2host="ns2.${domainhostname}"

# Set variables to let DirectAdmin install correctly.
if [ ! -z "${directadmin_setup_admin_username}" ] && [ ! "${#directadmin_setup_admin_username}" -gt 10 ]
	then
		export DA_ADMIN_USER=$directadmin_setup_admin_username
fi
export DA_HOSTNAME=$serverhostname
export DA_NS1=$ns1host
export DA_NS2=$ns2host
export DA_CHANNEL=stable
export DA_FOREGROUND_CUSTOMBUILD=yes
export mysql_inst=mysql
export mysql=8.0
export php1_release=8.2
export php2_release=8.1
export php1_mode=php-fpm
export php2_mode=php-fpm

# Download and install DirectAdmin.
wget -O directadmin.sh https://download.directadmin.com/setup.sh
chmod 755 directadmin.sh
./directadmin.sh $directadmin_setup_license_key  >> $log_file

# Change some DirectAdmin settings that should be the default.
/usr/local/directadmin/directadmin config-set allow_backup_encryption 1 >> $log_file
/usr/local/directadmin/directadmin config-set backup_ftp_md5 1 >> $log_file
/usr/local/directadmin/directadmin config-set mail_sni 1 >> $log_file
/usr/local/directadmin/directadmin set one_click_pma_login 1 >> $log_file

systemctl restart directadmin >> $log_file

/usr/local/directadmin/custombuild/build clean >> $log_file
/usr/local/directadmin/custombuild/build update >> $log_file
/usr/local/directadmin/custombuild/build set eximconf yes >> $log_file
/usr/local/directadmin/custombuild/build set dovecot_conf yes >> $log_file
/usr/local/directadmin/custombuild/build set_php "imagick" yes >> $log_files
/usr/local/directadmin/custombuild/build exim_conf >> $log_file
/usr/local/directadmin/custombuild/build dovecot_conf >> $log_file
/usr/local/directadmin/custombuild/build phpmyadmin >> $log_file
/usr/local/directadmin/custombuild/build composer >> $log_file
/usr/local/directadmin/custombuild/build wp >> $log_file
echo "action=rewrite&value=mail_sni" >> /usr/local/directadmin/data/task.queue
/usr/local/directadmin/custombuild/build "php_imagick" >> $log_file

# Check if there is a custom FTP script that needs to be installed.
if [ -f "${installdir}/files/ftp_upload.php" ] && [ -f "${installdir}/files/ftp_download.php" ] && [ -f "${installdir}/files/ftp_list.php" ];
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
	echo "Custom FTP script is installed."  >> $log_file
else
	echo "No Custom FTP script provided. Skipping..."
fi

# Check if there is a custom DNS file that needs to be used.
if [ -f "${installdir}/files/dns_ns.conf" ];
then
	mkdir /usr/local/directadmin/data/templates/custom
	cp "${installdir}/files/dns_ns.conf" /usr/local/directadmin/data/templates/custom/
	chmod 644 /usr/local/directadmin/data/templates/custom/dns_ns.conf
	chown diradmin:diradmin /usr/local/directadmin/data/templates/custom/dns_ns.conf
	echo "Custom NameServer config is installed."  >> $log_file
else
	echo "No Custom NameServer config is provided. Skipping..."  >> $log_file
fi

. /usr/local/directadmin/scripts/setup.txt
onetimelogin=`/usr/local/directadmin/directadmin --create-login-url user=$directadmin_setup_admin_username`

echo "{\"hostname\" : \"$serverhostname\", \"admin_username\" : \"$adminname\", \"admin_password\" : \"$adminpass\", \"login_url\" : \"$onetimelogin\", \"headless_email\" : \"$directadmin_setup_headless_email\"}" > "${installdir}/files/login.json"
/usr/local/bin/php -f "${installdir}/files/mailer.php"
rm "${installdir}/files/login.json"

exit 0
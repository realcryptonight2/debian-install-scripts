#!/bin/bash

CURL=/usr/local/bin/curl
if [ ! -e ${CURL} ]; then
	CURL=/usr/bin/curl
fi
RCLONE=/usr/bin/rclone
TMPDIR=/home/tmp
PORT=${ftp_port}
FTPS=0
if [ "${ftp_secure}" = "ftps" ]; then
	FTPS=1
fi
SHOW_BYTES=0
if [ "${ftp_show_bytes}" = "yes" ]; then
	SHOW_BYTES=1
fi
SSL_REQD=""
if ${CURL} --help tls | grep -m1 -q 'ftp-ssl-reqd'; then
    SSL_REQD="--ftp-ssl-reqd"
elif ${CURL} --help tls | grep -m1 -q 'ssl-reqd'; then
    SSL_REQD="--ssl-reqd"
fi

if [ "$FTPS" = "0" ]; then
	SSL_REQD=
fi

if [ "$PORT" = "" ]; then
	PORT=21
fi

RANDNUM=`/usr/local/bin/php -r 'echo rand(0,10000);'`
#we need some level of uniqueness, this is an unlikely fallback.
if [ "$RANDNUM" = "" ]; then
        RANDNUM=$ftp_ip;
fi

CFG=$TMPDIR/$RANDNUM.cfg
rm -f $CFG
touch $CFG
chmod 600 $CFG

DUMP=$TMPDIR/$RANDNUM.dump
rm -f $DUMP
touch $DUMP
chmod 600 $DUMP

#######################################################
# FTP
list_files()
{
	if [ ! -e ${CURL} ]; then
		echo "";
		echo "*** Unable to get list ***";
		echo "Please install curl by running:";
		echo "";
		echo "cd /usr/local/directadmin/custombuild";
		echo "./build curl";
		echo "";
		exit 10;
	fi

	#double leading slash required, because the first one doesn't count.
	#2nd leading slash makes the path absolute, in case the login is not chrooted.
	#without double forward slashes, the path is relative to the login location, which might not be correct.
	ftp_path="/${ftp_path}"

	/bin/echo "user =  \"$ftp_username:$ftp_password_esc_double_quote\"" >> $CFG

	${CURL} --config ${CFG} ${SSL_REQD} -k --silent --show-error ftp://$ftp_ip:${PORT}$ftp_path/ > ${DUMP} 2>&1
	RET=$?

	if [ "$RET" -ne 0 ]; then
		echo "${CURL} returned error code $RET";
		cat $DUMP
	else
		COLS=`awk '{print NF; exit}' $DUMP`
		if [ "${SHOW_BYTES}" = "1" ] && [ "${COLS}" = "9" ]; then
			cat $DUMP | grep -v -e '^d' | awk "{ print \$${COLS} \"=\" \$5; }"
		else
			cat $DUMP | grep -v -e '^d' | awk "{ print \$${COLS}; }"
		fi
	fi
}

#######################################################
# Object Storage via rclone
list_object_storage()
{
	if [ ! -e ${RCLONE} ]; then
		echo "";
		echo "*** Unable to get list ***";
		echo "Please install rclone by running:";
		echo "";
		echo "sudo -v ; curl https://rclone.org/install.sh | sudo bash";
		echo "";
		exit 10;
	fi
	
	#rclone command here
	rclone --config "/home/${ftp_password_esc_double_quote}/.config/rclone/rclone.conf" lsf --format "p" --files-only $ftp_username$ftp_path
	RET=$?

	if [ "$RET" -ne 0 ]; then
		echo "${RCLONE} returned error code $RET";
		cat $DUMP
	else
		cat $DUMP | grep -v -e '^d'
	fi
}

#######################################################
# Start

if [ "${PORT}" = "443" ]; then
	list_object_storage
else
	list_files
fi

rm -f $CFG
rm -f $DUMP

exit $RET

#!/bin/bash

# Original script created by: DirectAdmin
# Modified by: realcryptonight


VERSION=1.2
CURL=/usr/local/bin/curl
if [ ! -e ${CURL} ]; then
		CURL=/usr/bin/curl
fi
RCLONE=/usr/bin/rclone
DU=/usr/bin/du
BC=/usr/bin/bc
EXPR=/usr/bin/expr
TOUCH=/bin/touch
PORT=${ftp_port}
FTPS=0

MD5=${ftp_md5}

if [ "${ftp_secure}" = "ftps" ]; then
	FTPS=1
fi

CURL_TLS_HELP=$(${CURL} --help tls)
CURL_VERSION=$(${CURL} --version | head -n 1 | cut -d ' ' -f 2)
int_version() {
	local major minor patch
	major=$(cut -d . -f 1 <<< "$1")
	minor=$(cut -d . -f 2 <<< "$1")
	patch=$(cut -d . -f 3 <<< "$1")
	printf "%03d%03d%03d" "${major}" "${minor}" "${patch}"
}

SSL_ARGS=""
if grep -q 'ftp-ssl-reqd' <<< "${CURL_TLS_HELP}"; then
    SSL_ARGS="${SSL_ARGS} --ftp-ssl-reqd"
elif grep -q 'ssl-reqd' <<< "${CURL_TLS_HELP}"; then
    SSL_ARGS="${SSL_ARGS} --ssl-reqd"
fi
if grep -q 'Use TLSv1.1 or greater' <<< "${CURL_TLS_HELP}"; then
	SSL_ARGS="${SSL_ARGS} --tlsv1.1"
fi

# curl 7.78.0 fixed FTP upload TLS 1.3 bug, we add `--tls-max 1.2` for older
# versions.
if [ "$(int_version "${CURL_VERSION}")" -lt "$(int_version '7.78.0')" ] && grep -q 'tls-max' <<< "${CURL_TLS_HELP}"; then
	SSL_ARGS="${SSL_ARGS} --tls-max 1.2"
fi

#######################################################
# SETUP

if [ ! -e $TOUCH ] && [ -e /usr/bin/touch ]; then
	TOUCH=/usr/bin/touch
fi
if [ ! -x ${EXPR} ] && [ -x /bin/expr ]; then
	EXPR=/bin/expr
fi

if [ ! -e "${ftp_local_file}" ]; then
	echo "Cannot find backup file ${ftp_local_file} to upload";

	/bin/ls -la ${ftp_local_path}

	/bin/df -h

	exit 11;
fi

get_md5() {
	MF=$1

	MD5SUM=/usr/bin/md5sum
	if [ ! -x ${MD5SUM} ]; then
		return
	fi

	if [ ! -e ${MF} ]; then
		return
	fi

	FMD5=`$MD5SUM $MF | cut -d\  -f1`

	echo "${FMD5}"
}

#######################################################

CFG=${ftp_local_file}.cfg
/bin/rm -f $CFG
$TOUCH $CFG
/bin/chmod 600 $CFG

RET=0;

#######################################################
# FTP
upload_file_ftp()
{
        if [ ! -e ${CURL} ]; then
                echo "";
                echo "*** Backup not uploaded ***";
                echo "Please install curl by running:";
                echo "";
                echo "cd /usr/local/directadmin/custombuild";
                echo "./build curl";
                echo "";
                exit 10;
        fi

        /bin/echo "user =  \"$ftp_username:$ftp_password_esc_double_quote\"" >> $CFG

        if [ ! -s ${CFG} ]; then
                echo "${CFG} is empty. curl is not going to be happy about it.";
                ls -la ${CFG}
                ls -la ${ftp_local_file}
                df -h
        fi

        #ensure ftp_path ends with /
        ENDS_WITH_SLASH=`echo "$ftp_path" | grep -c '/$'`
        if [ "${ENDS_WITH_SLASH}" -eq 0 ]; then
                ftp_path=${ftp_path}/
        fi

        ${CURL} --config ${CFG} --silent --show-error --ftp-create-dirs --upload-file $ftp_local_file  ftp://$ftp_ip:${PORT}/$ftp_path$ftp_remote_file 2>&1
        RET=$?

        if [ "${RET}" -ne 0 ]; then
                echo "curl return code: $RET";
        fi
}

#######################################################
# FTPS
upload_file_ftps()
{
	if [ ! -e ${CURL} ]; then
		echo "";
		echo "*** Backup not uploaded ***";
		echo "Please install curl by running:";
		echo "";
		echo "cd /usr/local/directadmin/custombuild";
		echo "./build curl";
		echo "";
		exit 10;
	fi

	/bin/echo "user =  \"$ftp_username:$ftp_password_esc_double_quote\"" >> $CFG

	if [ ! -s ${CFG} ]; then
		echo "${CFG} is empty. curl is not going to be happy about it.";
		ls -la ${CFG}
		ls -la ${ftp_local_file}
		df -h
	fi

	#ensure ftp_path ends with /
	ENDS_WITH_SLASH=`echo "$ftp_path" | grep -c '/$'`
	if [ "${ENDS_WITH_SLASH}" -eq 0 ]; then
		ftp_path=${ftp_path}/
	fi

	${CURL} --config ${CFG} ${SSL_ARGS} -k --silent --show-error --ftp-create-dirs --upload-file $ftp_remote_file  ftp://$ftp_ip:${PORT}/$ftp_path$ftp_remote_file 2>&1
	RET=$?

	if [ "${RET}" -ne 0 ]; then
		echo "curl return code: $RET";
	fi
}

#######################################################
# Object Storage via rsync
upload_file_object_storage()
{
	if [ ! -e ${RCLONE} ]; then
		echo "";
		echo "*** Backup not uploaded ***";
		echo "Please install rclone by running:";
		echo "";
		echo "sudo -v ; curl https://rclone.org/install.sh | sudo bash";
		echo "";
		exit 10;
	fi
	
	rclone --config "/home/${ftp_password_esc_double_quote}/.config/rclone/rclone.conf" copy $ftp_local_file $ftp_username$ftp_path
	RET=$?
	
	if [ "${RET}" -ne 0 ]; then
		echo "rclone return code: $RET";
	fi
}

#######################################################
# Start

if [ "${PORT}" = "443" ]; then
	upload_file_object_storage
else
	if [ "${FTPS}" = "1" ]; then
		upload_file_ftps
	else
		upload_file_ftp
	fi
fi

if [ "${RET}" = "0" ] && [ "${MD5}" = "1" ]; then
	MD5_FILE=${ftp_local_file}.md5
	M=`get_md5 ${ftp_local_file}`
	if [ "${M}" != "" ]; then
		echo "${M}" > ${MD5_FILE}

		ftp_local_file=${MD5_FILE}
		ftp_remote_file=${ftp_remote_file}.md5
		
		if [ "${PORT}" = "443" ]; then
			upload_file_object_storage
		else
			if [ "${FTPS}" = "1" ]; then
				upload_file_ftps
			else
				upload_file
			fi
		fi
	fi
fi

/bin/rm -f $CFG

exit $RET


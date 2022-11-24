#!/bin/sh

le_cert_sum=`md5sum /usr/local/directadmin/conf/cacert.pem | awk '{ print $1 }'`
le_ca_sum=`md5sum /usr/local/directadmin/conf/carootcert.pem | awk '{ print $1 }'`
le_key_sum=`md5sum /usr/local/directadmin/conf/cakey.pem | awk '{ print $1 }'`

mysql_cert_sum=`md5sum /var/lib/mysql/server-cert.pem | awk '{ print $1 }'`
mysql_ca_sum=`md5sum /var/lib/mysql/ca.pem | awk '{ print $1 }'`
mysql_key_sum=`md5sum /var/lib/mysql/server-key.pem | awk '{ print $1 }'`

is_updated=0

if [ "$le_cert_sum" != "$mysql_cert_sum" ];
then
    echo "LE cert does not match MySQL cert"
	cp /usr/local/directadmin/conf/cacert.pem /var/lib/mysql/server-cert.pem
	is_updated=1
fi

if [ "$le_ca_sum" != "$mysql_ca_sum" ];
then
    echo "LE CA cert does not match MySQL CA cert"
	cp /usr/local/directadmin/conf/carootcert.pem /var/lib/mysql/ca.pem
	is_updated=1
fi

if [ "$le_key_sum" != "$mysql_key_sum" ];
then
    echo "LE key does not match MySQL key"
	cp /usr/local/directadmin/conf/cakey.pem /var/lib/mysql/server-key.pem
	is_updated=1
fi

if [ "$is_updated" == 1 ];
then
    systemctl restart mysqld.service
fi
exit 0
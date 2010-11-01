#!/bin/bash
# 1H - hawk_install.sh		                        Copyright(c) 2010 1H Ltd.
#                                                        All rights Reserved.
# copyright@1h.com                                              http://1h.com
# This code is subject to the 1H license. Unauthorized copying is prohibited.

VERSION='0.0.5'

# Various paths
syspath='/home/1h'
conf="$syspath/etc/hawk.conf"
db="$syspath/db/hawk.sql"
# Define the PGSQL cpustats user and generate new password for it
user="hawk_local"
dbname="hawk"
pass=$(head -n 5 /dev/urandom  | md5sum  | cut -d " " -f1)

if ( ! /usr/local/1h/bin/dns_setup.sh ); then
	echo "[!] Failed to setup the 1h dns zone"
	exit 1      
fi      
if ( ! /usr/local/1h/bin/add_1h_vhost.sh ); then
	echo "[!] failed to add the 1h vhost to the httpd.conf"
	exit 1
fi

if ( ! /usr/local/1h/bin/hawk_config.sh ); then
	echo "[!] hawk_config.sh failed"
	exit 1
fi

su - postgres -c "psql -Upostgres template1 -c \"drop database $dbname\""
su - postgres -c "psql -Upostgres template1 -c \"drop user $user\""

if ( ! su - postgres -c "psql -Upostgres -c \"CREATE USER $user PASSWORD '$pass'\" template1" ); then
    echo "[!] Failed to create user $user"
    exit 1
fi

if ( ! su - postgres -c "psql -Upostgres -c \"CREATE DATABASE $dbname OWNER $user\" template1" ); then
    echo "[!] Failed to create database $dbname with owner $user"
    exit 1
fi

if ( ! sed -i "/^dbpass/s/=.*/=$pass/" $conf ); then
    echo "Failed to add the new host $host to $conf"
    exit 1
fi

if [ ! -f /root/.pgpass ]; then
    touch /root/.pgpass
    chmod 600 /root/.pgpass
fi

if ( ! sed -i "/:$dbname:$user:/D" /root/.pgpass ); then
    echo "[!] Failed to clean $user from /root/.pgpass"
    exit 1
fi

if ( ! echo "*:*:$dbname:$user:$pass" >> /root/.pgpass ); then
    echo "[!] Failed to add the new records to /root/.pgpass"
    exit 1
fi

if ( ! cat $db | su - postgres -c "psql -Upostgres $dbname" ); then
    echo "[!] psql -Upostgres -f $db $dbname FAILED"
    exit 1
fi

if ( ! grep hawk-unblock.sh /var/spool/cron/root ); then
    if ( ! chattr -ia /var/spool/cron/root ); then
        echo "[!] chattr -ia /var/spool/cron/root FAILED"
        exit 1
    fi
    if ( ! echo '*/5 * * * * /usr/local/1h/bin/hawk-unblock.sh >> /usr/local/1h/var/log/hawk-unblock.log 2>&1' >> /var/spool/cron/root ); then
        echo "[!] Failed to add hawk-unblock.sh to the root cron"
        exit 1
    fi
fi

if [ -d /usr/local/1h/lib/guardian/svcstop ]; then
	touch /usr/local/1h/lib/guardian/svcstop/crond
fi

if ( ! /etc/init.d/crond restart ); then
	echo "/etc/init.d/crond restart failed"
	exit 1
fi
rm -f /usr/local/1h/lib/guardian/svcstop/crond

if [ ! -f /var/lib/pgsql/data/pg_hba.conf ]; then
    echo "/var/lib/pgsql/data/pg_hba.conf is missing"
    exit 1
fi

if ( ! cat /var/lib/pgsql/data/pg_hba.conf | grep -v ^$ | grep -v '\#' | awk '{print $3}' | grep ^$user$ ); then
    psql_conf="local $dbname $user md5\nhost $dbname $user 127.0.0.1 255.255.255.255 md5"
    if ( ! sed -i "1i$psql_conf" /var/lib/pgsql/data/pg_hba.conf ); then
        echo "[!] Failed to add the new psql config options to /var/lib/pgsql/data/pg_hba.conf"
        exit 1
    fi
    if ( ! /etc/init.d/postgresql reload ); then
        echo "[!] Failed to /etc/init.d/postgresql reload"
        exit 1
    fi
fi

/usr/local/cpanel/etc/init/stopcphulkd

if ( ! rm -rf /var/cpanel/cphulk_enable ); then
	echo "[!] rm -rf /var/cpanel/cphulk_enable FAILED"
	exit 1
fi

#if [ -f $etc_dir/portal.conf ]; then
#	. $etc_dir/portal.conf
#	if ( ! sed -i "/window.location/s/'http.*\/\/.*'/'https:\/\/$portalmaster_url\/portal\/'/" /home/$system_user/api/cgi-bin/hawk/js/hawk.js ); then
#		echo "Failed to set the correct link to the master interface but this is not fatal"
#	fi
#fi
if ( ! /usr/local/1h/bin/lockit.sh hawk ); then
	echo "[!] Failed to password protect the web folder with /usr/local/1h/bin/lockit.sh hawk"
	exit 1
fi

if ( ! chkconfig --add hawk ); then
    echo "chkconfig --add hawk FAILED"
    exit 1
fi

if ( ! chkconfig hawk on ); then
    echo "chkconfig hawk on FAILED"
    exit 1
fi

if [ -d /usr/local/1h/lib/guardian/svcstop ]; then
	touch /usr/local/1h/lib/guardian/svcstop/hawk
fi

if ( ! /etc/init.d/hawk restart ); then
   echo "/etc/init.d/hawk restart FAILED"
   exit 1
fi

rm -rf /usr/local/1h/lib/guardian/svcstop/hawk


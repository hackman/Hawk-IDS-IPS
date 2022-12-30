#!/bin/bash
# hawk_install.sh		           Copyright(c) Marian Marinov <mm@yuhu.biz>
# This code is subject to the GPLv2 license.

VERSION='0.1.4'

# Various paths
syspath='/var/lib/hawk'
conf="/etc/hawk.conf"
db="$syspath/db/hawk.sql"
# Define the PGSQL cpustats user and generate new password for it
user="hawk_local"
dbname="hawk"
pass=$(head -n 5 /dev/urandom  | md5sum  | cut -d " " -f1)
pgsql_data=/var/lib/pgsql/data

if ( ! /var/lib/hawk/bin/hawk_config.sh ); then
	echo "[!] hawk_config.sh failed"
	exit 1
fi

if [[ ! -d /var/log/hawk ]]; then
	mkdir -p /var/log/hawk
fi

# Test the connection here please
if ( ! su - postgres -c "if ( ! psql -Upostgres template1 -c 'select 1+1;' ); then exit 1; fi" ); then
    echo "Failed to test the connection to the postgresql database"
    exit 1
fi

# Create the DB user only if it does not exist already
if su - postgres -c "if psql -t -Upostgres -c '\du'|grep -q $user; then exit 1; fi"; then
	if ( ! su - postgres -c "psql -Upostgres -c \"CREATE USER $user PASSWORD '$pass'\" template1" ); then
		echo "[!] Failed to create user $user"
	    exit 1
	fi
else
	# Change the password of the user, so we can update the config
	su - postgres -c "psql -Upostgres -c \"ALTER ROLE $user WITH PASSWORD '$pass'\""
fi

# Create the DB only if does not exist already
if su - postgres -c "psql -t -Upostgres -c '\l'|grep -q $dbname"; then
	# make sure that this user is owning the DB
	info=($(su - postgres -c "psql -t -F ' ' -q -A -Upostgres -t -c '\l'"|awk "\$1~/^$dbname$/{print \$1,\$2}"))
	if [[ ${info[0]} == $dbname ]] then
		if [[ ${info[1]} != $user ]]; then
			su - postgres -c "psql -c \"ALTER DATABASE $dbname OWNER TO $user\""
		fi
	else
		echo "[!] unable to validate DB name and OWNER"
	fi
else
	if ( ! su - postgres -c "psql -Upostgres -c \"CREATE DATABASE $dbname OWNER $user\" template1" ); then
	    echo "[!] Failed to create database $dbname with owner $user"
	    exit 1
	fi
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

if [ ! -f /var/spool/cron/root ] || ( ! grep hawk-unblock.sh /var/spool/cron/root ); then
	if [ -f /var/spool/cron/root ]; then
	    if ( ! chattr -ia /var/spool/cron/root ); then
	        echo "[!] chattr -ia /var/spool/cron/root FAILED"
	        exit 1
	    fi
	fi
    if ( ! echo '*/5 * * * * /var/lib/hawk/bin/hawk-unblock.sh >> /var/log/hawk/unblock.log 2>&1' >> /var/spool/cron/root ); then
        echo "[!] Failed to add hawk-unblock.sh to the root cron"
        exit 1
    fi
fi

if [ -x /etc/init.d/crond ] && ( ! /etc/init.d/crond restart ); then
	echo "/etc/init.d/crond restart failed"
	exit 1
fi

if [ ! -f $pgsql_data/pg_hba.conf ]; then
    echo "$pgsql_data/pg_hba.conf is missing"
    exit 1
fi

if ( ! cat $pgsql_data/pg_hba.conf | grep -v ^$ | grep -v '\#' | awk '{print $3}' | grep ^$user$ ); then
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

if [ -x /usr/local/cpanel/etc/init/stopcphulkd ]; then
	/usr/local/cpanel/etc/init/stopcphulkd
	if ( ! rm -rf /var/cpanel/cphulk_enable ); then
		echo "[!] rm -rf /var/cpanel/cphulk_enable FAILED"
		exit 1
	fi
fi

if ( ! /var/lib/hawk/bin/lockit.sh hawk ); then
	echo "[!] Failed to password protect the web folder with /var/lib/hawk/bin/lockit.sh hawk"
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

if ( ! /etc/init.d/hawk restart ); then
   echo "/etc/init.d/hawk restart FAILED"
   exit 1
fi

exit 0

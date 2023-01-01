#!/bin/bash
# hawk_install.sh		           Copyright(c) Marian Marinov <mm@yuhu.biz>
# This code is subject to the GPLv2 license.

VERSION='0.2'

# Various paths
syspath='/var/lib/hawk'
conf="/etc/hawk.conf"

if ( ! /var/lib/hawk/bin/hawk_config.sh ); then
	echo "[!] hawk_config.sh failed"
	exit 1
fi

if [[ ! -d /var/log/hawk ]]; then
	mkdir -p /var/log/hawk
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

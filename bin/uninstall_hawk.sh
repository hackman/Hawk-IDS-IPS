#!/bin/bash
# Hawk uninstall                               Copyright(c) Marian Marinov <mm@yuhu.biz>
# This code is subject to the GPLv2 license.

VERSION='0.0.5'

function check_err() {
	if [ "$1" != 0 ]; then
		echo "Error: $2"
		exit 1
	fi
}

function warn_err() {
	if [ "$1" != 0 ]; then
		echo "Warn: $2"
	fi
}

function drop_user() {
	if [ -f /root/.pgpass ]; then
		sed -i "/.*[^\\]:.*[^\\]:.*[^\\]:$1:/D" /root/.pgpass
		if [ "$?" != 0 ]; then
			echo "removing $1 from /root/.pgpass failed"
			return 1
		fi
	fi

	# clean /var/lib/psql/data/pg_hba.conf
	sed -i "/[ \t]*\w\+[ \t]\+\w\+[ \t]\+$1[ \t]/D" /var/lib/pgsql/data/pg_hba.conf
	if [ "$?" != 0 ]; then
		echo "failed to remove entries for user $1 from /var/lib/pgsql/data/pg_hba.conf"
		return 1
	fi
	su - postgres -c "psql -Upostgres -c 'DROP USER $1;' template1"
	if [ "$?" != 0 ]; then
		echo "failed to drop PostgreSQL user $1"
		return 1
	fi
	return 0
}

function drop_db() {
	su - postgres -c "psql -Upostgres -c 'DROP DATABASE $1;' template1"
	if [ "$?" != 0 ]; then
		echo "failed to drop database $1"
		return 1
	fi
	return 0
}

function reload_pg() {
	if [ -x /etc/init.d/postgresql ]; then
		return 1
	fi
	/etc/init.d/postgresql reload
	if [ "$?" != 0 ]; then
		echo "failed to reload postgresql configuration"
		return 1
	fi
	return 0
}

drop_db hawk
drop_user hawk_local
reload_pg

if [ -f /usr/local/1h/etc/guardian.conf ]; then
	sed -i "/^check_services=/s/hawk//g" /usr/local/1h/etc/guardian.conf
	warn_err $? "Could not exclude hawk from guardian check_services"
	sed -i "/^check_services=/s/,,/,/g" /usr/local/1h/etc/guardian.conf
	sed -i "/^check_services/s/=,/=/g" /usr/local/1h/etc/guardian.conf
	sed -i "/^check_services=/s/,$//g" /usr/local/1h/etc/guardian.conf

	/etc/init.d/guardian restart
	warn_err $? "Could not restart guardian"
fi

/etc/init.d/hawk stop
warn_err $? "Could not stop Hawk daemon"

rm -f /usr/local/1h/var/run/hawk* /usr/local/1h/var/log/hawk*
warn_err $? "Could not remove pidfile and logfile"

if [ -f /var/spool/cron/root ]; then
	chattr -ai /var/spool/cron/root
	warn_err $? "Could not chattr -ai /var/spool/cron/root"

	sed -i '/usr\/local\/1h\/bin\/hawk-unblock.sh/D' /var/spool/cron/root
	warn_err $? "Could not remove hawk-unblock.sh from crontab"
fi

if [ -x /etc/init.d/crond ]; then
	# restart crond
	if [ -d /usr/local/1h/lib/guardian/svcstop ]; then
		touch /usr/local/1h/lib/guardian/svcstop/crond
	fi

	if ( ! /etc/init.d/crond restart ); then
		echo "/etc/init.d/crond restart failed"
		exit 1
	fi

	rm -f /usr/local/1h/lib/guardian/svcstop/crond
fi

if [ -f /home/1h/public_html/index.html ]; then
	sed -i '/hawk/D' /home/1h/public_html/index.html
fi

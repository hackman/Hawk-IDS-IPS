#!/bin/bash
# 1H - Hawk uninstall                               Copyright(c) 2010 1H Ltd.
#                                                        All rights Reserved.
# copyright@1h.com                                              http://1h.com
# This code is subject to the 1H license. Unauthorized copying is prohibited.

. /usr/loacal/1h/lib/sh/uninstall_funcs.sh

drop_db hawk
drop_user hawk_local
reload_pg

if [ -f /usr/local/1h/etc/guardian.conf ]; then
	sed -i "/^check_services=/s/hawk//g" /usr/local/1h/etc/guardian.conf
	warn_err $? "Could not exclude hawk from guardian check_services"
	sed -i "/^check_services=/s/,,/,/g" /usr/local/1h/etc/guardian.conf

	/etc/init.d/guardian restart
	warn_err $? "Could not restart guardian"
fi

/etc/init.d/hawk stop
warn_err $? "Could not stop Hawk daemon"

rm -f /usr/local/1h/var/run/hawk* /usr/local/1h/var/log/hawk*
warn_err $? "Could not remove pidfile and logfile"

chattr -ai /var/spool/cron/root
warn_err $? "Could not chattr -ai /var/spool/cron/root"

sed -i '/usr\/local\/1h\/bin\/hawk-unblock.sh/D' /var/spool/cron/root
warn_err $? "Could not remove hawk-unblock.sh from crontab"

# restart crond
if [ -d /usr/local/1h/lib/guardian/svcstop ]; then
	touch /usr/local/1h/lib/guardian/svcstop/crond
fi

if ( ! /etc/init.d/crond restart ); then
	echo "/etc/init.d/crond restart failed"
	exit 1
fi

rm -f /usr/local/1h/lib/guardian/svcstop/crond

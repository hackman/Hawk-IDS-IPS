#!/bin/bash
# 1H - hawk_config.sh		                        Copyright(c) 2010 1H Ltd.
#                                                        All rights Reserved.
# copyright@1h.com                                              http://1h.com
# This code is subject to the 1H license. Unauthorized copying is prohibited.

VERSION='0.0.2'

for ip in $(ip -4 -oneline addr list | sed 's/\/[0-9]\{1,2\}//' | awk '{print $4}'); do
	hawk_whitelist="$ip,$hawk_whitelist"
done
hawk_whitelist="${hawk_whitelist}${portalmaster_ip},"
sed -i "/block_whitelist/s/=.*/=$hawk_whitelist/" /home/1h/etc/hawk.conf

hawk_logs=""
mailserver=$(awk -F = '/mailserver=/{print $2}' /var/cpanel/cpanel.config)
if [ -z "$mailserver" ]; then
	echo "[!] No suitable mail servers found"
else
	if [ "$mailserver" == "courier" ]; then
		maillogs=$(grep 'mail.\*' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		sed -i -e '/watch_dovecot/s/=.*/=0/' -e '/watch_courier/s/=.*/=1/' /home/1h/etc/hawk.conf
	elif [ "$mailserver" == "dovecot" ]; then
		if ( grep log_path /etc/dovecot.conf | grep -v \# ); then
			maillogs=$(grep log_path /etc/dovecot.conf | grep -v \# | awk -F = '{print $2}')
		else
			maillogs=$(grep 'mail.\*' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		fi
		sed -i -e '/watch_dovecot/s/=.*/=1/' -e '/watch_courier/s/=.*/=0/' /home/1h/etc/hawk.conf
	else
		echo "[!] The mail server on this machine is not dovecot nor courier ..."
	fi
	if [ ! -z "$maillogs" ]; then
		echo "hawk_mailserver=$mailserver"
		for maillog in $maillogs; do
			hawk_logs="$maillog,$hawk_logs"
		done
	fi
fi

cplogs='/usr/local/cpanel/logs/access_log /usr/local/cpanel/logs/login_log'
for cplog in $cplogs; do
	if [ -f "$cplog" ]; then
		hawk_logs="$cplog,$hawk_logs"
		sed -i -e '/watch_cpanel/s/=.*/=1/' /home/1h/etc/hawk.conf
	fi
done

seclogs=$(grep 'authpriv.\*' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
for seclog in $seclogs; do
	hawk_logs="$seclog,$hawk_logs"
done

ftpserver=$(awk -F = '/ftpserver=/{print $2}' /var/cpanel/cpanel.config)
if [ ! -z "$ftpserver" ]; then
	if [ "$ftpserver" == "pure-ftpd" ]; then
		if ( grep SyslogFacility /etc/pure-ftpd.conf  | grep -v \# >> /dev/null ); then
			infologs=$(grep '\*.info' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		fi
		sed -i -e '/watch_pureftpd/s/=.*/=1/' -e '/watch_proftpd/s/=.*/=0/' /home/1h/etc/hawk.conf
	elif [[ "$ftpserver" =~ "pro" ]]; then
		infologs=$(grep '\*.info' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		sed -i -e '/watch_pureftpd/s/=.*/=0/' -e '/watch_proftpd/s/=.*/=1/' /home/1h/etc/hawk.conf
	else
		echo "[!] No suitable ftp server"
	fi
	if [ ! -z "$infologs" ]; then
		for infolog in $infologs; do
			hawk_logs="$infolog,$hawk_logs"
		done
		echo "hawk_ftpserver=$ftpserver"
	fi
fi

if [ -z "$hawk_logs" ]; then
	echo "[!] I was unable to find even a single logs which is quite strange. Nothing to monitor so good bye hawk"
	exit 1
fi
echo "All logs are $hawk_logs"
hawk_logs=$(echo $hawk_logs | sed 's/\//\\\//g')
sed -i "/monitor_list/s/=.*/=$hawk_logs/" /home/1h/etc/hawk.conf

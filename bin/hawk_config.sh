#!/bin/bash
# 1H - hawk_config.sh		                        Copyright(c) 2010 1H Ltd.
#                                                        All rights Reserved.
# copyright@1h.com                                              http://1h.com
# This code is subject to the 1H license. Unauthorized copying is prohibited.

VERSION='0.1.0'

for ip in $(ip -4 -oneline addr list | sed 's/\/[0-9]\{1,2\}//' | awk '{print $4}'); do
	hawk_whitelist="$ip,$hawk_whitelist"
done
hawk_whitelist="${hawk_whitelist}${portalmaster_ip},"
sed -i "/block_whitelist/s/=.*/=$hawk_whitelist/" /home/1h/etc/hawk.conf

hawk_logs=""

mailserver=''
if [ -f /var/cpanel/cpanel.config ]; then
	mailserver=$(awk -F = '/mailserver=/{print $2}' /var/cpanel/cpanel.config)
else
	if [ -f /etc/init.d/dovecot ]; then
		mailserver='dovecot'
	elif [ -f /etc/init.d/courier-imap ] && [ -f /etc/init.d/courier-authlib ]; then
		mailserver='courier'
	fi
fi

if [ -z "$mailserver" ]; then
	echo "[!] No suitable mail servers found"
else
	maillogs=''
	if [ "$mailserver" == "courier" ]; then
		if [ -f /etc/syslog.conf ]; then
			maillogs=$(grep 'mail.\*' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		fi
		sed -i -e '/watch_dovecot/s/=.*/=0/' -e '/watch_courier/s/=.*/=1/' /home/1h/etc/hawk.conf
	elif [ "$mailserver" == "dovecot" ]; then
		if [ -f /etc/dovecot.conf ] && ( grep log_path /etc/dovecot.conf | grep -v \# ); then
			maillogs=$(grep log_path /etc/dovecot.conf | grep -v \# | awk -F = '{print $2}')
		elif [ -f /etc/syslog.conf ]; then
			maillogs=$(grep 'mail.\*' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		fi
		sed -i -e '/watch_dovecot/s/=.*/=1/' -e '/watch_courier/s/=.*/=0/' /home/1h/etc/hawk.conf
	else
		echo "[!] The mail server on this machine is not dovecot nor courier ..."
	fi
	if [ ! -z "$maillogs" ]; then
		echo "hawk_mailserver=$mailserver"
		for maillog in $maillogs; do
			hawk_logs="$maillog $hawk_logs"
		done
	fi
fi

cplogs='/usr/local/cpanel/logs/access_log /usr/local/cpanel/logs/login_log'
for cplog in $cplogs; do
	if [ -f "$cplog" ]; then
		hawk_logs="$cplog $hawk_logs"
		sed -i -e '/watch_cpanel/s/=.*/=1/' /home/1h/etc/hawk.conf
	fi
done

seclogs=''
if [ -f /etc/syslog.conf ]; then
	seclogs=$(grep 'authpriv.\*' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
fi
for seclog in $seclogs; do
	if [ ! -f $seclog ]; then
		continue
	fi
	hawk_logs="$seclog $hawk_logs"
done

ftpserver=''
if [ -f /var/cpanel/cpanel.config ]; then
	ftpserver=$(awk -F = '/ftpserver=/{print $2}' /var/cpanel/cpanel.config)
elif [ -f /etc/init.d/proftpd ]; then
	ftpserver='pro'
elif [ -f /etc/init.d/pure-ftpd ]; then
	ftpserver='pure-ftpd'
fi
if [ ! -z "$ftpserver" ]; then
	if [ "$ftpserver" == "pure-ftpd" ]; then
		if [ -f /etc/pure-ftpd.conf ] && ( grep SyslogFacility /etc/pure-ftpd.conf  | grep -v \# >> /dev/null ); then
			infologs=$(grep '\*.info' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		fi
		sed -i -e '/watch_pureftpd/s/=.*/=1/' -e '/watch_proftpd/s/=.*/=0/' /home/1h/etc/hawk.conf
	elif [[ "$ftpserver" =~ "pro" ]]; then
		if [ -f /etc/syslog.conf ]; then
			infologs=$(grep '\*.info' /etc/syslog.conf | awk '{print $2}' | sed 's/-//g')
		fi
		sed -i -e '/watch_pureftpd/s/=.*/=0/' -e '/watch_proftpd/s/=.*/=1/' /home/1h/etc/hawk.conf
	else
		echo "[!] No suitable ftp server"
	fi
	if [ ! -z "$infologs" ]; then
		for infolog in $infologs; do
			if [ ! -f $infolog ]; then
				continue
			fi
			hawk_logs="$infolog $hawk_logs"
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

exit 0

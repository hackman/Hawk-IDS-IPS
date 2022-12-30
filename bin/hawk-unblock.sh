#!/bin/bash

hawk_conf='/etc/hawk.conf'
dbuser=$(awk -F = '/dbuser/{print $2}' $hawk_conf)
dbpass=$(awk -F = '/dbpass/{print $2}' $hawk_conf)
block_list=$(awk -F = '/block_list/{print $2}' $hawk_conf)
block_expire=$(awk -F = '/block_expire/{print $2}' $hawk_conf)

export PGUSER="$dbuser"
export PGPASSWD="$dbpass"
psql -t -n -A -F " " hawk -c "SELECT ip,id FROM blacklist WHERE date_rem IS NULL AND date_add < (now() - interval '$block_expire seconds')" | while read ip id; do
	if [ "$ip" != '' ] && [ "$id" != '' ]; then
		echo "`date` - Removing $ip($id) from DB and firewall"
		psql hawk -c "UPDATE blacklist SET date_rem=now() WHERE id = '$id'"
		sed -i "/in_hawk.*$ip/D" $block_list
		/sbin/iptables -D in_hawk -s $ip -j DROP
	fi
done
export PGUSER="letmein"
export PGPASSWD="letmein"

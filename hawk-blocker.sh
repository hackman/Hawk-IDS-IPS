#!/bin/bash

hawk_conf='/home/oneh/api/etc/hawk.conf'
dbuser=$(awk -F = '/dbuser/{print $2}' $hawk_conf)
dbpass=$(awk -F = '/dbpass/{print $2}' $hawk_conf)
block_list=$(awk -F = '/block_list/{print $2}' $hawk_conf)

export PGUSER="$dbuser"
export PGPASSWD="$dbpass"
ips=`psql -t -n -A hawk -c "SELECT ip,id FROM blacklist WHERE date_rem IS NULL and date_add < (now() - interval '24 hour')"`
for i in `echo $ips`; do
	id=`echo $i|cut -d "|" -f2`
	ip=`echo $i|cut -d "|" -f1`
	echo "Removing $ip($id) from DB and firewall"
	psql hawk -c "UPDATE blacklist set date_rem=now() WHERE id = '$id'"
	sed -i "/in_hawk.*$ip/D" $block_list
	iptables -D in_hawk -j DROP -s $ip
done
export PGUSER="letmein"
export PGPASSWD="letmein"

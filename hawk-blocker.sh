#!/bin/bash
# 1H - Hawk IDS/IPS blocker script                  Copyright(c) 2010 1H Ltd
#                                                        All rights Reserved
# copyright@1h.com                                             http://1h.com
# This code is subject to the GPLv2 license. 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

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
	iptables -D in_hawk -s $ip -j DROP
done
export PGUSER="letmein"
export PGPASSWD="letmein"

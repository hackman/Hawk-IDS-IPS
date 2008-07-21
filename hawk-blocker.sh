#!/bin/bash

max_attempts=2


# get offending IPs, count them and prepare them for the LOOP 
ip_list=`psql -n -t -A -Upostgres hawk -c "SELECT ip FROM broots WHERE \"date\" > (now() - interval '2 hour') ORDER BY ip ASC"|uniq -c|sed 's/\s\+/\|/g'`

# define protected IP ranges
sg_nets='127.0.0.1 70.84.112.90 67.15.187.4 64.246.15.53 67.15.157 67.15.172 67.15.211 67.15.243 67.15.245 67.15.250 67.15.255 216.40.199 207.218.208'

# check if the requested IP is not from our IP ranges
function check_ip() {
	for net in `echo $sg_nets`; do
                if [ "$1" == '' ]; then
                        echo "No ip supplied!"
                        exit 1
                fi
	        if [ "$(echo $1| grep -P "^$net")" == "$1" ]; then
	                echo "Can't block IP($1) from our networks!"
	                exit 1
	        fi
	done
	exit 0
}

function white_list() {
	ips=`psql -t -n -A -Upostgres hawk -c "SELECT ip,id FROM blacklist WHERE date_rem IS NULL and date_add < (now() - interval '24 hour')"`
	for i in `echo $ips`; do
		id=`echo $i|cut -d "|" -f2`
		ip=`echo $i|cut -d "|" -f1`
		echo "Removing $ip($id) from DB and firewall"
		psql -Upostgres hawk -c "UPDATE blacklist set date_rem=now() WHERE id = '$id'"
		sed -i "/in_sg.*$ip/D" /root/admin/sgfirewall
		iptables -D in_sg -j DROP -s $ip
	done
}

function check_existing() {
	if (psql -t -A -n -Upostgres hawk -c "SELECT ip FROM blacklist WHERE ip = '$1' AND date_rem IS NULL"|grep $1 > /dev/null); then
		echo "Found in DB $1!"
		exit 1
	fi
	exit 0
}

# blacklisted
# ID | DATE_ADD | DATE_REM | IP | COUNT | REASON | 
function log_block() {
	if (check_existing $1); then
		echo "Blocking IP $1 for having $count bruteforce attempts"
		psql -Upostgres hawk -c "INSERT INTO blacklist ( date_add, ip, count, reason ) VALUES ( now(), '$1', '1', 'Blocking IP $1 for having $count bruteforce attempts')"
		exit 0
	fi
	exit 1
}

# check for expired blacklisted IPs
white_list

# check, block and LOG the offending IPs
for i in $ip_list; do
	count=`echo $i|cut -d "|" -f 2`
	ip=`echo $i|cut -d "|" -f 3`
	if [ "$count" -gt "$max_attempts" ] && (check_ip $ip); then
		if (log_block $ip); then
			echo "iptables -I in_sg -j DROP -s $ip"
		        sed -i  "/HAWK-BLOCKED/aiptables -I in_sg -j DROP -s $ip" /root/admin/sgfirewall
		        iptables -I in_sg -j DROP -s $ip
		fi
	fi
done

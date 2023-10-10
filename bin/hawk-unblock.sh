#!/bin/bash

hawk_conf='/etc/hawk/hawk.conf'
block_list=$(awk -F = '/block_list/{print $2}' $hawk_conf)
block_expire=$(awk -F = '/block_expire/{print $2}' $hawk_conf)
db_type=$(awk -F = '$1 ~ /^db_type$/{print $2}' $hawk_conf)
iptables_chain=$(awk -F = '/^iptables_chain/{print $2}' $hawk_conf)
iptables_chain=${iptables_chain:-in_hawk}

function ublock_ip() {
	ip=$1
	sed -i "/in_hawk.*$ip/D" $block_list
	/sbin/iptables -D $iptables_chain -s $ip -j DROP
}

function sqlite_unblock() {
	sqlite_file=$(awk -F : '$1~/db=dbi/{print $3}' $hawk_conf)
	query="SELECT ip,id FROM blacklist WHERE date_rem IS NULL AND date_add < datetime(current_timestamp, '-$block_expire seconds')"
	sqlite3 -separator ' ' $sqlite_file "$query" | while read ip id; do
		if [[ -n $ip ]] && [[ -n $id ]]; then
			echo "$(date) - Removing $ip($id) from DB and firewall"
			sqlite3 $sqlite_file "UPDATE blacklist SET date_rem=now() WHERE id = '$id'"
			unblock_ip $ip
		fi
	done
}

function pgsql_unblock() {
	db_user=$(awk -F = '/db_user/{print $2}' $hawk_conf 2>/dev/null)
	db_pass=$(awk -F = '/db_pass/{print $2}' $hawk_conf 2>/dev/null)
	db_name=$(awk -F = '/db_pgsql/{gsub(/;.*/,"",$3);print $3}' $hawk_conf 2>/dev/null)
	if [[ -z $db_name ]]; then
		echo "$(date) Unable to find the Database name from config"
		exit 1
	fi
	export PGUSER="$db_user"
	export PGPASSWD="$db_pass"
	psql -t -n -A -F " " $db_name -c "SELECT ip,id FROM blacklist WHERE date_rem IS NULL AND date_add < (now() - interval '$block_expire seconds')" | while read ip id; do
		if [ "$ip" != '' ] && [ "$id" != '' ]; then
			echo "$(date) - Removing $ip($id) from DB and firewall"
			psql $db_name -c "UPDATE blacklist SET date_rem=now() WHERE id = '$id'"
			unblock_ip $ip
		fi
	done
	export PGUSER="letmein"
	export PGPASSWD="letmein"
}

function mysql_unblock() {
	db_user=$(awk -F = '/db_user/{print $2}' $hawk_conf 2>/dev/null)
	db_pass=$(awk -F = '/db_pass/{print $2}' $hawk_conf 2>/dev/null)
	db_name=$(awk -F = '/db_mysql/{gsub(/;.*/,"",$3);print $3}' $hawk_conf 2>/dev/null)
	if [[ -z $db_name ]]; then
		echo "$(date) Unable to find the Database name from config"
		exit 1
	fi

	echo "Not implemented, yet!"
}

case "$db_type" in
	sqlite)
		sqlite_unblock
	;;
	pgsql)
		pgsql_unblock
	;;
	mysql)
		mysql_unblock
	;;
	*)
		echo "Unsupported DB type"
	;;
esac

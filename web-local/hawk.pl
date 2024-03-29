#!/usr/bin/perl
# Author(s):
#	Jivko Angelov <jivko@1h.com> 

use strict;
use warnings;
use DBD::Pg;
use JSON::XS;
use CGI qw/:standard/;
use POSIX qw(strftime);

use lib '/var/lib/hawk/lib/';
use parse_config;

my $VERSION = '0.2.2';


my $conf = '/etc/hawk-web.conf';
my %config = parse_config($conf);

my %srvhash = split(/[: ]+/, $config{'service_names'});

my %interval_secs = (
	"8hours" => '28800',
	"daily" => '86400',
	"weekly" => '604800',
	"monthly" => '2678400',
	"yearly" => '32140800'
);

sub web_error {
	print "Content-type: text/plain\r\n\r\n";
	print $_[0], "\n";
	exit 1;
}

sub offset_to_interval {
	my $offset = $_[0];
	my $abs_offset = abs($offset);
	my $interval = '';
	$interval = "+ '0$abs_offset:00:00'::interval" if ($offset > 0);
	$interval = "- '0$abs_offset:00:00'::interval" if ($offset < 0);
	return $interval;
}

sub validate_ip {
    if (defined($_[0]) &&
        $_[0] =~ m/^((\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3}))$/ &&
        $2 <= 255 && $3 <= 255 && $4 <= 255 && $5 <=255 ) {
        return $1;
    }
    return $_[1];
}

my $time_offset = "+ '00:00:00'::interval";
$time_offset = offset_to_interval($config{'time_offset'}) if defined($config{'time_offset'});

my $conn   = DBI->connect("$config{'db'}", $config{'dbuser'}, $config{'dbpass'}, { PrintError => 1, AutoCommit => 1 } ) or web_error("Unable to connect to pgsql: $DBI::errstr");

my $charts_24h_query = "
	SELECT COUNT(id), TO_CHAR(date_trunc('hour', date $time_offset), 'HH24:MI') AS hourly
	FROM %s
	WHERE \"date\" > (now() - interval \'24 hour\')
	GROUP BY hourly
";

my $search_charts_query = "
	SELECT COUNT(id), extract(\'epoch\' from date::date) AS daily
	FROM %s
	WHERE ip = ? AND date >= now() - interval \'1 week\'
	GROUP BY daily
";

my $brutes_24h = $conn->prepare('
	SELECT TO_CHAR(date '.$time_offset.', \'YYYY-MM-DD HH:MI:SS\'), ip, service
	FROM broots
	WHERE date > now() - interval \'24 hours\'
	OFFSET ?
	LIMIT ?
');

my $brutes_24h_count = "
	SELECT COUNT(ip)
	FROM broots
	WHERE date > now() - interval \'24 hours\';
";

my $failed_24h = $conn->prepare('
	SELECT TO_CHAR(date '.$time_offset.', \'YYYY-MM-DD HH:MI:SS\'), ip, service, "user"
	FROM failed_log
	WHERE date > now() - interval \'24 hours\'
	OFFSET ?
	LIMIT ?
');

my $failed_24h_count = "
	SELECT COUNT(ip)
	FROM failed_log
	WHERE date > now() - interval \'24 hours\'
";

my $brutes_count = $conn->prepare('
	SELECT COUNT(id), service
	FROM broots
	WHERE date > now() - interval \'24 hour\'
	GROUP BY service
');

my $select_brutes = $conn->prepare('
	SELECT TO_CHAR(date '.$time_offset.', \'YYYY-MM-DD HH:MI:SS\'), ip
	FROM broots
	WHERE date > now() - interval \'24 hour\'
	AND service = ?
');

my $brutes_summary_query = "
	SELECT COUNT(id), ip
	FROM broots
	WHERE date > now() - interval '%s'
	GROUP BY ip;
";

my $failed_summary_query = "
	SELECT COUNT(id), ip
	FROM failed_log
	WHERE date > now() - interval '%s'
	GROUP BY ip;
";

my $select_blocked_ip = $conn->prepare('
	SELECT TO_CHAR(date_add '.$time_offset.', \'YYYY-MM-DD HH:MI:SS\'), TO_CHAR(date_rem '.$time_offset.', \'YYYY-MM-DD HH:MI:SS\'), ip, reason
	FROM blacklist
	WHERE ip=?
');

my $failed_ip_query = "
	SELECT TO_CHAR(date $time_offset, \'YYYY-MM-DD HH:MI:SS\'), ip, \"user\", service
	FROM failed_log
	WHERE date > now() - interval '%s'
	AND ip=?
	OFFSET ?
	LIMIT ?
";

my $failed_ip_query_count = "
	SELECT COUNT(ip)
	FROM failed_log
	WHERE date > now() - interval '%s'
	AND ip=?
";

my $select_blocked = $conn->prepare('
	SELECT
		TO_CHAR(date_add '.$time_offset.', \'YYYY-MM-DD HH:MI:SS\'),
		TO_CHAR(date_rem '.$time_offset.', \'YYYY-MM-DD HH:MI:SS\'),
		ip,
		reason
	FROM
		blacklist
	ORDER BY
		date_add DESC
	OFFSET ?
	LIMIT ?
');

my $get_blocked_count = "
	SELECT
		COUNT(ip)
	FROM
		blacklist
";

# 1 hour queries, needed by master interface

my $broots_1h_query = "
	SELECT
		COUNT(id) AS id 
	FROM
		broots 
	WHERE
		date > now() - interval \'1 hour\'
";

my $failed_1h_query = "
	SELECT
		COUNT(id) AS id 
	FROM
		failed_log 
	WHERE
		date > now() - interval \'1 hour\'
";

my $blacklisted_1h_active_query = "
	SELECT 
		COUNT(id) AS count 
	FROM
		blacklist 
	WHERE
		date_add > now() - interval \'1 hour\'
	AND
		date_rem IS NULL
";

my $blacklisted_daily_active_query = "
	SELECT
		COUNT(id) AS count 
	FROM
		blacklist 
	WHERE
		date_rem IS NULL
	AND
		date_add > now() - interval \'24 hours\'
";

my $blacklisted_1h_removed_query = "
	SELECT 
		COUNT(id) AS count 
	FROM
		blacklist 
	WHERE
		date_rem IS NOT NULL
	AND
		date_rem > now() - interval \'1 hour\'
";

my $blacklisted_daily_removed_query = "
	SELECT 
		COUNT(id) AS count
	FROM
		blacklist 
	WHERE
		date_rem IS NOT NULL
	AND
		date_rem > now() - interval \'24 hours\'
";

if (defined(param('id'))) {
	print "Content-type: text/plain\r\n\r\n";
	my $id = param('id');
	if ($id == 1) {
		if (defined(param('service'))) {
			my $service = param('service');
			$select_brutes->execute($service) or web_error("Unable to get bruteforces per service from database: $DBI::errstr");
			my @brutes = ();
			my $count = 0;
			while (my @data = $select_brutes->fetchrow_array) {
				$brutes[$count] = [@data];
				$count++;
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\@brutes);
		} else {
			my %brutes = ();
			$brutes_count->execute() or web_error("Unable to get bruteforce count from database: $DBI::errstr");
			while (my @data = $brutes_count->fetchrow_array) {
				$brutes{$data[1]} = $data[0];
			}
			# FTP(0) SSH(1) POP3(2) IMAP(3) WebMail(4) cPanel(5) da(6)
			my @srvs = ("ftp", "ssh", "pop3", "imap", "webmail", "cpanel", "da");
			for (my $i=0; $i<=$#srvs; $i++) {
				# Return -1 for that particular service if it is NOT enabled for monitoring
				$brutes{$srvs[$i]} = -1 if ($srvs[$i] eq 'ftp' && ! $config{'watch_pureftpd'} && ! $config{'watch_proftpd'});
				$brutes{$srvs[$i]} = -1 if ($srvs[$i] eq 'ssh' && ! $config{'watch_ssh'});
				$brutes{$srvs[$i]} = -1 if (($srvs[$i] eq 'pop3' || $srvs[$i] eq 'imap') && ! $config{'watch_dovecot'} && ! $config{'watch_courier'});
				$brutes{$srvs[$i]} = -1 if (($srvs[$i] eq 'cpanel' || $srvs[$i] eq 'webmail') && ! $config{'watch_cpanel'});
				$brutes{$srvs[$i]} = -1 if ($srvs[$i] eq 'da' && ! $config{'watch_da'});
				next if (defined($brutes{$srvs[$i]} && $brutes{$srvs[$i]} == -1));
				if (defined($brutes{$i})) {
					$brutes{$srvs[$i]} = $brutes{$i};
					delete $brutes{$i};
				} else {
					$brutes{$srvs[$i]} = 0;
				}
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\%brutes);
		}
	} elsif ($id == 2) {
		if (defined(param('interval'))) {
			my $interval = param('interval');
			my $failed_summary = $conn->prepare(sprintf($failed_summary_query, $interval));
			$failed_summary->execute() or web_error("Unable to get bruteforce summary from database: $DBI::errstr");
			my $count = 0;
			my @summary = ();
			while (my @data = $failed_summary->fetchrow_array) {
				$summary[$count] = [@data];
				$count++;
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\@summary);
		}
	} elsif ($id == 3) {
		if (defined(param('type'))) {
			my $type = param('type');
			my $hour = strftime('%H', localtime(time));
			my $new;
			my $charts_24h = $conn->prepare(sprintf($charts_24h_query, $type));
			$charts_24h->execute() or web_error("Unable to get chart info from database: $DBI::errstr");
			my @charts = ();
			my %interval;
			while (my @data = $charts_24h->fetchrow_array) {
				$interval{$data[1]} = $data[0];
			}
			for (my $i=23; $i>=0; $i--) {
				$new=($hour-$i)%24;
				if ($new < 10) {
					$new = "0$new:00";
				} else {
					$new = "$new:00";
				}
				if ($interval{$new}) {
					push(@charts, [$interval{$new}, $new]);
				} else {
					push(@charts, [0, $new]);
				}
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\@charts);
		}
	} elsif ($id == 4) {
		my $limit = (defined(param('limit')) && param('limit') =~ /^([0-9]+)$/) ? $1 : 20;
		my $offset = (defined(param('start')) && param('start') =~ /^([0-9]+)$/) ? $1 : 0;
		my %result;
		$result{'data'} = [];
		$result{'total'} = $conn->selectrow_array($brutes_24h_count);
		$brutes_24h->execute($offset, $limit) or web_error("Unable to get brutes 24h from database: $DBI::errstr");
		while (my @data = $brutes_24h->fetchrow_array) {
			# Make sure to convert the service id back to service name for the web interface
			$data[2] = $srvhash{$data[2]};
			push(@{$result{'data'}}, [@data]);
		}
		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\%result);
	} elsif ($id == 5) {
		my $limit = (defined(param('limit')) && param('limit') =~ /^([0-9]+)$/) ? $1 : 20;
		my $offset = (defined(param('start')) && param('start') =~ /^([0-9]+)$/) ? $1 : 0;
		my %result;
		$result{'data'} = [];
		$result{'total'} = $conn->selectrow_array($failed_24h_count);
		$failed_24h->execute($offset, $limit) or web_error("Unable to get failed 24h from database: $DBI::errstr");
		while (my @data = $failed_24h->fetchrow_array) {
			# Make sure to convert the service id back to service name for the web interface
			$data[2] = $srvhash{$data[2]};
			push(@{$result{'data'}}, [@data]);
		}
		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\%result);
	} elsif ($id == 6) {
		if (defined(param('ip'))) {
			my $ip = param('ip');
			$select_blocked_ip->execute($ip) or web_error("Unable to get IP address from database: $DBI::errstr");
			my $count = 0;
			my @result = ();
			while (my @data = $select_blocked_ip->fetchrow_array) {
				$result[$count] = [@data];
				$count++;
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\@result);
		}
	} elsif ($id == 7) {
		my $ip = validate_ip(scalar(param('ip')));
		web_error("No or invalid IP supplied!") if (!defined($ip));
		my $charts_24h_broots = $conn->prepare(sprintf($search_charts_query, "broots"));
		$charts_24h_broots->execute($ip) or web_error("Unable to get chart info from database: $DBI::errstr");
		my @charts = ();
		my @brutes;
		while (my @data = $charts_24h_broots->fetchrow_array) {
			push(@brutes, \@data);
		}
		my $charts_24h_failed = $conn->prepare(sprintf($search_charts_query, "failed_log"));
		$charts_24h_failed->execute($ip) or web_error("Unable to get chart info from database: $DBI::errstr");
		my @failed;
		while (my @data = $charts_24h_failed->fetchrow_array) {
			push(@failed, \@data);
		}

		my $timestamp = time();
		my @date_arr = localtime($timestamp);

		# we need to get today's timestamp
		$timestamp -= $date_arr[0] + 60 * $date_arr[1] + 3600 * $date_arr[2];

		my $temp_time = $timestamp - $interval_secs{'weekly'};
		for (my $i = 1; $i <= 7; $i ++) {
			$temp_time += $interval_secs{'daily'};
			my @result = (strftime("%Y-%m-%d", localtime($temp_time)));

			if (scalar(@brutes) > 0 && $brutes[0]->[1] == $temp_time) {
				push(@result, shift(@brutes)->[0]);
			} else {
				push(@result, 0);
			}
			if (scalar(@failed) > 0 && $failed[0]->[1] == $temp_time) {
				push(@result, shift(@failed)->[0]);
			} else {
				push(@result, 0);
			}

			push(@charts, \@result);
		}

		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\@charts);
	} elsif ($id == 8) {
		if (defined(param('interval')) && defined(param('ip'))) {
			my $interval = param('interval');
			my $ip = param('ip');
			my $limit = (defined(param('limit')) && param('limit') =~ /^([0-9]+)$/) ? $1 : 20;
			my $offset = (defined(param('start')) && param('start') =~ /^([0-9]+)$/) ? $1 : 0;
			my %result;
			$result{'data'} = [];
			$result{'total'} = $conn->selectrow_array(sprintf($failed_ip_query_count, $interval), undef, $ip);
			my $failed_ip = $conn->prepare(sprintf($failed_ip_query, $interval));
			$failed_ip->execute($ip, $offset, $limit) or web_error("Unable to get failed ip from database: $DBI::errstr");
			while (my @data = $failed_ip->fetchrow_array) {
				$data[3] = $srvhash{$data[3]};
				push(@{$result{'data'}}, [@data]);
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\%result);
		}
	} elsif ($id == 9) {
		my $limit = (defined(param('limit')) && param('limit') =~ /^([0-9]+)$/) ? $1 : 20;
		my $offset = (defined(param('start')) && param('start') =~ /^([0-9]+)$/) ? $1 : 0;
		my %result;
		$result{'data'} = [];
		$result{'total'} = $conn->selectrow_array($get_blocked_count);
		$select_blocked->execute($offset, $limit) or web_error("Could not get blocked ips: $DBI::errstr\n");
		while (my @data = $select_blocked->fetchrow_array()) {
			push(@{$result{'data'}}, [@data]);
		}
		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\%result);
	} elsif ($id == 10) {
		my @stats;
		my $broots_1h = $conn->selectrow_array($broots_1h_query);
		my $failed_1h = $conn->selectrow_array($failed_1h_query);
		my $blacklisted_1h_active = $conn->selectrow_array($blacklisted_1h_active_query);
		my $blacklisted_daily_active = $conn->selectrow_array($blacklisted_daily_active_query);
		my $blacklisted_1h_removed = $conn->selectrow_array($blacklisted_1h_removed_query);
		my $blacklisted_daily_removed = $conn->selectrow_array($blacklisted_daily_removed_query);
		@stats = [$broots_1h, $failed_1h, $blacklisted_1h_active, $blacklisted_daily_active, $blacklisted_1h_removed, $blacklisted_daily_removed];
		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\@stats);
	}
} else {
	print "Content-type: text/plain\r\n\r\n";
	print("Undefined parameter!");
	exit 1;
}

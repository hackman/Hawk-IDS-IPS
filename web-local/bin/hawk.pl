#!/usr/bin/perl

#############################################
# Author: 
#		Jivko Angelov <jivko@siteground.com> 
#
# Version 0.1
# Last update:	26.Mar.2010
#
#############################################

use strict;
use warnings;
use DBI; 
use JSON::XS;
use CGI qw/:standard/;
use POSIX qw(strftime);

my $dbname = "hawk";
my $dbuser = "hawk";
my $dbpass = 'b41f12bf5c9add618ce7d7032fd2f630';
my %db_config = (
	"db" => $dbname,
	"dbuser" => $dbuser,
	"dbpass" => $dbpass
);
my $version = 0.1;

sub web_error {
	print "Content-type: text/plain\r\n\r\n";
	print $_[0], "\n";
	exit 1;
}

my $conn   = DBI->connect("dbi:Pg:dbname=$db_config{'db'}", $db_config{'dbuser'}, $db_config{'dbpass'}, { PrintError => 1, AutoCommit => 1 } ) or web_error("Unable to connect to pgsql: $DBI::errstr");

my $charts_24h_query = "
	SELECT COUNT(id), TO_CHAR(date_trunc(\'hour\', date), \'HH:MI\') AS hourly
	FROM %s
	WHERE \"date\" > (now() - interval \'24 hour\')
	GROUP BY hourly
";

my $brutes_24h = $conn->prepare('
	SELECT TO_CHAR(date, \'YYYY-MM-DD HH:MI:SS\'), ip, service
	FROM broots
	WHERE date > now() - interval \'24 hours\';
');

my $failed_24h = $conn->prepare('
	SELECT TO_CHAR(date, \'YYYY-MM-DD HH:MI:SS\'), ip, service, "user"
	FROM failed_log
	WHERE date > now() - interval \'24 hours\';
');

my $brutes_count = $conn->prepare('
	SELECT COUNT(id), service
	FROM broots
	WHERE date > now() - interval \'24 hour\'
	GROUP BY service
');

my $brutes_summary_query = "
	SELECT COUNT(id), ip
	FROM broots
	WHERE date > now() - interval '%s'
	GROUP BY ip;
";

my $select_blocked = $conn->prepare('
	SELECT TO_CHAR(date_add, \'YYYY-MM-DD HH:MI:SS\'), TO_CHAR(date_rem, \'YYYY-MM-DD HH:MI:SS\'), ip, reason
	FROM blacklist
	WHERE ip=?
');

if (defined(param('id'))) {
	print "Content-type: text/plain\r\n\r\n";
	my $id = param('id');
	if ($id == 1) {
		my %brutes = ();
		$brutes_count->execute() or web_error("Unable to get bruteforce count from database: $DBI::errstr");
		while (my @data = $brutes_count->fetchrow_array) {
			$brutes{$data[1]} = $data[0];
		}
		# FTP(0) SSH(1) POP3(2) IMAP(3) WebMail(4) cPanel(5)
		my @srvs = ("ftp", "ssh", "pop3", "imap", "webmail", "cpanel");
		for (my $i=0; $i<=$#srvs; $i++) {
			if (!defined($brutes{$srvs[$i]})) {
				$brutes{$srvs[$i]} = 0
			}
		}
		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\%brutes);
	} elsif ($id == 2) {
		if (defined(param('interval'))) {
			my $interval = param('interval');
			my $brutes_summary = $conn->prepare(sprintf($brutes_summary_query, $interval));
			$brutes_summary->execute() or web_error("Unable to get bruteforce summary from database: $DBI::errstr");
			my $count = 0;
			my @summary = ();
			while (my @data = $brutes_summary->fetchrow_array) {
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
			#my $count = 0;
			my @charts = ();
			my %interval;
			while (my @data = $charts_24h->fetchrow_array) {
				$interval{$data[1]} = $data[0];
				#$charts[$count] = [@data];
				#$count++;
			}
			my $hour = strftime('%H', localtime(time));
			my $new;
			for (my $i=0; $i<24; $i++) {
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
			
			#foreach my $k (sort (keys(%interval))) {			
			#foreach my $k(keys %interval) {
			#	push(@charts, [$interval{$k}, $k]);
			#}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\@charts);
		}
	} elsif ($id == 4) {
		$brutes_24h->execute() or web_error("Unable to get brutes 24h from database: $DBI::errstr");
		my $count = 0;
		my @brutes = ();
		while (my @data = $brutes_24h->fetchrow_array) {
			$brutes[$count] = [@data];
			$count++;
		}
		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\@brutes);
	} elsif ($id == 5) {
		$failed_24h->execute() or web_error("Unable to get failed 24h from database: $DBI::errstr");
		my $count = 0;
		my @failed = ();
		while (my @data = $failed_24h->fetchrow_array) {
			$failed[$count] = [@data];
			$count++;
		}
		my $json = JSON::XS->new->ascii->pretty->allow_nonref;
		print $json->encode(\@failed);
	} elsif ($id == 6) {
		if (defined(param('ip'))) {
			my $ip = param('ip');
			$select_blocked->execute($ip) or web_error("Unable to get IP address from database: $DBI::errstr");
			my $count = 0;
			my @result = ();
			while (my @data = $select_blocked->fetchrow_array) {
				$result[$count] = [@data];
				$count++;
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\@result);
		}
	}
} else {
	print "Content-type: text/plain\r\n\r\n";
	print("Undefined parameter!");
	exit 1;
}
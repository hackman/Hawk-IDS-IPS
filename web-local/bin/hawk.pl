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
			my $charts_24h = $conn->prepare(sprintf($charts_24h_query, $type));
			$charts_24h->execute() or web_error("Unable to get chart info from database: $DBI::errstr");
			my $count = 0;
			my @charts = ();
			while (my @data = $charts_24h->fetchrow_array) {
				$charts[$count] = [@data];
				$count++;
			}
			my $json = JSON::XS->new->ascii->pretty->allow_nonref;
			print $json->encode(\@charts);
		}
	}
} else {
	print "Content-type: text/plain\r\n\r\n";
	print("Undefined parameter!");
	exit 1;
}
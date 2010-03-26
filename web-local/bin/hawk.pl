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

my $dbhost="localhost";
my $dbname = "hawk";
my $dbuser = "hawk";
my $dbpass = 'hdshd#$sjdh';
my $dbport = "5432";
my %db_config = (
	"dbhost" => $dbhost,
	"dbname" => $dbname,
	"dbuser" => $dbuser,
	"dbpass" => $dbpass,
	"dbport" => $dbport
);
my $version = 0.1;

sub web_error {
	print "Content-type: text/plain\r\n\r\n";
	print $_[0], "\n";
	exit 1;
}

my $conn   = DBI->connect("dbi:Pg:dbname=$db_config{'db'}", $db_config{'dbuser'}, $db_config{'dbpass'}, { PrintError => 1, AutoCommit => 1 } ) or web_error("Unable to connect to pgsql: $DBI::errstr");

my $failed_24h = $conn->prepare('
	SELECT COUNT(id), date_trunc(\'hour\', date) AS hourly
	FROM failed_log
	WHERE "date" > (now() - interval \'24 hour\')
	GROUP BY hourly
');

my $brutes_24h = $conn->prepare('
	SELECT COUNT(id), date_trunc(\'hour\', date) AS hourly
	FROM broots
	WHERE "date" > (now() - interval \'24 hour\')
	GROUP BY hourly
');

if (defined(param('id'))) {
	my $id = param('id');
	if ($id == 1) {
		
	} elsif ($id == 2) {
		
	}
} else {
	print "Content-type: text/plain\r\n\r\n";
	print("Undefined parameter!");
	exit 1;
}
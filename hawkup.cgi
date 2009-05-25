#!/usr/bin/perl

use strict;
use warnings;
use CGI qw(param);
use DBI;
use IO::Socket::INET;

my $debug = 0;

my $dbuser = 'srv2ip';
my $dbpass = 'apitonabatkosrv2';

print "Content-type: text/plain\n\n";

print "You are " . $ENV{'REMOTE_ADDR'} . "\n" if ($debug);

if (!defined(param('server'))) {
	print "Missing argvs!\n" if ($debug);
	exit 1;
}

$debug = 1 if (defined(param('debug')) && param('debug') == 1);
my $server = param('server');
my $ip = $ENV{'REMOTE_ADDR'};

print "Got server $server and ip $ip\n" if ($debug);

if ($server !~ /^siteground[0-9]+.com$/ &&
		$server !~ /^siteground.net$/ &&
		$server !~ /^clev.net$/ &&
		$server !~ /^clev[0-9]+.com$/) {
	print "Incorrect server name $server!\n" if ($debug);
	exit(1);
}

if ($ip !~ /^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$/) {
	print "Incorrect IP $ip!\n" if ($debug);
	exit(1);
}

my %loop_hash = (
	01	=>	["DBI:Pg:database=admin;host=127.0.0.1;port=5432",
			"SELECT ip FROM servers.list WHERE server = '$server'",
			1],

	02	=>	["DBI:Pg:database=netinfo;host=127.0.0.1;port=5432",
			"SELECT source FROM firewall.trusted WHERE status = '1'",
			0],

	03	=> ["DBI:Pg:database=admin;host=127.0.0.1;port=5432",
			"SELECT a.ip FROM servers.list a, backups.status b WHERE b.status=3 AND dst_id=(SELECT id FROM servers.list WHERE server='$server') AND a.id=b.src_id;",
			0]
);

while (my $key = each (%loop_hash)) {
	#print "$loop_hash{$key}[0]\n";
	if (my $conn = DBI->connect_cached($loop_hash{$key}[0], $dbuser, $dbpass, { PrintError => 1, AutoCommit => 1 })) {
		#print "Connected baby\n";
		print "$loop_hash{$key}[1]\n" if ($debug);
		if (my $query = $conn->prepare($loop_hash{$key}[1])) {
			#print "Prepared baby\n";
			if ($query->execute) {
				#print "Executed baby\n";
				if ($loop_hash{$key}[2]) {
					my $db_ip = $query->fetchrow_array;
					if ($db_ip ne $ip && $ip ne '87.118.135.130') {
						print "IP missmatch!\n" if ($debug);
						exit 1;
					} else {
						print "IP access granted for $server/$ip\n" if ($debug);
					}
				} else {
					while (my @allowed = $query->fetchrow_array) {
						foreach my $allowed_ip (@allowed) {
							print $allowed_ip . "\n";
						}
					}
				}
			} else {
				print "Failed to execute the query!\n" if ($debug);
				exit 1;
			}
		} else {
			print "Failed to prepare the query!\n" if ($debug);
			exit 1;
		}
	} else {
		print "Failed to connect to the database!\n" if ($debug);
		exit 1;
	}
}

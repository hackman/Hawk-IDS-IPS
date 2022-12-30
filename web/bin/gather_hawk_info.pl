#!/usr/bin/perl
use strict;
use warnings;
use DBD::Pg;
use JSON::XS;

use lib '/var/lib/hawk/lib';
use parse_config;
use db_utils;

my $VERSION = '0.0.2';

my $config_file = '/etc/hawk-web.conf';

my %config = parse_config($config_file);
my %admin_config = %config;
$admin_config{'dbname'} = $admin_config{'pg_dbname'};
$admin_config{'dbhost'} = $admin_config{'pg_dbhost'};
$admin_config{'dbport'} = $admin_config{'pg_dbport'};
$admin_config{'dbuser'} = $admin_config{'pg_dbuser'};
$admin_config{'dbpass'} = $admin_config{'pg_dbpass'};

my $count = 0;

if ((defined($config{'debug'}) && $config{'debug'}) || defined($ARGV[0])) {
	$config{'debug'} = 1;
}

my $server_list = '
	SELECT
		server
	FROM
		servers.list INNER JOIN servers.options ON id = srv_id
	WHERE
		group_id = 1 or group_id = 2
';

my $clear_old_info = '
	DELETE FROM
		hourly_info
	WHERE
		date < now() - \'25 hours\'::interval
';
my $insert_data  = ' 
	INSERT INTO
		hourly_info (server, failed, brutes, blocked)
	VALUES
		(?, ?, ?, ?)
';


sub get_server_info {
	my $name = $_[0];
	my $response;
	if (open(SERV, sprintf("curl http://%s/~sentry/cgi-bin/hawk-web.pl?cgi=1 2>/dev/null |", $name))) {
		local $/ = undef;
		$response = <SERV>;
		close(SERV);
	} else {
		printf(STDERR "Could not execute curl to get info for server %s\n", $_[0]);
		return undef;
	}
	print "$name - $response\n" if $config{'debug'};
	if ($response !~ m/^[0-9:|]+/) {
		printf(STDERR "$name returned a bad json: $response\n");
		return [0, 0, 0];
	}
	my @result;
	@result = split(/\|/,$response);
	if ($#result < 3) {
		printf(STDERR "$name returned a bad json: $response\n");
		return [0, 0, 0];
	}
	$result[2] = (split(/:/,$result[2]))[1];
	$result[2] = 0 if $result[2] eq "";
	return [$result[0], $result[1], $result[2]];
}

my $conn = connect_db(\%admin_config);

$server_list = $conn->prepare($server_list);
$server_list->execute() or die "Could not execute the query for server_list: $DBI::errstr";


my @data;
while (my $server_name = $server_list->fetchrow_array()) {
	my $server_data = get_server_info($server_name) or next;
	push(@data, [ $server_name, @$server_data ]);
}

$conn->disconnect();
$conn = connect_db(\%config, 0);

#delete old entries
$conn->do($clear_old_info) or die "Could not insert old data: $DBI::errstr";

$insert_data = $conn->prepare($insert_data);

# insert the info into the database
foreach my $server_data (@data) {
	my ($server_name, $brutes, $failed, $blacklisted) = @$server_data;
	print "server: $server_name, brutes: $brutes, failed: $failed, blacklisted: $blacklisted\n" if $config{'debug'};

	$insert_data->execute($server_name, $failed, $brutes, $blacklisted)
		or die "Could not add user information for server $server_name: $DBI::errstr";
}
$conn->commit() or die "Could not commit transaction: $DBI::errstr";

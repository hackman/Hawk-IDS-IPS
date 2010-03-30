#!/usr/bin/perl
use strict;
use warnings;
use CGI qw(param);
use CGI::Carp qw(fatalsToBrowser);
use JSON::XS;

use lib '/home/dvd/projects/local-api/lib/';
use parse_config;
use db_utils;
use web_error;

my $VERSION = '0.1.2';
my $conf_file = '/home/dvd/projects/hawk-commercial/web/web.conf';
my %config = parse_config($conf_file);

my $get_server_names = '
	SELECT
		server
	FROM
		daily_min_max_values
	WHERE
		min_failed >= ? AND
		max_failed <= ? AND
		min_brutes >= ? AND
		max_brutes <= ? AND
		min_blocked >= ? AND
		max_blocked <= ?
	ORDER BY
		server ASC
	LIMIT %s
	OFFSET %s
';

my $get_server_count = '
	SELECT
		count(server)
	FROM
		daily_min_max_values
	WHERE
		min_failed >= ? AND
		max_failed <= ? AND
		min_brutes >= ? AND
		max_brutes <= ? AND
		min_blocked >= ? AND
		max_blocked <= ?
';

my $get_server_info = '
	SELECT
		extract(hour from date) || \':00\',
		failed,
		brutes,
		blocked
	FROM
		hourly_info
	WHERE
		server = ?
';

$|=1;

if (!param('txt')) {
	print "Content-type: text/html\r\n\r\n";
	web_error("Not implemented!\n");
}

print "Content-type: text/plain\r\n\r\n";

sub validate_numerical_param {
	# $_[0] - param name
	# $_[1] - default value
	if (defined(param($_[0])) && (param($_[0]) =~ /^[0-9]+$/)) {
		return param($_[0]);
	}
	return $_[1];
}

my $min_brutes = validate_numerical_param('min_brutes', 0);
my $max_brutes = validate_numerical_param('max_brutes', $config{'max_brutes'});
my $min_failed = validate_numerical_param('min_failed', 0);
my $max_failed = validate_numerical_param('max_failed', $config{'max_failed'});
my $min_blocked = validate_numerical_param('min_blocked', 0);
my $max_blocked = validate_numerical_param('max_blocked', $config{'max_blocked'});

my $offset = validate_numerical_param('start', -1);
my $limit = validate_numerical_param('limit', -1);

if ($offset < 0 || $limit < 0) {
	print "start: ".param('start').".\n";
	print "limit: ".param('limit').".\n";
	web_error("Wrong or missing start and limit parameters\n");
}

# some debugginig info
print "After validation:

min_failed = $min_failed
max_failed = $max_failed

min_brutes = $min_brutes
max_brutes = $max_brutes

min_blocked = $min_blocked
max_blocked = $max_blocked

offset = $offset
limit = $limit" if param('debug');


if ($max_failed < $min_failed) {
	$min_failed = 0;
	$max_failed = $config{'max_failed'};
}

if ($max_brutes < $min_brutes) {
	$min_brutes = 0;
	$max_brutes = $config{'max_brutes'};
}

if ($max_blocked < $min_blocked) {
	$min_blocked = 0;
	$max_blocked = $config{'max_blocked'};
}


my $conn = connect_db(\%config);

my %result;

if (defined(param('server'))) {
	my $server_info_query = $conn->prepare($get_server_info);
	$server_info_query->execute(param('server')) or web_error("Could not get info for server: $DBI::errstr\n");
	my %server_entry;
	$server_entry{'name'} = param('server');
	$server_entry{'data'} = [];
	while (my @hourly_info = $server_info_query->fetchrow_array()) {
		push(@{$server_entry{'data'}},
			{'hour' => $hourly_info[0], 'failed' => $hourly_info[1], 'brutes' => $hourly_info[2], 'blocked' => $hourly_info[3]});
	}
	if (@{$server_entry{'data'}}) {
		$result{'servers'} = [ \%server_entry ];
		$result{'total'} = 1;
	} else {
		$result{'servers'} = [];
		$result{'total'} = 0;
	}
} else {
	$result{'servers'} = [];
	$result{'total'} = $conn->selectrow_array($get_server_count, undef,
		$min_failed, $max_failed,
		$min_brutes, $max_brutes,
		$min_blocked, $max_blocked);

	my $server_names_query = $conn->prepare(sprintf($get_server_names, $limit, $offset));
	$server_names_query->execute(
		$min_failed, $max_failed,
		$min_brutes, $max_brutes,
		$min_blocked, $max_blocked);

	my $server_info_query = $conn->prepare($get_server_info);

	while (my $server = $server_names_query->fetchrow_array()) {
		my %server_entry;
		$server_entry{'name'} = $server;
		$server_entry{'data'} = [];
		$server_info_query->execute($server) or web_error("Could not get info for server: $DBI::errstr\n");
		while (my @hourly_info = $server_info_query->fetchrow_array()) {
			push(@{$server_entry{'data'}},
				{'hour' => $hourly_info[0], 'failed' => $hourly_info[1], 'brutes' => $hourly_info[2], 'blocked' => $hourly_info[3]});
		}
		push(@{$result{'servers'}}, \%server_entry);
	}
}

my $json = JSON::XS->new->ascii->pretty->allow_nonref;
print $json->encode(\%result);

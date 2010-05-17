#!/usr/bin/perl
use strict;
use warnings;
use CGI qw(param);
use CGI::Carp qw(fatalsToBrowser);
use JSON::XS;

if (-e '/home/dvd/projects/local-api/lib/') {
	use lib '/home/dvd/projects/local-api/lib/';
} else {
	use lib '/home/sgapi/lib/';
}
use parse_config;
use db_utils;
use web_error;

my $VERSION = '0.2.5';
my $conf_file;
if (-e '/home/dvd/projects/hawk-commercial/web/web.conf') {
	$conf_file = '/home/dvd/projects/hawk-commercial/web/web.conf';
} else {
	$conf_file = '/home/sgapi/etc/web.conf';
}

my @order_criteria = (
	'failed_sum DESC',
	'failed_sum ASC',
	'brutes_sum DESC',
	'brutes_sum ASC',
	'blocked_sum DESC',
	'blocked_sum ASC',
);

my %config = parse_config($conf_file);

my $search_where_cond = 'AND server ~ \'.*%s.*\'';

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
		max_blocked <= ? %s
	ORDER BY %s
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
		max_blocked <= ? %s
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
		server = ? AND
		date > now() - interval \'24 hours\'
	ORDER BY date DESC
';

my $get_summary_query = '
	SELECT
		failed_sum, brutes_sum
	FROM
		stats_all_servers
';

sub validate_numerical_param {
	# $_[0] - param name
	# $_[1] - default value
	if (defined(param($_[0])) && (param($_[0]) =~ /^[0-9]+$/)) {
		return param($_[0]);
	}
	return $_[1];
}

$|=1;

if (!param('txt')) {
	print "Content-type: text/html\r\n\r\n";
	web_error("Not implemented!\n");
}

print "Content-type: text/plain\r\n\r\n";

my $conn = connect_db(\%config);
my %result;
if (param('txt') == 1) {

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
	limit = $limit" if param('debug') == 1;


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

	my $search = "";
	if (defined(param('server'))) {
		if (param('server') =~ m/^([\w\d.]+)$/) {
			$search = sprintf($search_where_cond, $1);
		} else {
			web_error("Invalid search parameter");
		}
	}

	$result{'servers'} = [];
	$result{'total'} = $conn->selectrow_array(sprintf($get_server_count, $search), undef,
		$min_failed, $max_failed,
		$min_brutes, $max_brutes,
		$min_blocked, $max_blocked);

	my $order = $order_criteria[0];
	$order = $order_criteria[$1] if (defined(param('sort')) && param('sort') =~ m/^([0-5])$/);

	print(sprintf($get_server_names, $search, $order, $limit, $offset)) if param('debug') == 1;
	my $server_names_query = $conn->prepare(sprintf($get_server_names, $search, $order, $limit, $offset));
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
} elsif (param('txt') == 2) {
	my $summary_list = $conn->prepare($get_summary_query);
	$summary_list->execute() or web_error("Could not get summary list: $DBI::errstr");
	my @summary;
	push(@summary, ['Last hour', $summary_list->fetchrow_array]);
	push(@summary, ['Last 24 hours', $summary_list->fetchrow_array]);
	$result{'data'} = \@summary;
}

my $json = JSON::XS->new->ascii->pretty->allow_nonref;
print $json->encode(\%result);

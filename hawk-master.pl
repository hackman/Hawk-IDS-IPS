#!/usr/bin/perl -T
use strict;
use warnings;
use DBD::Pg;
use CGI qw(param);
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw(setsid), qw(strftime);	# use only setsid & strftime from POSIX
use File::Basename;
use lib '/var/lib/hawk/lib';
use parse_config;

# system variables
$ENV{PATH} = '';		# remove unsecure path
my $version = '0.1';		# version string

my $conf = '/etc/hawk-web.conf';
# make DB vars
my $html	= '';
my %config;
# changing to unbuffered output
our $| = 1;
sub web_error {
	print $_[0], "\n";
	exit 1;
}

%config = parse_config($conf);

sub get_template {
        my $out='';
        if (defined($_[0])) {
		my $template = $config{'template_path'}.basename($_[0]).'.tmpl';
                open FILE, '<', $template or die "Unable to open template $template: $!\n";
		$out .= $_ while (<FILE>);
                close FILE;
        }
        return $out;
}

print "Content-type: text/html\r\n\r\n";

# prepare the connection
our $conn	= DBI->connect_cached( $config{'db'}, $config{'dbuser'}, $config{'dbpass'}, { PrintError => 1, AutoCommit => 1 } ) 
	or web_error("Unable to connecto to DB: $DBI::errstr\n");
our $list = $conn->prepare("
	SELECT TO_CHAR(\"date\", 'DD.Mon.YYYY HH24:MI'), server, brutes0, brutes1, brutes2, failed0, failed1, failed2 
	FROM \"system\".hawk_stats ORDER BY ? DESC") or web_error("Unable to prepare list query: $DBI::errstr\n");
# our $clear_list = $conn->prepare("DELETE FROM \"system\".hawk_stats");
# our $add_stats = $conn->prepare("
# 	INSERT INTO \"system\".hawk_stats
# 	( server, brutes0, brutes1, brutes2, failed0, failed1, failed2 ) 
# 	VALUES ( ?, ?, ?, ?, ?, ?, ? )");
# our $servers = $conn->prepare("SELECT \"server\",\"ip\" FROM \"system\".sitecur ORDER BY server ASC") or web_error("Unable to prepare list query: $DBI::errstr\n");
my $out = get_template('main-master');
$out =~ s/__VER__/$version/gi;

print $out;

sub get_info {
	my $out = '';
	open SERV, sprintf('/usr/bin/lynx --dump http://%s/~sentry/cgi-bin/hawk-web.pl\?action=summary\&cgi=1 2>&1|', $_[0])
		or web_error("Unable to open $_[0]: $!\n");
	$out .= $_ while (<SERV>);
	close SERV;
	return $out;
}
if (defined(param('action')) && param('action') eq 'update') {
	$clear_list->execute;
	$servers->execute or web_error("Tegavo e: $DBI::errstr");
	while (my ($server, $ip) = $servers->fetchrow_array) {
		print "Checking $server($ip)...\n" if defined(param('debug'));
		my $out = get_info($ip);
		my @stats = split /\|/, $out;
		for (my $i=0;$i<=5;$i++) {
			$stats[$i] = '0' if (!defined($stats[$i]))
		}
		$stats[0] = '0' if ($out =~ /Unable/);
		$add_stats->execute($server,@stats) or web_error("Unable to execute add_stats: $DBI::errstr");
	}
}
# ID DATE SERVER BRUTES0 BRUTES1 BRUTES2 FAILED0 FAILED1 FAILED2
my $table = get_template('stats-list');
my @stats = $conn->selectrow_array("
	SELECT 
		SUM(brutes0) AS B0, 
		SUM(brutes1) AS B1, 
		SUM(brutes2) AS B2, 
		SUM(failed0) AS F0, 
		SUM(failed1) AS F1, 
		SUM(failed2) AS F2
	FROM \"system\".hawk_stats") or web_error("Unable to prepare list query: $DBI::errstr\n");
$table =~ s/__BRUTES0__/$stats[0]/;
$table =~ s/__BRUTES1__/$stats[1]/;
$table =~ s/__BRUTES2__/$stats[2]/;
$table =~ s/__FAILED0__/$stats[3]/;
$table =~ s/__FAILED1__/$stats[4]/;
$table =~ s/__FAILED2__/$stats[5]/g;

my $order='brutes0';
if (defined(param('sort'))) {
	if (param('sort') == 0) {
		$order='failed0';		
	} elsif (param('sort') == 1) {
		$order='brutes0';
	} elsif (param('sort') == 2) {
		$order='failed1';
	} elsif (param('sort') == 3) {
		$order='brutes1';
	} elsif (param('sort') == 4) {
		$order='failed2';
	} elsif (param('sort') == 5) {
		$order='brutes2';
	} elsif (param('sort') == 6) {
		$order='"server"';
	} elsif (param('sort') == 7) {
		$order='"bl1h-a"';
	} elsif (param('sort') == 8) {
		$order='"bl1d-a"';
	} elsif (param('sort') == 9) {
		$order='"bl1h-r"';
	} elsif (param('sort') == 10) {
		$order='"bl1d-r"';
	} else {
		$order='brutes0';
	}
}
our $list = $conn->prepare("
	SELECT TO_CHAR(\"date\", 'DD.Mon.YYYY HH24:MI'), server, brutes0, brutes1, brutes2, failed0, failed1, failed2,\"bl1h-a\",\"bl1d-a\",\"bl1h-r\",\"bl1d-r\" 
	FROM \"system\".hawk_stats ORDER BY $order DESC") or web_error("Unable to prepare list query: $DBI::errstr\n");

$list->execute or web_error("Unable to execute query: $DBI::errstr");
my $serv_count = $list->rows;
$table =~ s/__COUNT__/$serv_count/;
my %test_servers = (
	'clev9.com' => 1,
	'clev10.com' => 1,
	'clev11.com' => 1,
	'clev15.com' => 1,
	'siteground.net' => 1,
	'siteground12.com' => 1,
	'siteground118.com' => 1,
	'siteground120.com' => 1,
	'siteground121.com' => 1,
	'siteground122.com' => 1,
	'siteground123.com' => 1,
	'siteground125.com' => 1,
	'siteground126.com' => 1,
	'siteground127.com' => 1,
	'siteground128.com' => 1,
	'siteground129.com' => 1,
	'siteground132.com' => 1,
	'siteground133.com' => 1,
	'siteground136.com' => 1,
	'siteground139.com' => 1,
	'siteground143.com' => 1,
	'siteground149.com' => 1,
	'siteground150.com' => 1,
	'siteground153.com' => 1,
	'siteground160.com' => 1,
	'siteground162.com' => 1,
	'siteground164.com' => 1,
	'siteground166.com' => 1,
	'siteground167.com' => 1,
	'siteground169.com' => 1,
	'siteground171.com' => 1,
	'siteground175.com' => 1,
	'siteground177.com' => 1,
	'siteground179.com' => 1,
	'siteground180.com' => 1,
	'siteground181.com' => 1,
	'siteground182.com' => 1,
	'siteground184.com' => 1,
	'siteground187.com' => 1,
	'siteground188.com' => 1,
	'siteground191.com' => 1,
	'siteground192.com' => 1
);
my $line0 = '<tr>
	<td class=\'__CLASS__\'>__DATE__</td>
	<td class=\'__CLASS__\'><a href=\'http://__SERVER__/~sentry/cgi-bin/hawk-web.pl\'>__SERVER__</td>
	<td class=\'__CLASS__\'><a href=\'http://__SERVER__/~sentry/cgi-bin/hawk-web.pl?action=listfailed\'>__FAILED0__</a></td>
	<td class=\'__CLASS__\'><a href=\'http://__SERVER__/~sentry/cgi-bin/hawk-web.pl?action=listbroots\'>__BRUTES0__</a></td>
<!--	<td class=\'__CLASS__\'>__FAILED1__</td>
	<td class=\'__CLASS__\'>__BRUTES1__</td>
	<td class=\'__CLASS__\'>__FAILED2__</td>
	<td class=\'__CLASS__\'>__BRUTES2__</td> -->
	<td class=\'__CLASS__\'><a href=\'http://__SERVER__/~sentry/cgi-bin/hawk-web.pl?action=blacklist&only=act\'>__BL1HA__</a></td>
	<td class=\'__CLASS__\'><a href=\'http://__SERVER__/~sentry/cgi-bin/hawk-web.pl?action=blacklist&only=act\'>__BL1DA__</a></td>
	<td class=\'__CLASS__\'><a href=\'http://__SERVER__/~sentry/cgi-bin/hawk-web.pl?action=blacklist&only=rem\'>__BL1HR__</a></td>
	<td class=\'__CLASS__\'><a href=\'http://__SERVER__/~sentry/cgi-bin/hawk-web.pl?action=blacklist&only=rem\'>__BL1DR__</a></td>
</tr>';
my $lines = '';
while (my @str = $list->fetchrow_array) {
	$lines .= $line0;
	my $class = 'td0';
# 	$class='redtd' if ( exists $test_servers {$str[1]} );
	$lines =~ s/__CLASS__/$class/g;
	$lines =~ s/__DATE__/$str[0]/;
	$lines =~ s/__SERVER__/$str[1]/g;
	$lines =~ s/__BRUTES0__/$str[2]/;
	$lines =~ s/__BRUTES1__/$str[3]/;
	$lines =~ s/__BRUTES2__/$str[4]/;
	$lines =~ s/__FAILED0__/$str[5]/;
	$lines =~ s/__FAILED1__/$str[6]/;
	$lines =~ s/__FAILED2__/$str[7]/;
	for (my $z=8; $z<=11; $z++) {
		$str[$z] =~ s/.*\|//;
		$str[$z] =~ s/\s+/\&nbsp;/;
		$str[$z] = '&nbsp;' if ($str[$z] == 0);
	}
	$lines =~ s/__BL1HA__/$str[8]/;
	$lines =~ s/__BL1DA__/$str[9]/;
	$lines =~ s/__BL1HR__/$str[10]/;
	$lines =~ s/__BL1DR__/$str[11]/;
}
$table =~ s/__CONTENTS__/$lines/;
print $table;

exit 0;

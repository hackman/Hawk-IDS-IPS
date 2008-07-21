#!/usr/bin/perl -T
use strict;
use warnings;
use DBD::Pg;
use CGI qw(param);
use CGI::Carp qw(fatalsToBrowser);
use POSIX qw(setsid), qw(strftime);	# use only setsid & strftime from POSIX
use File::Basename;

# system variables
$ENV{PATH} = '';		# remove unsecure path
my $version = '0.95';		# version string

my $conf = '/home/sentry/hackman/hawk-web.conf';
# make DB vars
my $html	= '';
my %config;
# changing to unbuffered output
our $| = 1;
sub web_error {
	print $_[0], "\n";
	exit 1;
}
# parse the configuration file $conf into the hash %config
sub parse_conf {
	my %hash;
	die "No config defined!\n" if !defined($_[0]);
	open CONF, '<', $_[0] or die "Unable to open $_[0]: $!\n";
	while (<CONF>) {
		if ($_ =~ /^#/ or $_ =~ /^[\s]*$/) {
			# if this is a comment
			# or blank line
			# skip to next line
			next;
		} else {
			# clean unwanted chars
			$_ =~ s/[\r|\n]$//;
			$_ =~ s/([\s]*=[\s]*){1}/=/;
			my $key = my $val = $_;
			$key =~ s/=.*//;
			$val =~ s/.*?=//;
			$hash{$key} = $val;
		}
	}
	close CONF;
	return %hash;
}
%config = parse_conf($conf);

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

sub build_graph {
	# lines should be in this format
	# [0] - option name
	# [1] - option color
	# [2] - option value
	my @values = @_;
	my $graph = get_template('graphs');
	my $xml = get_template('graphs-xml');
	my $option = "<set name='%s' color='%s' value='%s'/>\n";
	my $options = '';
	my @colors = ( 'AFD8F8', 'F6BD0F', '8BBA00', 'A66EDD', 
		'F984A1', 'CCCC00', '999999', '0099CC', 'FF0000', 
		'006F00', '0099FF', 'FF66CC', '669966', '7C7CB4', 
		'FF9933', '9900FF', '99FFCC', 'CCCCFF', '669900', 
		'1941A5', 'FFFF99', 'FFFF00', 'FFCC00', 'FF9966', 
		'FF9999', 'FF6600', 'FF00FF', 'CCCCFF', 'CC3333', 
		'CC0000', '99CCFF', '6666FF', '33FF33', '339900', 
		'00CCCC', '99CC33');
	$xml =~ s/__XNAME__/$values[0][0]/;
	$xml =~ s/__YNAME__/$values[0][1]/;
	$xml =~ s/__TITLE__/$values[0][2]/;
	for (my $i=1; $i<=7;$i++) {
		$options .= sprintf($option, $values[$i][0], $colors[$values[$i][1]], $values[$i][2]) if defined($values[$i][0]);;
	}
	$xml =~ s/__OPTIONS__/$options/;
	$graph =~ s/__XML__/$xml/g;
	return $graph;
}

sub get_service_num {
	if ($_[0] eq 'pop3') {
		return '0';
	} elsif ($_[0] eq 'imap') {
		return '1';
	} elsif ($_[0] eq 'ftp') {
		return '2';
	} elsif ($_[0] eq 'ssh') {
		return '3';
	} elsif ($_[0] eq 'cp_panel') {
		return 4;
	} elsif ($_[0] eq 'cp_webmail') {
		return 5;
	}
}
sub get_num_service {
	if ($_[0] == 0) {
		return 'pop3';
	} elsif ($_[0] == 1) {
		return 'imap';
	} elsif ($_[0] == 2) {
		return 'ftp';
	} elsif ($_[0] == 3) {
		return 'ssh';
	} elsif ($_[0] == 4) {
		return 'cp_panel';
	} elsif ($_[0] == 5) {
		return 'cp_webmail';
	}
}


print "Content-type: text/html\r\n\r\n";

# prepare the connection
our $conn	= DBI->connect( $config{'db'}, $config{'dbuser'}, $config{'dbpass'}, { PrintError => 1, AutoCommit => 1 } ) 
	or web_error("Unable to connecto to DB: $!\n");
my $action='';
$action=param('action') if defined(param('action'));
if (!defined(param('cgi'))) {
	my $out = get_template('main');
	$out =~ s/__VER__/$version/gi;
	print $out;
}
if ($action eq 'listfailed') {
# 	header('listfailed');
	my $table .= get_template('failed');
	my $lines = '';
	my $line0 = "<tr><td class='td0'>__DATE__</td><td class='td0'><a href='?action=search&w=ip&addr=__IP__'>__IP__</a></td><td class='td0'><a href='?action=stat&w=sv&ss=__SERVICE__</a></td><td class='td0'><a href='?action=search&w=us&user=__USER__'>__USER__</td></tr>";
	my $order = '"date"';
	if (defined(param('order'))) {
		if (param('order') == 1) {
			$order = 'ip';
		} elsif (param('order') == 2) {
			$order = 'service';
		} elsif (param('order') == 3) {
			$order = '"user"';	
		} else {
			$order = '"date"';
		}
	}
	my $get_failed = $conn->prepare("SELECT TO_CHAR(\"date\", 'DD.Mon.YYYY HH24:MI') AS \"date\",ip,service,\"user\" FROM failed_log WHERE \"date\" > (now() - interval '12 hour') ORDER BY $order DESC") 
		or web_error("Unable to prepare get_broots: $DBI::errstr");
	$get_failed->execute;
	while (my ($date,$ip,$service,$user) = $get_failed->fetchrow_array) {
		my $line = $line0;
		my $service_num = get_service_num($service);
		$user =~ s/[\<\>]/_/g;
		$line =~ s/__DATE__/$date/;		
		$line =~ s/__IP__/$ip/g;		
		$line =~ s/__SERVICE__/$service_num\'>$service/;
		$line =~ s/__USER__/$user/g;
		$lines .= $line;
	}
	$table =~ s/__CONTENTS__/$lines/;
	$html .= $table;
} elsif ($action eq 'listbroots') {
# 	header('listbroots');
	my $table = get_template('broots');
	my $lines = '';
	my $line0 = "<tr><td class='td0'>__DATE__</td><td class='td0'><a href='?action=search&w=ip&addr=__IP__'>__IP__</a></td><td class='td0'><a href='?action=stat&w=sv&ss=__SERVICE__</a></td></tr>\n";
	my $order = '"date"';
	if (defined(param('order'))) {
		if (param('order') == 1) {
			$order = 'ip';
		} elsif (param('order') == 2) {
			$order = 'service';
		} else {
			$order = '"date"';
		}
	}
	my $get_broots = $conn->prepare("SELECT to_char(\"date\", 'DD.Mon.YYYY HH24:MI') AS \"date\",ip,service FROM broots WHERE \"date\" > (now() - interval '12 hour') ORDER BY $order DESC") 
		or web_error("Unable to prepare get_broots: $DBI::errstr");
	$get_broots->execute;
	while (my ($date,$ip,$service) = $get_broots->fetchrow_array) {
		my $line = $line0;
		my $service_num = get_service_num($service);
		$line =~ s/__DATE__/$date/;		
		$line =~ s/__IP__/$ip/g;		
		$line =~ s/__SERVICE__/$service_num\'>$service/;
		$lines .= $line;
	}
	$table =~ s/__CONTENTS__/$lines/;
	$html .= $table;
} elsif ($action eq 'search') {
# 	header('search');
	print get_template('search');
	if (defined(param('w'))) {
		my $query = '';
		my @values;
		if ( param('w') eq 'ip' && param('addr') =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ ) {
			# search for IP
 			$query = "SELECT TO_CHAR(\"date\", 'DD.Mon.YYYY HH24:MI') AS \"date\",ip,\"user\",service FROM failed_log WHERE ip = ? ORDER BY \"date\" DESC LIMIT ?";
			push @values, param('addr');
		} elsif ( param('w') eq 'tp' && param('from') =~ /^[0-9:\.\-\s]+$/ && param('to') =~ /^[0-9:\.\-\s]+$/ ) {
# 			$query = sprintf("SELECT \"date\",ip,\"user\",service FROM failed_log WHERE \"date\" BETWEEN TO_DATE('%s') AND TO_DATE('%s') ORDER BY \"date\" DESC", param('from'), param('to'));
			# search for time period
 			$query = "SELECT TO_CHAR(\"date\", 'DD.Mon.YYYY HH24:MI') AS \"date\",ip,\"user\",service FROM failed_log WHERE \"date\" BETWEEN TO_DATE( ? ) AND TO_DATE( ? ) ORDER BY \"date\" DESC LIMIT ?";
			push @values, param('from');
			push @values, param('to');
		} elsif ( param('w') eq 'us' && param('user') =~ /^[a-zA-Z0-9\.\@\-]+$/ ) {
			# search for user
 			$query = "SELECT TO_CHAR(\"date\", 'DD.Mon.YYYY HH24:MI') AS \"date\",ip,\"user\",service FROM failed_log WHERE \"user\" ~ ? ORDER BY \"date\" DESC LIMIT ?";
			push @values, param('user');	
		} elsif ( param('w') eq 'sv' && param('ss') =~ /^[0-9]+$/ ) {
			# search for service
 			$query = "SELECT TO_CHAR(\"date\", 'DD.Mon.YYYY HH24:MI') AS \"date\",ip,\"user\",\"service\" FROM failed_log WHERE \"service\" = ? ORDER BY \"date\" DESC LIMIT ?";
			my $service = get_num_service(param('ss'));
			push @values, $service;			
		} else {
			print "<h2 align=center><b>Invalid parameters!</b></h2>";
		}
		if ( defined(param('lim')) && param('lim') =~ /^[0-9+]$/ ) {
			push @values, param('lim');
		} else {
			push @values, 200; # default LIMIT for the SQL queryes		
		}
		# minimum parameters 2 VALUE & LIMIT
		if (defined($values[1])) {
			my $get_info = $conn->prepare($query) or web_error("Unable to prepare query: $DBI::errstr");
			$get_info->execute(@values) or web_error("Unable to execute query: $DBI::errstr");
			my $lines='';
			my $line0 = "<tr><td class='td0'>__DATE__</td><td class='td0'><a href='?action=search&w=ip&addr=__IP__'>__IP__</td><td class='td0'><a href='?action=search&w=us&user=__USER__'>__USER__</a></td><td class='td0'>__SERVICE__</td></tr>\n";
			print "<br /><table cellspacing=0 cellpadding=0 class='broots'>
	<tr>
	<td class='td-top'><b>Date</b></td>
	<td class='td-top'><b>IP Address</b></td>
	<td class='td-top'><b>User<b></td>
	<td class='td-top'><b>Service</b></td>
	</tr>";

			while ( my @str =  $get_info->fetchrow_array) {
				my $line = $line0;	
				$str[2] = '&nbsp;' if (!defined($str[2]) || $str[2] eq '');
				$str[2] =~ s/[\<\>]/_/g;
				$line =~ s/__DATE__/$str[0]/;
				$line =~ s/__IP__/$str[1]/g;
				$line =~ s/__USER__/$str[2]/g;
				$line =~ s/__SERVICE__/$str[3]/;
				print $line;
			}
			print '</table>';
		}
	}
} elsif ($action eq 'blacklist') {
	print get_template('blacklist');
	my $query ='';
	my @values;
	my $type = 1;
	if (	defined(param('w')) && 
		defined(param('addr')) && 
		param('w') eq 'ip' && 
		param('addr') =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/ ) {
 		$query = "SELECT TO_CHAR(date_add, 'DD.Mon.YYYY HH24:MI') AS date_add,date_rem,ip,reason FROM blacklist WHERE ip = ? ORDER BY date_add DESC LIMIT ?";
		push @values,  param('addr');
		$type = 0;
	} else {
		if (defined(param('only')) && param('only') eq 'rem') {
			$query = "SELECT 
			TO_CHAR(date_add, 'DD.Mon.YYYY HH24:MI') AS date_add, TO_CHAR(date_rem, 'DD.Mon.YYYY HH24:MI') AS date_rem,ip,reason 
			FROM blacklist 
			WHERE date_rem IS NOT NULL AND date_rem > (now() - interval '24 hour')
			ORDER BY date_add DESC LIMIT ?";
		} elsif (defined(param('only')) && param('only') eq 'act') {
			$query = "SELECT 
			TO_CHAR(date_add, 'DD.Mon.YYYY HH24:MI') AS date_add, TO_CHAR(date_rem, 'DD.Mon.YYYY HH24:MI') AS date_rem,ip,reason 
			FROM blacklist 
			WHERE date_rem IS NULL AND date_add > (now() - interval '24 hour')
			ORDER BY date_add DESC LIMIT ?";
		} else {
			$query = "SELECT TO_CHAR(date_add, 'DD.Mon.YYYY HH24:MI') AS date_add, TO_CHAR(date_rem, 'DD.Mon.YYYY HH24:MI') AS date_rem,ip,reason FROM blacklist ORDER BY date_add DESC LIMIT ?";
		}
	}
	if ( defined(param('lim')) && param('lim') =~ /^[0-9+]$/ ) {
		push @values,  param('lim');
	} else {
		push @values, 200; # default LIMIT for the SQL queryes		
	}
	my $get_info = $conn->prepare($query) or web_error("Unable to prepare query: $DBI::errstr");
	$get_info->execute(@values) or web_error("Unable to execute query: $DBI::errstr");
	my $lines='';
	my $line0 = "<tr><td class='td0'>__DATE0__</td><td class='td0'>__DATE1__</td><td class='td0'><a href='?action=search&w=ip&addr=__IP__'>__IP__</a></td><td class='td0'>__REASON__</td></tr>\n";
	if ($type) {
		print "<h3>Listing the blacklist for the last 26 hours(limited to the first 200 entries):</h3>";
	} else {
		print "<h3>Listing search results(limited to the first 200 entries):</h3>";
	}
	print "<table cellspacing=0 cellpadding=0 class='broots'>
	<tr>
	<td class='td-top'><b>Date added</b></td>
	<td class='td-top'><b>Date removed</b></td>
	<td class='td-top'><b>IP Address</b></td>
	<td class='td-top' align=left><b>Reason<b></td>
	</tr>";

	while ( my @str =  $get_info->fetchrow_array) {
		my $line = $line0;		
		my $val = $str[1];
		$val = 'none' if ($str[1] eq '');
		$line =~ s/__DATE0__/$str[0]/;
		$line =~ s/__DATE1__/$val/;
		$line =~ s/__IP__/$str[2]/g;
		$line =~ s/__REASON__/$str[3]/;
		print $line;
	}
	print '</table>';
} elsif ($action eq 'stat') {
	my $query ='';
	if (	defined(param('w')) && 
		defined(param('ss')) && 
		param('w') eq 'sv' && 
		param('ss') =~ /^[0-9]+$/ ) {
		my $service = get_num_service(param('ss'));
		web_error('Unknown service') if !defined($service);
		my $sort = 'count';
		if (defined(param('sort'))) {
			$sort = 'ip' if param('sort') == 0;
		}
 		my $query1 = "SELECT ip,COUNT(ip) AS count FROM failed_log WHERE \"service\" ~ '$service' AND \"date\" > (now() - interval '1 hour') GROUP BY ip ORDER BY $sort DESC";
 		my $query24 = "SELECT ip,COUNT(ip) AS count FROM failed_log WHERE \"service\" ~ '$service' AND \"date\" > (now() - interval '24 hour') GROUP BY ip ORDER BY $sort DESC";
		my $get_info1 = $conn->prepare($query1) or web_error("Unable to prepare query: $DBI::errstr");
		my $get_info24 = $conn->prepare($query24) or web_error("Unable to prepare query: $DBI::errstr");
		$get_info1->execute() or web_error("Unable to execute query: $DBI::errstr");
		my $script = "
<script>
function sort(val) {
	var url = document.location.href;
	var search = /\&sort=[0-9]/;
	if (search.test(url)) {
		alert('String found!');
		url = url.replace(/\&sort\=[0-9]/, '');
	}
	window.location = url  + '&sort=' + val;
}
</script>
";
		my $table = "<h3>Listing results for service %s(last 1 %s):</h3>
<table cellspacing=0 cellpadding=0 class='broots'>
<tr>
<td class='td-top'><a href='javascript: sort(0)'>IP Address</a></td>
<td class='td-top'><a href='javascript: sort(1)'><b>Failed count</a></td>
</tr>\n";
		print $script;
		printf $table, $service, 'hour';
		my $lines='';
		my $line0 = "<tr><td class='td0'><a href='?action=search&w=ip&addr=__IP__'>__IP__</a></td><td class='td0'>__COUNT__</td></tr>\n";
		while ( my @str =  $get_info1->fetchrow_array) {
			my $line = $line0;		
			$line =~ s/__IP__/$str[0]/g;
			$line =~ s/__COUNT__/$str[1]/;
			print $line;
		}
		print '</table>';
		$get_info1->execute() or web_error("Unable to execute query: $DBI::errstr");
		printf $table, $service, 'day';
		while ( my @str =  $get_info24->fetchrow_array) {
			my $line = $line0;		
			$line =~ s/__IP__/$str[0]/;
			$line =~ s/__COUNT__/$str[1]/;
			print $line;
		}
		print '</table>';


	}

} else {
	my $lines = '';
	my $line0 = "<tr><td>__DATE__</td><td>__COUNT__</td></tr>\n";
	my $line1 = "<tr><td>__SSH__</td><td>__FTP__</td><td>__POP3__</td><td>__IMAP__</td><td>__CPANEL__</td><td>__WEBMAIL__</td></tr>\n";
	my $line2 = "<tr><td><a href=\"?action=search\&w=ip\&addr=__IP__\">__IP__</a></td></tr>\n";

	# last 1 hour
	my $broots0 = $conn->selectrow_array("
		SELECT COUNT(id) AS id 
		FROM broots 
		WHERE date > (now() - interval '1 hour')");
	my $failed0 = $conn->selectrow_array("
		SELECT COUNT(id) AS id 
		FROM failed_log 
		WHERE date > (now() - interval '1 hour')");
	my $broots1 = $conn->prepare("SELECT 
		TO_CHAR(\"date\", 'YY-MM-DD') AS ddate, COUNT( id ) AS count 
		FROM broots
		GROUP BY TO_CHAR(\"date\", 'YY-MM-DD')
		ORDER BY TO_CHAR(\"date\", 'YY-MM-DD') DESC LIMIT 7");
	my $failed1 = $conn->prepare("SELECT 
		TO_CHAR(\"date\", 'YY-MM-DD') AS ddate, COUNT( id ) AS count
		FROM failed_log
		GROUP BY TO_CHAR(\"date\", 'YY-MM-DD')
		ORDER BY TO_CHAR(\"date\", 'YY-MM-DD') DESC LIMIT 7");

	my $blacklisted_1h_active = $conn->selectrow_array("SELECT 
		COUNT(id) AS count 
		FROM blacklist 
		WHERE date_add > (now() - interval '1 hour') AND date_rem IS NULL");
	my $blacklisted_1h_removed = $conn->selectrow_array("SELECT 
		COUNT(id) AS count 
		FROM blacklist 
		WHERE date_add > (now() - interval '1 hour') AND date_rem IS NOT NULL");
 	my @blacklisted_days_active0 = $conn->selectrow_array("SELECT 
 		COUNT(id) AS count 
 		FROM blacklist 
 		WHERE date_rem IS NULL AND date_add > (now() - interval '24 hour') "); 
 	my @blacklisted_days_removed0 = $conn->selectrow_array("SELECT 
		COUNT(id)
 		FROM blacklist 
 		WHERE date_rem IS NOT NULL AND date_rem > (now() - interval '24 hour')");
	my $blacklisted_days_active = $conn->prepare("SELECT 
		TO_CHAR(date_add, 'YYYY-MM-DD') AS date_add, COUNT(TO_CHAR(date_add, 'YYYY-MM-DD')) AS count 
		FROM blacklist 
		WHERE date_rem IS NULL
		GROUP BY TO_CHAR(date_add, 'YYYY-MM-DD') 
		ORDER BY TO_CHAR(date_add, 'YYYY-MM-DD') DESC LIMIT ?");
	my $blacklisted_days_removed = $conn->prepare("SELECT 
		TO_CHAR(date_add, 'YYYY-MM-DD') AS date_add, COUNT(TO_CHAR(date_add, 'YYYY-MM-DD')) AS count 
		FROM blacklist 
		WHERE date_rem IS NOT NULL
		GROUP BY TO_CHAR(date_add, 'YYYY-MM-DD') 
		ORDER BY TO_CHAR(date_add, 'YYYY-MM-DD') DESC LIMIT 1");

	if (defined(param('cgi'))) {
		print "$broots0|$failed0|0:$blacklisted_1h_active|0:$blacklisted_days_active0[1]|1:$blacklisted_1h_removed|1:$blacklisted_days_removed0[1]";
# 		$blacklisted_days_active->execute('1');
# 		while (my ($date, $count) = $blacklisted_days_active->fetchrow_array) {
# 			print "|0:$date:$count";
# 		}
# 		print "|1:$blacklisted_1h_removed";
# 		$blacklisted_days_removed->execute('1');
# 		while (my ($date, $count) = $blacklisted_days_removed->fetchrow_array) {
# 			print "|1:$date:$count";
# 		}
		print "\n";
	} else {
		my $brutes1 = $conn->prepare("
			SELECT DISTINCT ip FROM broots
			WHERE date > (now() - interval '1 hour') ORDER BY ip");
		my $brutes24 = $conn->prepare("
			SELECT DISTINCT ip FROM broots
			WHERE date > (now() - interval '1 day') ORDER BY ip");
		my $brutes7 = $conn->prepare("
			SELECT DISTINCT ip FROM broots
			WHERE date > (now() - interval '7 day') ORDER BY ip");
  		my $ftp = $conn->selectrow_array('SELECT COUNT(id) FROM failed_log 
 			WHERE service = \'ftp\' AND date > (now() - interval \'1 hour\')');
 		my $ssh = $conn->selectrow_array('SELECT COUNT(id) FROM failed_log 
 			WHERE service = \'ssh\' AND date > (now() - interval \'1 hour\')');
		my $pop3 = $conn->selectrow_array('SELECT COUNT(id) FROM failed_log 
			WHERE service = \'pop3\' AND date > (now() - interval \'1 hour\')');
		my $imap = $conn->selectrow_array('SELECT COUNT(id) FROM failed_log 
			WHERE service = \'imap\' AND date > (now() - interval \'1 hour\')');
		my $cpanel = $conn->selectrow_array('SELECT COUNT(id) FROM failed_log 
			WHERE service = \'cp_panel\' AND date > (now() - interval \'1 hour\')');
		my $webmail = $conn->selectrow_array('SELECT COUNT(id) FROM failed_log 
			WHERE service = \'cp_webmail\' AND date > (now() - interval \'1 hour\')');
		$html .= get_template('summary');

		my $i=2;
		my @values0;
		my $lines_0 .= $line0;
		$lines_0 =~ s/__DATE__/last 1 hour/;
		$lines_0 =~ s/__COUNT__/$failed0/;
		$values0[0][0] = 'Date';
		$values0[0][1] = 'attempts count';
		$values0[0][2] = 'Failed count for the last 7 days';
		$values0[1][0] = 'last 1 hour';
		$values0[1][1] = '0';
		$values0[1][2] = $failed0;
		$failed1->execute();
		while (my ($date, $count) = $failed1->fetchrow_array) {
			$lines_0 .= $line0;
			$lines_0 =~ s/__DATE__/$date/;
			$lines_0 =~ s/__COUNT__/$count/;
			$values0[$i][0]=$date;
			$values0[$i][1]=$i;
			$values0[$i][2]=$count;
			$i++;
		}
		my $graph0 = build_graph(@values0);


		my @values1;
		my $lines_1 .= $line0;
		$lines_1 =~ s/__DATE__/last 1 hour/;
		$lines_1 =~ s/__COUNT__/$broots0/;
		$values1[0][0] = 'Date';
		$values1[0][1] = 'attempts count';
		$values1[0][2] = 'Bruteforce attempts for the last 7 days';	
		$values1[1][0] = 'last 1 hour';
		$values1[1][1] = '0';
		$values1[1][2] = $broots0;
		$i=2;
		$broots1->execute();
		while (my ($date, $count) = $broots1->fetchrow_array) {
			$lines_1 .= $line0;
			$lines_1 =~ s/__DATE__/$date/;
			$lines_1 =~ s/__COUNT__/$count/;
			$values1[$i][0]=$date;
			$values1[$i][1]=$i;
			$values1[$i][2]=$count;
			$i++;
		}
		my $graph1 = build_graph(@values1);
		my $lines_2 = $line0;
		$lines_2 =~ s/__DATE__/last 1 hour/;
		$lines_2 =~ s/__COUNT__/$blacklisted_1h_active/;
		$blacklisted_days_active->execute('3');
		while (my ($date, $count) = $blacklisted_days_active->fetchrow_array) {
			$lines_2 .= $line0;
			$lines_2 =~ s/__DATE__/$date/;
			$lines_2 =~ s/__COUNT__/$count/;
		}
		my $lines_3 = $line0;
		$lines_3 =~ s/__DATE__/last 1 hour/;
		$lines_3 =~ s/__COUNT__/$blacklisted_1h_removed/;
		$blacklisted_days_removed->execute('3');
		while (my ($date, $count) = $blacklisted_days_removed->fetchrow_array) {
			$lines_3 .= $line0;
			$lines_3 =~ s/__DATE__/$date/;
			$lines_3 =~ s/__COUNT__/$count/;
		}

		$html =~ s/__TABLE0__/$lines_0/;
		$html =~ s/__TABLE1__/$lines_1/;
		$html =~ s/__GRAPH0__/$graph0/ig;
		$html =~ s/__GRAPH1__/$graph1/ig;
		$html =~ s/__TABLE6__/$lines_2/;
		$html =~ s/__TABLE7__/$lines_3/;
		

		$line1 =~ s/__FTP__/$ftp/;
		$line1 =~ s/__SSH__/$ssh/;
		$line1 =~ s/__POP3__/$pop3/;
		$line1 =~ s/__IMAP__/$imap/;
		$line1 =~ s/__CPANEL__/$cpanel/;
		$line1 =~ s/__WEBMAIL__/$webmail/;
		$html =~ s/__TABLE2__/$line1/;
		
		$lines = '';
		$brutes1->execute;
		while ( my $ip =  $brutes1->fetchrow_array) {
			$lines .= $line2;		
			$lines =~ s/__IP__/$ip/g;
		}
		$html =~ s/__TABLE3__/$lines/g;
		$lines = '';
		$brutes24->execute;
		while ( my $ip =  $brutes24->fetchrow_array) {
			$lines .= $line2;		
			$lines =~ s/__IP__/$ip/g;
		}
		$html =~ s/__TABLE4__/$lines/g;
		$lines = '';
		$brutes7->execute;
		while ( my $ip =  $brutes7->fetchrow_array) {
			$lines .= $line2;		
			$lines =~ s/__IP__/$ip/g;
		}
		$html =~ s/__TABLE5__/$lines/g;
	}
}
print $html,"\n";
exit 0;

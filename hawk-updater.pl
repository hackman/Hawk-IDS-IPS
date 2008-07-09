#!/usr/bin/perl -T
use strict;
use warnings;
use DBD::Pg;
use POSIX qw(setsid), qw(strftime);	# use only setsid & strftime from POSIX

# system variables
$ENV{BASH_ENV}='';
$ENV{PATH} = '';		# remove unsecure path
my $version = '0.1';		# version string

my $conf = '/home/sentry/hackman/hawk-web.conf';
# make DB vars
my %config;
# changing to unbuffered output
our $| = 1;
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


# prepare the connection
our $local	= DBI->connect_cached( $config{'db'}, $config{'dbuser'}, $config{'dbpass'}, { PrintError => 1, AutoCommit => 1 } ) 
	or die("Unable to connecto to DB: $DBI::errstr\n");
our $clear_list = $local->prepare("DELETE FROM \"system\".hawk_stats");
our $add_stats = $local->prepare("
	INSERT INTO \"system\".hawk_stats
	( server, brutes0, brutes1, brutes2, failed0, failed1, failed2 ) 
	VALUES ( ?, ?, ?, ?, ?, ?, ? )");
our $servers = $local->prepare("SELECT \"server\",\"ip\" FROM \"system\".sitecur ORDER BY server ASC") or die("Unable to prepare list query: $DBI::errstr\n");

sub get_info {
	my $out = '';
	open SERV, sprintf('/usr/bin/lynx --dump http://%s/~sentry/cgi-bin/hawk-web.pl\?action=summary\&cgi=1 2>&1|', $_[0])
		or die("Unable to open $_[0]: $!\n");
	$out .= $_ while (<SERV>);
	close SERV;
	return $out;
}
$clear_list->execute;
$servers->execute or die("Tegavo e: $DBI::errstr");
while (my ($server, $ip) = $servers->fetchrow_array) {
	print "Checking $server($ip)...\n";
	my $out = get_info($ip);
	my @stats = split /\|/, $out;
	for (my $i=0;$i<=5;$i++) {
		$stats[$i] = '0' if (!defined($stats[$i]))
	}
	$stats[0] = '0' if ($out =~ /Unable/);
	$add_stats->execute($server,@stats) or die("Unable to execute add_stats: $DBI::errstr");
}



exit 0;

#!/usr/bin/perl -T
use strict;
use warnings;
use DBD::mysql;
use POSIX qw(setsid), qw(strftime);	# use only setsid & strftime from POSIX

# system variables
$ENV{PATH} = '';		# remove unsecure path
my $version = '0.1';	# version string

# Hawk files
my $logfile = '/var/log//hawk.log';	# daemon logfile
my $pidfile = '/var/run/hawk.pid';	# daemon pidfile
my $ioerrfile = '/home/sentry/public_html/io.err'; # File where to add timestamps for I/O Errors
my $log_list = '/usr/bin/tail -f /var/log/messages |';
our $debug = 0;			# by default debuging is OFF

my $start_time = time();

# check for debug
if ( defined($ARGV[0]) && $ARGV[0] =~ /debug/ ) {
	$debug=1;		# turn on debuging
}

# changing to unbuffered output
our $| = 1;

# Change program name
$0 = "[Hawk]";

# open the logfile
open HAWK, '>>', $logfile or die "DIE: Unable to open logfile $logfile: $!\n";
logger("Hawk version $version started!");
#print HAWK get_time(), " Hawk version $version started!\n";


# execute this before DIE-ing :)
$SIG{__DIE__}  = sub { logger(@_); };

# check if the daemon is running
if ( -e $pidfile ) {
        # get the old pid
        open PIDFILE, '<', $pidfile or die "DIE: Can't open pid file($pidfile): $!\n";
	my $old_pid = <PIDFILE>;
        close PIDFILE;
        # check if $old_pid is still running
	if ( $old_pid =~ /[0-9]+/ ) {
		if ( -d "/proc/$old_pid" ) {
			logger("Hawk is already running!");
			die "DIE: Hawk is already running!\n";
	        }
	} else {
		logger("Incorrect pid format!");
		die "DIE: Incorrect pid format!\n";
	}
}

# generate time format: 15.May.07 02:41:52
sub get_time {
	return strftime('%b %d %H:%M:%S', localtime(time));
}

sub logger {
	print HAWK strftime('%b %d %H:%M:%S', localtime(time)) . ' ' . $_[0] . "\n";
}

# Fork to background
defined(my $pid=fork) or die "DIE: Cannot fork process: $! \n";
exit if $pid;
setsid or die "DIE: Unable to setsid: $!\n";
umask 0;

# redirect standart file descriptors to /dev/null
open STDIN, '</dev/null' or die "DIE: Cannot read stdin: $! \n";
open STDOUT, '>>/dev/null' or die "DIE: Cannot write to stdout: $! \n";
if (!$debug) {
	open STDERR, '>>/dev/null' or die "DIE: Cannot write to stderr: $! \n";
}

# write the program pid to the $pidfile
open PIDFILE, '>', $pidfile or die "DIE: Unable to open pidfile $pidfile: $!\n";
print PIDFILE $$;
close PIDFILE;

# open logs
open LOGS, $log_list or die "DIE: Unable to open logs: $!\n";

# make the output unbuffered
select((select(HAWK), $| = 1)[0]);
select((select(LOGS), $| = 1)[0]);


while (<LOGS>) {
	# Feb 13 19:18:35 serv01 kernel: end_request: I/O error, dev sdb, sector 1405725148
	# Feb 13 19:18:58 serv01 kernel: end_request: I/O error, dev sdb, sector 1405727387 
	if ( $_ =~ /I\/O error/i ) {
		my @line = split /\s+/, $_;
		open IOERR, '>', $ioerrfile or logger('Unable to log I/O Error');
		print IOERR get_time() . "$line[9]\n";
		close IOERR;
 	} else {
		next;
	}
}
close LOGS;
close HAWK;
close STDIN;
close STDOUT;
if (!$debug) {
	close STDERR;
}
exit 0;

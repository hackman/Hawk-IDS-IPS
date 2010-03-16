#!/usr/bin/perl -T

use strict;
use warnings;

use DBD::mysql;
use POSIX qw(setsid), qw(strftime), qw(WNOHANG);

require "/usr/local/sbin/parse_config.pm";

import parse_config;

# system variables
$ENV{PATH} = '';		# remove unsecure path
my $VERSION = '3.0.1';	# version string

# defining fault hashes
my %ssh_faults = ();				# ssh faults storage
my %ftp_faults = ();				# ftp faults storage
my %pop3_faults = ();				# pop3 faults storage
my %imap_faults = ();				# imap faults storage
my %smtp_faults = ();				# smtp faults storage
my %cpanel_faults = ();				# cpanel faults storage
my %notifications = ();				# notifications
my %possible_attackers = ();		# possible hack attempts

my $conf = '/home/sentry/hackman/hawk-web.conf';
my %config = parse_config($conf);

# Hawk files
my $logfile = '/var/log/hawk.log';	# daemon logfile
my $pidfile = '/var/run/hawk.pid';	# daemon pidfile
my $log_list = '/usr/bin/tail -s 1.00 -F --max-unchanged-stats=30 \
					/var/log/messages \
					/var/log/secure \
					/var/log/maillog \
					/usr/local/cpanel/logs/login_log |';

my $broot_time = 300;				# time(in seconds) before cleaning the hashes
my $clean_reported = 600;
my $max_attempts = 5;				# max number of attempts(for $broot_time) before notify

my $debug = 1;						# by default debuging is OFF
my $do_limit = 0;					# by default do not limit the offending IPs
my $start_time = time();

my $fw_time = $start_time;
my $hostname = '';
my %service_codes = split(/[:\s]/, $config{'service_ids'});

# check for debug
if (defined($ARGV[0])) {
	if ($ARGV[0] =~ /debug/) {
		$debug=1;					# turn on debuging
	}
}

open HOST, '<', '/proc/sys/kernel/hostname' or die "Unable to open hostname file: $!\n";
$hostname = <HOST>;
close HOST;
$hostname =~ s/serv01.//;
chomp ($hostname);

# changing to unbuffered output
our $| = 1;

# Change program name
$0 = "[Hawk]";

# open the logfile
open HAWK, '>>', $logfile or die "DIE: Unable to open logfile $logfile: $!\n";
my $myip = get_ip();
my %never_block = ("$myip" => 1, "127.0.0.1" => 1);

sub logger {
	print HAWK strftime('%b %d %H:%M:%S', localtime(time)) . ' ' . $_[0] . "\n";
}


logger("Hawk version $VERSION started!");

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

# get the server IP address
sub get_ip {
	my @ip;
	open IP, "/sbin/ip a l |" or die "DIE: Unable to get local IP Address: $!\n";
	while (<IP>) {
		if ( $_ =~ /eth0$/) {
			@ip = split /\s+/, $_;
			$ip[2] =~ s/\/[0-9]+//;
			logger("Server ip: $ip[2]") if ($debug);
		}
	}
	close IP;
	return $ip[2]
}

# clean the hashes
sub cleanh {
	delete @ftp_faults{keys %ftp_faults};
	delete @ssh_faults{keys %ssh_faults};
	delete @pop3_faults{keys %pop3_faults};
	delete @imap_faults{keys %imap_faults};
	delete @cpanel_faults{keys %cpanel_faults};
	delete @notifications{keys %notifications};
	logger("All faults hashes cleaned!") if ($debug);
}

# check for broots
sub check_broot {
	while ( my ($k,$v) = each (%ssh_faults) ) {
		notify('ssh', $k, $ssh_faults{$k}) if ( $v > $max_attempts );
	}
	while ( my ($k,$v) = each (%pop3_faults) ) {
		notify('pop3', $k, $v) if ( $v >= $max_attempts );
	}
	while ( my ($k,$v) = each (%imap_faults) ) {
		notify('imap', $k, $imap_faults{$k}) if ( $v > $max_attempts );
	}
	while ( my ($k,$v) = each (%smtp_faults) ) {
		notify('imap', $k, $smtp_faults{$k}) if ( $v > $max_attempts );
	}
	while ( my ($k,$v) = each (%cpanel_faults) ) {
		notify('cPanel', $k, $cpanel_faults{$k}) if ( $v > $max_attempts );
	}
	while ( my ($k,$v) = each (%ftp_faults) ) {
		notify('ftp', $k, $ftp_faults{$k}) if ( $v > $max_attempts );
	}
}

# Fork to background
defined(my $pid=fork) or die "DIE: Cannot fork process: $! \n";
exit if $pid;
setsid or die "DIE: Unable to setsid: $!\n";
umask 0;

# redirect standart file descriptors to /dev/null
open STDIN, '<', '/dev/null' or die "DIE: Cannot read stdin: $! \n";
open STDOUT, '>>', '/dev/null' or die "DIE: Cannot write to stdout: $! \n";
if (!$debug) {
	open STDERR, '>>', "$logfile" or die "DIE: Cannot write to $logfile: $! \n";
} else {
	open STDERR, '>>', '/dev/null' or die "DIE: Cannot write to stderr: $! \n";
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

# Clean the zombie childs!
sub sigChld {
	while (waitpid(-1,WNOHANG)>0 ) {
		logger("The child has been cleaned!") if ($debug);
	}
}

# Call a given function uppon signal receipt!
$SIG{"CHLD"} = \&sigChld;
$SIG{__DIE__}  = sub { logger(@_); };

sub store_to_db {
	# $_[0] 0 for insert into failed_log || 1 for insert into broots a.k.a 0 for log_me || 1 for broot_me
	# $_[1] IP
	# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
	# $_[3] The user who is bruteforcing only if $_[0] == log_me
	our $conn = DBI->connect_cached( $config{"db"}, $config{"dbuser"}, $config{"dbpass"}, { PrintError => 1, AutoCommit => 1 })
		or logger("Unable to connect to the database while trying to log $_[0]: $!");
	our $log_me = $conn->prepare('INSERT INTO failed_log ( ip, service, "user" ) VALUES ( ?, ?, ? ) ') or logger("Unable to prepare the log query: $!");
	our $broot_me = $conn->prepare('INSERT INTO broots ( ip, service ) VALUES ( ?, ? ) ') or logger("Unable to prepare the broot_me query: $!");

	if ($_[0] == 0) {
		logger("Got caller $_[0] with argvs: $_[1], $_[2], $_[3]") if ($debug);
		$log_me->execute($_[1], $_[2], $_[3]) or logger("log_me insert failed ($_[1], $_[2], $_[3]) | $DBI::errstr");
	} elsif ($_[0] == 1) {
		logger("Got caller $_[0] with argvs: $_[1], $_[2]") if ($debug);
		$broot_me->execute($_[1], $_[2]) or logger("broot_me insert failed ($_[1], $_[2]) | $DBI::errstr");
	} elsif (defined($_[0])) {
		logger("Unknown store_to_db caller $_[0]");
	} else {
		logger("Weird undefined store_to_db caller");
	}

	$conn->disconnect;
}

sub notify {
	# 0 - SERVICE 
	# 1 - IP
	# 2 - COUNT
	my %services = (
		ftp => '21',
		ssh => '22',
		smtp => '25',
		pop3 => '110',
		imap => '143',
		cPanel => '2083'
	);
	# log to DB and file
	if (! exists($notifications{$_[1]})) { 
		$notifications{$_[1]}=1;
		store_to_db(1, $_[1], $_[0]);
		logger("!!! $_[0] $_[1] failed $_[2] times in $broot_time seconds. It is now added to the db blocklist!") if ($debug);
	}
	# Limit the offender
	if ($do_limit) {
		# variant 0
		# iptables -I in_hawk -s $_[0] -p tcp --dport $_[2]
		# variant 1
		#iptables -A in_hawk -p tcp --dport $_[2] --syn -m recent --name  --update --seconds 60 --hitcount 6 -m limit --limit 6/minute -j SSH_bruteforce
		# variant 2
		#iptables -I in_hawk -i eth0 -p tcp --dport $_[2] -s $_[0] -m state --state NEW -m recent --set
		#iptables -I in_hawk -i eth0 -p tcp --dport $_[2] -s $_[0] -m state --state NEW -m recent --update --seconds 120 --hitcount 1 -j DROP 
		if (system("/usr/local/sbin/iptables -I in_hawk -i eth0 -p tcp --dport $services{$_[2]} -s $_[0] -m state --state NEW -m recent --set && /usr/local/sbin/iptables -I in_hawk -i eth0 -p tcp --dport $_[2] -s $_[0] -m state --state NEW -m recent --update --seconds 120 --hitcount 1 -j DROP ")) {
			logger("Unable to block: $_[0], $_[1], $_[2]");
		} else {
			logger("Blocked: ip - $_[0], port - $_[2]");
		}
	}
}

while (<LOGS>) {
	# Dovecot IMAP & POP3
	if ($_ =~ /pop3-login:|imap-login:/) {
		my @current_line = split /\s+/, $_;
		my $current_service = 'imap';
		$current_service = 'pop3' if ($current_line[5] =~ /pop3-login:/);
		if ($_ =~ /auth failed/) {
			my $user = $_;
			my $ip = $_;
			my $attempts = $_;

			$user =~ s/^.* user=<(.+)>,.*$/$1/;
			$ip =~ s/^.* rip=([0-9.]+),.*$/$1/;
			$attempts =~ s/^.* ([0-9]+) attempts\).*$/$1/;
			chomp ($user, $ip, $attempts);

			next if (exists($never_block{$ip}) && $never_block{$ip});	# Do not block never block

			if (exists $possible_attackers{$ip}) {
				$possible_attackers{$ip}[0] = $possible_attackers{$ip}[0] + $attempts;
				$possible_attackers{$ip}[1] = $user;
				logger("Possible attacker update: IP: $ip Attempts: $possible_attackers{$ip}[0] User: $user Line: $_") if ($debug); 
			} else {
				$possible_attackers{$ip} = [ $attempts, $user, $service_codes{'pop3'} ];
				logger("Possible attacker new: IP: $ip Attempts: $attempts User: $user Line: $_") if ($debug); 
			}
			# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
			if ($current_service eq 'pop3') {
				store_to_db(0, $ip, 2, $user);
				if (exists $pop3_faults{$ip}) {
					$pop3_faults{$ip} = $pop3_faults{$ip} + $attempts;
				} else {
					$pop3_faults{$ip} = $attempts;
				}
			} elsif ($current_service eq 'imap') {
				store_to_db(0, $ip, 3, $user);
				if (exists $imap_faults{$ip}) {
					$imap_faults{$ip} = $imap_faults{$ip} + $attempts;
				} else {
					$imap_faults{$ip} = $attempts;
				}
			}
			logger("Service: $current_service IP: $ip User: $user Attempts: $attempts") if ($debug);
		}
	} elsif ( $_ =~ /sshd\[[0-9].+\]:/) {
		my $ip = '';
		my $user = '';
		#sshd issue is bruteforce which will be stored to the db and notified to the monitoring if 1.
		#if 2 we only send a notification.
		if ($_ =~ /Failed \w \w/ || $_ =~ /authentication failure/ || $_ =~ /Invalid user/i || $_ =~ /Bad protocol/) {
			my @sshd = split /\s+/, $_;
			if ( $sshd[8] =~ /invalid/ ) {
				#May 16 03:27:24 serv01 sshd[25536]: Failed password for invalid user suport from ::ffff:85.14.6.2 port 52807 ssh2
				#May 19 22:54:19 serv01 sshd[21552]: Failed none for invalid user supprot from 194.204.32.101 port 20943 ssh2
				$sshd[12] =~ s/::ffff://;
				$ip = $sshd[12];
				$user = $sshd[10];
				logger("sshd: Incorrect V1 $user $ip") if ($debug);
			} elsif ( $sshd[5] =~ /Invalid/) {
				#May 19 22:54:19 serv01 sshd[21552]: Invalid user supprot from 194.204.32.101
				$sshd[9] =~ s/::ffff://;
				$ip = $sshd[9];
				$user = $sshd[7];
				logger("sshd: Incorrect V2 $user $ip") if ($debug);
			} elsif ( $sshd[5] =~ /pam_unix\(sshd:auth\)/ ) {
				#May 15 09:39:10 serv01 sshd[9474]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=194.204.32.101  user=root
				$sshd[13] =~ s/::ffff://;
				$sshd[13] =~ s/rhost=//;
				$ip = $sshd[13];
				$user = $sshd[14];
				logger("sshd: Incorrect PAM $user $ip") if ($debug);
			} elsif ( $sshd[5] =~ /Bad/ ) {
				#May 15 09:33:45 serv01 sshd[29645]: Bad protocol version identification '0penssh-portable-com' from 194.204.32.101
				my @sshd = split /\s+/, $_;
				$sshd[11] =~ s/::ffff://;
				$ip = $sshd[11];
				$user = 'none';
				logger("sshd: Grabber $user $ip") if ($debug);
			} else {
				#May 15 09:39:12 serv01 sshd[9474]: Failed password for root from 194.204.32.101 port 17326 ssh2
				#May 15 11:36:27 serv01 sshd[5448]: Failed password for support from ::ffff:67.15.243.7 port 47597 ssh2
				next if (! defined($sshd[10]));
				$sshd[10] =~ s/::ffff://;
				$ip = $sshd[10];
				$user = $sshd[8];
				logger("sshd: Incorrect V3 $user $ip") if ($debug);
			}
		} else {
			logger("Did not found any matches for $_") if ($debug);
			next;
		} 

		$_ =~ s/\'//g;
		next if (exists($never_block{$ip}) && $never_block{$ip});	# this is the local server
		# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
		# Store attacker's ip to the database
		logger("SSH store_to_db: 0, $ip, 1, $user") if ($debug);
		store_to_db(0, $ip, 1, $user);
		# Increase the attempts
		if ( exists $ssh_faults {$ip} ) {
			$ssh_faults{$ip}++;
		} else {
			$ssh_faults{$ip} = 1;
		}
		# Mark it as possible attacker for the notices system!
		if (exists $possible_attackers{$ip}) {
			$possible_attackers{$ip}[0]++;
			$possible_attackers{$ip}[1] = $user;
			logger("Possible attacker update: IP: $ip Attempts: $possible_attackers{$ip}[0] Line: $_") if ($debug);
		} else {
			$possible_attackers{$ip} = [ 1, $user, $service_codes{'ssh'} ];
			logger("Possible attacker update: IP: $ip Attempts: $possible_attackers{$ip}[0] Line: $_") if ($debug);
		}
	} elsif ( $_ =~ /pure-ftpd:/ && $_ =~ /Authentication failed/ ) {
		# May 16 03:06:43 serv01 pure-ftpd: (?@85.14.6.2) [WARNING] Authentication failed for user [mamam]
		# Mar  7 01:03:49 serv01 pure-ftpd: (?@68.4.142.211) [WARNING] Authentication failed for user [streetr1] 
		my @ftp = split /\s+/, $_;	
 		$ftp[5] =~ s/\(.*\@(.*)\)/$1/;	# get the IP
		next if (exists($never_block{$ftp[5]}) && $never_block{$ftp[5]});   # Do not block never block
		$ftp[11] =~ s/\[(.*)\]/$1/;		# get the username
		# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
		store_to_db(0, $ftp[5], 0, $ftp[11]);
		if ( exists $possible_attackers {$ftp[5]} && $possible_attackers{$ftp[5]}[1] ne $ftp[11])  {
			$possible_attackers{$ftp[5]}[0]++;
			$possible_attackers{$ftp[5]}[1] = $ftp[11];
			logger("Possible attacker update: IP: $ftp[5] Attempts: $possible_attackers{$ftp[5]}[0] Line: $_") if ($debug);
		} else {
			$possible_attackers{$ftp[5]} = [ 1, $ftp[11], $service_codes{'ftp'} ];
			logger("Possible attacker new: IP: $ftp[5] Attempts: $possible_attackers{$ftp[5]}[0] Line: $_") if ($debug);
		}
		if ( exists $ftp_faults {$ftp[5]} ) {
			$ftp_faults{$ftp[5]}++;
		} else {
			$ftp_faults{$ftp[5]} = 1;
		}
		logger("IP: $ftp[5] User: ($ftp[11]) failed to identify to Pure-FTPD.") if ($debug);
	} elsif ($_ =~ /FAILED LOGIN/ && ($_ =~ /webmaild:/ || $_ =~ /cpaneld:/)) {
		logger("cPanel/Webmail failed login attempt: $_");
		#209.62.36.16 - webmail.siteground216.com [07/17/2008:16:12:49 -0000] "GET / HTTP/1.1" FAILED LOGIN webmaild: user password hash is miss
		#201.245.82.85 - khaoib [07/17/2008:19:56:36 -0000] "POST / HTTP/1.1" FAILED LOGIN cpaneld: user name not provided or invalid user
		my @cpanel = split /\s+/;
		next if (exists($never_block{$cpanel[0]}) && $never_block{$cpanel[0]});   # Do not block never block
		my $service = $service_codes{'webmail'};
		$service = $service_codes{'cpanel'} if ($cpanel[10] eq 'cpaneld:');
		$cpanel[2] = '' if $cpanel[2] =~ /\[/;
		# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
		store_to_db(0, $cpanel[0], $service, $cpanel[2]);
		if ( exists $cpanel_faults {$cpanel[0]} ) {
			$cpanel_faults{$cpanel[0]}++;
		} else {
			$cpanel_faults{$cpanel[0]} = 1;
		}
		logger("IP: $cpanel[0] User: $cpanel[2] failed to identify to cPanel/Webmail. Exact service: $service") if ($debug);
   	} else {
		next;
	}

	check_broot();

	my $curr_time = time();

	if (($curr_time - $start_time) > $broot_time) {		# if the passed time is grater then $broot_time
		logger("Cleaning the faults hashes and resetting the timers") if ($debug);
		cleanh();										# clean the hashes
		$start_time = time();							# set the start_time to now
	}
}

logger("Gone ...after the main loop");
close LOGS;
logger("Gone ...after we closed the logs");
close STDIN;
logger("Gone ...after we closed the stdin");
close STDOUT;
logger("Gone ...after we closed the stdout");
close STDERR if (!$debug);
logger("Gone ...after we closed the stderr");
close HAWK;
exit 0;

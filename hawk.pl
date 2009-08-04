#!/usr/bin/perl -T

use strict;
use warnings;

use DBD::mysql;
use POSIX qw(setsid), qw(strftime), qw(WNOHANG);

require "/usr/local/sbin/parse_config.pm";
require "/usr/local/sbin/post_a_note.pm";

import parse_config;
import post_a_note;

# system variables
$ENV{PATH} = '';		# remove unsecure path
my $version = '1.25';	# version string

# defining fault hashes
my %ssh_faults = ();		# ssh faults storage
my %ftp_faults = ();		# ftp faults storage
my %pop3_faults = ();		# pop3 faults storage
my %imap_faults = ();		# imap faults storage
my %smtp_faults = ();		# smtp faults storage
my %cpanel_faults = ();	# cpanel faults storage
my %notifications = ();	# notifications
my %possible_attackers = ();	# possible hack attempts

my %authenticated_ips = ();	# authenticated_ips storage
my %reported_ips = ();
our %allowed_ips = ();

my $conf = '/home/sentry/hackman/hawk-web.conf';
my %config = parse_config($conf);

# Hawk files
my $logfile = '/var/log/hawk.log';	# daemon logfile
my $pidfile = '/var/run/hawk.pid';	# daemon pidfile
my $log_list = '/usr/bin/tail -s 0.03 -F --max-unchanged-stats=20 /var/log/messages /var/log/secure /var/log/maillog /usr/local/cpanel/logs/access_log /usr/local/cpanel/logs/login_log |';
my $authenticated_ips_file = '/etc/relayhosts';	# Authenticated to Dovecot IPs are stored here

my $broot_time = 300;	# time(in seconds) before cleaning the hashes
my $firewall_update_time = 5400; # time(in seconds) before updating the firewall
my $clean_reported = 600;
my $max_attempts = 5;	# max number of attempts(for $broot_time) before notify
my $pop_max_time = 1800;

my $debug = 0;			# by default debuging is OFF
my $do_limit = 0;		# by default do not limit the offending IPs
my $dovecot = 1;
my $start_time = time();
my $io_last_notified = $start_time;
my $io_already_notified = 0;
my $mem_last_notified = $start_time;
my $mem_already_notified = 0;
my $pop_time = $start_time;
my $fw_time = $start_time;
my $myip = get_ip();
my $hostname = '';
my %service_codes = split(/[:\s]/, $config{'service_ids'});

# check for debug
if (defined($ARGV[0])) {
	if ($ARGV[0] =~ /debug/) {
		$debug=1;		# turn on debuging
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
logger("Hawk version $version started!");

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
			if ($debug) {
				print $ip[2], "\n";
			}
		}
	}
	close IP;
	return $ip[2]
}

# generate time format: 15.May.07 02:41:52
sub get_time {
	return strftime('%b %d %H:%M:%S', localtime(time));
}

sub logger {
	print HAWK strftime('%b %d %H:%M:%S', localtime(time)) . ' ' . $_[0] . "\n";
}

# clean the hashes
sub cleanh {
	delete @ftp_faults{keys %ftp_faults};
	delete @ssh_faults{keys %ssh_faults};
	delete @pop3_faults{keys %pop3_faults};
	delete @imap_faults{keys %imap_faults};
	delete @cpanel_faults{keys %cpanel_faults};
	delete @notifications{keys %notifications};
	logger("hashes cleaned!") if ($debug);
}

sub save_ip {
	my $ip = shift;
	if (!defined $authenticated_ips{$ip}) {
		logger("New pop3/imap authenticated IP $ip ... adding it to the list") if ($debug);
		$authenticated_ips{$ip} = time();
		open AUTH, '>>', $authenticated_ips_file;
		print AUTH $ip, "\n";
		close AUTH;
	} else {
		logger("The hash for $ip already exists. Already added as popbeforesmtp ... skipping it!") if ($debug);
	}
}

sub clean_ips {
	my @to_be_removed = ();
	# first get all IPs that are to be removed(duration more then $pop_max_time)
	# and remove the IPs from authenticated_ips hash
	while ( my ($k, $v) = each(%authenticated_ips) ) {
		my $duration = time() - $v;
		if ($duration >= $pop_max_time) {
			logger("I will remove $k from the /etc/relayhosts file ... current time - $v > $pop_max_time") if ($debug);
			push(@to_be_removed, $k);
			delete($authenticated_ips{$k});
		}
	}
	# now get the file into a string
	if (open AUTH, '<', $authenticated_ips_file) {
		my @auth_list = <AUTH>;
		close AUTH;
		chomp(@auth_list);
		# write the new file without the ips from @to_be_removed
		if (open AUTH, '>', $authenticated_ips_file) {
			foreach my $auth_ip(@auth_list) {
				my $skip_ip = 0;
				chomp($auth_ip);
				foreach my $ip (@to_be_removed) {
					if ($auth_ip =~ /$ip/) {
						logger("$auth_ip will be removed") if ($debug);
						$skip_ip = 1;
					}
				}
				next if ($skip_ip);
				print AUTH $auth_ip, "\n";
			}
			close AUTH;
		} else {
			logger("I was unable to open $authenticated_ips_file for writing");
		}
	} else {
 		logger("I was unable to open $authenticated_ips_file");
	}
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
	#while ( my ($k,$v) = each (%possible_attackers) ) {
	#	if ( $possible_attackers{$k}[0] > 10 ) {
	#		if (defined($possible_attackers{$k}[3])) {
	#			if ($possible_attackers{$k}[0] > 25 && $possible_attackers{$k}[3] < 3) {
	#				$possible_attackers{$k}[3] = 6;
	#				post_a_note(1, 2, "BRUTEFORCE||$possible_attackers{$k}[2]||$k||$possible_attackers{$k}[0]");
	#			}
	#		} else {
	#			post_a_note(1, 2, "BRUTEFORCE||$possible_attackers{$k}[2]||$k||$possible_attackers{$k}[0]");
	#			$possible_attackers{$k}[3] = 1;
	#		}
	#	}
	#}
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

sub firewall_update {
	my %own_rules = ();
	eval {
		local $SIG{ALRM} = sub { die 'alarm'; };
		alarm 5;
		use IO::Socket::INET;
		if ( my $sock = new IO::Socket::INET ( PeerAddr => 'master.sgvps.net', PeerPort => '80', Proto => 'tcp', Timeout => '3') ) {
			# Send the faulty drive!
			print $sock "GET /~sentry/cgi-bin/hawkup.cgi?server=$hostname\n\n";
			while (<$sock>) {
				chomp($_);
				logger("Socket answer $_") if ($debug);
				$own_rules{$_} = $_;
			}
			close $sock;
			while (my $ip = each (%own_rules)) {
				logger("Allowed IPs hash entry $ip") if ($debug); 
			}
		} else {
			logger("Unable to get our allowed hosts list: $!");
		}
        alarm 0;
    };
	return %own_rules;
}

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
	# $_[3] Is the user who is brooteforcing only if $_[0] == log_me
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
	if ( ! exists $notifications {$_[1]} ) { 
		$notifications{$_[1]}=1;
		store_to_db(1, $_[1], $_[0]);
		logger("!!! $_[0] $_[1] failed $_[2] times in $broot_time seconds") if ($debug);
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

%allowed_ips = firewall_update();

while (<LOGS>) {
	# Dovecot IMAP & POP3
	if ($_ =~ /pop3-login:/) {
		my @pop3 = split /\s+/, $_;
		if (defined $pop3[10] && $pop3[10] eq 'Login') {
			# Jan 27 23:06:03 serv01 dovecot: pop3-login: user=<pelletsqa@leepharma.com>, method=PLAIN, rip=121.243.129.200, lip=67.15.172.14 Login
			$pop3[8] =~ s/rip=(.*),/$1/;
			save_ip($pop3[8]);
		} elsif ($_ =~ /auth failed/) {
			my $failed_entry = 14;
			if ($_ =~ /secured Aborted login/ ) {
				$failed_entry = 15;
			} elsif ($_ =~ /Aborted login/ && $_ !~ /secured/) {
				$failed_entry = 14;
			} elsif ($_ =~ /Disconnected/) {
				$failed_entry = 13;
			}
			#Jan 27 23:09:37 serv01 dovecot: pop3-login: user=<aaa>, method=PLAIN, rip=77.70.33.151, lip=67.15.172.14 Aborted login (auth failed, 8 attempts)
			$pop3[8] =~ s/rip=(.*),/$1/;
			$pop3[6] =~ s/user=<(.*)>,/$1/;
			next if ( $pop3[8] =~ /$myip/ || $pop3[8] =~ /127.0.0.1/);	# this is the local server
			logger("$failed_entry on line $_") if ($debug);
			if (exists $possible_attackers{$pop3[8]}) {
				$possible_attackers{$pop3[8]}[0] = $possible_attackers{$pop3[8]}[0] + $pop3[$failed_entry];
				$possible_attackers{$pop3[8]}[1] = $pop3[6];
				logger("Possible attacker update: IP: $pop3[8] Attempts: $possible_attackers{$pop3[8]}[0] Failed entry num is: $failed_entry Line: $_") if ($debug); 
			} else {
				$possible_attackers{$pop3[8]} = [ $pop3[$failed_entry], $pop3[6], $service_codes{'pop3'} ];
				logger("Possible attacker new: IP: $pop3[8] Attempts: $possible_attackers{$pop3[8]}[0]  Failed entry num is: $failed_entry Line: $_") if ($debug); 
			}
			# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
			store_to_db(0, $pop3[8], 2, $pop3[6]);
			if (exists $pop3_faults{$pop3[8]}) {
				$pop3_faults{$pop3[8]} = $pop3_faults{$pop3[8]} + $pop3[$failed_entry];
			} else {
				$pop3_faults{$pop3[8]} = $pop3[$failed_entry];
			}
			logger("IP $pop3[8]($pop3[6]) faild to identify to dovecot-pop3 $pop3[$failed_entry] times") if ($debug);
		}
	# Skip shutting down lines such as:
	#Aug  4 01:24:34 serv01 dovecot: IMAP(accounts@flyeschool.com): Server shutting down bytes=189/970
	#ug  4 01:30:31 serv01 dovecot: imap-login: user=<Msussman@marcsussman.com>, method=PLAIN, rip=69.193.200.186, lip=75.125.60.5 Disconnected: Shutting down (auth failed, 1 attempts)
	} elsif ($_ =~ /imap-login/ && $_ !~ /Shutting down/i) {
		#Jan 27 23:24:28 serv01 dovecot: imap-login: user=<user>, method=PLAIN, rip=77.70.33.151, lip=67.15.172.14 Aborted login (auth failed, 1 attempts)
		my @imap = split /\s+/, $_;
		if (defined $imap[11] && $imap[11] eq 'Login') {
		# Jan 27 23:31:26 serv01 dovecot: imap-login: user=<m.harrington@okemomountainschool.org>, method=PLAIN, rip=67.223.78.73, lip=67.15.172.14, TLS Login
		# Jan 27 23:31:52 serv01 dovecot: imap-login: user=<m.harrington@okemomountainschool.org>, method=PLAIN, rip=67.15.172.14, lip=67.15.172.14, secured Login
			$imap[8] =~ s/rip=(.*),/$1/;
			save_ip($imap[8]);
		} elsif ($_ =~ /auth failed/) {
			my $failed_entry = 14;
			if ($_ =~ /secured Aborted login/ || $_ =~ /TLS Aborted login/) {
				$failed_entry = 15;
			} elsif ($_ =~ /Aborted login/ && $_ !~ /secured/) {
				$failed_entry = 14;
			} elsif ($_ =~ /Disconnected/ && $_ !~ /Inactivity/) {
				$failed_entry = 13;
			} elsif ($_ =~ /Inactivity/) {
				$failed_entry = 14;
			}
			# Jan 27 23:33:24 serv01 dovecot: imap-login: user=<test>, method=PLAIN, rip=77.70.33.151, lip=67.15.172.14 Aborted login (auth failed, 3 attempts)
			$imap[8] =~ s/rip=(.*),/$1/;
			$imap[6] =~ s/user=<(.*)>,/$1/;
			next if ( $imap[8] =~ /$myip/ || $imap[8] =~ /127.0.0.1/ );	# this is the local server
			logger("$failed_entry on line $_") if ($debug);
			if (exists $possible_attackers{$imap[8]}) {
				$possible_attackers{$imap[8]}[0] = $possible_attackers{$imap[8]}[0] + $imap[$failed_entry];
				$possible_attackers{$imap[8]}[1] = $imap[6];
				logger("Possible attacker update: IP: $imap[8] Attempts: $possible_attackers{$imap[8]}[0] Failed entry num is: $failed_entry Line: $_") if ($debug); 
			} else {
				$possible_attackers{$imap[8]} = [ $imap[$failed_entry], $imap[6], $service_codes{'imap'} ];
				logger("Possible attacker new: IP: $imap[8] Attempts: $possible_attackers{$imap[8]}[0] Failed entry num is: $failed_entry Line: $_") if ($debug); 
			}
			# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
			store_to_db(0, $imap[8], 4, $imap[6]);
			if ( exists $imap_faults {$imap[8]} ) {
				$imap_faults{$imap[8]} = $imap_faults{$imap[8]} + $imap[$failed_entry];
			} else {
				$imap_faults{$imap[8]} = $imap[$failed_entry];
			}
			logger("IP $imap[8]($imap[6]) faild to identify to dovecot-pop3 $imap[$failed_entry] times") if ($debug);
		}
	} elsif ( $_ =~ /I\/O error/i ) { 
		# Feb 14 19:18:35 serv01 kernel: end_request: I/O error, dev sdb, sector 1405725148
		my $io_time_now = time();
		next if (($io_time_now - $io_last_notified) < 900 && $io_already_notified == 1);
		my @line = split /\s+/, $_;
		post_a_note(1, 1, "$line[9]||$_");
		logger("IO error detected: $_") if ($debug);
		$io_already_notified = 1 if ($io_already_notified  == 0); 
		$io_last_notified = $io_time_now;
 	} elsif ( $_ =~ /kernel: EDAC/) {
		my $mem_time_now = time();
		next if (($mem_time_now - $mem_last_notified) < 900 && $mem_already_notified == 1);
		post_a_note(1, 9, "$_");
		logger("Memory corruption detected: $_") if ($debug);
		$mem_already_notified = 1 if ($mem_already_notified  == 0);
		$mem_last_notified = $mem_time_now;
	} elsif ( $_ =~ /sshd\[[0-9].+\]:/) {
		my $ip = '';
		my $user = '';
		my $ssh_issue = 0; #sshd issue is bruteforce which will be stored to the db and notified to the monitoring if 1. if 2 we only send a notification.
		if ($_ =~ /Failed \w \w/ ||
			$_ =~ /authentication failure/ ||
			$_ =~ /Invalid user/i ||
			$_ =~ /Connection closed by/ ||
			$_ =~ /Bad protocol/) {
			# After if starts here :)
			my @sshd = split /\s+/, $_;
			$ssh_issue = 1;
			if ( $sshd[8] =~ /invalid/ ) {
				#May 16 03:27:24 serv01 sshd[25536]: Failed password for invalid user suport from ::ffff:85.14.6.2 port 52807 ssh2
				#May 19 22:54:19 serv01 sshd[21552]: Failed none for invalid user supprot from 194.204.32.101 port 20943 ssh2
				$sshd[12] =~ s/::ffff://;
				$ip = $sshd[12];
				$user = $sshd[10];
				logger("sshd: Incorrect V1 $user $ip") if ($debug);
			} elsif ( $sshd[5] =~ /Connection/ ) {
				#May 25 02:11:34 serv01 sshd[10146]: Connection closed by 87.118.135.130
				$sshd[8] =~ s/::ffff://;
				$ip = $sshd[8];
				$user = 'none';
				logger("sshd: Incorrect KEY $user $ip") if ($debug);
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
				$sshd[10] =~ s/::ffff://;
				$ip = $sshd[10];
				$user = $sshd[8];
				logger("sshd: Incorrect V3 $user $ip") if ($debug);
			}
		} elsif ($_ =~ /Accepted publickey for/ || $_ =~ /Accepted password for/ || $_ =~ /Postponed publickey for/) {
			logger("It seems that someone logged in? $_") if ($debug);
			#May 25 00:48:58 serv01 sshd[16015]: Accepted publickey for root from 75.125.60.5 port 32863 ssh2
			#May 20 00:51:54 serv01 sshd[20568]: Accepted password for support from ::ffff:67.15.245.5 port 50336 ssh2
			#Jun  8 17:13:39 serv01 sshd[4474]: Postponed publickey for root from 77.70.33.151 port 35098 ssh2
			my %protected_users = (
				'root' => '0',
				'support' => '0'
			);
			my @sshd = split /\s+/, $_;
			$sshd[10] =~ s/::ffff://;
			$ip = $sshd[10];
			$user = $sshd[8];
			my $mask = $ip;
			$mask =~ s/\.[0-9]{1,3}$/\.0/;

			logger("The mask is now $mask") if ($debug);

			next if (!exists $protected_users{$user});
			next if ((defined($allowed_ips{$ip}) || defined($allowed_ips{$mask})) && $protected_users{$user} == 0);
			$ssh_issue = 2;
			logger("sshd: Login $user $ip") if ($debug);
		} else {
			logger("Did not found any matches for $_") if ($debug);
			next;
		} 

		$_ =~ s/\'//g;
		if ($ssh_issue == 1) {
			next if ( $ip =~ /$myip/ || $ip =~ /127.0.0.1/ );	# this is the local server
			#post_a_note(1, 2, "BRUTEFORCE||$service_codes{'ssh'}||$ip||$_");
			# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
			# Store the bastard to the database
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
		} elsif ($ssh_issue == 2) {
			post_a_note(1, 2, "UNAUTHORIZED||$service_codes{'ssh'}||$ip||$_");
		}
	} elsif ( $_ =~ /pure-ftpd:/ && $_ =~ /Authentication failed/ ) {
		# May 16 03:06:43 serv01 pure-ftpd: (?@85.14.6.2) [WARNING] Authentication failed for user [mamam]
		# Mar  7 01:03:49 serv01 pure-ftpd: (?@68.4.142.211) [WARNING] Authentication failed for user [streetr1] 
		my @ftp = split /\s+/, $_;	
 		$ftp[5] =~ s/\(.*\@(.*)\)/$1/;	# get the IP
		$ftp[11] =~ s/\[(.*)\]/$1/;		# get the username
		# $_[2] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel
		store_to_db(0, $ftp[5], 0, $ftp[11]);
		if ( exists $possible_attackers {$ftp[5]} && $possible_attackers{$ftp[5]}[1] ne $ftp[11])  {
			$possible_attackers{$ftp[5]}[0]++;
			$possible_attackers{$ftp[5]}[1] = $ftp[11];
			logger("Possible attacker update: IP: $ftp[5] Attempts: $possible_attackers{$ftp[5]}[0] Line: $_") if ($debug);
		} else {
			$possible_attackers{$ftp[5]} = [ 0, $ftp[11], $service_codes{'ftp'} ];
			logger("Possible attacker new: IP: $ftp[5] Attempts: $possible_attackers{$ftp[5]}[0] Line: $_") if ($debug);
		}
		if ( exists $ftp_faults {$ftp[5]} ) {
			$ftp_faults{$ftp[5]}++;
		} else {
			$ftp_faults{$ftp[5]} = 1;
		}
		logger("IP $ftp[5]($ftp[11]) failed to identify to Pure-FTPD.") if ($debug);
	} elsif ($_ =~ /FAILED LOGIN/ && ($_ =~ /webmaild:/ || $_ =~ /cpaneld:/)) {
		#209.62.36.16 - webmail.siteground216.com [07/17/2008:16:12:49 -0000] "GET / HTTP/1.1" FAILED LOGIN webmaild: user password hash is miss
		#201.245.82.85 - khaoib [07/17/2008:19:56:36 -0000] "POST / HTTP/1.1" FAILED LOGIN cpaneld: user name not provided or invalid user
		my @cpanel = split /\s+/;
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
		logger("IP $cpanel[0]($cpanel[2])failed to identify to cPanel($service).") if ($debug);
   	} else {
		next;
	}

	check_broot();

	my $curr_time = time();

	if (($curr_time - $start_time) > $broot_time) {		# if the passed time is grater then $broot_time
		cleanh();							# clean the hashes
		$start_time = time();				# set the start_time to now
	}

	if (($curr_time - $pop_time) > 300) {
		clean_ips();				# clean the authenticated_ips_file
		$pop_time = time();			# set the pop_time to now
	}

	if (($curr_time - $fw_time) > $firewall_update_time) {
		%allowed_ips = firewall_update();
		$fw_time = time();
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

#!/usr/bin/perl -T
# Hawk IDS/IPS								 Copyright(c) Marian Marinov
# This code is subject to the GPLv2 license. 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

use strict;
use warnings;

use DBD::Pg;
use POSIX qw(setsid), qw(strftime), qw(WNOHANG);

use lib '/usr/lib/hawk/';
use parse_config;

$SIG{"CHLD"} = \&sigChld;
$SIG{__DIE__}  = sub { logger(@_); };

$ENV{PATH} = '';		# remove unsecure path
my $VERSION = '6.5';

# input/output should be unbuffered. pass it as soon as you get it
our $| = 1;

my $debug = 0;
$debug = 1 if (defined($ARGV[0]));

# This will be our function that will print all logger requests to /var/log/$logfile
sub logger {
	print HAWKLOG strftime('%b %d %H:%M:%S', localtime(time)) . ' ' . $_[0] . "\n" and return 1 or return 0;
}

sub get_local_ips {
	my %local_ips = ();
	open my $ips, '-|', '/usr/sbin/ip -4 a l';
	while(my $line = <$ips>) {
		if ($line =~ /inet ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\/[0-9]+/) {
			$local_ips{$1} = 1;
		}
	}
	close $ips;
	return %local_ips;
}

# Compare the current attacker's ip address with the local ips (primary and localhost)
sub is_local_ip {
	my %whitelists = %{$_[0]};
	my $current_ip = $_[1];

	# Return 1 if the attacker ip is our own ip
	return 1 if (defined($whitelists{$current_ip}));
	return 0;
}

# Check if hawk is already running
sub is_hawk_running {
	my $pidfile = shift;
	# hawk is not running if the pid file is missing
	return 0 if (! -e $pidfile);
	# get the old pid
	open PIDFILE, '<', $pidfile or return 0;
	my $old_pid = <PIDFILE>;
	close PIDFILE;
	# if the pid format recorded in the file is incorrect answer as like hawk is running. this shoud never happen!
	return 1 if ($old_pid !~ /[0-9]+/);
	# hawk is running if the pid from the pidfile exists as dir in /proc
	return 1 if (-d "/proc/$old_pid");
	# hawk is not running
	return 0;
}

sub close_stdh {
	my $logfile = shift;
	# Close stdin ...
	open STDIN, '<', '/dev/null' or return 0;
	# ... and stdout
	open STDOUT, '>>', '/dev/null' or return 0;
	# Redirect stderr to our log file
	open STDERR, '>>', "$logfile" or return 0;
	return 1;
}

# write the program pid to the $pidfile
sub write_pid {
	my $pidfile = shift;
	open PIDFILE, '>', $pidfile or return 0;
	print PIDFILE $$ or return 0;
	close PIDFILE;
	return 1;
}

# Clean the zombie childs!
sub sigChld {
	while (waitpid(-1,WNOHANG) > 0) {
		logger("The child has been cleaned!") if ($debug);
	}
}

# If $_[3] is 0, store the failed login attempt to the DB
# If $_[3] is 1, store the bruteforce attempt to the DB
# The brootforce table is later checked by the cron
sub store_to_db {
	# $_[0] DB name
	# $_[1] DB user
	# $_[2] DB pass
	# $_[3] 0 insert into failed_log || 1 for insert into broots a.k.a 0 for log_me || 1 for broot_me || 2 inser into blacklist
	# $_[4] IP
	# $_[5] The service under attack - 0 = ftp, 1 = ssh, 2 = pop3, 3 = imap, 4 = webmail, 5 = cpanel | failed attempts if $_[3] == 2
	# $_[6] The user who is bruteforcing only if $_[3] == log_me
	my $conn = DBI->connect_cached($_[0], $_[1], $_[2], { PrintError => 1, AutoCommit => 1 }) or return 0;

	# Store each failed attempt to the failed_log table
	if ($_[3] == 0) {
		my $log_me = $conn->prepare('INSERT INTO failed_log ( ip, service, "user" ) VALUES ( ?, ?, ? ) ') or return 0;
		$log_me->execute($_[4], $_[5], $_[6]) or return 0;
	} elsif ($_[3] == 1) {
		my $broot_me = $conn->prepare('INSERT INTO broots ( ip, service ) VALUES ( ?, ? ) ') or return 0;
		$broot_me->execute($_[4], $_[5]) or return 0;
	} elsif ($_[3] == 2) {
		my $log_block = $conn->prepare('INSERT INTO blacklist ( date_add, ip, count, reason ) VALUES (now(), ?, ?, ?)') or return 0;
		$log_block->execute($_[4], $_[5], "Blocking IP $_[4] for having $_[5] $_[6] attempts") or return 0;
	}

	$conn->disconnect;
	# return 1 on success
	return 1;
}

sub get_attempts {
	my $new_count = shift;
	my $current_attacker_count = shift;
	# Return the current number of bruteforce attempts for that ip if no old records has been found
	return $new_count if (! defined($current_attacker_count));
	# Sum the number of current bruteforce attempts for that ip with the recorded number of bruteforce attempts
	return $new_count + $current_attacker_count;
}

# Compare the number of failed attampts to the $max_attempts variable
sub check_broots {
	my $ip_failed_count = shift;
	my $max_attempts = shift;	# max number of attempts(for $broot_time) before notify

	# Return 1 if $ip_failed_count > $max_attempts
	# On return 1 the attacker's ip will be recorded to the store_to_db(broots) table
	return 1 if ($ip_failed_count >= $max_attempts);
	# Do not block/store if the broot attempts for this ip are less than the $max_attempts
	return 0;
}

sub do_block {
	my $blocked_ip = shift;
	my $attempts = shift;
	my $config_ref = shift;
	my $cmd_ref = shift;
	my $info = shift;
	my $block_list = $config_ref->{'block_list'};
	my $comment = "$info $attempts attempts";
	my @cmd_line = @{$cmd_ref};
	my $ip_param = shift(@cmd_line);	# the first parameter in the array shows where the IP should be in the parameters

	# For all commands, the comment is the last parameter, so add it here, if supported on this system
	push(@cmd_line, $comment) if ($config_ref->{'block_comments'});

	$block_list =~ s/(\r|\n)//g;
	$blocked_ip = $1 if ($blocked_ip =~ /([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)/) or logger ("Illegal ip content at $blocked_ip") and return 0;

	$cmd_line[$ip_param] = $blocked_ip;
	system(@cmd_line);

	$block_list = $1 if ($block_list =~ /^(.*)$/);
	open BLOCKLIST, '+>>', $block_list or "Failed to open $block_list for append: $!" and return 0;
	print BLOCKLIST "iptables -I in_hawk -s $blocked_ip -j DROP\n" or "Failed to write to $block_list: $!" and return 0;
	close BLOCKLIST;
	return 1;
}

# Parse the pop3/imap logs
sub dovecot_broot {
	# Dovecot POP3
	#Aug 30 03:01:57 tester dovecot: pop3-login: method=PLAIN, rip=87.118.135.130, lip=209.62.32.14 Disconnected (auth failed, 2 attempts)
	#Aug 30 03:11:00 tester dovecot: pop3-login: method=PLAIN, rip=87.118.135.130, lip=209.62.32.14, TLS: Disconnected Disconnected (auth failed, 3 attempts)
	#Aug 30 03:12:51 tester dovecot: pop3-login: user=<testuser>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14 Aborted login (auth failed, 1 attempts)
	#Aug 30 03:19:42 tester dovecot: pop3-login: Disconnected (auth failed, 1 attempts): user=<dqdo>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14
	#Aug 30 03:20:06 tester dovecot: pop3-login: Disconnected (auth failed, 1 attempts): user=<dqdo>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14, TLS: Disconnected
	#Aug 30 03:15:03 tester dovecot: pop3-login: user=<dqdo>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14 Disconnected (auth failed, 1 attempts)
	#Aug 30 03:15:21 tester dovecot: pop3-login: user=<dqdo>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14, TLS: Disconnected Disconnected (auth failed, 1 attempts)
	# Dovecot IMAP
	#Aug 30 03:11:59 tester dovecot: imap-login: method=PLAIN, rip=87.118.135.130, lip=209.62.32.14 Disconnected (auth failed, 3 attempts)
	#Aug 30 03:11:36 tester dovecot: imap-login: method=PLAIN, rip=87.118.135.130, lip=209.62.32.14, TLS: Disconnected Disconnected (auth failed, 2 attempts)
	#Aug 30 03:13:21 tester dovecot: imap-login: user=<testuser>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14 Aborted login (auth failed, 1 attempts)
	#Aug 30 03:15:37 tester dovecot: imap-login: user=<dqdo>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14, TLS: Disconnected Disconnected (auth failed, 1 attempts)
	#Aug 30 03:20:26 tester dovecot: imap-login: Disconnected (auth failed, 1 attempts): user=<dqdo>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14
	#Aug 30 03:20:40 tester dovecot: imap-login: Disconnected (auth failed, 1 attempts): user=<dqdo>, method=PLAIN, rip=87.118.135.130, lip=209.62.32.14, TLS: Disconnected

	my $current_service = 3; # The default service id is 3 -> imap
	$current_service = 2 if ($_ =~ /pop3-login:/); # Service is now 2 -> pop3

	# Extract the user, ip and number of failed attempts from the log
	my $user = 'multiple';
	$user = $1 if ($_ =~ /^.* user=<(.+)>,.*$/);
	my $ip = $1 if ($_ =~ /^.* rip=([0-9.]+),.*$/);
	my $attempts = $1 if ($_ =~ /^.* ([0-9]+) attempts\).*$/);
	chomp ($user, $ip, $attempts);
	logger("Returning User: $user IP: $ip Attempts $attempts") if ($debug);
	# return ip, number of failed attempts, service under attack, failed username
	# this is later stored to the failed_log table via store_to_db
	return ($ip, $attempts, $current_service, $user);
}

sub courier_broot {
	# cPanel
	#  Aug 27 06:10:57 m670 imapd: LOGIN FAILED, user=wrelthkl, ip=[::ffff:87.118.135.130]
	#  Aug 27 06:11:10 m670 pop3d: LOGIN FAILED, user=test, ip=[::ffff:87.118.135.130]
	#  Aug 27 06:12:35 m670 pop3d-ssl: LOGIN FAILED, user=root:x:0:0:root:/root:/bin/bash, ip=[::ffff:87.118.135.130]
	#  Aug 27 06:13:53 m670 imapd-ssl: LOGIN FAILED, user=root:x:0:0:root:/root:/bin/bash, ip=[::ffff:87.118.135.130]
	# Plesk
	#  Mar  7 07:08:14 plesk pop3d: IMAP connect from @ [127.0.0.1]checkmailpasswd: FAILED: testing - short names not allowed from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
	#  Mar  7 07:08:39 plesk pop3d: IMAP connect from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
	#  Mar  7 07:09:01 plesk imapd: IMAP connect from @ [127.0.0.1]checkmailpasswd: FAILED: lala - short names not allowed from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
	#  Mar  7 07:09:28 plesk imapd: IMAP connect from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
	#  Mar  7 07:17:44 plesk pop3d-ssl: IMAP connect from @ [192.168.0.133]checkmailpasswd: FAILED: lalalal - short names not allowed from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]
	#  Mar  7 07:18:28 plesk pop3d-ssl: IMAP connect from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]
	#  Mar  7 07:20:33 plesk imapd-ssl: IMAP connect from @ [192.168.0.133]checkmailpasswd: FAILED: akakaka - short names not allowed from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]
	#  Mar  7 07:20:53 plesk imapd-ssl: IMAP connect from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]

	chomp($_);
	my $current_service = 3; # The default service id is 3 -> imap
	$current_service = 2 if ($_ =~ /pop3d(-ssl)?:/); # Service is now 2 -> pop3
	my $user = 'unknown';
	my $ip = '';
	my $attempts = 1;

	# Get the user if available
	$user = $1 if ($_ =~ /user=(.*),/);
	$user = $1 if ($_ =~ /checkmailpasswd: FAILED: (.*) -/);
	# Parse the IP
	$ip = $1 if ($_ =~ /ip=\[(.*)\]/);
	$ip =~ s/.*://;
	# return ip, number of failed attempts, service under attack, failed username
	# this is later stored to the failed_log table via store_to_db
	return ($ip, $attempts, $current_service, $user);
}

sub ssh_broot {
	my $ip = '';
	my $user = '';
	my @sshd = split /\s+/, $_;

	if ($sshd[8] =~ /invalid/ ) {
		#May 16 03:27:24 serv01 sshd[25536]: Failed password for invalid user suport from ::ffff:85.14.6.2 port 52807 ssh2
		#May 19 22:54:19 serv01 sshd[21552]: Failed none for invalid user supprot from 194.204.32.101 port 20943 ssh2
		$sshd[12] =~ s/::ffff://;
		$ip = $sshd[12];
		$user = $sshd[10];
		logger("sshd: Incorrect V1 $user $ip") if ($debug);
	} elsif ($sshd[5] =~ /Invalid/) {
		#May 19 22:54:19 serv01 sshd[21552]: Invalid user supprot from 194.204.32.101
		$sshd[9] =~ s/::ffff://;
		$ip = $sshd[9];
		$user = $sshd[7];
		logger("sshd: Incorrect V2 $user $ip") if ($debug);
	} elsif ($sshd[5] =~ /pam_unix\(sshd:auth\)/ ) {
		#May 15 09:39:10 serv01 sshd[9474]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=194.204.32.101  user=root
		$sshd[13] =~ s/::ffff://;
		$sshd[13] =~ s/rhost=//;
		$ip = $sshd[13];
		#$user = $sshd[14];
		$user = $1 if ($sshd[14] =~ /user=(.*)/);
		logger("sshd: Incorrect PAM $user $ip") if ($debug);
	} elsif ($sshd[5] =~ /Bad/ ) {
		#May 15 09:33:45 serv01 sshd[29645]: Bad protocol version identification '0penssh-portable-com' from 194.204.32.101
		#my @sshd = split /\s+/, $_;
		$sshd[11] =~ s/::ffff://;
		$ip = $sshd[11];
		$user = 'none';
		logger("sshd: Grabber $user $ip") if ($debug);
	} elsif ($sshd[5] eq 'Failed' && $sshd[6] eq 'password' ) {
		#May 15 09:39:12 serv01 sshd[9474]: Failed password for root from 194.204.32.101 port 17326 ssh2
		#May 15 11:36:27 serv01 sshd[5448]: Failed password for support from ::ffff:67.15.243.7 port 47597 ssh2
		return undef if (! defined($sshd[10]));
		$sshd[10] =~ s/::ffff://;
		$ip = $sshd[10];
		$user = $sshd[8];
		logger("sshd: Incorrect V3 $user $ip") if ($debug);
	} else {
		logger("ssh_broot - unknown case. line: $_");
		# return undef if we do not know how to handle the current line. this should never happens.
		# if it happens we should create parser for $_
		return undef;
	}

	# return ip, number of failed attempts, service under attack, failed username
	# this is later stored to the failed_log table via store_to_db
	# service id 1 -> ssh
	return ($ip, 1, 1, $user);
}

sub pureftpd_broot {
	# May 16 03:06:43 serv01 pure-ftpd: (?@85.14.6.2) [WARNING] Authentication failed for user [mamam]
	# Mar  7 01:03:49 serv01 pure-ftpd: (?@68.4.142.211) [WARNING] Authentication failed for user [streetr1] 
	my @ftp = split /\s+/, $_;	

	$ftp[5] =~ s/\(.*\@(.*)\)/$1/;	# get the IP
	$ftp[11] =~ s/\[(.*)\]/$1/;		# get the username
	# return ip, number of failed attempts, service under attack, failed username
	# this is later stored to the failed_log table via store_to_db
	# service id 0 -> ftp
	return ($ftp[5], 1, 0, $ftp[11]);
}

sub proftpd_broot {
	#Aug 27 06:43:28 tester proftpd[4374]: tester (::ffff:87.118.135.130[::ffff:87.118.135.130]) - USER user: no such user found from ::ffff:87.118.135.130 [::ffff:87.118.135.130] to ::ffff:209.62.32.14:21 
	#Aug 27 06:43:47 tester proftpd[4374]: tester (::ffff:87.118.135.130[::ffff:87.118.135.130]) - USER werethet: no such user found from ::ffff:87.118.135.130 [::ffff:87.118.135.130] to ::ffff:209.62.32.14:21 
	#Aug 27 06:45:54 tester proftpd[7449]: tester (::ffff:127.0.0.1[::ffff:127.0.0.1]) - USER jivko (Login failed): Incorrect password. 
	#Aug 27 06:46:31 tester proftpd[8655]: tester (::ffff:87.118.135.130[::ffff:87.118.135.130]) - USER jivko (Login failed): Incorrect password. 
	# TODO
	my $user = $1 if ($_ =~ / - USER (\w+)/);
	my $ip = $1 if ($_ =~ /\(.*\[(.*)\]\)/);
	$ip =~ s/.*://g;
	logger("Returning: $ip, 1, 0, $user") if ($debug);
	return ($ip, 1, 0, $user);
}

sub cpanel_webmail_broot {
	#209.62.36.16 - webmail.1h216.com [07/17/2008:16:12:49 -0000] "GET / HTTP/1.1" FAILED LOGIN webmaild: user password hash is miss
	#201.245.82.85 - khaoib [07/17/2008:19:56:36 -0000] "POST / HTTP/1.1" FAILED LOGIN cpaneld: user name not provided or invalid user
	my @cpanel = split /\s+/, $_;
	my $service = 4; # Service type is webmail by default

	$service = 5 if ($cpanel[10] eq 'cpaneld:'); # Service type is cPanel if the log contains cpaneld:
	$cpanel[2] = 'unknown' if $cpanel[2] =~ /\[/;
	# return ip, number of failed attempts, service under attack, failed username
	# this is later stored to the failed_log table via store_to_db
	# service id 4 -> webmail
	# service id 5 -> cpanel
	return ($cpanel[0], 1, $service, $cpanel[2]);
}

sub da_broot {
	#87.118.135.130=attempts=7&date=1299076385&username=turba
	#87.118.135.130=attempts=2&date=1299076492&username=admin
	$_ =~ s/(\r|\n)//g;
	$_ =~ s/&/=/g;	# Convert all & to = so we can easily parse them
	my @brute_log = split /=/, $_;
	logger("IP: $brute_log[0], Failed: $brute_log[2], SVC: 6, User: $brute_log[6]") if ($debug);

	# return ip, number of failed attempts, service under attack, failed username
	# this is later stored to the failed_log table via store_to_db
	return ($brute_log[0], $brute_log[2], 6, $brute_log[6]);
}

sub postfix_broot {
	#Dec 30 09:04:16 BlackPearl postfix/smtpd[14147]: warning: unknown[46.148.40.150]: SASL LOGIN authentication failed: UGFzc3dvcmQ6
	if ($_ =~ /\[([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)\]: /) {
		logger("IP: $1, Failed: 1, SVC: 7, User: N/A") if ($debug);
		return ($1, 1, 7, 'unknown');
	}
}

# This is the main function which calls all other functions
# The entire logic is stored here
sub main {
	my $conf = '/etc/hawk.conf';
	my %config = parse_config($conf);
	my @block_cmd = ();

	# Hawk files
	my $logfile = $config{'logfile'};	# daemon logfile
	die "No logfile defined in the conf" if (! defined($logfile) || $logfile eq '');

	$logfile = $1 if ($logfile =~ /^(.*)$/);
	# open the hawk log so we can immediately start logging any errors or debugging prints
	open HAWKLOG, '>>', $logfile or die "DIE: Unable to open logfile $logfile: $!\n";
	
	my $pidfile = $config{'pidfile'};	# daemon pidfile
	$pidfile  = $1 if ($pidfile =~ /^(.*)$/);

	# This is the system command that will monitor all log files
	# For our own convenience and so we can easily add new logs with new parsers the logs are defined in the conf
	# The logs should be space separated
	# If we need to monitor more logs just append them to the monitor_list conf var
	my $monitor_list = '';
	my $logs_provided = $1 if ($config{'monitor_list'} =~ /^(.*)$/);
	for my $log_file_entry(split /\s+/, $logs_provided) {
		if ($log_file_entry =~ /^(\/[0-9a-z_.\/-]+)$/) {
			if ( -f $1 ) {
				$monitor_list .= $1 . ' ';
			} else {
				logger("Notice: skipping file $1 as it does not exists on this system");
			}
		} else {
			logger("Warning: file path '$log_file_entry' contains invalid chars and is skipped");
		}
	}
	if ($monitor_list eq '') {
		die("Error: no valid file found in monitor_list file list: $config{'monitor_list'}\n");
	}
	my $log_list = "/usr/bin/tail -s 1.00 -F --max-unchanged-stats=30 $monitor_list |";

	if ($debug) {
		# service_ids=ftp:0 ssh:1 pop3:2 imap:3 webmail:4 cpanel:5 da:6
		$config{'services'} = ();
		my @services_list = split /\s+/, $config{'service_ids'};
		for my $svc_def(split /\s+/, $config{'service_ids'}) {
			my @svc_info = split /:/, $svc_def;
			$config{'services'}{$svc_info[1]} = $svc_info[0];
		}
	}

	$config{'block_comments'} = 0 if (!defined($config{'block_comments'}));
	
	# The first parameter of @block_cmd must be the position which has to be replaced with the IP
	if (defined($config{'block_script'}) && $config{'block_script'} ne '' && -x $config{'block_script'}) {
		push(@block_cmd, (1, $config{'block_script'}, 'IP'));
	} else {
		if (defined($config{'ipset_name'}) && $config{'ipset_name'} ne '') {
			push(@block_cmd, (3, '/usr/sbin/ipset', 'add', $config{'ipset_name'}, 'IP'));
			push(@block_cmd, 'comment') if ($config{'block_comments'});
		} else {
			my $chain = 'in_hawk';
			if (defined($config{'iptables_chain'}) && $config{'iptables_chain'} ne '') {
				$chain = $config{'iptables_chain'};
			}
			push(@block_cmd, (6, '/usr/sbin/iptables', '-I', $chain, '-j', 'DROP', '-s', 'IP'));
			push(@block_cmd, ('-m', 'comment', '--comment')) if ($config{'block_comments'});
		}
	}
	logger("Hawk version $VERSION started!");
	# This is the lifetime of the broots hash
	# Each $broot_time all attacker's ips will be removed from the hash
	my $broot_time = $config{'broot_time'};
	
	my $start_time = time();

	my $hack_attempt = ();
	my $attacked_svcs = ();
	
	# What the name of the pid will be in ps auxwf :)
	if (defined($config{'daemon_name'}) && $config{'daemon_name'} ne '') {
		$0 = $config{'daemon_name'};
	}
	
	# make sure that hawk is not running before trying to create a new pid
	# THIS SHOULD BE FIXED!!!
	if (is_hawk_running($pidfile)) {
		logger("is_hawk_running() failed");
		exit 1;
	}
	
	# Get the local primary ip of the server so we do not block it later
	# This open a security loop hole in case of local bruteforce attempts
	# my $local_ip = get_ip();
	my $whitelislt = $config{'whitelist'};
	my %whitelists = ( get_local_ips(), map { $_ => '1' } split /\s+/, $whitelislt );
	my $set_limit = $config{'set_limit'};

	# me are daemon now :)
	defined(my $pid=fork) or die "DIE: Cannot fork process: $! \n";
	exit if $pid;
	setsid or die "DIE: Unable to setsid: $!\n";
	#umask 0;

	# close stdin and stdout
	# redirect stderr to the hawk log
	if (! close_stdh($logfile)) {
		logger("close_stdh() failed");
		exit 1;
	}
	
	# write the new pid to the hawk pid file
	if (! write_pid($pidfile)) {
		logger("write_pid() failed");
		exit 1;
	}
	
	# use tail to open all logs that should be monitored
	open LOGS, $log_list or die "open $log_list with tail failed: $!\n";
	
	# make the output of the opened logs unbuffered
	select((select(HAWKLOG), $| = 1)[0]);
	select((select(LOGS), $| = 1)[0]);
	select((select(STDIN), $| = 1)[0]);
	select((select(STDOUT), $| = 1)[0]);
	select((select(STDERR), $| = 1)[0]);
	
	# this should never ends.
	# this is the main infinity loop
	# read each line and parse it. if we do not know how to handle it go to the next line
	while (<LOGS>) {
		# parse each known line
		# if this is a real attack from non local ip the attacker's ip, the number of failed attempts, the bruteforced service and the failed user are stored to @block_results

		# $block_results[0] - attacker's ip address
		# $block_results[1] - number of failed attempts. NOTE: This is the CURRENT number of failed attempts for that IP. The total number is stored in $hack_attempt{svc}{$ip}
		# $block_results[2] - each service parser return it's own unique service id which is the id of the service which is under attack
		# $block_results[3] - the username that failed to authenticate to the given service
		my @block_results = undef;

		if (defined($config{'watch_ssh'}) && $config{'watch_ssh'}) {
			if ( $_ =~ /sshd\[[0-9].+\]:/) {
				next if ($_ !~ /Failed \w \w/ && $_ !~ /authentication failure/ && $_ !~ /Invalid user/i && $_ !~ /Bad protocol/); # This looks like sshd attack
				logger ("calling ssh_broot") if ($debug);
				@block_results = ssh_broot($_); # Pass it to the ssh_broot parser and get the attacker's results
			}
		}

		if (defined($config{'watch_cpanel'}) && $config{'watch_cpanel'}) {
			if ($_ =~ /FAILED LOGIN/ && ($_ =~ /webmaild:/ || $_ =~ /cpaneld:/)) { # This looks like cPanel/Webmail attack
				logger ("calling cpanel_webmail_broot") if ($debug);
				@block_results = cpanel_webmail_broot($_); # Pass it to the cpanel_webmail_broot parser and get the attacker's results
			}
		}

		if (defined($config{'watch_da'}) && $config{'watch_da'}) {
			# 87.118.135.130=attempts=7&date=1299076385&username=turba
			# 87.118.135.130=attempts=2&date=1299076492&username=admin
			# 'security.log' strings are skipped since when someone is logged out from the DA panel writes down this string:
			#   - 87.118.135.130=attempts=1&date=1299076474&username=invalid username: check security.log
			if ($_ =~ /attempts.*date.*username/ && $_ !~ /security.log/) { # This looks like Direct admin attack
				logger ("calling da_broot") if ($debug);
				@block_results = da_broot($_); # Pass the line for parsing to da_broot
			}
		}

		if (defined($config{'watch_pureftpd'}) && $config{'watch_pureftpd'}) {
			if ($_ =~ /pure-ftpd:/ && $_ =~ /Authentication failed/) {
				logger ("calling pureftpd_broot") if ($debug);
				@block_results = pureftpd_broot($_);
			}
		}

		if (defined($config{'watch_proftpd'}) && $config{'watch_proftpd'}) {
			#Aug 27 06:43:28 tester proftpd[4374]: tester (::ffff:87.118.135.130[::ffff:87.118.135.130]) - USER user: no such user found from ::ffff:87.118.135.130 [::ffff:87.118.135.130] to ::ffff:209.62.32.14:21 
			#Aug 27 06:43:47 tester proftpd[4374]: tester (::ffff:87.118.135.130[::ffff:87.118.135.130]) - USER werethet: no such user found from ::ffff:87.118.135.130 [::ffff:87.118.135.130] to ::ffff:209.62.32.14:21 
			#Aug 27 06:45:54 tester proftpd[7449]: tester (::ffff:127.0.0.1[::ffff:127.0.0.1]) - USER jivko (Login failed): Incorrect password. 
			#Aug 27 06:46:31 tester proftpd[8655]: tester (::ffff:87.118.135.130[::ffff:87.118.135.130]) - USER jivko (Login failed): Incorrect password. 
			if ($_ =~ /proftpd\[[0-9]+\]:/ && $_ =~ /no such user|Incorrect password/) {
				logger ("calling proftpd_broot") if ($debug);
				@block_results = proftpd_broot($_);
			}
		}

		if (defined($config{'watch_postfix'}) && $config{'watch_postfix'}) {
			#Dec 30 09:03:59 BlackPearl postfix/smtpd[14147]: warning: unknown[46.148.40.150]: SASL LOGIN authentication failed: UGFzc3dvcmQ6
			#Dec 30 08:56:20 BlackPearl postfix/submission/smtpd[14176]: Anonymous TLS connection established from unknown[45.128.36.154]: TLSv1.2 with cipher DHE-RSA-AES256-GCM-SHA384 (256/256 bits)

			if ($_ =~ /postfix\/s/ && $_ =~ /SASL LOGIN authentication failed|Anonymous TLS connection established from/ && $_ !~ /Connection lost/) {
				logger ("calling postfix_broot") if ($debug);
				@block_results = postfix_broot($_);
			}
		}

		if (defined($config{'watch_dovecot'}) && $config{'watch_dovecot'}) {
			# Make sure to skip lines that say "Internal login failure". This is internal processing error inside the daemon itself and should not be considered as attack
			if ($_ =~ /pop3-login:|imap-login:/ && $_ =~ /auth failed/ && $_ !~ /Internal/) { # This looks like a pop3/imap attack.
				logger ("calling dovecot_broot") if ($debug);
				@block_results = dovecot_broot($_); # Pass the log line to the pop_imap_broot parser and get the attacker's details
			}
		}

		if (defined($config{'watch_courier'}) && $config{'watch_courier'}) {
			# cPanel
			#  Aug 27 06:10:57 m670 imapd: LOGIN FAILED, user=wrelthkl, ip=[::ffff:87.118.135.130]
			#  Aug 27 06:11:10 m670 pop3d: LOGIN FAILED, user=test, ip=[::ffff:87.118.135.130]
			#  Aug 27 06:12:35 m670 pop3d-ssl: LOGIN FAILED, user=root:x:0:0:root:/root:/bin/bash, ip=[::ffff:87.118.135.130]
			#  Aug 27 06:13:53 m670 imapd-ssl: LOGIN FAILED, user=root:x:0:0:root:/root:/bin/bash, ip=[::ffff:87.118.135.130]
			# Plesk
			#  Mar  7 07:08:14 plesk pop3d: IMAP connect from @ [127.0.0.1]checkmailpasswd: FAILED: testing - short names not allowed from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
			#  Mar  7 07:08:39 plesk pop3d: IMAP connect from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
			#  Mar  7 07:09:01 plesk imapd: IMAP connect from @ [127.0.0.1]checkmailpasswd: FAILED: lala - short names not allowed from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
			#  Mar  7 07:09:28 plesk imapd: IMAP connect from @ [127.0.0.1]ERR: LOGIN FAILED, ip=[127.0.0.1]
			#  Mar  7 07:17:44 plesk pop3d-ssl: IMAP connect from @ [192.168.0.133]checkmailpasswd: FAILED: lalalal - short names not allowed from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]
			#  Mar  7 07:18:28 plesk pop3d-ssl: IMAP connect from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]
			#  Mar  7 07:20:33 plesk imapd-ssl: IMAP connect from @ [192.168.0.133]checkmailpasswd: FAILED: akakaka - short names not allowed from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]
			#  Mar  7 07:20:53 plesk imapd-ssl: IMAP connect from @ [192.168.0.133]ERR: LOGIN FAILED, ip=[192.168.0.133]
			if ($_ =~ /pop3d(-ssl)?:|imapd(-ssl?):/ && $_ =~ /FAILED/) {
				logger ("calling courier_broot") if ($debug);
				@block_results = courier_broot($_);
			}
	   	}

		next if (@block_results < 2);	# Go ahead if the size of the block results is < 3
		next if (is_local_ip(\%whitelists, $block_results[0]));	# Go ahead if this is a local ip
	
		# $block_results[0] - attacker's ip address
		# $block_results[1] - number of failed attempts. NOTE: This is the CURRENT number of failed attempts for that IP. The total number is stored in $hack_attempts{$svc}{$ip}
		# $block_results[2] - each service parser return it's own unique service id which is the id of the service which is under attack
		# $block_results[3] - the username that failed to authenticate to the given service
		my $attacker_ip = $block_results[0];
		my $attacker_attempts = $block_results[1];
		my $attacked_service = $block_results[2];
		my $block_info = $block_results[3];

		my $curr_time = time();
		# Store this failed attempt to the database
		logger("Storing failed: 0, $attacker_ip, $attacked_service, $block_info") if ($debug);
		if (! store_to_db($config{"db"}, $config{"dbuser"}, $config{"dbpass"}, 0, $attacker_ip, $attacked_service, $block_info)) {
			logger("store_to_db failed: 0, $attacker_ip, $attacked_service, $block_info!");
		}

		$hack_attempt->{$attacked_service}->{$attacker_ip} = get_attempts($attacker_attempts, $hack_attempt->{$attacked_service}->{$attacker_ip});
		logger("Failed attempts are $hack_attempt->{$attacked_service}->{$attacker_ip}") if ($debug);

		if ($set_limit && check_broots($hack_attempt->{$attacked_service}->{$attacker_ip}, $config{"block_count"})) {
			store_to_db($config{"db"}, $config{"dbuser"}, $config{"dbpass"}, 1, $attacker_ip, $attacked_service);
			if (! do_block($attacker_ip, $hack_attempt->{$attacked_service}->{$attacker_ip}, \%config, \@block_cmd, $block_info)) {
				logger("Failed to block $attacker_ip and store it to $config{'block_list'}") if ($debug);
			} else {
				logger("Successfully blocked $attacker_ip and stored to $config{'block_list'}") if ($debug);
				store_to_db($config{"db"}, $config{"dbuser"}, $config{"dbpass"}, 2, $attacker_ip, $config{"block_count"}, "failed");
			}
		} elsif (check_broots($hack_attempt->{$attacked_service}->{$attacker_ip}, $config{"broot_number"})) {
			#logger("store_to_db(broots): 1, ip, service code");
			store_to_db($config{"db"}, $config{"dbuser"}, $config{"dbpass"}, 1, $attacker_ip, $attacked_service);

			# Zero the number of failed attempts for this IP so we can prevent adding a new brute record on attempt_to_brute+1
			$hack_attempt->{$attacked_service}->{$attacker_ip} = 0;

			# Push that particular bruteforce attempt to the $attacked_svcs array ref
			#push(@{$svc{'as'}}, @arr); 
			push(@{$attacked_svcs->{$attacked_service}}, [$curr_time, $attacker_ip]);
			# Per-service counters
			# attacked_svcs->{service}[0] - Time of detection of the attempt
			# attacked_svcs->{service}[1] - IP of the attacker

			while (my ($service, @attackers) = each %$attacked_svcs) {
				my %attacks = ();
				# attacks{IP}[0] - 0 - number of bruteforce attempts per-IP
				# attacks{IP}[1] - 1 - storred to DB

				for (my $i = 0; $i < @{$attackers[0]}; $i++) {
					# This is really old attack and we do not count it now + we delete its records
					delete($attackers[0]->[$i]) and next if (($curr_time - $config{'broot_interval'}) > $attackers[0]->[$i]->[0]);

					# Remove the remaining elements for that IP if it is already blocked
					delete($attackers[0]->[$i]) and next if (defined($attacks{$attackers[0]->[$i]->[1]}[1]) && $attacks{$attackers[0]->[$i]->[1]}[1]);

					# Increase the number of broot attempts for this IP
					$attacks{$attackers[0]->[$i]->[1]}[0] = 0 if (! defined($attacks{$attackers[0]->[$i]->[1]}[0]));
					$attacks{$attackers[0]->[$i]->[1]}[0]++;
					#print "IP: $attackers[0]->[$i]->[1] Brutes: $attacks{$attackers[0]->[$i]->[1]}[0]\n";

					# Next as the bruteforce attempts are not enough for blocking
					next if ($attacks{$attackers[0]->[$i]->[1]}[0] < $config{'max_attempts'});

					if (! do_block($attackers[0]->[$i]->[1], $attacks{$attackers[0]->[$i]->[1]}[0], \%config, \@block_cmd, $block_info)) {
						logger("Failed to block $attackers[0]->[$i]->[1] and store it to $config{'block_list'}") if ($debug);
					} else {
						logger("Successfully blocked $attackers[0]->[$i]->[1] and stored to $config{'block_list'}") if ($debug);
						$attacks{$attackers[0]->[$i]->[1]}[1] = store_to_db($config{"db"}, $config{"dbuser"}, $config{"dbpass"}, 2, $attackers[0]->[$i]->[1], $config{'max_attempts'}, "bruteforce");
					}
				}
			}
		} else {
			logger("Not enough minerals to block $attacker_ip for bruteforcing $config{'services'}{$attacked_service} attempts $hack_attempt->{$attacked_service}->{$attacker_ip}(limit $config{'broot_number'})") if ($debug);
		}
	
		# clean all %hack_attempt entries if the $broot_time from the conf passed
		if (($curr_time - $start_time) > $broot_time) {
			logger("Cleaning the faults hashes and resetting the timers") if ($debug);
			# clean the hack_attempt hash and reset the timer
			#delete @hack_attempt{keys \$hack_attempt};
			$hack_attempt = {};
			$start_time = time();	# set the start_time to now
		}
	}
	
	# We should never hit those unless we kill tail :)
	logger("Gone ... after the main loop");
	close LOGS;
	logger("Gone ... after we closed the logs");
	close STDIN;
	logger("Gone ... after we closed the stdin");
	close STDOUT;
	logger("Gone ... after we closed the stdout");
	close STDERR;
	logger("Gone ... after we closed the stderr");
	close HAWKLOG;
	exit 0;
}

main();

=head1 NAME

hawk.pl - Hawk Open Source IDS/IPS 

=head1 SYNOPSIS

/path/to/hawk.pl [debug]

=head1 DESCRIPTION

hawk.pl also known as [Hawk] is a bruteforce monitoring detection and prevention daemon.

It monitors various CONFIGURABLE log files by using the GNU tail util.

The output from the logs is monitored for predefined patterns and later passed to different parsers depending on the service which appears to be under attack.

Currently [Hawk] is capable of detecting and blocking bruteforce attempts against the following services:

	- ftp - PureFTPD and ProFTPd

	- ssh - OpenSSH support only

	- pop3 - Dovecot support only

	- imap - Dovecot support only

	- smtp - Postfix

	- cPanel

	- cPanel webmail

	- DirectAdmin

	- more to come soon ... :)

Each failed login attempt is stored to a local USER CONFIGURABLE PostgreSQL database inside the failed_log table which is later used by hawk-web.pl for data visualization and stats.

In case of too many failed login attempts from a single IP address for certain predefined USER CONFIGURABLE amount of time the IP address is stored/logged to the same database but inside the broots table. The broots table is later parsed by the /root/hawk-blocker.sh which does the actual blocking of the IP via iptables.

=head1 PROGRAM FLOW

	- main() - init the vital variables and go to the main daemon loop.

	- parse_config() - get the conf variables.

	- is_hawk_running() - make sure that hawk is not already running.

	- get_ip() - get the main ip of the server.

	- fork.

	- close_stdh() - close stdin and stdout, redirect stderr to the logs.

	- write_pid() - write the new [Hawk] pid to the pidfile.

	- open the logs for monitoring.

	- MONITOR THE LOGS

	- pop_imap_broot(), ssh_broot(), ftp_broot(), cpanel_webmail_broot() - In case of hack attempt match, the control is passed to line parser for the given service.

	- is_local_ip() - Make sure that the IP of the attacker is not the local IP. We do not want to block localhosts.

	- get_attempts() - In case of bruteforce attempt we initialize or calculate the total number of failed attempts for that ip with this function.

	- store_to_db() - We also store this particular attempt to the failed_log table.

	- Check all attackers stored in %hack_attempt.

	- check_broots() - Compare the number of failed attempts for the current IP address with the max allowed failed attempts

	- store_to_db() - If the IP reached/exceeded the max allowed failed attempts the IP is stored to the broots table

	- Clear ALL IP addresses stored in %hack_attempt ONLY if $broot_time (USER CONFIGURABLE) seconds has elapsed and reset the timer

	- Start over to MONITOR LOGS

=head1 IMPORTANT VARIABLES

	- $conf - Full path to the [Hawk] and hawk-web.pl configuration file

	- %config - Store all $k,$v from the conf file so we can easily refference them via the conf var name

	- $logfile - Full path to the hawk.pl log file

	- $pidfile - Full path to the hawk.pl pid file

	- $config{'monitor_list'} - Space separated list of log files that should be monitoried by hawk. All of them should be on a SINGLE line

	- $log_list - The system command that will be executed to monitor the commands

	- $broot_time - The amount of time in seconds that should elapse before clearing all hack attempts from the hash

	- $local_ip - Primary IP address of the server

	- @block_results - Temporary storage for the results returned by the service_name_parsers. If no results it should be undef.
		
		$block_results[0] - attacker's ip address

		$block_results[1] - number of failed attempts as returned by the parser. NOTE: This is the CURRENT number of failed attempts for that IP. The total number is stored in $hack_attempts{$svc}{$ip}

		$block_results[2] - each service parser return it's own unique service id which is the id of the service which is under attack

		$block_results[3] - the username that failed to authenticate to the given service or a comment provided by the check

=head1 FUNCTIONS

=head2 get_ip() - Get the primary ip address of the server

	Input: NONE

	Returns: Main ip address of the server

=head2 is_local_ip() - Compare the current attacker's ip address with the local server ip

	Input:
		$local_ip - the local ip address of the server previously obtained from get_ip()
		$current_ip - the ip attacker's address returned by the servive_name_parser

	Output:
		0 if the IP address does not seem to be local
		1 if the IP address appears to be local

=head2 is_hawk_running() - Check if hawk is already running

	Input: $pidfile - The full system path to the pid file

	Output:
		0 if the pid does not exists, the old pid left from previous hawk instances does not exist in proc
		1 if hawk is already running or we have problem with the pid format left by previous/current hawk instance

=head2 close_stdh() - Close STDIN, STDOUT and redirect STDERR to the log fil

	Input: $logfile - The full system path to the hawk.pl log file

	Output:
		0 on failure
		1 on success

=head2 write_pid() - Write the new hawk pid to the pid file

	Input: $pidfile - The full system path to the hawk pid file

	Ouput:
		0 on failure
		1 on success

=head2 sigChld() - Reaper of the dead childs

	Called only in case of SIG CHILD

	Input: None

	Output: None

=head2 get_local_ips() - Get all currently assigned IPs. This makes sure we do not block any local IP in the firewall.

	Input: None

	Output: a hash with keys, all detected IPs and as values 1 for each IP

=head2 store_to_db() - Store the attacker's ip address to the failed_log or broots tables depending on the case

	Input:
		$_[0] - Where we should store this attempt
			- 0 means failed_log
			- 1 means broots
		$_[1] - The attacker's ip address that should be recorded to the DB
		$_[2] - The code of the service which is under attack
		$_[3] - The username that the attacker tried to use to login. Correctly defined only in case $_[0] is 0. Otherwise it is undef
		$_[4] - DB name
		$_[5] - DB user
		$_[6] - DB pass

	Output:
		0 on failure - In such case we will retry to store the attacker later on the next loop :)
		1 on success

=head2 get_attempts() - Compute the number of failed attempts for the current attacker

	Input:
		$new_count - The number of failed attempts we just received from the service parser for that ip
		$current_attacker_count - The stored number of failed attempts for that ip. Undef if this is a new attacker

	Output:
		Total number of failed attempts (we just sum old+new or return new if old is undef)

=head2 check_broots() - Compare the number of failed attempts for this attacker with the $max_attempts CONF variable

	Input:
		$ip_failed_count - Total number of failed attempts from this IP address
		$max_attempts - The conf variable

	Output:
		0 if $ip_failed_count < $max_attempts
		1 if $ip_failed_count >= $max_attempts -> This means, store this IP to the broots db and later block it with iptables via the cron

=head2 pop_imap_broot() ssh_broot() ftp_broot() cpanel_webmail_broot() - The logs output parsers for the supported services

	Input: $_ - The log line that looks like bruteforce attempt

	Output:
		$ip - The IP address of the attacker
		$num_failed - The number of failed attempts for that IP returned by the parser
		$service_id - The id/code of the service which is under attack
			0 - FTP
			1 - SSH
			2 - POP3
			3 - IMAP
			4 - WebMail
			5 - cPanel
			6 - DirectAdmin
			7 - Postfix
		$username - The username that failed to authenticate from that IP

=head2 main() - NO HELP AVAIL :)

=head1 CONFIGURATION FILE and CONFIGURABLE parameters

	db - The name of the database where the data will be stored by the daemon
	
	dbuser - The name of the user which has the rights to connect and store info to the db

	dbpass - ...

	template_path - Path to the hawk templates. Used only by hawk-web.pl

	service_ids - service_name:id pairs. What is the ID of "this" service?

	service_names - id:service_name pairs. What is the name of "this" service id?

	logfile - The full system path to the hawk.pl log file

	monitor_list - The full space separated list of logfiles that should be monitored by [Hawk] via tail. Should be on a single line.

	broot_time - The max amount of time in seconds that should pass before we clear the stored attacker's from the hash

	max_attempts - The max number of failed attempts before we block the attacker's ip address

	daemon_name - The name of the hawk.pl daemon as it will appear in ps uaxwf

=head1 SUPPORTED DATABASE ENGINES

	PostgreSQL only so far. We do not plan to release MySQL support as MySQL .... a duck :)

=head1 REPORTING BUGS

	mm@yuhu.biz

=head1 COPYRIGHT

	Marian Marinov <mm@yuhu.biz>, 
	Jivko Angelov <jivko@siteground.com>, 
	Valentin Chernozemski <valentin@siteground.com>

	License GPLv2

=head1 SEE ALSO

	hawk-web.pl, hawk-web.conf, hawk-block.sh, hawk.init
=cut

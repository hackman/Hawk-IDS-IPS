#!/usr/bin/perl -T
use strict;
use warnings;
use DBD::mysql;
use POSIX qw(setsid), qw(strftime), qw(WNOHANG);	# use only setsid & strftime from POSIX

# system variables
$ENV{PATH} = '';		# remove unsecure path
my $version = '0.91';	# version string

# defining fault hashes
our %ssh_faults = ();		# ssh faults storage
our %ftp_faults = ();		# ftp faults storage
our %pop3_faults = ();		# pop3 faults storage
our %imap_faults = ();		# imap faults storage
our %smtp_faults = ();		# smtp faults storage
our %cpanel_faults = ();	# cpanel faults storage
our %notifications = ();	# notifications
our %possible_attackers = ();	# possible hack attempts
our %authenticated_ips = ();	# authenticated_ips storage
our %reported_ips = ();

# make DB vars
my $db		= 'DBI:Pg:database=hawk;host=localhost;port=5432';
my $user	= 'hawk';
my $pass	= '19b536501eea';

# Hawk files
my $logfile = '/var/log/hawk.log';	# daemon logfile
my $pidfile = '/var/run/hawk.pid';	# daemon pidfile
my $ioerrfile = '/home/sentry/public_html/io.err'; # File where to add timestamps for I/O Errors
my $log_list = '/usr/bin/tail -s 0.03 -F --max-unchanged-stats=20 /var/log/messages /var/log/secure /var/log/maillog /usr/local/cpanel/logs/access_log /usr/local/cpanel/logs/login_log |';
our $broot_time = 300;	# time(in seconds) before cleaning the hashes
our $firewall_update = 5400; # time(in seconds) before updating the firewall
our $clean_reported = 600;
our %allowed_ips = ();
our $max_attempts = 5;	# max number of attempts(for $broot_time) before notify
our $debug = 0;			# by default debuging is OFF
our $do_limit = 0;		# by default do not limit the offending IPs
our $authenticated_ips_file = '/etc/relayhosts';	# Authenticated to Dovecot IPs are stored here
my $courier_imap = 0;
my $dovecot = 0;
my $start_time = time();
my $io_notified = $start_time;
my $io_first = 0;
my $pop_time = $start_time;
my $fw_time = $start_time;
my $pop_max_time = 1800;
my $myip = get_ip();
my $hostname = '';

# check for debug
if ( defined($ARGV[0]) && $ARGV[0] =~ /debug/ ) {
	$debug=1;		# turn on debuging
}

open HOST, '<', '/proc/sys/kernel/hostname' or die "Unable to open hostname file: $!\n";
$hostname = <HOST>;
close HOST;
#$hostname =~ s/[\r|\n]//;
$hostname =~ s/serv01.//;
chomp ($hostname);

open EXIM, '<', '/etc/exim.conf' or die "Unable to open exim.conf: $!\n";
while (<EXIM>) {
	if ($_ =~ /maildir/) {
		$courier_imap = 1;
		last;
	}
}
close EXIM;

if ( -f '/etc/dovecot.conf' ) {
	$courier_imap = 0;
	$dovecot = 1;
}
# changing to unbuffered output
our $| = 1;

# Change program name
$0 = "[Hawk]";

# open the logfile
open HAWK, '>>', $logfile or die "DIE: Unable to open logfile $logfile: $!\n";
logger("Hawk version $version started!");

# execute this before DIE-ing :)
$SIG{__DIE__}  = sub { logger(@_); };
$SIG{"CHLD"} = \&sigChld;

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

sub sigChld {
	while (waitpid(-1,WNOHANG)>0 ) {
		logger("The child has been cleaned!") if ($debug);
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

sub check_ip {
	if ( $_[0] =~ /[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}/ ) {
		return 1;
	} else {
		return 0;
	}
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
	while ( my ($k,$v) = each (%possible_attackers) ) {
		if ( $possible_attackers{$k}[0] > 5 ) {
			if (defined($possible_attackers{$k}[3])) {
				if ($possible_attackers{$k}[0] > 25 && $possible_attackers{$k}[3] < 3) {
					$possible_attackers{$k}[3] = 6;
					notify_hack("ip: $k service: $possible_attackers{$k}[2] attempts: $possible_attackers{$k}[0] type: bruteforce server: $hostname");
				}
			} else {
				notify_hack("ip: $k service: $possible_attackers{$k}[2] attempts: $possible_attackers{$k}[0] type: bruteforce server: $hostname");
				$possible_attackers{$k}[3] = 1;
			}
		}
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
if ($debug) {
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

# prepare the connection
our $conn	= DBI->connect_cached( $db, $user, $pass, { PrintError => 1, AutoCommit => 1 }) or die "DIE: Unable to connecto to DB: $!\n";
our $log_me = $conn->prepare('INSERT INTO failed_log ( ip, "user", service ) VALUES ( ?, ?, ? ) ') 
	or die "DIE: Unable to prepare log query: $!\n";
our $broot_me = $conn->prepare('INSERT INTO broots ( ip, service ) VALUES ( ?, ? ) ') 
	or die "DIE: Unable to prepare broot query: $!\n";
my $get_failed = $conn->prepare('SELECT COUNT(id) AS id FROM failed_log') 
	or die "Unable to prepare log query: $!\n";

# notifications to admins

sub notify_hack {
	my @message = split /\s+/, shift;
	my $enabled = 1;
	my $internal = 0;
	my $dbhost = '209.85.112.32';
	my $dbuser = 'parolcho';
	my $dbpass = 'parolataa';
	my $dbase = 'sitechecker';	
	if ($enabled) {	
		my $mask = $message[1];
		$mask =~ s/\.[0-9]{1,3}$/\.0/;
		$internal = 1 if (defined($allowed_ips{$message[1]}) || defined($allowed_ips{$mask}));
		if (! $internal) {
			my $now = time();
			if (defined($reported_ips{$message[1]}) && (($now - $reported_ips{$message[1]}[1]) < $clean_reported)) {
				logger("$message[1] already reported as intruder!") if ($debug);
			} else {
				logger("Intruder @message ... notifying our monitoring!") if ($debug);
				my $mconn = DBI->connect("DBI:mysql:database=$dbase:host=$dbhost","$dbuser","$dbpass", {'RaiseError' => 0});
				my $notify = $mconn->prepare("INSERT internal_notes(servername,date,notice) VALUES('$hostname' , now(), '@message')");
				$notify->execute;
				$notify->finish;
				$mconn->disconnect;
				$reported_ips{$message[1]}[0] = $message[1];
				$reported_ips{$message[1]}[1] = $now;
			}
		}
	}
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
		$broot_me->execute($_[1],$_[0]) or logger("Failed broot: $_[0], $_[1], $_[2] |$DBI::errstr");
		logger("!!! $_[0] $_[1] failed $_[2] times in $broot_time seconds");
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

sub send_fault() {
	eval {
		local $SIG{ALRM} = sub { die 'alarm'; };
		alarm 5;
		use IO::Socket::INET;
		if ( my $sock = new IO::Socket::INET ( PeerAddr => 'master.sgvps.net', PeerPort => '80', Proto => 'tcp', Timeout => '3') ) {
			# Send the faulty drive!
			print $sock "GET /~sentry/cgi-bin/ioerrors.pl?hdd=$_[0]\n\n";
			my @replay = <$sock>;
			close $sock;
		} else {
			logger "Unable to connect to report IO error: $!";
		}
		open IOERR, '>', $ioerrfile or logger('Unable to log I/O Error');
		print IOERR strftime('%b %d %H:%M:%S', localtime(time)) . " $_[0]\n";
		close IOERR;
		alarm 0;
	};
}

sub firewall_update {
    delete @allowed_ips{keys %allowed_ips};
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
				$allowed_ips{$_} = $_;
			}
			close $sock;
			while (my $ip = each (%allowed_ips)) {
				logger("Allowed IPs hash entry $ip") if ($debug);
			}
		} else {
			logger("Unable to connect to report IO error: $!");
		}
        alarm 0;
    };
}

firewall_update();

while (<LOGS>) {
	if ($dovecot) {
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
				next if ( $pop3[8] =~ /$myip/ );	# this is the local server
				if (exists $possible_attackers{$pop3[8]}) {
					$possible_attackers{$pop3[8]}[0] = $possible_attackers{$pop3[8]}[0] + $pop3[$failed_entry];
					$possible_attackers{$pop3[8]}[1] = $pop3[6];
					logger("Possible attacker ".$possible_attackers{$pop3[8]}[0]." attempts with different usernames from ip ".$pop3[8]) if ($debug);
				} else {
					$possible_attackers{$pop3[8]} = [ $pop3[$failed_entry], $pop3[6], 'pop3' ];
					logger("Possible attacker first attempt from ip ".$pop3[8]) if ($debug);
				}
				$log_me->execute($pop3[8], $pop3[6], 'pop3');
				if (exists $pop3_faults{$pop3[8]}) {
					$pop3_faults{$pop3[8]} = $pop3_faults{$pop3[8]} + $pop3[$failed_entry];
				} else {
					$pop3_faults{$pop3[8]} = $pop3[$failed_entry];
				}
				logger("IP $pop3[8]($pop3[6]) faild to identify to dovecot-pop3 $pop3[$failed_entry] times") if ($debug);
			}
		} elsif ($_ =~ /imap-login/ ) {
			#Jan 27 23:24:28 serv01 dovecot: imap-login: user=<user>, method=PLAIN, rip=77.70.33.151, lip=67.15.172.14 Aborted login (auth failed, 1 attempts)
			my @imap = split /\s+/, $_;
			if (defined $imap[11] && $imap[11] eq 'Login') {
			# Jan 27 23:31:26 serv01 dovecot: imap-login: user=<m.harrington@okemomountainschool.org>, method=PLAIN, rip=67.223.78.73, lip=67.15.172.14, TLS Login
			# Jan 27 23:31:52 serv01 dovecot: imap-login: user=<m.harrington@okemomountainschool.org>, method=PLAIN, rip=67.15.172.14, lip=67.15.172.14, secured Login
				$imap[8] =~ s/rip=(.*),/$1/;
				save_ip($imap[8]);
			} elsif ($_ =~ /auth failed/) {
				my $failed_entry = 14;
				if ($_ =~ /secured Aborted login/ ) {
					$failed_entry = 15;
				} elsif ($_ =~ /Aborted login/ && $_ !~ /secured/) {
					$failed_entry = 14;
				} elsif ($_ =~ /Disconnected/) {
					$failed_entry = 13;
				}
				# Jan 27 23:33:24 serv01 dovecot: imap-login: user=<test>, method=PLAIN, rip=77.70.33.151, lip=67.15.172.14 Aborted login (auth failed, 3 attempts)
				$imap[8] =~ s/rip=(.*),/$1/;
				$imap[6] =~ s/user=<(.*)>,/$1/;
				next if ( $imap[8] =~ /$myip/ );	# this is the local server
				if (exists $possible_attackers{$imap[8]}) {
					$possible_attackers{$imap[8]}[0] = $possible_attackers{$imap[8]}[0] + $imap[$failed_entry];
					$possible_attackers{$imap[8]}[1] = $imap[6];
					logger("Possible attacker ".$possible_attackers{$imap[8]}[0]." attempts from ip ".$imap[8]) if ($debug);
				} else {
					$possible_attackers{$imap[8]} = [ $imap[$failed_entry], $imap[6], 'imap' ];
					logger("Possible attacker first attempt from ip ".$imap[8]) if ($debug);
				}
				$log_me->execute($imap[8], $imap[6], 'imap');
				if ( exists $imap_faults {$imap[8]} ) {
					$imap_faults{$imap[8]} = $imap_faults{$imap[8]} + $imap[$failed_entry];
				} else {
					$imap_faults{$imap[8]} = $imap[$failed_entry];
				}
				logger("IP $imap[8]($imap[6]) faild to identify to dovecot-pop3 $imap[$failed_entry] times") if ($debug);
			}
		}
	} elsif ($courier_imap) {
		# Courier IMAP & POP3
		if ( $_ =~ /pop3d:/ && $_ =~ /FAILED/ ) {
			#May 11 03:58:40 serv01 pop3d: LOGIN FAILED, user=kate, ip=[::ffff:72.43.28.210]
			my @pop3 = split /\s+/, $_;
			$pop3[8] =~ s/ip=\[(.*)\]/$1/;
			$pop3[7] =~ s/user=(.*),/$1/;
			$pop3[8] =~ s/.*:// if $pop3[8] =~ /ffff/;
			next if ( $pop3[8] =~ /$myip/ );	# this is the local server
			if ( exists $possible_attackers {$pop3[8]} && $possible_attackers{$pop3[8]}[1] ne $pop3[7] ) {
				$possible_attackers{$pop3[8]}[0]++;
				$possible_attackers{$pop3[8]}[1] = $pop3[7];
				logger("Possible attacker ".$possible_attackers{$pop3[8]}[0]." attempts with different usernames from ip ".$pop3[8]) if ($debug);
			} else {
				$possible_attackers{$pop3[8]} = [ 0, $pop3[7], 'pop3' ];
				logger("Possible attacker first attempt with different usernames from ip ".$pop3[8]) if ($debug);
			}
			$log_me->execute($pop3[8], $pop3[7], 'pop3');
			if ( exists $pop3_faults {$pop3[8]} ) {
				$pop3_faults{$pop3[8]}++;
			} else {
				$pop3_faults{$pop3[8]} = 1;
			}
			logger("IP $pop3[8]($pop3[7]) faild to identify to courier-pop3") if ($debug);
		} elsif ( $_ =~ /imapd/ && $_ =~ /FAILED/ ) {
			#May 15 05:26:16 serv01 imapd: LOGIN FAILED, user=admin, ip=[::ffff:67.15.243.20]
			my @imap = split /\s+/, $_;
			$imap[8] =~ s/host=\[::ffff:(.*)\]/$1/;
			$imap[7] =~ s/user=//;
			next if ( $imap[8] =~ /$myip/ );	# this is the local server
			if ( exists $possible_attackers {$imap[8]} && $possible_attackers{$imap[8]}[1] ne $imap[7] ) {
				$possible_attackers{$imap[8]}[0]++;
				$possible_attackers{$imap[8]}[1] = $imap[7];
				logger("Possible attacker ".$possible_attackers{$imap[8]}[0]." attempts with different usernames from ip ".$imap[8]) if ($debug);
			} else {
				$possible_attackers{$imap[8]} = [ 0, $imap[7], 'imap' ];
				logger("Possible attacker first attempt with different usernames from ip ".$imap[8]) if ($debug);
			}
			$log_me->execute($imap[8], $imap[7], 'imap');
			if ( exists $imap_faults {$imap[8]} ) {
				$imap_faults{$imap[8]}++;
			} else {
				$imap_faults{$imap[8]} = 1;
			}
			logger(" IP $imap[8]($imap[7]) failed to identify to courier-imap.") if ($debug);
		}
	} elsif ($dovecot == 0 && $courier_imap == 0) {
		if ( $_ =~ /cpanelpop/ && $_ =~ /totalxfer=102\s*$/ ) {
			#May 16 02:37:31 serv01 cpanelpop[29746]: Session Closed host=67.15.172.8 ip=67.15.172.8 user=root realuser= totalxfer=102
			my @pop3 = split /\s+/, $_;
			if ( defined($pop3[10]) && $pop3[10] =~  /realuser=/ ) {
				$pop3[7] =~ s/host=//;
				next if ( $pop3[7] =~ /$myip/ ); # this is the local server
				$log_me->execute($pop3[7], '', 'pop3') or logger("Failed to insert: $pop3[7], $DBI::errstr");
				if ( exists $pop3_faults {$pop3[7]} ) {
					$pop3_faults{$pop3[7]}++;
				} else {
					$pop3_faults{$pop3[7]} = 1;
				}
				logger("IP $pop3[7] faild to identify to cppop") if ($debug);
			}
	 	} elsif ( $_ =~ /imapd/ && $_ =~ /failed/ ) {
			#May 17 17:06:44 serv01 imapd[32199]: Login failed user=dsada domain=(null) auth=dsada host=[85.14.6.2]
			my @imap = split /\s+/, $_;
			$imap[10] =~ s/host=\[(.*)\]/$1/;
			$imap[7] =~ s/user=//;
			next if ( $imap[10] =~ /$myip/ );	# this is the local server
			$log_me->execute($imap[10], $imap[7], 'imap');
			if ( exists $imap_faults {$imap[10]} ) {
				$imap_faults{$imap[10]}++;
			} else {
				$imap_faults{$imap[10]} = 1;
			}
			logger("IP $imap[10]($imap[7]) failed to identify to cpimap.") if ($debug);
		}
	}
	if ( $_ =~ /I\/O error/i ) { 
		# Feb 14 19:18:35 serv01 kernel: end_request: I/O error, dev sdb, sector 1405725148
		if ($io_first) {
			if ((time() - $io_notified) < 900) {
				logger("IO error detected but have been already notified during the last 15 mins ... skipping the notice");
				next;
			}
		}
		my @line = split /\s+/, $_;
		my $pid = fork();
		defined $pid or logger("Resources not avilable. Unable to fork checker.");
		setsid;
		if ($pid == 0) {
			# this is the child
			$0="sending_hdd_fault_on-".$line[9];
			&send_fault($line[9]);
			exit 0;
		}
		$io_first = 1 if ($io_first != 1);
		$io_notified = time();
	} elsif ($_ =~ /\/\.htaccess uploaded/) {
		# Aug 14 16:20:09 serv01 pure-ftpd: (kansasc1@87.248.180.90) [NOTICE] /home/kansasc1//.htaccess uploaded  (471 bytes, 2.83KB/sec)
		my @line = split /\s+/, $_;
		my $ip = $line[5];
		my $user = $ip;
		$user =~ s/\((.*)\@.*/$1/;
		$ip   =~ s/.*\@(.*)\)/$1/;
 		#notify_hack("ip: $ip service: ftpd user: $user server: $hostname type: uploaded .htaccess");
 	} elsif ( $_ =~ /sshd\[[0-9].+\]:/) {
		chomp($_);
		next if ($_ =~ /input_userauth_request:/);
		my $ip = '';
		my $user = '';
		my $message = $_;
		my $ssh_issue = 0;
		my $action = 0;
		if ( $_ =~ /Failed password for/ || $_ =~ /Failed none for/ || $_ =~ /authentication failure/ || $_ =~ /Invalid user/ || $_ =~ /Connection closed by/ ) {
			my @sshd = split /\s+/, $_;
			if ( $sshd[8] =~ /invalid/ ) {
				#May 16 03:27:24 serv01 sshd[25536]: Failed password for invalid user suport from ::ffff:85.14.6.2 port 52807 ssh2
				#May 19 22:54:19 serv01 sshd[21552]: Failed none for invalid user supprot from 194.204.32.101 port 20943 ssh2
				$sshd[12] =~ s/::ffff://;
				$ip = $sshd[12];
				$user = $sshd[10];
				$ssh_issue = 1;
				logger("sshd: Incorrect V1 $user $ip $message") if ($debug);
			} elsif ( $sshd[5] =~ /Connection/ ) {
				#May 25 02:11:34 serv01 sshd[10146]: Connection closed by 87.118.135.130
				$sshd[8] =~ s/::ffff://;
				$ip = $sshd[8];
				$user = 'none';
				$ssh_issue = 1;
				logger("sshd: Incorrect KEY $user $ip $message") if ($debug);
			} elsif ( $sshd[5] =~ /Invalid/) {
				#May 19 22:54:19 serv01 sshd[21552]: Invalid user supprot from 194.204.32.101
				$sshd[9] =~ s/::ffff://;
				$ip = $sshd[9];
				$user = $sshd[7];
				$ssh_issue = 1;
				logger("sshd: Incorrect V2 $user $ip $message") if ($debug);
			} elsif ( $sshd[5] =~ /pam_unix\(sshd:auth\)/ ) {
				#May 15 09:39:10 serv01 sshd[9474]: pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=194.204.32.101  user=root
				$sshd[13] =~ s/::ffff://;
				$sshd[13] =~ s/rhost=//;
				$ip = $sshd[13];
				$user = $sshd[14];
				$ssh_issue = 1;
				logger("sshd: Incorrect PAM $user $ip $message") if ($debug);
			} else {
				#May 15 09:39:12 serv01 sshd[9474]: Failed password for root from 194.204.32.101 port 17326 ssh2
				#May 15 11:36:27 serv01 sshd[5448]: Failed password for support from ::ffff:67.15.243.7 port 47597 ssh2
				$sshd[10] =~ s/::ffff://;
				$ip = $sshd[10];
				$user = $sshd[8];
				$ssh_issue = 1;
				logger("sshd: Incorrect V3 $user $ip $message") if ($debug);
			}
			$action = 1 if ($ssh_issue);
		} elsif ( $_ =~ /Accepted publickey/ || $_ =~ /Accepted password/ ) {
			#May 25 00:48:58 serv01 sshd[16015]: Accepted publickey for root from 75.125.60.5 port 32863 ssh2
			#May 20 00:51:54 serv01 sshd[20568]: Accepted password for support from ::ffff:67.15.245.5 port 50336 ssh2
			#May 20 01:14:46 serv01 sshd[17692]: Accepted password for support from ::ffff:67.15.245.5 port 59698 ssh2
			my @sshd = split /\s+/, $_;
			$sshd[10] =~ s/::ffff://;
			$ip = $sshd[10];
			$user = $sshd[8];
			$ssh_issue = 1;
			$action = 2;
			logger("sshd: Login $user $ip $message") if ($debug);
		} elsif ( $_=~ /Bad protocol version identification/ ) {
			#May 15 09:33:45 serv01 sshd[29645]: Bad protocol version identification '0penssh-portable-com' from 194.204.32.101
			my @sshd = split /\s+/, $_;
			$sshd[11] =~ s/::ffff://;
			$ip = $sshd[11];
			$user = 'none';
			$ssh_issue = 1;
			$action = 2;
			logger("sshd: Grabber $user $ip $message") if ($debug);
		}

		if ($ssh_issue) {
			$message =~ s/\'//g;
			if ($action == 1) {
				next if ( $ip =~ /$myip/ );	# this is the local server
				notify_hack("ip: $ip service: sshd user: $user type: bruteforce server: $hostname verbose: $message");
				$log_me->execute($ip, $user, 'ssh');
				if ( exists $ssh_faults {$ip} ) {
					$ssh_faults{$ip}++;
				} else {
					$ssh_faults{$ip} = 1;
				}
			} elsif ($action == 2) {
				notify_hack("ip: $ip service: sshd user: $user type: UNAUTHORIZED server: $hostname verbose: $message");
			} else {
				logger("sshd: Unknown action on sshd issue!");
			}
		} else {
			logger("sshd: Unknown case verbose: $message");
		}
	} elsif ( $_ =~ /pure-ftpd:/ && $_ =~ /failed/ ) {
		# May 16 03:06:43 serv01 pure-ftpd: (?@85.14.6.2) [WARNING] Authentication failed for user [mamam]
		# Mar  7 01:03:49 serv01 pure-ftpd: (?@68.4.142.211) [WARNING] Authentication failed for user [streetr1] 
		my @ftp = split /\s+/, $_;	
 		$ftp[5] =~ s/\(.*\@(.*)\)/$1/;	# get the IP
		$ftp[11] =~ s/\[(.*)\]/$1/;		# get the username
		$log_me->execute($ftp[5], $ftp[11], 'ftp') or logger("Unable to execute query: $DBI::errstr");
		if ( exists $possible_attackers {$ftp[5]} && $possible_attackers{$ftp[5]}[1] ne $ftp[11])  {
			$possible_attackers{$ftp[5]}[0]++;
			$possible_attackers{$ftp[5]}[1] = $ftp[11];
			logger("Possible attacker ".$possible_attackers{$ftp[5]}[0]." attempts with different usernames from ip ".$ftp[5]) if ($debug);
		} else {
			$possible_attackers{$ftp[5]} = [ 0, $ftp[11], 'ftp' ];
			logger("Possible attacker first attempt with different usernames from ip ".$ftp[5]) if ($debug);
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
		my $service = 'webmail';
		$service = 'cpanel' if ($cpanel[10] eq 'cpaneld:');
		$cpanel[2] = '' if $cpanel[2] =~ /\[/;
		$log_me->execute($cpanel[0], $cpanel[2], 'cp_'.$service);
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

	if (($curr_time - $fw_time) > $firewall_update) {
		firewall_update();
		$fw_time = time();
	}
}

close LOGS;
close HAWK;
close STDIN;
close STDOUT;
close STDERR if (!$debug);
exit 0;

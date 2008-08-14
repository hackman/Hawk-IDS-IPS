#!/usr/bin/perl -T
use strict;
use warnings;
use DBD::mysql;
use POSIX qw(setsid), qw(strftime);	# use only setsid & strftime from POSIX

# system variables
$ENV{PATH} = '';		# remove unsecure path
my $version = '0.76';	# version string

# defining fault hashes
our %ssh_faults = ();		# ssh faults storage
our %ftp_faults = ();		# ftp faults storage
our %pop3_faults = ();		# pop3 faults storage
our %imap_faults = ();		# imap faults storage
our %smtp_faults = ();		# smtp faults storage
our %cpanel_faults = ();	# cpanel faults storage
our %notifications = ();	# notifications

our %possible_attackers = ();	# possible hack attempts

# make DB vars
my $db		= 'DBI:Pg:database=hawk;host=localhost;port=5432';
my $user	= 'hawk';
my $pass	= '157856cc61d4';

# Hawk files
my $logfile = '/var/log//hawk.log';	# daemon logfile
my $pidfile = '/var/run/hawk.pid';	# daemon pidfile
my $ioerrfile = '/home/sentry/public_html/io.err'; # File where to add timestamps for I/O Errors
my $log_list = '/usr/bin/tail -f /var/log/messages /var/log/secure /var/log/maillog /usr/local/cpanel/logs/access_log /usr/local/cpanel/logs/login_log |';
our $broot_time = 300;	# time(in seconds) before cleaning the hashes
our $max_attempts = 5;	# max number of attempts(for $broot_time) before notify
our $debug = 0;			# by default debuging is OFF
our $do_limit = 0;		# by default do not limit the offending IPs

my $hostname = '';
my $start_time = time();
my $myip = get_ip();


# check for debug
if ( defined($ARGV[0]) && $ARGV[0] =~ /debug/ ) {
	$debug=1;		# turn on debuging
}

open HOST, '<', '/proc/sys/kernel/hostname';
$hostname = <HOST>;
close HOST;
$hostname =~ s/[\r|\n]//;

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
		logger("hashes cleaned!");
}

# check for broots
sub check_broot {
# 	foreach ( keys %ssh_faults ) {
# 		if ( $ssh_faults{$_} > $max_attempts ) {
# 			notify('ssh', $_, $ssh_faults{$_});
# 		}
# 	}
# 	foreach ( keys %pop3_faults ) {
# 		if ( $pop3_faults{$_} >= $max_attempts ) {
# 			notify('pop3', $_, $pop3_faults{$_});
# 		}
# 	}
# 	foreach ( keys %imap_faults ) {
# 		if ( $imap_faults{$_} > $max_attempts ) {
# 			notify('imap', $_, $imap_faults{$_});
# 		}
# 	}
#         foreach ( keys %smtp_faults ) {
#                 if ( $smtp_faults{$_} > $max_attempts ) {
#                         notify('imap', $_, $smtp_faults{$_});
#                 }
#         }
# 	foreach ( keys %cpanel_faults ) {
# 		if ( $cpanel_faults{$_} > $max_attempts ) {
# 			notify('cPanel', $_, $cpanel_faults{$_});
# 		}
# 	}
	while ( my ($k,$v) = each (%ssh_faults) ) {
		if ( $v > $max_attempts ) {
			notify('ssh', $k, $ssh_faults{$k});
		}
	}
	while ( my ($k,$v) = each (%pop3_faults) ) {
		if ( $v >= $max_attempts ) {
			notify('pop3', $k, $v);
		}
	}
	while ( my ($k,$v) = each (%imap_faults) ) {
		if ( $v > $max_attempts ) {
			notify('imap', $k, $imap_faults{$k});
		}
	}
	while ( my ($k,$v) = each (%smtp_faults) ) {
                if ( $v > $max_attempts ) {
                        notify('imap', $k, $smtp_faults{$k});
                }
        }
	while ( my ($k,$v) = each (%cpanel_faults) ) {
		if ( $v > $max_attempts ) {
			notify('cPanel', $k, $cpanel_faults{$k});
		}
	}
	while ( my ($k,$v) = each (%ftp_faults) ) {
		if ( $v > $max_attempts ) {
			notify('ftp', $k, $ftp_faults{$k});
		}
	}
	while ( my ($k,$v) = each (%possible_attackers) ) {
		if ( $possible_attackers{$k}[0] > 5 ) {
			if (defined($possible_attackers{$k}[3])) {
				if ($possible_attackers{$k}[0] > 25 && $possible_attackers{$k}[3] < 3) {
					$possible_attackers{$k}[3] = 6;
					notify_hack("$hostname possible break in, ".$possible_attackers{$k}[0]." attempts with different usernames from ip $k(".$possible_attackers{$k}[2].')');
				}
			} else {
				notify_hack("$hostname possible break in, ".$possible_attackers{$k}[0]." attempts with different usernames from ip $k(".$possible_attackers{$k}[2].')');
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

# prepare the connection
our $conn	= DBI->connect_cached( $db, $user, $pass, { PrintError => 1, AutoCommit => 1 }) or die "DIE: Unable to connecto to DB: $!\n";
our $log_me = $conn->prepare('INSERT INTO failed_log ( ip, "user", service ) VALUES ( ?, ?, ? ) ') 
	or die "DIE: Unable to prepare log query: $!\n";
our $broot_me = $conn->prepare('INSERT INTO broots ( ip, service ) VALUES ( ?, ? ) ') 
	or die "DIE: Unable to prepare broot query: $!\n";
my $get_failed = $conn->prepare('SELECT COUNT(id) AS id FROM failed_log') 
	or die "Unable to prepare log query: $!\n";

# $conn->{mysql_auto_reconnect} = 1;
# if ($conn->{mysql_auto_reconnect}) {
# 	print "Autoreconnect OK\n" if ($debug == 1);
# } else {
# 	die "Autoreconnect turned OFF!\n";
# }

# notifications to admins

sub notify_hack {
	my $message = shift;
	my $dbhost	= '209.85.112.32';
	my $dbuser	= 'parolcho';
	my $dbpass	= 'parolataa';
	my $dbase	= 'sitechecker';	
	my $mconn = DBI->connect("DBI:mysql:database=$dbase:host=$dbhost","$dbuser","$dbpass", {'RaiseError' => 0});
	my $notify = $mconn->prepare("INSERT internal_notes(servername,date,notice) VALUES('$hostname' , now(), '$message')");
	$notify->execute;
	$notify->finish;
	$mconn->disconnect;
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
		if (system("/usr/local/sbin/iptables -I in_hawk -i eth0 -p tcp --dport $services{$_[2]} -s $_[0] -m state --state NEW -m recent --set && iptables -I in_hawk -i eth0 -p tcp --dport $_[2] -s $_[0] -m state --state NEW -m recent --update --seconds 120 --hitcount 1 -j DROP ")) {
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
		if ( my $sock = new IO::Socket::INET ( PeerAddr => '64.246.15.53', PeerPort => '80', Proto => 'tcp', Timeout => '3') ) {
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

our @senders = ();
while (<LOGS>) {
	# Feb 13 19:18:35 serv01 kernel: end_request: I/O error, dev sdb, sector 1405725148
	# Feb 13 19:18:58 serv01 kernel: end_request: I/O error, dev sdb, sector 1405727387 
	if ( $_ =~ /I\/O error/i ) {
		my @line = split /\s+/, $_;
		# fork the checker
		my $pid = fork();
		# add the child's pid to che fork array
		push @senders, $pid;
		defined $pid or print "Resources not avilable. Unable to fork checker.\n";
		setsid;
		if ($pid == 0) {
			# this is the child
			$0="sending_hdd_fault_on-".$line[14];
			&send_fault($line[14]);
			exit 0;
		}		
	} elsif ($_ =~ /\/\.htaccess uploaded/) {
	# Aug 13 16:20:09 serv01 pure-ftpd: (kansasc1@87.248.180.90) [NOTICE] /home/kansasc1//.htaccess uploaded  (471 bytes, 2.83KB/sec)
		my @line = split /\s+/, $_;
		my $ip = $line[5];
		my $user = $ip;
		$user =~ s/\((.*)\@.*/$1/;
		$ip   =~ s/.*\@(.*)\)/$1/;
		notify_hack("Possible hack attempt at $hostname to user $user from ip $ip");
 	} elsif ( $_ =~ /ssh/ && $_ =~ /Failed/ ) {
	#May 15 11:36:27 serv01 sshd[5448]: Failed password for support from ::ffff:67.15.243.7 port 47597 ssh2
	#May 16 03:27:24 serv01 sshd[25536]: Failed password for invalid user suport from ::ffff:85.14.6.2 port 52807 ssh2
		my @sshd = split /\s+/, $_;
		my $ip = '';
		my $user = '';
		if ( $sshd[8] =~ /invalid/ ) {
			$sshd[12] =~ s/::ffff://;
			$ip = $sshd[12];
			$user = $sshd[10];
		} else {
			$sshd[10] =~ s/::ffff://;
			$ip = $sshd[10];
			$user = $sshd[8];
		}
		next if ( $ip =~ /$myip/ );	# this is the local server
		$log_me->execute($ip, $user, 'ssh');
		if ( exists $ssh_faults {$ip} ) {
			$ssh_faults{$ip}++;
		} else {
			$ssh_faults{$ip} = 1;
		}
		logger(" IP $ip failed to identify to ssh.") if ($debug);
    } elsif ( $_ =~ /cpanelpop/ && $_ =~ /totalxfer=102\s*$/ ) {
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
	} elsif ( $_ =~ /pop3d:/ && $_ =~ /FAILED/ ) {
	# Courier POP3
	#May 11 03:58:40 serv01 pop3d: LOGIN FAILED, user=kate, ip=[::ffff:72.43.28.210]
		my @pop3 = split /\s+/, $_;
		$pop3[8] =~ s/ip=\[(.*)\]/$1/;
		$pop3[7] =~ s/user=(.*),/$1/;
		$pop3[8] =~ s/.*:// if $pop3[8] =~ /ffff/;
		next if ( $pop3[8] =~ /$myip/ );	# this is the local server
		if ( exists $possible_attackers {$pop3[8]} && $possible_attackers{$pop3[8]}[1] ne $pop3[7] ) {
			$possible_attackers{$pop3[8]}[0]++;
			$possible_attackers{$pop3[8]}[1] = $pop3[7];
			logger("Possible attacker ".$possible_attackers{$pop3[8]}[0]." attempts with different usernames from ip ".$pop3[8]) if $debug;
		} else {
			$possible_attackers{$pop3[8]} = [ 0, $pop3[7], 'pop3' ];
			logger("Possible attacker first attempt with different usernames from ip ".$pop3[8]) if $debug;
		}
		$log_me->execute($pop3[8], $pop3[7], 'pop3');
		if ( exists $pop3_faults {$pop3[8]} ) {
			$pop3_faults{$pop3[8]}++;
		} else {
			$pop3_faults{$pop3[8]} = 1;
		}
		logger("IP $pop3[8]($pop3[7]) faild to identify to courier-pop3") if ($debug);
	} elsif ( $_ =~ /imapd/ && $_ =~ /failed/ ) {
	# cPanel IMAP
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
	} elsif ( $_ =~ /imapd/ && $_ =~ /FAILED/ ) {
	# Courier IMAP
	#May 15 05:26:16 serv01 imapd: LOGIN FAILED, user=admin, ip=[::ffff:67.15.243.20]
	    my @imap = split /\s+/, $_;
		$imap[8] =~ s/host=\[::ffff:(.*)\]/$1/;
		$imap[7] =~ s/user=//;
		next if ( $imap[8] =~ /$myip/ );	# this is the local server
		if ( exists $possible_attackers {$imap[8]} && $possible_attackers{$imap[8]}[1] ne $imap[7] ) {
			$possible_attackers{$imap[8]}[0]++;
			$possible_attackers{$imap[8]}[1] = $imap[7];
			logger("Possible attacker ".$possible_attackers{$imap[8]}[0]." attempts with different usernames from ip ".$imap[8]) if $debug;
		} else {
			$possible_attackers{$imap[8]} = [ 0, $imap[7], 'imap' ];
			logger("Possible attacker first attempt with different usernames from ip ".$imap[8]) if $debug;
		}
		$log_me->execute($imap[8], $imap[7], 'imap');
		if ( exists $imap_faults {$imap[8]} ) {
			$imap_faults{$imap[8]}++;
		} else {
			$imap_faults{$imap[8]} = 1;
		}
		logger(" IP $imap[8]($imap[7]) failed to identify to courier-imap.") if ($debug);
	} elsif ( $_ =~ /pure-ftpd:/ && $_ =~ /failed/ ) {
	#May 16 03:06:43 serv01 pure-ftpd: (?@85.14.6.2) [WARNING] Authentication failed for user [mamam]
	#Mar  7 01:03:49 serv01 pure-ftpd: (?@68.4.142.211) [WARNING] Authentication failed for user [streetr1] 
		my @ftp = split /\s+/, $_;	
 		$ftp[5] =~ s/\(.*\@(.*)\)/$1/;	# get the IP
		$ftp[11] =~ s/\[(.*)\]/$1/;		# get the username
		$log_me->execute($ftp[5], $ftp[11], 'ftp') or logger("Unable to execute query: $DBI::errstr");
		if ( exists $possible_attackers {$ftp[5]} && $possible_attackers{$ftp[5]}[1] ne $ftp[11])  {
			$possible_attackers{$ftp[5]}[0]++;
			$possible_attackers{$ftp[5]}[1] = $ftp[11];
			logger("Possible attacker ".$possible_attackers{$ftp[5]}[0]." attempts with different usernames from ip ".$ftp[5]) if $debug;
		} else {
			$possible_attackers{$ftp[5]} = [ 0, $ftp[11], 'ftp' ];
			logger("Possible attacker first attempt with different usernames from ip ".$ftp[5]) if $debug;
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
	my $passed_time = time() - $start_time;	# get the pssed time
	if ($passed_time > $broot_time) {		# if the passed time is grater then $broot_time
		cleanh();							# clean the hashes
		eval {
			local $SIG{ALRM} = sub { die 'alarm'; };
			alarm 2;
			# clean the childs(RAPER)
			# I have to write the new(better) RAPER, using SIGCHLD
			waitpid($_, 0) foreach(@senders);
			alarm 0;
		};
		$start_time = time();				# set the start_time to now
	}
}
close LOGS;
close HAWK;
close STDIN;
close STDOUT;
close STDERR if (!$debug);
exit 0;

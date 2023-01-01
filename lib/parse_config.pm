#!/usr/bin/perl
use strict;
use warnings;
package parse_config;
require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT     = qw(parse_config);
our $VERSION    = 0.00;
__PACKAGE__->main($ARGV[0]) unless caller; # executes at run-time, unless used as module

sub main {
	my $self = shift;
	my %conf = $self->parse_config($ARGV[0]);
	while (my ($k, $v) = each (%conf)) {
		print "$k => $v\n";
	}
}

sub parse_config {
	my %hash;
 	shift if ($_[0] eq 'parse_config');
	die "No config defined!\n" if !defined($_[0]);
	open CONF, '<', $_[0] or die "Unable to open $_[0]: $!\n";
	while (<CONF>) {
		if ($_ =~ /^#/ or $_ =~ /^[\s]*$/) {
			# if this is a comment or blank line skip to the next
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

1;
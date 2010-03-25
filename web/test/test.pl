#!/usr/bin/perl
use strict;
use warnings;
use CGI qw(param);
use CGI::Carp qw(fatalsToBrowser);
use JSON::XS;

print "Content-type: text/plain\r\n\r\n";
my $json = JSON::XS->new->ascii->allow_nonref;

my $rand_from = 0;
my $rand_to = 10000;

my $big_json = {
	total => 8,
	servers=> [ 
		{
			num=> '1',
			data=> [
				{hour=>'08:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from,	blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'09:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'10:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'11:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'12:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'13:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'14:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'15:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'16:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'17:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'18:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'19:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'20:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'21:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'22:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'23:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'00:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'01:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'02:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'03:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'04:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'05:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'06:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'07:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from}
			],
			name=> 'siteground' . int(rand(200)) . '.com',
		},
		{
			num=> '2',
			data=> [
				{hour=>'08:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from,	blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'09:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'10:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'11:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'12:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'13:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'14:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'15:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'16:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'17:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'18:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'19:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'20:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'21:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'22:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'23:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'00:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'01:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'02:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'03:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'04:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'05:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'06:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'07:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from}
			],
			name=> 'siteground' . int(rand(200)) . '.com',
		},
		{
			num=> '3',
			data=> [
				{hour=>'08:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from,	blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'09:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'10:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'11:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'12:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'13:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'14:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'15:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'16:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'17:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'18:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'19:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'20:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'21:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'22:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'23:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'00:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'01:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'02:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'03:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'04:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'05:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'06:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'07:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from}
			],
			name=> 'siteground' . int(rand(200)) . '.com',
		},
		{
			num=> '4',
			data=> [
				{hour=>'08:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from,	blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'09:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'10:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'11:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'12:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'13:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'14:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'15:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'16:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'17:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'18:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'19:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'20:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'21:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'22:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'23:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'00:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'01:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'02:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'03:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'04:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'05:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'06:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from},
				{hour=>'07:00', brutes=>int(rand($rand_to - $rand_from)) + $rand_from, failed=>int(rand($rand_to - $rand_from)) + $rand_from, blocked=>int(rand($rand_to - $rand_from)) + $rand_from}
			],
			name=> 'siteground' . int(rand(200)) . '.com',
		},
	]
};

print $json->encode($big_json);

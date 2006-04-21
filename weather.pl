#!/usr/bin/perl -W

use strict;
use URI;
use LWP::UserAgent;
use POSIX qw(strftime);
use XML::XPath;
use Getopt::Std;

our ($opt_x);
getopts('x:');

open GEOPOS, '<', '~/.geopos' or open GEOPOS, '<', '/etc/geopos' or die "can't get geopos\n";
my ($geopos) = <GEOPOS>;
close GEOPOS;
my ($lat, $lon) = split ' ', $geopos;

my $xp;
if (defined $opt_x)
{
	$xp = XML::XPath->new($opt_x);
}
else
{
	my $ndfdcache = "/tmp/ndfd-cache.xml";
	if (!-r $ndfdcache or -M $ndfdcache > 0.05)
	{
		my $time = time;
		my $tfmt = '%Y-%m-%dT%H:%M:%S%z';
		my $begin = strftime($tfmt, localtime($time));
		my $end = strftime($tfmt, localtime($time+86400));

		my $LWP = LWP::UserAgent->new;
		my $uri = URI->new('http://www.weather.gov/forecasts/xml/SOAP_server/ndfdXMLclient.php');
		$uri->query_form(
				'lat' => $lat,
				'lon' => $lon,
				'product' => 'time-series',
				'begin' => $begin,
				'end' => $end,
				'maxt' => 'maxt',
				'mint' => 'mint',
				'temp' => 'temp',
				'pop12' => 'pop12',
				'sky' => 'sky',
				'wspd' => 'wspd',
				'wdir' => 'wdir',
				'wx' => 'wx',
				'icons' => 'icons');
		my $got = $LWP->get($uri);
		die $got->status_line unless $got->is_success;
		open OUT, '>', $ndfdcache or die "$ndfdcache: $!\n";
		print OUT $got->content;
		close OUT;
	}
	$xp = XML::XPath->new($ndfdcache);
}

sub get
{
	my $r = $xp->find(@_);
	#die "@_ isn't a literal: $r" . ref($r) unless $r->isa('XML::XPath::Literal') || $r->isa('XML::XPath::Number');
	$r
}

my $maxt = get('//data/parameters/temperature[@type="maximum"]/value[1]/text()');
my $mint = get('//data/parameters/temperature[@type="minimum"]/value[1]/text()');
my $temp = get('//data/parameters/temperature[@type="hourly"]/value[1]/text()');
my $pop = get('//data/parameters/probability-of-precipitation[@type="12 hour"]/value[1]/text()');
my $cloud = get('//data/parameters/cloud-amount[@type="total"]/value[1]/text()');
my $condicon = get('//data/parameters/conditions-icon[@type="forecast-NWS"]/icon-link[1]/text()');
my $windspeed = get('//data/parameters/wind-speed[@type="sustained"]/value[1]/text()');
my $winddir = get('//data/parameters/direction[@type="wind"]/value[1]/text()');
my ($cond) = $condicon =~ /\/(\w*)\.jpg$/;

print <<EOF;
$cond
$mint $maxt $temp
$cloud $pop
$windspeed $winddir
EOF

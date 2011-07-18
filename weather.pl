#!/usr/bin/perl

use strict;
use URI;
use LWP::UserAgent;
use POSIX qw(strftime);
use XML::XPath;
use Getopt::Std;
#use Time::Piece;

our ($opt_x, $opt_n, $opt_f);
getopts('nfx:');

open GEOPOS, '<', "$ENV{HOME}/.geopos" or open GEOPOS, '<', '/etc/geopos' or die "can't get geopos\n";
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
	if (!$opt_n && (!-r $ndfdcache or -M $ndfdcache > 0.05 or $opt_f))
	{
		my $time = time;
		my $tfmt = '%Y-%m-%dT%H:%M:%S%z';
		my $begin = strftime($tfmt, localtime($time));
		my $end = strftime($tfmt, localtime($time+162000));

		my $LWP = LWP::UserAgent->new;
		my $uri = URI->new('http://www.weather.gov/forecasts/xml/SOAP_server/ndfdXMLclient.php');
		#my $uri = URI->new('http://www.weather.gov/forecasts/xml/sample_products/browser_interface/ndfdXMLclient.php');
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
	my $r = $xp->findnodes(@_);
	wantarray 
		? map { $_->string_value } $r->get_nodelist
		: $r->get_node(1)->string_value
}

my %tl_cache;
sub get_tl($)
{
	my ($tl) = @_;
	return $tl_cache{$tl} if exists $tl_cache{$tl};
	my @ts = get('//data/time-layout[layout-key="'.$tl.'"]/start-valid-time');
	#@ts = map { Time::Piece->strptime($_, '%Y-%m-%dT%T%z')->epoch } @ts;
	$tl_cache{$tl} = \@ts;
	@ts
}

sub get_tv
{
	my $r = $xp->findnodes(@_);
	my $n = $r->size;
	return if !$n;
	die "too many @_" if $n > 1;
	$r = $r->get_node(1);
	my $tl = $r->getAttribute("time-layout") or die "no time-layout in @_";
	my @ts = get_tl($tl);
	my %r;
	for my $v ($r->getChildNodes)
	{
		next unless $v->getName eq 'value';
		die "time-series mismatch" unless @ts;
		$r{shift @ts} = $v->string_value;
	}
	die "time-series mismatch" if @ts;
	%r
}

my %maxt = get_tv('//data/parameters/temperature[@type="maximum"]');
my %mint = get_tv('//data/parameters/temperature[@type="minimum"]');
my @temp = get('//data/parameters/temperature[@type="hourly"]/value');
my $pop = get('//data/parameters/probability-of-precipitation[@type="12 hour"]/value[1]');
my $cloud = get('//data/parameters/cloud-amount[@type="total"]/value[1]') || 0;
my @condicon = get('//data/parameters/conditions-icon[@type="forecast-NWS"]/icon-link');
my $windspeed = get('//data/parameters/wind-speed[@type="sustained"]/value[1]');
my $winddir = get('//data/parameters/direction[@type="wind"]/value[1]');

my %ext = (%maxt, %mint);
my @ext = sort keys %ext;
@ext = @ext{@ext};

my $condicon;
$condicon = shift @condicon until $condicon;
my ($cond) = $condicon =~ /\/(\w*)\.jpg$/;
$cond ||= 'none';
$cond =~ s/([1-9]|10)0$//;

print <<EOF;
$cond
@ext
@temp
$cloud
$pop
$windspeed $winddir
EOF

#!/usr/bin/perl -w

use strict;
use URI;
use LWP::UserAgent;
use POSIX qw(strftime);
use XML::XPath;
use Getopt::Std;
#use Time::Piece;

our ($opt_x, $opt_n, $opt_f, $opt_v);
getopts('nfvx:');

open GEOPOS, '<', "$ENV{HOME}/.geopos" or open GEOPOS, '<', '/etc/geopos' or die "can't get geopos\n";
my ($geopos) = <GEOPOS>;
close GEOPOS;
my ($lat, $lon) = split ' ', $geopos;

my $xp;
my $base = '/dwml/data';
if (defined $opt_x)
{
	$xp = XML::XPath->new($opt_x);
}
else
{
	my $ndfdcache = "/tmp/ndfd-cache.xml";
	my $upd = (!-r $ndfdcache or -M $ndfdcache > 0.05 or $opt_f) unless $opt_n;
	if ($upd)
	{
		my $time = time;
		my $tfmt = '%Y-%m-%dT%H:%M:%S%z';
		my $begin = strftime($tfmt, localtime($time));
		my $end = strftime($tfmt, localtime($time+432100));

		my $LWP = LWP::UserAgent->new;
		my $uri = URI->new('https://graphical.weather.gov/xml/SOAP_server/ndfdXMLclient.php');
		#my $uri = URI->new('http://www.weather.gov/forecasts/xml/SOAP_server/ndfdXMLclient.php');
		#my $uri = URI->new('http://www.weather.gov/forecasts/xml/sample_products/browser_interface/ndfdXMLclient.php');
		$uri->query_form(
				'lat' => $lat,
				'lon' => $lon,
				'product' => 'time-series',
				'begin' => $begin,
				'end' => $end,
				'Unit' => 'e',
				'maxt' => 'maxt',
				'mint' => 'mint',
				'temp' => 'temp',
				'dew' => 'dew',
				'pop12' => 'pop12',
				'sky' => 'sky',
				'wspd' => 'wspd',
				'wdir' => 'wdir',
				#'wx' => 'wx',
				'icons' => 'icons');
		print "$uri\n" if $opt_v;
		my $got = $LWP->get($uri);
		die $got->status_line unless $got->is_success;
		open OUT, '>', $ndfdcache or die "$ndfdcache: $!\n";
		my $content = $got->decoded_content;
		$content =~ s{^(.*<br />\n)*(?=<\?xml)}{};
		print OUT $content;
		close OUT;
	}
	$xp = XML::XPath->new($ndfdcache);

	if (!$xp->exists($base))
	{
		unlink $ndfdcache unless $opt_n || $upd;
		die "Error parsing result\n";
	}
}

sub get($)
{
	my $p = shift;
	my $r = $xp->findnodes($base.$p);
	return unless $r;
	wantarray 
		? map { $_->string_value } $r->get_nodelist
		: $r->get_node(1)->string_value
}

my %tl_cache;
sub get_tl($)
{
	my ($tl) = @_;
	return $tl_cache{$tl} if exists $tl_cache{$tl};
	my @ts = get('/time-layout[layout-key="'.$tl.'"]/start-valid-time');
	#@ts = map { Time::Piece->strptime($_, '%Y-%m-%dT%T%z')->epoch } @ts;
	$tl_cache{$tl} = \@ts;
	@ts
}

sub get_tv($)
{
	my $p = shift;
	my $r = $xp->findnodes($base.$p);
	return unless defined $r;
	my $n = $r->size;
	return if !$n;
	die "too many @_" if $n > 1;
	$r = $r->get_node(1);
	my $tl = $r->getAttribute("time-layout") or die "no time-layout in @_";
	my @ts = get_tl($tl);
	my %r;
	for my $v ($r->getChildNodes)
	{
		next unless ($v->getName // '') eq 'value';
		die "time-series mismatch" unless @ts;
		$r{shift @ts} = $v->string_value;
	}
	die "time-series mismatch" if @ts;
	%r
}

my %maxt = get_tv('/parameters/temperature[@type="maximum"]');
my %mint = get_tv('/parameters/temperature[@type="minimum"]');
my @temp = get('/parameters/temperature[@type="hourly"]/value');
my @dew = get('/parameters/temperature[@type="dew point"]/value');
my @pop = get('/parameters/probability-of-precipitation[@type="12 hour"]/value');
my @cloud = get('/parameters/cloud-amount[@type="total"]/value');
my @condicon = get('/parameters/conditions-icon[@type="forecast-NWS"]/icon-link');
my @windspeed = get('/parameters/wind-speed[@type="sustained"]/value');
my @winddir = get('/parameters/direction[@type="wind"]/value');

my %ext = (%maxt, %mint);
my @ext = sort keys %ext;
@ext = @ext{@ext};
pop @ext;

my $cond;
$cond = shift @condicon while @condicon && !$cond;
$cond ||= 'none';
$cond =~ s/^.*\/(\w*)\.jpg$/$1/;
$cond =~ s/([1-9]|10)0$/ ${1}0/;

print <<EOF;
$cond
@ext
@temp
@dew
@cloud
@pop
@windspeed
@winddir
EOF

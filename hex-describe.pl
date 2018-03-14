#!/usr/bin/env perl
# Copyright (C) 2018  Alex Schroeder <alex@gnu.org>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <http://www.gnu.org/licenses/>.

use Modern::Perl;
use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojo::Log;

my $log = Mojo::Log->new;

my $default_map = q{0101 dark-green trees village
0102 light-green bushes
0103 light-green bushes
0104 light-green bushes
0105 light-green bushes
0106 light-green forest-hill
0107 light-grey mountain
0108 white mountains cliff1
0109 white mountain
0110 light-grey mountain
0201 dark-grey swamp
0202 light-green bushes
0203 light-green bushes
0204 green forest
0205 light-green fir-forest
0206 light-green firs thorp
0207 white mountain cliff1
0208 white mountain
0209 light-grey mountain
0210 grey swamp
0301 light-green bushes
0302 dark-green trees town
0303 green forest
0304 dark-grey swamp
0305 light-green firs thorp cliff1
0306 light-green forest-hill
0307 light-grey mountain
0308 light-grey mountain
0309 light-grey mountain
0310 light-green fir-forest
0401 green forest
0402 green forest
0403 light-green bushes
0404 green trees village
0405 light-green fir-forest
0406 light-green forest-hill
0407 light-green firs thorp
0408 light-green fir-forest
0409 light-green forest-hill
0410 light-green firs thorp
0501 green forest
0502 light-green bushes
0503 green forest
0504 light-green bushes
0505 light-green firs thorp
0506 grey swamp
0507 grey swamp
0508 light-green fir-forest
0509 light-green fir-forest
0510 light-green bushes
0601 light-green fir-forest
0602 light-green fir-forest
0603 light-green fir-forest
0604 light-green forest-hill
0605 light-green forest-hill
0606 light-green forest-hill
0607 light-green bushes
0608 dark-grey swamp
0609 dark-grey swamp
0610 green trees village
0701 light-green forest-hill
0702 light-green forest-hill
0703 light-green fir-forest
0704 light-green firs thorp
0705 light-grey mountain
0706 light-grey mountain cliff4
0707 grey swamp
0708 light-green fir-forest
0709 light-green firs thorp
0710 dark-grey swamp
0801 light-grey mountain
0802 grey swamp
0803 light-grey mountain
0804 white mountains cliff0 cliff1 cliff5
0805 white mountain cliff4
0806 light-green fir-forest
0807 grey swamp
0808 light-green forest-hill
0809 light-green fir-forest
0810 light-green firs thorp
0901 white mountain
0902 light-grey mountain
0903 light-grey mountain
0904 white mountain
0905 white mountain
0906 light-grey mountain
0907 light-green firs thorp
0908 light-grey mountain cliff0
0909 light-green firs thorp
0910 light-green forest-hill
1001 white mountains cliff3 cliff5
1002 white mountain cliff3
1003 light-grey mountain
1004 white mountain cliff2
1005 light-grey mountain
1006 light-grey mountain
1007 light-grey mountain
1008 white mountain cliff5
1009 light-grey mountain
1010 light-green forest-hill
1101 white mountain
1102 light-grey mountain
1103 grey swamp
1104 water
1105 white mountains cliff1 cliff3 cliff5
1106 white mountain
1107 light-grey mountain
1108 white mountains cliff0 cliff1 cliff2
1109 white mountain
1110 light-grey mountain
1201 light-grey mountain
1202 grey swamp
1203 light-grey mountain
1204 white mountain cliff0 cliff3
1205 light-grey mountain
1206 light-grey mountain
1207 light-grey mountain
1208 white mountain
1209 light-grey mountain
1210 light-green firs thorp
1301 light-green forest-hill
1302 light-green forest-hill
1303 light-green fir-forest
1304 light-grey mountain
1305 grey swamp
1306 water
1307 light-grey mountain
1308 white mountains cliff0 cliff1
1309 white mountain
1310 light-grey mountain
1401 grey swamp
1402 grey swamp
1403 light-green firs thorp
1404 grey swamp
1405 light-grey mountain
1406 light-grey mountain
1407 white mountain
1408 white mountain
1409 light-grey mountain
1410 light-green firs thorp
1501 light-green fir-forest
1502 light-green forest-hill
1503 light-green fir-forest
1504 light-grey mountain
1505 grey swamp
1506 white mountain cliff1
1507 white mountains cliff0
1508 white mountains
1509 white mountain
1510 light-grey mountain
1601 light-green firs thorp
1602 light-grey mountain
1603 white mountain cliff0 cliff3
1604 light-grey mountain
1605 light-grey mountain
1606 white mountain
1607 white mountain
1608 white mountain
1609 light-grey mountain
1610 light-green firs thorp
1701 light-grey mountain
1702 white mountain cliff0
1703 white mountains cliff0 cliff3 cliff4
1704 grey swamp
1705 water
1706 light-grey mountain
1707 light-grey mountain
1708 light-grey mountain
1709 light-grey mountain
1710 light-green fir-forest
1801 light-grey mountain
1802 white mountain
1803 light-grey mountain
1804 light-grey mountain
1805 light-grey mountain
1806 grey swamp
1807 light-green fir-forest
1808 light-green firs thorp
1809 light-green forest-hill
1810 light-green fir-forest
1901 light-green firs thorp
1902 light-grey mountain
1903 light-grey mountain
1904 white mountain cliff2
1905 white mountain
1906 light-grey mountain
1907 light-green firs thorp
1908 grey swamp
1909 light-green fir-forest
1910 light-green bushes
2001 grey swamp
2002 light-green firs thorp
2003 light-green fir-forest
2004 white mountains cliff1
2005 white mountain
2006 light-grey mountain
2007 light-green forest-hill
2008 light-green firs thorp
2009 green trees village
2010 light-green bushes
1704-1604-1505 canyon
1510-1610-1711 river
1609-1710-1810-1711 river
1310-1410-1511 river
1102-1202-1303-1402-1401-1400 river
1110-1210-1111 river
0110-0210-0310-0410-0311 river
1409-1410-1511 river
0209-0210-0310-0410-0311 river
1602-1503-1402-1401-1400 river
2006-1907-1908-1909-2009-2110 river
0309-0408-0508-0608-0609-0610-0611 river
1206-1306-1305-1404-1403-1402-1401-1400 river
1405-1305-1404-1403-1402-1401-1400 river
1504-1404-1403-1402-1401-1400 river
1902-2002-2102 river
1906-1907-1908-1909-2009-2110 river
1203-1104-1103-1202-1303-1402-1401-1400 river
0107-0206-0205-0204-0304-0303-0302-0201-0101-0100 river
1801-1901-1900 river
1701-1601-1501-1500 river
1201-1202-1303-1402-1401-1400 river
1009-0909-0809-0710-0609-0610-0611 river
0908-0807-0707-0708-0608-0609-0610-0611 river
1708-1807-1908-1909-2009-2110 river
1304-1305-1404-1403-1402-1401-1400 river
1007-0907-0807-0707-0708-0608-0609-0610-0611 river
1903-2003-2103 river
0906-0806-0807-0707-0708-0608-0609-0610-0611 river
1709-1808-1909-2009-2110 river
0308-0407-0507-0508-0608-0609-0610-0611 river
1406-1306-1305-1404-1403-1402-1401-1400 river
1003-1103-1202-1303-1402-1401-1400 river
1006-0907-0807-0707-0708-0608-0609-0610-0611 river
1707-1807-1908-1909-2009-2110 river
1805-1806-1807-1908-1909-2009-2110 river
1307-1306-1305-1404-1403-1402-1401-1400 river
0706-0707-0708-0608-0609-0610-0611 river
1605-1505-1404-1403-1402-1401-1400 river
1804-1704-1604-1505-1404-1403-1402-1401-1400 river
1604-1505-1404-1403-1402-1401-1400 river
0902-0802-0703-0602-0503-0402-0302-0201-0101-0100 river
1209-1210-1111 river
1205-1306-1305-1404-1403-1402-1401-1400 river
0801-0802-0703-0602-0503-0402-0302-0201-0101-0100 river
1803-1704-1604-1505-1404-1403-1402-1401-1400 river
0307-0407-0507-0508-0608-0609-0610-0611 river
1005-0906-0806-0807-0707-0708-0608-0609-0610-0611 river
0705-0704-0603-0503-0402-0302-0201-0101-0100 river
1207-1107-1206-1306-1305-1404-1403-1402-1401-1400 river
1706-1806-1807-1908-1909-2009-2110 river
0803-0704-0603-0503-0402-0302-0201-0101-0100 river
0903-0802-0703-0602-0503-0402-0302-0201-0101-0100 river
1301-1401-1400 river
1809-1810-1711 river
1302-1401-1400 river
2001-2002-2102 river
1010-0911 river
2007-2008-2009-2110 river
0409-0509-0609-0610-0611 river
1502-1501-1500 river
0605-0505-0404-0304-0303-0302-0201-0101-0100 river
0910-0810-0710-0609-0610-0611 river
0701-0601-0501-0401-0302-0201-0101-0100 river
1705-1704-1604-1505-1404-1403-1402-1401-1400 river
0406-0405-0404-0304-0303-0302-0201-0101-0100 river
0306-0305-0304-0303-0302-0201-0101-0100 river
0808-0709-0608-0609-0610-0611 river
0702-0602-0503-0402-0302-0201-0101-0100 river
0106-0205-0204-0304-0303-0302-0201-0101-0100 river
0606-0506-0505-0404-0304-0303-0302-0201-0101-0100 river
0604-0505-0404-0304-0303-0302-0201-0101-0100 river
0404-0302 trail
0709-0610 trail
0305-0302 trail
0810-0610 trail
0302-0101 trail
1808-2009 trail
1210-0909 trail
1601-1403 trail
1901-1601 trail
0907-0709 trail
0206-0404 trail
0410-0610 trail
0407-0404 trail
2002-1901 trail
1410-1210 trail
1610-1808 trail
0909-0610 trail
0704-0404 trail
2008-2009 trail
0505-0404 trail
1907-2009 trail
include https://campaignwiki.org/contrib/gnomeyland.txt
# Seed: 1520694313
};

my $default_table = q{;light-grey mountain
1,the green valley up here has some sheep and a *kid* called [human kid] guarding them
1,there is a cold pond up in this valley [cold lake]
1,the upper valley is rocky [maybe a hill giant]
1,steep cliffs make progress practically impossible without climbing gear
1,nothing but gray rocks

;human kid
1,Al
1,Bert
1,Cus
1,Dirk
1,Ed
1,Fal
1,Gil
1,Hela
1,Ila
1,Jo
1,Keg

;cold lake
4,but it's cold and nothing lives here
1,and in it lives a *water spirit* called [undine]
1,with [2d4] *turtle people* led by one they call [turtle]

;undine
1,Tears of Joy
1,Tears of Sorrow
1,Mountain Dew
1,Eyes of Ice
1,Sweet Sleep

;turtle
1,Patience
1,Calm
1,Quiet
1,Slow
1,Peace
1,Submit
1,Wait

;maybe a hill giant
5,and empty
1,and some of these boulders have been assembled into a crude stone tower with [2d4] *hill giants* led by one they call [hill giant]

;hill giant
1,Flat Nose
1,Thunder Voice
1,Smash Fist
1,Sheep Finder
1,Ogon of the Valley, former soldier of Ugra the Great

;white mountain
1,the air up here is cold
1,snow fields make progress difficult without skis
1,there is a hidden meadow up here, hidden from view from below
1,the glaciers need a local guide and ropes to cross
1,the glacier ends at a small lake [maybe an ice cave]

;maybe an ice cave
1,bright blue and ice cold
1,and there is an ice cave leading beneath the glacier
1,and there is an ice cave inhabited by a *cryohydra*

;mountains
1,these peaks are impossible to climb
1,these passes need a local guide to cross
1,[mountain people]
1,ice covers these mountains and passage is dangerous
1,a glacier fills the gap between these mountains
1,the locals call these mountains the [dreadful] [peaks]

;dreadful
1,Dire
1,Desert
1,Dead
1,Mourning
1,Giant
1,Sharp
1,Hungry

;peaks
1,Peaks
1,Domes
1,Teeth
1,Giants
1,Domes
1,Mounts
1,Graves

;mountain people
1,[1d4 frost giants]
1,[2d4] *winter wolves*

;1d4 frost giants
1,the *frost giant* [frost giant] lives here in a [frost giant lair] with [frost giant companions]
3,[1d3+1] *frost giants* led by one they call [frost giant] live here with [frost giant companions] in a [frost giant lair]

;frost giant
1,Winter's Bone
1,Snow
1,Ice
1,Cold
1,Glacier
1,Storm
1,Darkness
1,Tooth

;frost giant lair
1,a glorious ice blue cave
1,an old castle built of gray stones
1,a castle built of ice and snow
1,a gargantuan palace of ice and darkness
1,a fortress guarding one of the passages to the realm of eternal ice

;frost giant companions
3,[1d4] *white bears*
2,[2d4] *winter wolves*
1,a *cryohydra*
1,a *white dragon*
1,a *spectre* of their ancient ice king
};

sub get_data {
  my $url = shift;
  $log->debug("get_data: $url");
  my $ua = Mojo::UserAgent->new;
  my $res = $ua->get($url)->result;
  return $res->body if $res->is_success;
  $log->error("get_data: " . $res->code . " " . $res->message);
}

sub get_post_data {
  my $url = shift;
  my %data = @_;
  $log->debug("get_post_data: $url");
  my $ua = Mojo::UserAgent->new;
  my $res = $ua->post($url => form => \%data)->result;
  return $res->body if $res->is_success;
  $log->error("get_post_data: " . $res->code . " " . $res->message);
}

sub parse_table {
  my $text = shift;
  $log->debug("parse_table: parsing " . length($text) . " characters");
  my $data = {};
  my $key;
  for my $line (split(/\n/, $text)) {
    if ($line =~ /^;([^#\n]+)/) {
      $key = $1;
    } elsif ($key and $line =~ /^(\d+),(.+)/) {
      $data->{$key}->{total} += $1;
      my %h = (count => $1, text => $2);
      $h{text} =~ s/\*(.*?)\*/<strong>$1<\/strong>/g;
      push(@{$data->{$key}->{lines}}, \%h);
    }
  }
  return $data;
}

sub pick_description {
  my $total = shift;
  my $lines = shift;
  my $roll = int(rand($total)) + 1;
  my $i = 0;
  for my $line (@$lines) {
    $i += $line->{count};
    if ($i >= $roll) {
      return $line->{text};
    }
  }
  return '';
}

sub describe {
  my $data = shift;
  my @words = @_;
  my @descriptions;
  for my $word (@words) {
    if (my ($n, $d, $p) = $word =~ /^(\d+)d(\d+)(?:\+(\d+))?$/) {
      my $r = $p||0;
      for(my $i = 0; $i < $n; $i++) {
	$r += int(rand($d)) + 1;
      }
      $log->debug("rolling dice: $word = $r");
      push(@descriptions, $r);
    } else {
      $log->debug("looking for a $word table");
      if ($data->{$word}) {
	my $total = $data->{$word}->{total};
	my $lines = $data->{$word}->{lines};
	my $text = pick_description($total, $lines);
	$text =~ s/\[(.*?)\]/describe($data,$1)/ge;
	$log->debug("picked $text from $total entries");
	push(@descriptions, $text);
      }
    }
  }
  return join(' ', @descriptions);
}

sub describe_map {
  my $map = shift;
  my $data = shift;
  my %descriptions;
  for my $hex (split(/\n/, $map)) {
    # based on text-mapper.pl Mapper process
    if ($hex =~ /^(\d\d)(\d\d)(?:\s+([^"\r\n]+)?\s*(?:"(.+)"(?:\s+(\d+))?)?|$)/) {
      my ($x, $y, $types) = ($1, $2, $3);
      $log->debug("describing $x$y");
      my @types = split(/ /, $types);
      my @words;
      for my $w1 (@types) {
	for my $w2 (@types) {
	  if ($w1 eq $w2) {
	    push(@words, $w1);
	  } else {
	    push(@words, "$w1 $w2");
	  }
	}
      }
      $descriptions{"$x$y"} = describe($data, @words);
    }
  }
  return \%descriptions;
}

get '/' => sub {
  my $c = shift;
  my $map = $c->param('map') || $default_map;
  my $url = $c->param('url');
  $c->render(template => 'edit', map => $map, url => $url);
};

get '/load/random/smale' => sub {
  my $c = shift;
  my $url = 'https://campaignwiki.org/text-mapper/smale/random/text';
  my $map = get_data($url);
  $c->render(template => 'edit', map => $map);
};

get '/load/random/alpine' => sub {
  my $c = shift;
  my $url = 'https://campaignwiki.org/text-mapper/alpine/random/text';
  my $map = get_data($url);
  $c->render(template => 'edit', map => $map);
};

any '/describe' => sub {
  my $c = shift;
  my $map = $c->param('map');
  my $svg = get_post_data('https://campaignwiki.org/text-mapper/render', map => $map);
  my $url = $c->param('table');
  my $table = $url ? get_data($url) : $default_table;
  my $data = parse_table($table);
  $c->render(template => 'description',
	     svg => $svg,
	     descriptions => describe_map($map, $data));
};

get '/default/map' => sub {
  my $c = shift;
  $c->render(text => $default_map, format => 'txt');
};

get '/default/table' => sub {
  my $c = shift;
  $c->render(text => $default_table, format => 'txt');
};

get '/source' => sub {
  my $c = shift;
  seek(DATA,0,0);
  local $/ = undef;
  $c->render(text => <DATA>, format => 'txt');
};

get '/help' => sub {
  my $c = shift;
  $c->render(template => 'help');
};

app->start;

__DATA__
@@ edit.html.ep
% layout 'default';
% title 'Hex Describe';
<h1>Hex Describe</h1>
<p>
Describe a hex map using some random data.
</p>
<p>
Load <%= link_to 'random Smale data' => 'loadrandomsmale' %>.
Load <%= link_to 'random Alpine data' => 'loadrandomalpine' %>.
</p>
%= form_for describe => (method => 'POST') => begin
%= text_area map => (cols => 60, rows => 15) => begin
<%= $map =%>
% end

<p>
Table URL:
%= text_field table => $url

<p>
%= submit_button 'Submit', name => 'submit'
</p>
%= end

<p>
<%= link_to 'Default Map' => 'defaultmap' %>&#x2003;
<%= link_to 'Default Table' => 'defaulttable' %>&#x2003;
</p>


@@ description.html.ep
% layout 'default';
% title 'Hex Describe';
<h1>Hex Descriptions</h1>
%== $svg

% for my $hex (sort keys %$descriptions) {
<p><strong><%= $hex =%></strong>: <%== $descriptions->{$hex} %></p>
% }


@@ help.html.ep
% layout 'default';
% title 'Hex Describe';
<h1>Hex Describe Help</h1>
<p>Sadly, the help is still missing.</p>


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
%= stylesheet '/hex-describe.css'
%= stylesheet begin
body {
  padding: 1em;
  font-family: "Palatino Linotype", "Book Antiqua", Palatino, serif;
}
textarea {
  width: 100%;
}
table {
  padding-bottom: 1em;
}
td, th {
  padding-right: 0.5em;
}
.example {
  font-size: smaller;
}
% end
<meta name="viewport" content="width=device-width">
</head>
<body>
<%= content %>
<hr>
<p>
<a href="https://campaignwiki.org/hex-describe">Hex Describe</a>&#x2003;
<%= link_to 'Help' => 'help' %>&#x2003;
<%= link_to 'Source' => 'source' %>&#x2003;
<a href="https://github.com/kensanata/hex-mapping/blob/master/hex-describe.pl">GitHub</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

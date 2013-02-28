#!/usr/bin/perl
# Copyright (C) 2007-2013  Alex Schroeder <alex@gnu.org>
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

# This code started out as a fork of old-school-hex.pl.

use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';
use strict;

package Hex;

use Class::Struct;

struct Hex => {
	       x => '$',
	       y => '$',
	       type => '$',
	       label => '$',
	       map => 'Mapper',
	      };

sub str {
  my $self = shift;
  return '(' . $self->x . ',' . $self->y . ')';
}

my $dx = 100;
my $dy = 100*sqrt(3);

sub svg {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $data = '';
  for my $type (@{$self->type}) {
    $data .= sprintf(qq{  <use x="%.1f" y="%.1f" xlink:href="#%s" />\n},
		     $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2, $type);
  }
  $data .= sprintf(qq{  <text text-anchor="middle" x="%.1f" y="%.1f" %s>}
		   . qq{%02d.%02d}
		   . qq{</text>\n},
		   $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 - $dy * 0.4,
		   $self->map->text_attributes,
		   $x, $y);
  return $data;
}

sub svg_label {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $filter = $self->map->glow ? qq{filter="url(#label-glow)"} : '';
  my $data = sprintf(qq{  <text text-anchor="middle" x="%.1f" y="%.1f" %s %s>%s</text>\n},
		     $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 + $dy * 0.4,
		     $self->map->label_attributes, $filter,
		     $self->label) if $self->label;
  return $data;
}

package Mapper;

use Class::Struct;

struct Mapper => {
		  hexes => '@',
		  attributes => '%',
		  map => '$',
		  path => '%',
		  path_attributes => '%',
		  text_attributes => '$',
		  label_attributes => '$',
		  glow => '$',
		 };

my $example = q{
# map definition
0101 mountain
0102 mountain
0103 hill
0104 forest
0201 mountain
0202 hill
0203 coast
0204 empty
0301 mountain
0302 mountain
0303 plain
0304 sea
0401 hill
0402 sand house
0403 jungle "Harald's Repose"

# attributes
empty attributes fill="#ffffff" stroke="black" stroke-width="3"
plain attributes fill="#7cfc00" stroke="black" stroke-width="3"
plain path attributes fill="#76ee00"
forest attributes fill="#228b22" stroke="black" stroke-width="3"
jungle attributes fill="#9acd32" stroke="black" stroke-width="3"
jungle path attributes fill="#228b22"
hill attributes fill="#daa520" stroke="black" stroke-width="3"
hill path attributes fill="#b8860b"
mountain attributes fill="#708090" stroke="black" stroke-width="3"
mountain path attributes fill="#666666"
sand attributes fill="#eedd82" stroke="black" stroke-width="3"
coast attributes fill="#7fffd4" stroke="black" stroke-width="3"
sea attributes fill="#4169e1" stroke="black" stroke-width="3"

# add shapes
hill path M -42,11 C -38,5 -34,0 -28,-3 C -20,-6 -11,-5 -5,-0 C -2,2 1,6 3,9 C 4,12 2,13 0,14 C -3,9 -7,5 -13,2 C -21,-1 -30,0 -36,6 C -38,9 -40,11 -43,14 C -43,15 -44,14 -44,13 C -43,12 -43,12 -42,11 z M -5,-0 C 0,-6 7,-12 15,-16 C 21,-18 28,-17 33,-14 C 39,-11 41,-5 43,-0 C 42,2 41,5 39,2 C 37,-2 33,-8 27,-10 C 20,-13 12,-12 6,-7 C 2,-4 -1,-1 -4,1 C -7,4 -6,0 -5,-0 z

plain path M -18,-13 C -13,-6 -13,4 -8,12 C -11,14 -15,21 -18,26 C -20,17 -22,4 -28,0 C -26,-4 -21,-9 -18,-13 z M 5,-31 C 4,-19 3,-6 6,5 C 1,10 -0,14 -3,19 C -2,6 -3,-4 -4,-16 C -4,-21 2,-26 5,-31 z M 26,-1 C 16,6 19,5 9,18 C 12,3 21,-8 34,-17 C 32,-12 29,-6 27,-1 z

mountain path M 30,-30 c -5,3 -19,18 -28,28 -4,-5 -7,-10 -9,-16 -7,4 -40,43 -43,53 2,2 4,2 6,2 7,-8 26,-40 34,-46 10,14 26,31 35,49 2,-1 4,-3 5,-3 C 30,33 16,18 3,0 11,-8 21,-19 29,-25 39,-9 49,-3 58,13 60,12 60,11 61,10 61,5 42,-7 29,-30 z

house path M 0,4 C -6,7 -7,22 -6,26 -3,26 4,25 7,26 8,24 6,5 0,4 z M 7,-7 C 10,3 19,14 15,29 8,28 -5,30 -14,29 -13,9 -9,1 7,-7 z M 6,-38 c 7,12 34,23 48,27 -1,6 0,12 1,14 -9,-5 -11,-7 -18,-9 -3,14 0,24 2,33 -9,0 -7,3 -14,3 1,-13 4,-32 5,-39 -9,-4 -17,-11 -26,-17 -8,7 -20,13 -29,20 1,12 0,21 2,33 -7,1 -8,2 -14,4 0,-9 2,-22 1,-31 -7,4 -14,6 -21,8 2,-11 45,-22 64,-46 z

house path attributes fill="#664"

jungle path m 8,-20 c -6,-12 -36,-5 -44,7 9,-6 35,-12 37,-5 -18,0 -29,6 -33,24 C -22,-13 -8,-14 2,-13 -8,6 -20,13 -16,50 c 4,3 9,-5 5,-8 -1,-7 -1,-13 0,-20 C -10,10 1,-7 9,-12 27,-8 36,0 34,15 44,4 30,-12 14,-15 28,-16 41,-7 45,1 47,-8 29,-19 17,-20 c 11,-7 25,-3 30,3 -5,-14 -36,-11 -39,-3 z

text font-size="20pt" dy="15px"
label font-size="20pt" dy="5px"
glow
};

sub example {
  return $example;
}

my $dx = 100;
my $dy = 100*sqrt(3);

sub initialize {
  my ($self, $map) = @_;
  $self->map($map);
  foreach (split(/\r?\n/, $map)) {
    if (/^(\d\d)(\d\d)\s+([^"\r\n]+)?\s*(?:"(.+)")?/) {
      my $hex = Hex->new(x => $1, y => $2, map => $self);
      $hex->label($4);
      my @types = split(' ', $3);
      $hex->type(\@types);
      $self->add($hex);
    } elsif (/^(\S+)\s+attributes\s+(.*)/) {
      $self->attributes($1, $2);
    } elsif (/^(\S+)\s+path\s+attributes\s+(.*)/) {
      $self->path_attributes($1, $2);
    } elsif (/^(\S+)\s+path\s+(.*)/) {
      $self->path($1, $2);
    } elsif (/^text\s+(.*)/) {
      $self->text_attributes($1);
    } elsif (/^glow/) {
      $self->glow(1);
    } elsif (/^label\s+(.*)/) {
      $self->label_attributes($1);
    }
  }
}

sub add {
  my ($self, $hex) = @_;
  push(@{$self->hexes}, $hex);
}

sub svg {
  my ($self) = @_;

  my ($minx, $miny, $maxx, $maxy);
  foreach my $hex (@{$self->hexes}) {
    $minx = $hex->x if not defined($minx);
    $maxx = $hex->x if not defined($maxx);
    $miny = $hex->y if not defined($miny);
    $maxy = $hex->x if not defined($maxy);
    $minx = $hex->x if $minx > $hex->x;
    $maxx = $hex->x if $maxx < $hex->x;
    $miny = $hex->y if $miny > $hex->y;
    $maxy = $hex->x if $maxy < $hex->y;
  }
  ($minx, $miny, $maxx, $maxy) =
    (($minx -0.5) * $dx - 10, ($miny - 1) * $dy - 10,
     ($maxx) * 1.5 * $dx + $dx + 10, ($maxy + 1.5) * $dy + 10);

  my $doc = qq{<?xml version="1.0" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     viewBox="$minx $miny $maxx $maxy"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <filter id="label-glow">
      <feFlood flood-color="white"/>
      <feComposite in2="SourceGraphic" operator="in"/>
      <feGaussianBlur stdDeviation="2.5 1.5"/>
      <feComponentTransfer>
        <feFuncA type="linear" slope="4" intercept="0.0"/>
      </feComponentTransfer>
      <feComposite in="SourceGraphic"/>
    </filter>
};

  # collect hex types from attributess and paths in case the sets don't overlap
  my %type = ();
  foreach my $type (keys %{$self->attributes}) {
    $type{$type} = 1;
  }
  foreach my $type (keys %{$self->path}) {
    $type{$type} = 1;
  }

  # now go through them all
  foreach my $type (keys %type) {
    my $attributes = $self->attributes($type);
    my $path = $self->path($type);
    my $path_attributes = $self->path_attributes($type);
    my ($x1, $y1, $x2, $y2, $x3, $y3,
	$x4, $y4, $x5, $y5, $x6, $y6) =
	  (-$dx, 0, -$dx/2, $dy/2, $dx/2, $dy/2,
	   $dx, 0, $dx/2, -$dy/2, -$dx/2, -$dy/2);
    if ($path && $attributes) {
      $doc .= qq{
    <g id='$type'>
      <polygon $attributes points='$x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 $x6,$y6' />
      <path $path_attributes d='$path' />
    </g>};
    } elsif ($path) {
      $doc .= qq{
    <path id='$type' $path_attributes d='$path' />};
    } else {
      $doc .= qq{
    <polygon id='$type' $attributes points='$x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 $x6,$y6' />}
    }
  }
  $doc .= q{
  </defs>
};

  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg();
  }
  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg_label();
  }

  $doc .= "<!-- Source\n" . $self->map() . "\n-->";

  $doc .= qq{
</svg>};

  return $doc;
}

package main;

sub print_map {
  print header(-type=>'image/svg+xml');
  my $map = new Mapper;
  $map->initialize(shift);
  print $map->svg;
}

sub print_html {
  print (header(-type=>'text/html; charset=UTF-8'),
	 start_html(-encoding=>'UTF-8', -title=>'Text Mapper',
		    -author=>'kensanata@gmail.com'),
	 h1('Text Mapper'),
	 p('Submit your text desciption of the map.'),
	 start_form(-method=>'GET'),
	 p(textarea('map', Mapper::example(), 15, 60)),
	 p(submit()),
	 end_form(),
	 hr(),
	 p(a({-href=>'http://www.alexschroeder.ch/wiki/About'},
	     'Alex Schröder'),
	   a({-href=>url() . '/source'}, 'Source'),
	   a({-href=>'https://github.com/kensanata/hex-mapping'},
	     'GitHub')),
	 end_html());
}

sub main {
  if (param('map')) {
    print_map(param('map'));
  } elsif (path_info() eq '/source') {
    seek(DATA,0,0);
    undef $/;
    print <DATA>;
  } else {
    print_html();
  }
}

main ();

__DATA__

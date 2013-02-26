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
use strict;

package Hex;

use Class::Struct;

struct Hex => {
	       x => '$',
	       y => '$',
	       type => '$',
	       map => 'Mapper',
	      };

sub at {
  my ($self, $x, $y) = @_;
  return $self->x == $x && $self->y == $y;
}

sub str {
  my $self = shift;
  return '(' . $self->x . ',' . $self->y . ')';
}

my $dx = 100*sqrt(3);
my $dy = 100;

sub svg {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $type = $self->type;
  my $data = sprintf(qq{  <use x="%.1f" y="%.1f" xlink:href="#%s" />\n}
		     . qq{  <text text-anchor="middle" x="%.1f" y="%.1f" %s>}
		     . qq{%d, %d}
		     . qq{</text>\n},
		     $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy, $type,
		     $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy - $dy * 2 / 3,
		     $self->map->text_attributes,
		     $x, $y);
  return $data;
}

package Mapper;

use Class::Struct;

struct Mapper => {
		  hexes => '@',
		  attributes => '%',
		  path => '%',
		  path_attributes => '%',
		  text_attributes => '$',
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
0402 sand
0403 forest

# attributes
empty attributes fill="#ffffff" stroke="black" stroke-width="3"
plain attributes fill="#7cfc00" stroke="black" stroke-width="3"
plain path attributes fill="#76ee00"
forest attributes fill="#228b22" stroke="black" stroke-width="3"
hill attributes fill="#daa520" stroke="black" stroke-width="3"
hill path attributes fill="#b8860b"
mountain attributes fill="#708090" stroke="black" stroke-width="3"
sand attributes fill="#eedd82" stroke="black" stroke-width="3"
coast attributes fill="#7fffd4" stroke="black" stroke-width="3"
sea attributes fill="#4169e1" stroke="black" stroke-width="3"

# add shapes
hill path M -42,11 C -38,5 -34,0 -28,-3 C -20,-6 -11,-5 -5,-0 C -2,2 1,6 3,9 C 4,12 2,13 0,14 C -3,9 -7,5 -13,2 C -21,-1 -30,0 -36,6 C -38,9 -40,11 -43,14 C -43,15 -44,14 -44,13 C -43,12 -43,12 -42,11 z M -5,-0 C 0,-6 7,-12 15,-16 C 21,-18 28,-17 33,-14 C 39,-11 41,-5 43,-0 C 42,2 41,5 39,2 C 37,-2 33,-8 27,-10 C 20,-13 12,-12 6,-7 C 2,-4 -1,-1 -4,1 C -7,4 -6,0 -5,-0 z

plain path M -18,-13 C -13,-6 -13,4 -8,12 C -11,14 -15,21 -18,26 C -20,17 -22,4 -28,0 C -26,-4 -21,-9 -18,-13 z M 5,-31 C 4,-19 3,-6 6,5 C 1,10 -0,14 -3,19 C -2,6 -3,-4 -4,-16 C -4,-21 2,-26 5,-31 z M 26,-1 C 16,6 19,5 9,18 C 12,3 21,-8 34,-17 C 32,-12 29,-6 27,-1 z

text font-size="20pt" dy="15px"
};

sub example {
  return $example;
}

my $dx = 100*sqrt(3);
my $dy = 100;

sub initialize {
  my ($self, $map) = @_;
  foreach (split(/\r?\n/, $map)) {
    if (/^(\d\d)(\d\d)\s+(\S+)/) {
      my $hex = Hex->new(x => $1, y => $2, type => $3, map => $self);
      $self->add($hex);
    } elsif (/^(\S+)\s+attributes\s+(.*)/) {
      $self->attributes($1, $2);
    } elsif (/^(\S+)\s+path\s+attributes\s+(.*)/) {
      $self->path_attributes($1, $2);
    } elsif (/^(\S+)\s+path\s+(.*)/) {
      $self->path($1, $2);
    } elsif (/^text\s+(.*)/) {
      $self->text_attributes($1);
    }
  }
}

sub add {
  my ($self, $hex) = @_;
  push(@{$self->hexes}, $hex);
}

# This implementation is *very* slow.
sub get {
  my ($self, $x, $y) = @_;
  foreach my $hex (@{$self->hexes}) {
    if ($hex->at($x, $y)) {
      return $hex;
    }
  }
  # warn "did not find ($x,$y)\n";
  return undef;
}

sub svg {
  my ($self) = @_;
  my $doc = qq{<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
  "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     viewBox="-$dx -$dy 1000 1000"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>};

  # collect hex types from attributess and paths in case the sets don't overlap
  my %type = ();
  foreach my $type (keys %{$self->attributes}) {
    $type{$type} = 1;
  }
  foreach my $type (keys %{$self->path}) {
    $type{$type} = 1;
  }

  # no go through them all
  foreach my $type (keys %type) {
    my $attributes = $self->attributes($type);
    my $path = $self->path($type);
    my $path_attributes = $self->path_attributes($type);
    my ($x1, $y1, $x2, $y2, $x3, $y3,
	$x4, $y4, $x5, $y5, $x6, $y6) =
	  (-$dx/2, -$dy/2, -$dx/2, $dy/2, 0, $dy,
	   $dx/2, $dy/2, $dx/2, -$dy/2, 0, -$dy);
    if ($path) {
      $doc .= qq{
    <g id='$type'>
      <polygon $attributes points='$x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 $x6,$y6' />
      <path $path_attributes d='$path' />
    </g>};
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

  $doc .= q{
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
	   a({-href=>url() . '/source'}, 'Source')),
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

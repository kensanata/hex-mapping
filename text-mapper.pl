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
		     . qq{  <text text-anchor="middle" x="%.1f" y="%.1f">}
		     . qq{%d, %d}
		     . qq{</text>\n},
		     $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy, $type,
		     $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy - $dy * 2 / 3,
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
empty attributes fill="#ffffff" stroke="#b3b3ff"
plain attributes fill="#7cfc00"
plain path attributes fill="#7fff00"
forest attributes fill="#228b22"
hill attributes fill="#daa520"
hill path attributes fill="#b8860b"
mountain attributes fill="#708090"
sand attributes fill="#eedd82"
coast attributes fill="#7fffd4"
sea attributes fill="#4169e1"

# add shapes
hill path M -42.887901,11.051062 C -38.8,5.5935948 -34.0,0.5 -28.174309,-3.0 C -20.987476,-6.5505102 -11.857161,-5.1811592 -5.7871072,-0.050580244 C -2.0,2.6706698 1.1683798,6.1 3.8585628,9.8783938 C 4.1,12.295981 2.5,13.9 0.57117882,14.454662 C -3.0696782,9.3 -7.8,5.1646538 -13.4,2.1 C -21.686794,-1.7 -30.0,0.79168476 -36.5,6.6730178 C -38.8,9.0 -40.9,11.5 -43.086547,14.0 C -43.088939,15.072012 -44.8,14.756431 -44.053241,13.8 C -43.7,12.8 -43.0,12.057 -42.887901,11.051062 z M -5.0,-0.75883624 C 0.9,-6.9553992 7.6,-12.7 15.5,-16.171056 C 21.5,-18.6 28.5,-17.6 33.9,-14.2 C 39.15207,-11.0 41.67227,-5.5846132 43.7,-0.072156244 C 42.456295,2.4 41.252332,5.7995568 39.0,2.9 C 37.295351,-2.9527612 33.1,-8.2775842 27.4,-10.7 C 20.5,-13.551561 12.2,-12.061567 6.4,-7.4 C 2.4597998,-4.7 -1.0845122,-1.4893282 -4.5,1.8 C -7.2715222,4.0 -6.0866092,0.89928976 -5.0,-0.75883624 z

plain path M -18.4,-13.8 C -13.773555,-6.4 -13.5,4.8 -8.5597061,12.2 C -11.8,14.870577 -15.069019,21.666847 -18.3,26.4 C -20.361758,17.3 -22.6,4.6520873 -28.6,0.77998732 C -26.199022,-4.0 -21.798258,-9.2 -18.4,-13.8 z M 5.6,-31.658907 C 4.3,-19.899253 3.8,-6.1 6.266188,5.9733973 C 1.5,10.168437 -0.26595005,14.952917 -3.5,19.4 C -2.899459,6.8 -3.177218,-4.7 -4.689108,-16.686835 C -4.2,-21.8 2.474668,-26.0 5.6,-31.658907 z M 26.968846,-1.1996857 C 16.0,6.5525273 19.067496,5.3 9.571268,18.1 C 12.890808,3.4845973 21.898666,-8.9 34.1,-17.3 C 32.1,-12.1 29.4,-6.5 27.0,-1.2 z
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

=head2 The Coordinate System

The coordinates of the hex map use a slanted Y axis:

      0,-1       1,-1     2,-1
 -1,0      0,0       1,0      2,0
      -1,1       0,1      1,1
          -1,2       0,2      1,2
                -1,3      0,3

=cut

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

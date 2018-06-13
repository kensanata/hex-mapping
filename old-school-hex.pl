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

use CGI qw/:standard/;
use strict;

=head1 Old School Hex Mapper

A CGI script that will accept a map written using ASCII characters and
create an SVG map.

=cut

# $Id: old-school-hex.pl,v 1.17 2007/06/08 23:36:23 alex Exp $

package Hex;

use Class::Struct;

struct Hex => {
	       x => '$',
	       y => '$',
	       type => '$',
	       road => '$',
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
  my $data = sprintf(qq{  <use class="hex" x="%.1f" y="%.1f" xlink:href="#%s" />\n}
		     . qq{  <text class="number" text-anchor="middle" x="%.1f" y="%.1f">}
		     . qq{%d, %d}
		     . qq{</text>\n},
		     $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy, $type,
		     $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy - $dy * 2 / 3,
		     $x, $y);
  if ($self->road) {
    foreach my $tile ($self->straight_roads, $self->road_start,
		      $self->bent_roads, $self->very_bent_roads) {
      $data .= sprintf(qq{  <use class="road" x="%.1f" y="%.1f" xlink:href="#%s" transform="rotate(%s, %.1f, %.1f)" />\n},
		       $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy,
		       $tile->{name}, $tile->{angle},
		       $x * $dx + $y * $dx / 2, $y * 3 / 2 * $dy);
    }
  }
  return $data;
}

=head3 @connect

The connection data to connect to neighbouring hexes. The array is
indexed as follows:

      2  3
     1    4
      0  5

=cut

my $connect = [[-1, +1,   0],
	       [-1,  0,  60],
	       [ 0, -1, 120],
	       [+1, -1, 180],
	       [+1,  0, 240],
	       [ 0, +1, 300]];

=head3 neighbor

Return the neighboring hex specified by number:

      2  3
     1    4
      0  5

=cut

sub neighbor {
  my ($self, $num) = @_;
  my $x = $self->x + @$connect[$num]->[0];
  my $y = $self->y + @$connect[$num]->[1];
  my $hex = $self->map->get($x, $y);
  # warn "getting ($x,$y) -> $hex\n";
  return $hex;
}

=head3 neighbors

Return a list of all neighboring hexes. This returns an array of
exactly six elements indexed by direction. An undefined elements means
that there is no neighbour in this direction.

These are the directions:

      2  3
     1    4
      0  5

=cut

sub neighbors {
  my $self = shift;
  return map { $self->neighbor($_); } 0..5;
}

=head3 angle

Return the angle between the current hex and the one provided.
Basically this is the direction times 60.

These are the directions:

      2  3
     1    4
      0  5

=cut

sub angle {
  my ($self, $obj1, $obj2) = @_;
  if (ref($obj1) eq 'Hex') {
    my $dx = $obj1->x - $self->x;
    my $dy = $obj1->y - $self->y;
    foreach my $conn (@$connect) {
      return $conn->[2] if $conn->[0] == $dx && $conn->[1] == $dy;
    }
  } elsif (defined($obj2)) {
    return ($obj2 - $obj1) * 60;
  }
  die "Unknown objects $obj1 and $obj2";
}

=head3 neighboring_roads

Return a list of all neighboring hexes containing roads.

=cut

sub neighboring_roads {
  my $self = shift;
  my @result;
  foreach my $hex ($self->neighbors) {
    push(@result, $hex) if $hex && $hex->road;
  }
  return @result;
}

=head3 straight_roads

Look at surrounding hexes to determine if there is a straight road
running through the current hex. Return a list of hash-references,
each hash containing two keys: The name of the tile to use and the
angle to rotate it by.

=cut

sub straight_roads {
  my $self = shift;
  my @hex = $self->neighbors;
  my @roads;
  foreach my $dir ([0,3], [1,4], [2,5]) {
    my $from = $dir->[0];
    my $to = $dir->[1];
    # warn join(', ', $self->str, $from, $to, $hex[$from], $hex[$to]), "\n";
    if ($hex[$from] && $hex[$to]
	&& $hex[$from]->road && $hex[$to]->road) {
      push(@roads, {name => "road180", angle => $self->angle($hex[$from])});
    }
  }
  return @roads;
}

=head3 road_start

Look at surrounding hexes to determine if there is but a single road
leaving the hex. Return the angle you need to rotate the tile by in
order to draw the road.

=cut

sub road_start {
  my $self = shift;
  my @hexes = $self->neighboring_roads;
  # warn sprintf("%s has %d neighbors\n", $self->str, $#hexes+1);
  return () if $#hexes != 0; # more than one neighboring hex has a road, or none
  return {name=>'road-start', angle=>$self->angle($hexes[0])};
}

=head3 bent_roads

Look at surrounding hexes to determine if there are two neighbors with
roads at a 120° angle. Return the angle you need to rotate the tile by
in order to draw the road.

=cut

sub bent_roads {
  my $self = shift;
  my @hexes = $self->neighboring_roads;
  return () if $#hexes > 2; # only works for three or less neighboring hexes with roads
  my @hex = $self->neighbors;
  my @roads = ();
  foreach my $dir ([0,2], [1,3], [2,4], [3,5], [4,0], [5,1]) {
    my $from = $dir->[0];
    my $to = $dir->[1];
    if ($hex[$from] && $hex[$to]
	&& $hex[$from]->road && $hex[$to]->road) {
      push(@roads, {name => "road120", angle => $self->angle($hex[$from])});
    }
  }
  return @roads;
}

=head3 very_bent_roads

Look at surrounding hexes to determine if there are two neighbours at
a 60° angle. Only hexes with two neighboring roads are candidates.
Return the angle you need to rotate the tile by in order to draw the
road.

FIXME: Is this required?

=cut

sub very_bent_roads {
  my $self = shift;
  my @hexes = $self->neighboring_roads;
  return () if $#hexes != 1; # only works for exactly two neighboring hexes with roads
  my @hex = $self->neighbors;
  my @roads = ();
  foreach my $dir ([0,1], [1,2], [2,3], [3,4], [4,5], [5,0]) {
    my $from = $dir->[0];
    my $to = $dir->[1];
    if ($hex[$from] && $hex[$to]
	&& $hex[$from]->road && $hex[$to]->road) {
      push(@roads, {name => "road60", angle => $self->angle($hex[$from])});
    }
  }
  return @roads;
}

package Mapper;

use Class::Struct;

struct Mapper => {
		  hexes => '@',
		 };

my %char = (
	    'n' => 'hill',
	    'o' => 'town',
	    'O' => 'city',
	    '"' => 'grass',
	    '.' => 'empty',
	    '-' => 'road',
	   );

sub chars {
  return join("\n", map { $_ . ' - ' . $char{$_} } keys %char);
}

my $example = q{" " o " "
 n " " .
n-n O-. .
 n-"-" .
};

sub example {
  return $example;
}

my $dx = 100*sqrt(3);
my $dy = 100;

# data goes where the first empty line is
my $doc = sprintf(qq{<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN"
  "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     viewBox="-$dx -$dy 1000 1000"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <desc>Old School Hex Map</desc>
  <defs>
    <polygon fill="none" stroke="black" stroke-width="1" id="empty" title="empty"
             points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f" />
    <g id="hill" title="hill">
      <use xlink:href="#empty" />
      <path d="M -42.887901,11.051062 C -38.8,5.5935948 -34.0,0.5 -28.174309,-3.0 C -20.987476,-6.5505102 -11.857161,-5.1811592 -5.7871072,-0.050580244 C -2.0,2.6706698 1.1683798,6.1 3.8585628,9.8783938 C 4.1,12.295981 2.5,13.9 0.57117882,14.454662 C -3.0696782,9.3 -7.8,5.1646538 -13.4,2.1 C -21.686794,-1.7 -30.0,0.79168476 -36.5,6.6730178 C -38.8,9.0 -40.9,11.5 -43.086547,14.0 C -43.088939,15.072012 -44.8,14.756431 -44.053241,13.8 C -43.7,12.8 -43.0,12.057 -42.887901,11.051062 z " />
      <path d="M -5.0,-0.75883624 C 0.9,-6.9553992 7.6,-12.7 15.5,-16.171056 C 21.5,-18.6 28.5,-17.6 33.9,-14.2 C 39.15207,-11.0 41.67227,-5.5846132 43.7,-0.072156244 C 42.456295,2.4 41.252332,5.7995568 39.0,2.9 C 37.295351,-2.9527612 33.1,-8.2775842 27.4,-10.7 C 20.5,-13.551561 12.2,-12.061567 6.4,-7.4 C 2.4597998,-4.7 -1.0845122,-1.4893282 -4.5,1.8 C -7.2715222,4.0 -6.0866092,0.89928976 -5.0,-0.75883624 z " />
    </g>
    <g id="grass" title="grass">
      <use xlink:href="#empty" />
      <path d="M -18.4,-13.8 C -13.773555,-6.4 -13.5,4.8 -8.5597061,12.2 C -11.8,14.870577 -15.069019,21.666847 -18.3,26.4 C -20.361758,17.3 -22.6,4.6520873 -28.6,0.77998732 C -26.199022,-4.0 -21.798258,-9.2 -18.4,-13.8 z " />
      <path d="M 5.6,-31.658907 C 4.3,-19.899253 3.8,-6.1 6.266188,5.9733973 C 1.5,10.168437 -0.26595005,14.952917 -3.5,19.4 C -2.899459,6.8 -3.177218,-4.7 -4.689108,-16.686835 C -4.2,-21.8 2.474668,-26.0 5.6,-31.658907 z " />
      <path d="M 26.968846,-1.1996857 C 16.0,6.5525273 19.067496,5.3 9.571268,18.1 C 12.890808,3.4845973 21.898666,-8.9 34.1,-17.3 C 32.1,-12.1 29.4,-6.5 27.0,-1.2 z " />
    </g>
    <g id="city" title="city">
      <use xlink:href="#empty" />
      <circle cx="0" cy="0" r="40" fill="black"/>
    </g>
    <g id="town" title="town">
      <use xlink:href="#empty" />
      <circle cx="0" cy="0" r="20" fill="black"/>
    </g>
    <path id="road180" title="road"
	  stroke="black" stroke-width="6" stroke-dasharray="6" fill="none"
	  d="M 43.3,-75 C 27.9,-49.4 58.2,-37.5 62.0,-23.4 C 71.3,10.6 54.6,45.5 38.2,57.9 C 6.7,81.5 -22.5,36.6 -43.3,75" />
    <path id="road120" title="road"
	  stroke="black" stroke-width="6" stroke-dasharray="6" fill="none"
          d="M -43.3,-75 C -22.3,-38.8 -51.0,-21.4 -63.8,15.5 C -74.3,45.6 -31.4,54.3 -43.3,75" />
    <!-- M -43.3,75 L -43.3,-75 -->
    <path id="road60" title="road"
	  stroke="black" stroke-width="6" stroke-dasharray="6" fill="none"
          d="M -86.6,0 C -48.8,-2.1 -62.2,24.5 -63.8,28.2 C -76.5,57.4 -31.4,54.3 -43.3,75" />
    <!-- M -43.3,75 L -86.6,0 -->
    <path id="road-start" title="road"
	  stroke="black" stroke-width="6" stroke-dasharray="6" fill="none"
          d="M -7.1,35.1 C -24.4,68.8 -22.5,36.6 -43.3,75" />
  </defs>

</svg>
}, -$dx/2, -$dy/2, -$dx/2, $dy/2, 0, $dy, $dx/2,$dy/2, $dx/2, -$dy/2, 0, -$dy);

sub initialize {
  my ($self, $map) = @_;
  my $y = 0;
  foreach (split(/\n/, $map)) {
    my $i = 0;
    my $hex;
    my $offset = int(-$y/2);
    foreach my $c (split(//, $_)) {
      if ($char{$c}) {
	# skip every second character depending on the row
	if (($i + $y) % 2) {
	  my $x = $offset + int(($i - 1)/2);
	  die "the road at ($x,$y) doesn't belong to the current hex "
	    if $hex->x != $x || $hex->y != $y;
	  # warn sprintf("$i: adding road to ($x,$y) at %s\n", $hex->str);
	  $hex->road(1);
	} else {
	  my $x = $offset + int($i/2);
	  # warn "$i: creating $char{$c} ($c) hex ($x,$y)\n";
	  $hex = Hex->new(x => $x, y => $y, type => $char{$c}, map => $self);
	  $self->add($hex);
	}
      }
      $i++;
    }
    $y++;
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
  my $data;
  foreach my $hex (@{$self->hexes}) {
    $data .= $hex->svg();
  }
  $doc =~ s/\n\n/\n$data/;
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
	 start_html(-encoding=>'UTF-8', -title=>'Old School Hex Mapper',
		    -author=>'kensanata@gmail.com'),
	 h1('Old School Hex Mapper'),
	 p('Submit your ASCII map of the area using the following characters:'),
	 pre(Mapper->chars()),
	 p('Notice how you need to use spaces to align the regions in the following example:'),
	 pre(Mapper->example()),
	 start_form(-method=>'GET'),
	 p('ASCII map: '),
	 p(textarea('map', Mapper::example(), 15, 60)),
	 p(submit()),
	 end_form(),
	 hr(),
	 p(a({-href=>'http://www.alexschroeder.ch/wiki/About'},
	     'Alex Schröder'),
	   a({-href=>url() . '/source'}, 'Source'),
	   a({-href=>'https://alexschroeder.ch/cgit/hex-mapping/about/#old-school-hex'},
	     'Git')),
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

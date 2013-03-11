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
use LWP::UserAgent;
use strict;
use utf8;

my $dx = 100;
my $dy = 100*sqrt(3);

package Point;

use Class::Struct;

struct Point => { x => '$', y => '$', };

sub equal {
  my ($self, $other) = @_;
  return $self->x == $other->x
      && $self->y == $other->y;
}

sub coordinates {
  my ($self, $precision) = @_;
  if (wantarray) {
    return $self->x, $self->y;
  } else {
    return $self->x . "," . $self->y;
  }
}

sub pixels {
  my ($self) = @_;
  my ($x, $y) = ($self->x * $dx * 3/2, $self->y * $dy - $self->x % 2 * $dy/2);
  if (wantarray) {
    return ($x, $y);
  } else {
    return sprintf("%.1f,%.1f", $x, $y);
  }
}

# Brute forcing the "next" step by trying all the neighbors. The
# connection data to connect to neighbouring hexes.
#
# Example Map             Index for the array
#
#      0201                      2
#  0102    0302               1     3
#      0202    0402
#  0103    0303               6     4
#      0203    0403              5
#  0104    0304
#
#  Note that the arithmetic changes when x is odd.

sub one_step_to {
  my ($self, $other) = @_;
  my $delta = [[[-1,  0], [ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1]],  # x is even
	       [[-1, -1], [ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0]]]; # x is odd
  my ($min, $best);
  for my $i (0 .. 5) {
    # make a new guess
    my ($x, $y) = ($self->x + $delta->[$self->x % 2]->[$i]->[0],
		   $self->y + $delta->[$self->x % 2]->[$i]->[1]);
    my $d = ($other->x - $x) * ($other->x - $x)
          + ($other->y - $y) * ($other->y - $y);
    if (!defined($min) || $d < $min) {
      $min = $d;
      $best = Point->new(x => $x, y => $y);
    }
  }
  return $best;
}

sub partway {
  my ($self, $other, $q) = @_;
  my ($x1, $y1) = $self->pixels;
  my ($x2, $y2) = $other->pixels;
  $q ||= 1;
  if (wantarray) {
    return $x1 + ($x2 - $x1) * $q, $y1 + ($y2 - $y1) * $q;
  } else {
    return sprintf("%.1f,%.1f", $x1 + ($x2 - $x1) * $q, $y1 + ($y2 - $y1) * $q);
  }
}

package Line;

use Class::Struct;

struct Line => {
		points => '@',
		type => '$',
		map => 'Mapper',
	       };

sub compute_missing_points {
  my $self = shift;
  my $i = 0;
  my $current = $self->points($i++);
  my @result = ($current);
  while ($self->points($i)) {
    $current = $current->one_step_to($self->points($i));
    push(@result, $current);
    $i++ if $current->equal($self->points($i));
  }

  return @result;
}

sub svg {
  my $self = shift;
  my ($path, $current, $next);
  my @points = $self->compute_missing_points();
  for my $i (0 .. $#points - 1) {
    $current = $points[$i];
    $next = $points[$i+1];
    if (!$path) {
      # bézier curve A B A B
      my $a = $current->partway($next, 0.3);
      my $b = $current->partway($next, 0.5);
      $path = "M$a C$b $a $b";
    } else {
      # continue curve
      $path .= " S" . $current->partway($next, 0.3)
	      . " " . $current->partway($next, 0.5);
    }
  }
  # end with a little stub
  $path .= " L" . $current->partway($next, 0.7);

  my $type = $self->type;
  my $attributes = $self->map->path_attributes($type);
  my $data = "<path $attributes d='$path'/>\n";
  $data .= $self->debug() if main::param('debug');
  return $data;
}

sub debug {
  my $self = shift;
  my ($data, $current, $next);
  my @points = $self->compute_missing_points();
  for my $i (0 .. $#points - 1) {
    $current = $points[$i];
    $next = $points[$i+1];
    $data .= circle($current->pixels, 15, $i++);
    $data .= circle($current->partway($next, 0.3), 3, 'a');
    $data .= circle($current->partway($next, 0.5), 5, 'b');
    $data .= circle($current->partway($next, 0.7), 3, 'c');
  }
  $data .= circle($next->pixels, 15, $#points);
  return $data;
}

sub circle {
  my ($x, $y, $r, $i) = @_;
  my $data = "<circle fill='#666' cx='$x' cy='$y' r='$r'/>";
  $data .= "<text fill='#000' font-size='20pt' "
    . "text-anchor='middle' dominant-baseline='central' "
    . "x='$x' y='$y'>$i</text>" if $i;
  return "$data\n";
}

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
  return unless $self->label;
  my $x = $self->x;
  my $y = $self->y;
  my $data = sprintf(qq{  <text text-anchor="middle" x="%.1f" y="%.1f" %s %s>}
		   . $self->label
		   . qq{</text>\n},
		   $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 + $dy * 0.4,
		   $self->map->label_attributes,
		   $self->map->glow_attributes);
  $data .= sprintf(qq{  <text text-anchor="middle" x="%.1f" y="%.1f" %s>}
		   . $self->label
		   . qq{</text>\n},
		   $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 + $dy * 0.4,
		   $self->map->label_attributes);
  return $data;
}

package Mapper;

use Class::Struct;

struct Mapper => {
		  hexes => '@',
		  attributes => '%',
		  map => '$',
		  path => '%',
		  lines => '@',
		  path_attributes => '%',
		  text_attributes => '$',
		  glow_attributes => '$',
		  label_attributes => '$',
		  messages => '@',
		  seen => '%',
		 };

my $example = q{
0101 mountain "mountain"
0102 swamp "swamp"
0103 hill "hill"
0104 forest "horest"
0201 empty pyramid "pyramid"
0202 tundra "tundra"
0203 coast "coast"
0204 empty house "house"
0301 woodland "woodland"
0302 wetland "wetland"
0303 plain "plain"
0304 sea "sea"
0401 hill tower "tower"
0402 sand house "house"
0403 jungle "jungle"
0502 sand "sand"
0205-0103-0202-0303-0402 road
0101-0203 river
0401-0303-0403 border
include http://alexschroeder.ch/contrib/default.txt
};

sub example {
  return $example;
}

sub initialize {
  my ($self, $map) = @_;
  $self->map($map);
  $self->process(split(/\r?\n/, $map));
}

sub process {
  my $self = shift;
  foreach (@_) {
    if (/^(\d\d)(\d\d)\s+([^"\r\n]+)?\s*(?:"(.+)")?/) {
      my $hex = Hex->new(x => $1, y => $2, map => $self);
      $hex->label($4);
      my @types = split(' ', $3);
      $hex->type(\@types);
      $self->add($hex);
    } elsif (/^(\d\d\d\d(?:-\d\d\d\d)+)\s+(\S+)/) {
      my $line = Line->new(map => $self);
      $line->type($2);
      my @points = map { my $point = Point->new(x => substr($_, 0, 2),
						y => substr($_, 2, 2));
		       } split(/-/, $1);
      $line->points(\@points);
      push(@{$self->lines}, $line);
    } elsif (/^(\S+)\s+attributes\s+(.*)/) {
      $self->attributes($1, $2);
    } elsif (/^(\S+)\s+path\s+attributes\s+(.*)/) {
      $self->path_attributes($1, $2);
    } elsif (/^(\S+)\s+path\s+(.*)/) {
      $self->path($1, $2);
    } elsif (/^text\s+(.*)/) {
      $self->text_attributes($1);
    } elsif (/^glow\s+(.*)/) {
      $self->glow_attributes($1);
    } elsif (/^label\s+(.*)/) {
      $self->label_attributes($1);
    } elsif (/^include\s+(\S*)/) {
      if (scalar keys %{$self->seen} > 5) {
	push(@{$self->messages},
	     "Includes are limited to five to prevent loops");
      } elsif ($self->seen($1)) {
	push(@{$self->messages}, "$1 was included twice");
      } else {
	$self->seen($1, 1);
	my $ua = LWP::UserAgent->new;
	my $response = $ua->get($1);
	if ($response->is_success) {
	  $self->process(split(/\n/, $response->decoded_content));
	} else {
	  push(@{$self->messages}, $response->status_line);
	}
      }
    }
  }
}

sub add {
  my ($self, $hex) = @_;
  push(@{$self->hexes}, $hex);
}

sub merge_attributes {
  my %attr = ();
  for my $attr (@_) {
    while ($attr =~ /(\S+)=((["']).*?\3)/g) {
      $attr{$1} = $2;
    }
  }
  return join(' ', map { $_ . '=' . $attr{$_} } sort keys %attr);
}

sub svg {
  my ($self) = @_;

  my ($minx, $miny, $maxx, $maxy);
  foreach my $hex (@{$self->hexes}) {
    $minx = $hex->x if not defined($minx);
    $maxx = $hex->x if not defined($maxx);
    $miny = $hex->y if not defined($miny);
    $maxy = $hex->y if not defined($maxy);
    $minx = $hex->x if $minx > $hex->x;
    $maxx = $hex->x if $maxx < $hex->x;
    $miny = $hex->y if $miny > $hex->y;
    $maxy = $hex->y if $maxy < $hex->y;
  }

  my ($vx1, $vy1, $vx2, $vy2) =
    map { int($_) } ($minx * $dx * 3/2 - $dx - 10, ($miny - 1.0) * $dy - 10,
		     $maxx * $dx * 3/2 + $dx + 10, ($maxy + 0.5) * $dy + 10);
  my ($width, $height) = ($vx2 - $vx1, $vy2 - $vy1);

  my $doc = qq{<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     viewBox="$vx1 $vy1 $vx2 $vy2"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <!-- ($minx, $miny) ($maxx, $maxy) -->
  <defs>};

  # collect hex types from attributess and paths in case the sets don't overlap
  my %types = ();
  foreach my $hex (@{$self->hexes}) {
    foreach my $type (@{$hex->type}) {
      $types{$type} = 1;
    }
  }
  foreach my $line (@{$self->lines}) {
    $types{$line->type} = 1;
  }

  # now go through them all
  foreach my $type (keys %types) {
    my $path = $self->path($type);
    my $attributes = merge_attributes($self->attributes('default'),
				      $self->attributes($type));
    my $path_attributes = merge_attributes($self->path_attributes('default'),
					   $self->path_attributes($type));
    my $glow_attributes = $self->glow_attributes;
    my ($x1, $y1, $x2, $y2, $x3, $y3,
	$x4, $y4, $x5, $y5, $x6, $y6) =
	  (-$dx, 0, -$dx/2, $dy/2, $dx/2, $dy/2,
	   $dx, 0, $dx/2, -$dy/2, -$dx/2, -$dy/2);
    if ($path && $attributes) {
      # hex with shapes, eg. plains and grass
      $doc .= qq{
    <g id='$type'>
      <polygon $attributes points='$x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 $x6,$y6' />
      <path $path_attributes d='$path' />
    </g>};
    } elsif ($path) {
      # just shapes, eg. a house
      $doc .= qq{
    <g id='$type'>
      <path $glow_attributes d='$path' />
      <path $path_attributes d='$path' />
    </g>};
    } else {
      # just a hex
      $doc .= qq{
    <polygon id='$type' $attributes points='$x1,$y1 $x2,$y2 $x3,$y3 $x4,$y4 $x5,$y5 $x6,$y6' />}
    }
  }
  $doc .= q{
  </defs>
};

  $doc .= " <rect x='$vx1' y='$vy1' width='$width' height='$height' stroke='black' fill-opacity='0' stroke-width='1' />\n"
    if main::param('debug');

  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg();
  }
  foreach my $line (@{$self->lines}) {
    $doc .= $line->svg();
  }
  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg_label();
  }
  my $y = 10;
  foreach my $msg (@{$self->messages}) {
    $doc .= "  <text x='0' y='$y'>$msg</text>\n";
    $y += 10;
  }

  $doc .= "<!-- Source\n" . $self->map() . "\n-->";

  $doc .= qq{
</svg>};

  return $doc;
}

package main;

sub print_map {
  print header(-type=>'image/svg+xml', -charset=>'utf-8');
  my $map = new Mapper;
  $map->initialize(shift);
  print $map->svg;
}

sub print_html {
  print header(-type=>'text/html; charset=UTF-8'),
	start_html(-encoding=>'UTF-8', -title=>'Text Mapper',
		    -author=>'kensanata@gmail.com'),
	h1('Text Mapper'),
	p('Submit your text desciption of the map.'),
	start_form(-method=>'GET'),
	p(textarea(-style => 'width:100%',
		    -name => 'map',
		    -default => Mapper::example(),
		    -rows => 15,
		    -columns => 60, )),
	p(submit()),
	end_form(),
	hr(),
	p(a({-href=>'http://www.alexschroeder.ch/wiki/About'},
	    'Alex Schröder'),
	  a({-href=>url() . '/source'}, 'Source'),
	  a({-href=>'https://github.com/kensanata/hex-mapping'},
	    'GitHub')),
	end_html();
}

sub main {
  binmode(STDOUT, ':utf8');
  if (param('map')) {
    print_map(param('map'));
  } elsif (path_info() eq '/source') {
    print header(-type=>'text/plain; charset=UTF-8');
    seek(DATA,0,0);
    undef $/;
    print <DATA>;
  } else {
    print_html();
  }
}

main ();

__DATA__

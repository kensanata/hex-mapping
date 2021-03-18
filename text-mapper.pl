#!/usr/bin/env perl
# Copyright (C) 2009-2021  Alex Schroeder <alex@gnu.org>
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

package main;
use Modern::Perl '2018';

my $dx = 100;
my $dy = 100*sqrt(3);
my $debug;
my $log;
my $contrib;

package Point;

use Modern::Perl '2018';
use Mojo::Base -base;

has 'x';
has 'y';

sub equal {
  my ($self, $other) = @_;
  return $self->x == $other->x && $self->y == $other->y;
}

sub cmp {
  my ($a, $b) = @_;
  return $a->x <=> $b->x || $a->y <=> $b->y;
}

sub coordinates {
  my ($self) = @_;
  return $self->x, $self->y if wantarray;
  return $self->x . "," . $self->y;
}

sub coord {
  my ($x, $y, $separator) = @_;
  $separator //= "";
  # print (1,1) as 0101; print (-1,-1) as -01-01
  return sprintf("%0*d$separator%0*d",
		 ($x < 0 ? 3 : 2), $x,
		 ($y < 0 ? 3 : 2), $y);
}

package Line;

use Modern::Perl '2018';
use URI::Escape;
use Mojo::Base -base;

has 'id';
has 'points';
has 'type';
has 'label';
has 'map';

sub compute_missing_points {
  my $self = shift;
  my $i = 0;
  my $current = $self->points->[$i++];
  my @result = ($current);
  while ($self->points->[$i]) {
    $current = $self->one_step($current, $self->points->[$i]);
    push(@result, $current);
    $i++ if $current->equal($self->points->[$i]);
  }

  return @result;
}

sub partway {
  my ($self, $from, $to, $q) = @_;
  my ($x1, $y1) = $self->pixels($from);
  my ($x2, $y2) = $self->pixels($to);
  $q ||= 1;
  return $x1 + ($x2 - $x1) * $q, $y1 + ($y2 - $y1) * $q if wantarray;
  return sprintf("%.1f,%.1f", $x1 + ($x2 - $x1) * $q, $y1 + ($y2 - $y1) * $q);
}

sub svg {
  my $self = shift;
  my ($path, $current, $next, $closed);

  my @points = $self->compute_missing_points();
  if ($points[0]->equal($points[$#points])) {
    $closed = 1;
  }

  if ($closed) {
    for my $i (0 .. $#points - 1) {
      $current = $points[$i];
      $next = $points[$i+1];
      if (!$path) {
	my $a = $self->partway($current, $next, 0.3);
	my $b = $self->partway($current, $next, 0.5);
	my $c = $self->partway($points[$#points-1], $current, 0.7);
	my $d = $self->partway($points[$#points-1], $current, 0.5);
	$path = "M$d C$c $a $b";
      } else {
	# continue curve
	my $a = $self->partway($current, $next, 0.3);
	my $b = $self->partway($current, $next, 0.5);
	$path .= " S$a $b";
      }
    }
  } else {
    for my $i (0 .. $#points - 1) {
      $current = $points[$i];
      $next = $points[$i+1];
      if (!$path) {
	# line from a to b; control point a required for following S commands
	my $a = $self->partway($current, $next, 0.3);
	my $b = $self->partway($current, $next, 0.5);
	$path = "M$a C$b $a $b";
      } else {
	# continue curve
	my $a = $self->partway($current, $next, 0.3);
	my $b = $self->partway($current, $next, 0.5);
	$path .= " S$a $b";
      }
    }
    # end with a little stub
    $path .= " L" . $self->partway($current, $next, 0.7);
  }

  my $id = $self->id;
  my $type = $self->type;
  my $attributes = $self->map->path_attributes->{$type};
  my $data = qq{    <path id="$id" $attributes d="$path"/>\n};
  $data .= $self->debug($closed) if $debug;
  return $data;
}

sub svg_label {
  my ($self) = @_;
  return '' unless defined $self->label;
  my $id = $self->id;
  my $label = $self->label;
  my $attributes = $self->map->label_attributes || "";
  my $glow = $self->map->glow_attributes || "";
  my $url = $self->map->url;
  $url =~ s/\%s/uri_escape($self->label)/e or $url .= uri_escape($self->label) if $url;
  # default is left, but if the line goes from right to left, then "left" means "upside down"
  my $side = '';
  if ($self->points->[1]->x < $self->points->[0]->x
      or $#{$self->points} >= 2 and $self->points->[2]->x < $self->points->[0]->x) {
    $side = ' side="right"';
  }
  my $data = qq{    <g>\n};
  $data .= qq{      <text $attributes $glow><textPath$side href='#$id'>$label</textPath></text>\n} if $glow;
  $data .= qq{      <a xlink:href="$url">} if $url;
  $data .= qq{      <text $attributes><textPath href='#$id'>$label</textPath></text>\n};
  $data .= qq{      </a>} if $url;
  $data .= qq{    </g>\n};
  return $data;
}

sub debug {
  my ($self, $closed) = @_;
  my ($data, $current, $next);
  my @points = $self->compute_missing_points();
  for my $i (0 .. $#points - 1) {
    $current = $points[$i];
    $next = $points[$i+1];
    $data .= circle($self->pixels($current), 15, $i++);
    $data .= circle($self->partway($current, $next, 0.3), 3, 'a');
    $data .= circle($self->partway($current, $next, 0.5), 5, 'b');
    $data .= circle($self->partway($current, $next, 0.7), 3, 'c');
  }
  $data .= circle($self->pixels($next), 15, $#points);

  my ($x, $y) = $self->pixels($points[0]); $y += 30;
  $data .= "<text fill='#000' font-size='20pt' "
    . "text-anchor='middle' dominant-baseline='central' "
    . "x='$x' y='$y'>closed</text>"
      if $closed;

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

package Line::Hex;

use Modern::Perl '2018';
use Mojo::Base 'Line';

sub pixels {
  my ($self, $point) = @_;
  my ($x, $y) = ($point->x * $dx * 3/2, $point->y * $dy - $point->x % 2 * $dy/2);
  return ($x, $y) if wantarray;
  return sprintf("%.1f,%.1f", $x, $y);
}

# Brute forcing the "next" step by trying all the neighbors. The
# connection data to connect to neighboring hexes.
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

sub one_step {
  my ($self, $from, $to) = @_;
  my $delta = [[[-1,  0], [ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1]],  # x is even
	       [[-1, -1], [ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0]]]; # x is odd
  my ($min, $best);
  for my $i (0 .. 5) {
    # make a new guess
    my ($x, $y) = ($from->x + $delta->[$from->x % 2]->[$i]->[0],
		   $from->y + $delta->[$from->x % 2]->[$i]->[1]);
    my $d = ($to->x - $x) * ($to->x - $x)
          + ($to->y - $y) * ($to->y - $y);
    if (!defined($min) || $d < $min) {
      $min = $d;
      $best = Point->new(x => $x, y => $y);
    }
  }
  return $best;
}

package Line::Square;

use Modern::Perl '2018';
use Mojo::Base 'Line';

sub pixels {
  my ($self, $point) = @_;
  my ($x, $y) = ($point->x * $dy, $point->y * $dy);
  return ($x, $y) if wantarray;
  return sprintf("%d,%d", $x, $y);
}

sub one_step {
  my ($self, $from, $to) = @_;
  my ($min, $best);
  my $dx = $to->x - $from->x;
  my $dy = $to->y - $from->y;
  if (abs($dx) >= abs($dy)) {
    my $x = $from->x + ($dx > 0 ? 1 : -1);
    return Point->new(x => $x, y => $from->y);
  } else {
    my $y = $from->y + ($dy > 0 ? 1 : -1);
    return Point->new(x => $from->x, y => $y);
  }
}

package Hex;

use Modern::Perl '2018';
use URI::Escape;
use Encode qw(encode_utf8);
use Mojo::Base -base;

has 'x';
has 'y';
has 'type';
has 'label';
has 'size';
has 'map';

sub str {
  my $self = shift;
  return '(' . $self->x . ',' . $self->y . ')';
}

my @hex = ([-$dx, 0], [-$dx/2, $dy/2], [$dx/2, $dy/2],
	   [$dx, 0], [$dx/2, -$dy/2], [-$dx/2, -$dy/2]);

sub corners {
  return @hex;
}

sub svg_region {
  my ($self, $attributes) = @_;
  my $x = $self->x * $dx * 3/2;
  my $y = $self->y * $dy - $self->x % 2 * $dy/2;
  my $id = "hex" . $self->x . $self->y;
  my $points = join(" ", map {
    sprintf("%.1f,%.1f", $x + $_->[0], $y + $_->[1]) } $self->corners());
  return qq{    <polygon id="$id" $attributes points="$points" />\n}
}

sub svg {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $data = '';
  for my $type (@{$self->type}) {
    $data .= sprintf(qq{    <use x="%.1f" y="%.1f" xlink:href="#%s" />\n},
		     $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2, $type);
  }
  return $data;
}

sub svg_coordinates {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $data = '';
  $data .= qq{    <text text-anchor="middle"};
  $data .= sprintf(qq{ x="%.1f" y="%.1f"},
		   $x * $dx * 3/2,
		   $y * $dy - $x%2 * $dy/2 - $dy * 0.4);
  $data .= ' ';
  $data .= $self->map->text_attributes || '';
  $data .= '>';
  $data .= Point::coord($x, $y, ".");
  $data .= qq{</text>\n};
  return $data;
}

sub svg_label {
  my ($self, $url) = @_;
  return '' unless defined $self->label;
  my $attributes = $self->map->label_attributes;
  if ($self->size) {
    if (not $attributes =~ s/\bfont-size="\d+pt"/'font-size="' . $self->size . 'pt"'/e) {
      $attributes .= ' font-size="' . $self->size . '"';
    }
  }
  $url =~ s/\%s/uri_escape(encode_utf8($self->label))/e or $url .= uri_escape(encode_utf8($self->label)) if $url;
  my $x = $self->x;
  my $y = $self->y;
  my $data = sprintf(qq{    <g><text text-anchor="middle" x="%.1f" y="%.1f" %s %s>}
                     . $self->label
                     . qq{</text>},
                     $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 + $dy * 0.4,
                     $attributes ||'',
		     $self->map->glow_attributes ||'');
  $data .= qq{<a xlink:href="$url">} if $url;
  $data .= sprintf(qq{<text text-anchor="middle" x="%.1f" y="%.1f" %s>}
		   . $self->label
		   . qq{</text>},
		   $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 + $dy * 0.4,
		   $attributes ||'');
  $data .= qq{</a>} if $url;
  $data .= qq{</g>\n};
  return $data;
}

package Square;

use Modern::Perl '2018';
use URI::Escape;
use Mojo::Base -base;

has 'x';
has 'y';
has 'type';
has 'label';
has 'size';
has 'map';

sub str {
  my $self = shift;
  return '(' . $self->x . ',' . $self->y . ')';
}

sub svg_region {
  my ($self, $attributes) = @_;
  my $x = ($self->x - 0.5) * $dy;
  my $y = ($self->y - 0.5) * $dy; # square!
  my $id = "square" . $self->x . $self->y;
  return qq{    <rect id="$id" $attributes x="$x" y="$y" width="$dy" height="$dy" />\n}
}

sub svg {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $data = '';
  for my $type (@{$self->type}) {
    $data .= sprintf(qq{    <use x="%d" y="%d" xlink:href="#%s" />\n},
		     $x * $dy,
		     $y * $dy, # square
		     $type);
  }
  return $data;
}

sub svg_coordinates {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $data = '';
  $data .= qq{    <text text-anchor="middle"};
  $data .= sprintf(qq{ x="%d" y="%d"},
		   $x * $dy,
		   ($y - 0.4) * $dy); # square
  $data .= ' ';
  $data .= $self->map->text_attributes || '';
  $data .= '>';
  $data .= Point::coord($x, $y, ".");
  $data .= qq{</text>\n};
  return $data;
}

sub svg_label {
  my ($self, $url) = @_;
  return '' unless defined $self->label;
  my $attributes = $self->map->label_attributes;
  if ($self->size) {
    if (not $attributes =~ s/\bfont-size="\d+pt"/'font-size="' . $self->size . 'pt"'/e) {
      $attributes .= ' font-size="' . $self->size . '"';
    }
  }
  $url =~ s/\%s/uri_escape($self->label)/e or $url .= uri_escape($self->label) if $url;
  my $x = $self->x;
  my $y = $self->y;
  my $data = sprintf(qq{    <g><text text-anchor="middle" x="%d" y="%d" %s %s>}
                     . $self->label
                     . qq{</text>},
                     $x  * $dy,
		     ($y + 0.4) * $dy, # square
                     $attributes ||'',
		     $self->map->glow_attributes ||'');
  $data .= qq{<a xlink:href="$url">} if $url;
  $data .= sprintf(qq{<text text-anchor="middle" x="%d" y="%d" %s>}
		   . $self->label
		   . qq{</text>},
		   $x * $dy,
		   ($y + 0.4) * $dy, # square
		   $attributes ||'');
  $data .= qq{</a>} if $url;
  $data .= qq{</g>\n};
  return $data;
}

package Mapper;

use Modern::Perl '2018';
use LWP::UserAgent;
use Mojo::Base -base;

has 'map';
has 'regions' => sub { [] };
has 'attributes' => sub { {} };
has 'defs' => sub { [] };
has 'path' => sub { {} };
has 'lines' => sub { [] };
has 'things' => sub { [] };
has 'path_attributes' => sub { {} };
has 'text_attributes' => '';
has 'glow_attributes' => '';
has 'label_attributes' => '';
has 'messages' => sub { [] };
has 'seen' => sub { {} };
has 'license' => '';
has 'other' => sub { [] };
has 'url' => '';

sub example {
  return <<"EOT";
0101 mountain "mountain"
0102 swamp "swamp"
0103 hill "hill"
0104 forest "forest"
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
0501 mountain cave "cave"
0502 sand "sand"
0205-0103-0202-0303-0402 road
0101-0203 river
0401-0303-0403 border
include $contrib/default.txt
license <text>Public Domain</text>
EOT
}

sub initialize {
  my ($self, $map) = @_;
  $map =~ s/&#45;/-/g; # -- are invalid in source comments...
  $self->map($map);
  $self->process(split(/\r?\n/, $map));
}

sub process {
  my $self = shift;
  my $line_id = 0;
  foreach (@_) {
    if (/^(-?\d\d)(-?\d\d)\s+(.*)/) {
      my $region = $self->make_region(x => $1, y => $2, map => $self);
      my $rest = $3;
      while (my ($tag, $label, $size) = $rest =~ /\b([a-z]+)=["“]([^"”]+)["”]\s*(\d+)?/) {
	if ($tag eq 'name') {
	  $region->label($label);
	  $region->size($size);
	}
	$rest =~ s/\b([a-z]+)=["“]([^"”]+)["”]\s*(\d+)?//;
      }
      while (my ($label, $size) = $rest =~ /["“]([^"”]+)["”]\s*(\d+)?/) {
	$region->label($label);
	$region->size($size);
	$rest =~ s/["“]([^"”]+)["”]\s*(\d+)?//;
      }
      my @types = split(/\s+/, $rest);
      $region->type(\@types);
      push(@{$self->regions}, $region);
      push(@{$self->things}, $region);
    } elsif (/^(-?\d\d-?\d\d(?:--?\d\d-?\d\d)+)\s+(\S+)\s*(?:["“](.+)["”])?/) {
      my $line = $self->make_line(map => $self);
      my $str = $1;
      $line->type($2);
      $line->label($3);
      $line->id('line' . $line_id++);
      my @numbers = $str =~ /\G(-?\d\d)(-?\d\d)-?/cg;
      my @points;
      while (@numbers) {
	my ($x, $y) = splice(@numbers, 0, 2);
	push(@points, Point->new(x => $x, y => $y));
      }
      $line->points(\@points);
      push(@{$self->lines}, $line);
    } elsif (/^(\S+)\s+attributes\s+(.*)/) {
      $self->attributes->{$1} = $2;
    } elsif (/^(\S+)\s+lib\s+(.*)/) {
      $self->def(qq{<g id="$1">$2</g>});
    } elsif (/^(\S+)\s+xml\s+(.*)/) {
      $self->def(qq{<g id="$1">$2</g>});
    } elsif (/^(<.*>)/) {
      $self->def($1);
    } elsif (/^(\S+)\s+path\s+attributes\s+(.*)/) {
      $self->path_attributes->{$1} = $2;
    } elsif (/^(\S+)\s+path\s+(.*)/) {
      $self->path->{$1} = $2;
    } elsif (/^text\s+(.*)/) {
      $self->text_attributes($1);
    } elsif (/^glow\s+(.*)/) {
      $self->glow_attributes($1);
    } elsif (/^label\s+(.*)/) {
      $self->label_attributes($1);
    } elsif (/^license\s+(.*)/) {
      $self->license($1);
    } elsif (/^other\s+(.*)/) {
      push(@{$self->other()}, $1);
    } elsif (/^url\s+(\S+)/) {
      $self->url($1);
    } elsif (/^include\s+(\S*)/) {
      if (scalar keys %{$self->seen} > 5) {
	push(@{$self->messages},
	     "Includes are limited to five to prevent loops");
      } elsif (not $self->seen->{$1}) {
	$self->seen->{$1} = 1;
	my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1 });
	my $response = $ua->get($1);
	if ($response->is_success) {
	  $self->process(split(/\n/, $response->decoded_content));
	} else {
	  push(@{$self->messages}, $response->status_line);
	}
      }
    } else {
      $log->debug("Did not parse $_") if $_;
    }
  }
  return $self;
}

sub def {
  my ($self, $svg) = @_;
  $svg =~ s/>\s+</></g;
  push(@{$self->defs}, $svg);
}

sub merge_attributes {
  my %attr = ();
  for my $attr (@_) {
    if ($attr) {
      while ($attr =~ /(\S+)=((["']).*?\3)/g) {
        $attr{$1} = $2;
      }
    }
  }
  return join(' ', map { $_ . '=' . $attr{$_} } sort keys %attr);
}

sub svg_header {
  my ($self) = @_;

  my $header = qq{<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     xmlns:xlink="http://www.w3.org/1999/xlink"
};

  my ($minx, $miny, $maxx, $maxy);
  foreach my $region (@{$self->regions}) {
    $minx = $region->x if not defined($minx);
    $maxx = $region->x if not defined($maxx);
    $miny = $region->y if not defined($miny);
    $maxy = $region->y if not defined($maxy);
    $minx = $region->x if $minx > $region->x;
    $maxx = $region->x if $maxx < $region->x;
    $miny = $region->y if $miny > $region->y;
    $maxy = $region->y if $maxy < $region->y;
  }

  if (defined($minx) and defined($maxx) and defined($miny) and defined($maxy)) {

    my ($vx1, $vy1, $vx2, $vy2) = $self->viewbox($minx, $miny, $maxx, $maxy);
    my ($width, $height) = ($vx2 - $vx1, $vy2 - $vy1);

    $header .= qq{     viewBox="$vx1 $vy1 $width $height">\n};
    $header .= qq{     <!-- min ($minx, $miny), max ($maxx, $maxy) -->\n};
  } else {
    $header .= qq{>\n}; # something is seriously wrong, though!
  }
  return $header;
}

sub svg_defs {
  my ($self) = @_;
  # All the definitions are included by default.
  my $doc = "  <defs>\n";
  $doc .= "    " . join("\n    ", @{$self->defs}) if @{$self->defs};
  # collect region types from attributess and paths in case the sets don't overlap
  my %types = ();
  foreach my $region (@{$self->regions}) {
    foreach my $type (@{$region->type}) {
      $types{$type} = 1;
    }
  }
  foreach my $line (@{$self->lines}) {
    $types{$line->type} = 1;
  }
  # now go through them all
  foreach my $type (sort keys %types) {
    my $path = $self->path->{$type};
    my $attributes = merge_attributes($self->attributes->{$type});
    my $path_attributes = merge_attributes($self->path_attributes->{'default'},
					   $self->path_attributes->{$type});
    my $glow_attributes = $self->glow_attributes;
    if ($path || $attributes) {
      $doc .= qq{    <g id="$type">\n};
      # just shapes get a glow such, eg. a house (must come first)
      if ($path && !$attributes) {
	$doc .= qq{      <path $glow_attributes d='$path' />\n}
      }
      # region with attributes get a shape (square or hex), eg. plains and grass
      if ($attributes) {
	$doc .= "      " . $self->shape($attributes) . "\n";
      }
      # and now the attributes themselves the shape itself
      if ($path) {
      $doc .= qq{      <path $path_attributes d='$path' />\n}
      }
      # close
      $doc .= qq{    </g>\n};
    } else {
      # nothing
    }
  }
  $doc .= qq{  </defs>\n};
}

sub svg_backgrounds {
  my $self = shift;
  my $doc = qq{  <g id="backgrounds">\n};
  foreach my $thing (@{$self->things}) {
    # make a copy
    my @types = @{$thing->type};
    # keep attributes
    $thing->type([grep { $self->attributes->{$_} } @{$thing->type}]);
    $doc .= $thing->svg();
    # reset copy
    $thing->type(\@types);
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg_things {
  my $self = shift;
  my $doc = qq{  <g id="things">\n};
  foreach my $thing (@{$self->things}) {
    # drop attributes
    $thing->type([grep { not $self->attributes->{$_} } @{$thing->type}]);
    $doc .= $thing->svg();
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg_coordinates {
  my $self = shift;
  my $doc = qq{  <g id="coordinates">\n};
  foreach my $region (@{$self->regions}) {
    $doc .= $region->svg_coordinates();
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg_lines {
  my $self = shift;
  my $doc = qq{  <g id="lines">\n};
  foreach my $line (@{$self->lines}) {
    $doc .= $line->svg();
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg_regions {
  my ($self) = @_;
  my $doc = qq{  <g id="regions">\n};
  my $attributes = $self->attributes->{default} || qq{fill="none"};
  foreach my $region (@{$self->regions}) {
    $doc .= $region->svg_region($attributes);
  }
  $doc .= qq{  </g>\n};
}

sub svg_line_labels {
  my $self = shift;
  my $doc = qq{  <g id="line_labels">\n};
  foreach my $line (@{$self->lines}) {
    $doc .= $line->svg_label();
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg_labels {
  my $self = shift;
  my $doc = qq{  <g id="labels">\n};
  foreach my $region (@{$self->regions}) {
    $doc .= $region->svg_label($self->url);
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg {
  my ($self) = @_;

  my $doc = $self->svg_header();
  $doc .= $self->svg_defs();
  $doc .= $self->svg_backgrounds(); # opaque backgrounds
  $doc .= $self->svg_lines();
  $doc .= $self->svg_things(); # icons, lines
  $doc .= $self->svg_coordinates();
  $doc .= $self->svg_regions();
  $doc .= $self->svg_line_labels();
  $doc .= $self->svg_labels();
  $doc .= $self->license() ||'';
  $doc .= join("\n", @{$self->other()}) . "\n";

  # error messages
  my $y = 10;
  foreach my $msg (@{$self->messages}) {
    $doc .= "  <text x='0' y='$y'>$msg</text>\n";
    $y += 10;
  }

  # source code (comments may not include -- for SGML compatibility!)
  # https://stackoverflow.com/questions/10842131/xml-comments-and
  my $source = $self->map();
  $source =~ s/--/&#45;&#45;/g;
  $doc .= "<!-- Source\n$source\n-->\n";
  $doc .= qq{</svg>\n};

  return $doc;
}

package Mapper::Hex;

use Modern::Perl '2018';
use Mojo::Base 'Mapper';

sub make_region {
  my $self = shift;
  return Hex->new(@_);
}

sub make_line {
  my $self = shift;
  return Line::Hex->new(@_);
}

sub shape {
  my $self = shift;
  my $attributes = shift;
  my $points = join(" ", map {
    sprintf("%.1f,%.1f", $_->[0], $_->[1]) } Hex::corners());
  return qq{<polygon $attributes points='$points' />};
}

sub viewbox {
  my $self = shift;
  my ($minx, $miny, $maxx, $maxy) = @_;
  map { int($_) } ($minx * $dx * 3/2 - $dx - 60, ($miny - 1.0) * $dy - 50,
		   $maxx * $dx * 3/2 + $dx + 60, ($maxy + 0.5) * $dy + 100);
}

package Mapper::Square;

use Modern::Perl '2018';
use Mojo::Base 'Mapper';

sub make_region {
  my $self = shift;
  return Square->new(@_);
}

sub make_line {
  my $self = shift;
  return Line::Square->new(@_);
}

sub shape {
  my $self = shift;
  my $attributes = shift;
  my $half = $dy / 2;
  return qq{<rect $attributes x="-$half" y="-$half" width="$dy" height="$dy" />};
}

sub viewbox {
  my $self = shift;
  my ($minx, $miny, $maxx, $maxy) = @_;
  map { int($_) } (($minx - 1) * $dy, ($miny - 1) * $dy,
		   ($maxx + 1) * $dy, ($maxy + 1) * $dy);
}

package Smale;
use Modern::Perl '2018';

my %world = ();

#         ATLAS HEX PRIMARY TERRAIN TYPE
#         Water   Swamp   Desert  Plains  Forest  Hills   Mountains
# Water   P       W       W       W       W       W       -
# Swamp   W       P       -       W       W       -       -
# Desert  W       -       P       W       -       W       W
# Plains  S [1]   S       T       P [4]   S       T       -
# Forest  T [2]   T       -       S       P [5]   W [8]   T [11]
# Hills   W       -       S [3]   T       T [6]   P [9]   S
# Mountns -       -       W       -       W [7]   S [10]  P [12]
#
#  1. Treat as coastal (beach or scrub) if adjacent to water
#  2. 66% light forest
#  3. 33% rocky desert or high sand dunes
#  4. Treat as farmland in settled hexes
#  5. 33% heavy forest
#  6. 66% forested hills
#  7. 66% forested mountains
#  8. 33% forested hills
#  9. 20% canyon or fissure (not implemented)
# 10. 40% chance of a pass (not implemented)
# 11. 33% forested mountains
# 12. 20% chance of a dominating peak; 10% chance of a mountain pass (not
#     implemented); 5% volcano (not implemented)
#
# Notes
# water:    water
# sand:     sand or dust
# swamp:    dark-grey swamp (near trees) or dark-grey marshes (no trees)
# plains:   light-green grass, bush or bushes near water or forest
# forest:   green trees (light), green forest, dark-green forest (heavy);
#           use firs and fir-forest near hills or mountains
# hill:     light-grey hill, dust hill if sand dunes
# mountain: grey mountain, grey mountains (peak)

# later, grass land near a settlement might get the colors soil or dark-soil!

my %primary = ("water" =>  ["water"],
	       "swamp" =>  ["dark-grey swamp"],
	       "desert" => ["dust desert"],
	       "plains" => ["light-green grass"],
	       "forest" => ["green forest",
			    "green forest",
			    "dark-green fir-forest"],
	       "hill" =>   ["light-grey hill"],
	       "mountain" => ["grey mountain",
			      "grey mountain",
			      "grey mountain",
			      "grey mountain",
			      "grey mountains"]);

my %secondary = ("water" =>  ["light-green grass",
			      "light-green bush",
			      "light-green bushes"],
		 "swamp" =>  ["light-green grass"],
		 "desert" =>   ["light-grey hill",
				"light-grey hill",
				"dust hill"],
		 "plains" =>  ["green forest"],
		 "forest" => ["light-green grass",
			      "light-green bush"],
		 "hill" =>   ["grey mountain"],
		 "mountain" => ["light-grey hill"]);

my %tertiary = ("water" => ["green forest",
			    "green trees",
			    "green trees"],
		"swamp" => ["green forest"],
		"desert" => ["light-green grass"],
		"plains" => ["light-grey hill"],
		"forest" => ["light-grey forest-hill",
			     "light-grey forest-hill",
			     "light-grey hill"],
		"hill" => ["light-green grass"],
		"mountain" => ["green fir-forest",
			       "green forest",
			       "green forest-mountains"]);

my %wildcard = ("water" => ["dark-grey swamp",
			    "dark-grey marsh",
			    "sand desert",
			    "dust desert",
			    "light-grey hill",
			    "light-grey forest-hill"],
		"swamp" => ["water"],
		"desert" => ["water",
			     "grey mountain"],
		"plains" => ["water",
			     "dark-grey swamp",
			     "dust desert"],
		"forest" => ["water",
			     "water",
			     "water",
			     "dark-grey swamp",
			     "dark-grey swamp",
			     "dark-grey marsh",
			     "grey mountain",
			     "grey forest-mountain",
			     "grey forest-mountains"],
		"hill" => ["water",
			   "water",
			   "water",
			   "sand desert",
			   "sand desert",
			   "dust desert",
			   "green forest",
			   "green forest",
			   "green forest-hill"],
		"mountain" => ["sand desert",
			       "dust desert"]);


my %reverse_lookup = (
  # primary
  "water" => "water",
  "dark-grey swamp" => "swamp",
  "dust desert" => "desert",
  "light-green grass" => "plains",
  "green forest" => "forest",
  "dark-green fir-forest" => "forest",
  "light-grey hill" => "hill",
  "grey mountain" => "mountain",
  "grey mountains" => "mountain",
  # secondary
  "light-green bush" => "plains",
  "light-green bushes" => "plains",
  "dust hill" => "hill",
  # tertiary
  "green trees" => "forest",
  "light-grey forest-hill" => "hill",
  "green fir-forest" => "forest",
  "green forest-mountains" => "forest",
  # wildcard
  "dark-grey marsh" => "swamp",
  "sand desert" => "desert",
  "grey forest-mountain" => "mountain",
  "grey forest-mountains" => "mountain",
  "green forest-hill" => "forest",
  # code
  "light-soil fields" => "plains",
  "soil fields" => "plains",
    );

my %encounters = ("settlement" => ["thorp", "thorp", "thorp", "thorp",
				   "village",
				   "town", "town",
				   "large-town",
				   "city"],
		  "fortress" => ["keep", "tower", "castle"],
		  "religious" => ["shrine", "law", "chaos"],
		  "ruin" => [],
		  "monster" => [],
		  "natural" => []);

my @needs_fields;

sub one {
  my @arr = @_;
  @arr = @{$arr[0]} if @arr == 1 and ref $arr[0] eq 'ARRAY';
  return $arr[int(rand(scalar @arr))];
}

sub member {
  my $element = shift;
  foreach (@_) {
    return 1 if $element eq $_;
  }
}

sub verbose {
  $log->info(shift);
}

sub place_major {
  my ($x, $y, $encounter) = @_;
  my $thing = one(@{$encounters{$encounter}});
  return unless $thing;
  verbose("placing $thing ($encounter) at ($x,$y)");
  my $hex = one(full_hexes($x, $y));
  $x += $hex->[0];
  $y += $hex->[1];
  my $coordinates = Point::coord($x, $y);
  my $primary = $reverse_lookup{$world{$coordinates}};
  my ($color, $terrain) = split(' ', $world{$coordinates}, 2);
  if ($encounter eq 'settlement') {
    if ($primary eq 'plains') {
      $color = one('light-soil', 'soil');
      verbose(" " . $world{$coordinates} . " is $primary and was changed to $color");
    }
    if ($primary ne 'plains' or member($thing, 'large-town', 'city')) {
      push(@needs_fields, [$x, $y]);
    }
  }
  # ignore $terrain for the moment and replace it with $thing
  $world{$coordinates} = "$color $thing";
}

sub populate_region {
  my ($hex, $primary) = @_;
  my $random = rand 100;
  if ($primary eq 'water' and $random < 10
      or $primary eq 'swamp' and $random < 20
      or $primary eq 'sand' and $random < 20
      or $primary eq 'grass' and $random < 60
      or $primary eq 'forest' and $random < 40
      or $primary eq 'hill' and $random < 40
      or $primary eq 'mountain' and $random < 20) {
    place_major($hex->[0], $hex->[1], one(keys %encounters));
  }
}

# Brute forcing by picking random sub hexes until we found an
# unassigned one.

sub pick_unassigned {
  my ($x, $y, @region) = @_;
  my $hex = one(@region);
  my $coordinates = Point::coord($x + $hex->[0], $y + $hex->[1]);
  while ($world{$coordinates}) {
    $hex = one(@region);
    $coordinates = Point::coord($x + $hex->[0], $y + $hex->[1]);
  }
  return $coordinates;
}

sub pick_remaining {
  my ($x, $y, @region) = @_;
  my @coordinates = ();
  for my $hex (@region) {
    my $coordinates = Point::coord($x + $hex->[0], $y + $hex->[1]);
    push(@coordinates, $coordinates) unless $world{$coordinates};
  }
  return @coordinates;
}

# Precomputed for speed

sub full_hexes {
  my ($x, $y) = @_;
  if ($x % 2) {
    return ([0, -2],
	    [-2, -1], [-1, -1], [0, -1], [1, -1], [2, -1],
	    [-2,  0], [-1,  0], [0,  0], [1,  0], [2,  0],
	    [-2,  1], [-1,  1], [0,  1], [1,  1], [2,  1],
	    [-1,  2], [0,  2], [1,  2]);
  } else {
    return ([-1, -2], [0, -2], [1, -2],
	    [-2, -1], [-1, -1], [0, -1], [1, -1], [2, -1],
	    [-2,  0], [-1,  0], [0,  0], [1,  0], [2,  0],
            [-2,  1], [-1,  1], [0,  1], [1,  1], [2,  1],
	    [0,  2]);
  }
}

sub half_hexes {
  my ($x, $y) = @_;
  if ($x % 2) {
    return ([-2, -2], [-1, -2], [1, -2], [2, -2],
	    [-3,  0], [3,  0],
	    [-3,  1], [3,  1],
	    [-2,  2], [2,  2],
	    [-1,  3], [1,  3]);
  } else {
    return ([-1, -3], [1, -3],
	    [-2, -2], [2, -2],
	    [-3, -1], [3, -1],
	    [-3,  0], [3,  0],
	    [-2,  2], [-1,  2], [1,  2], [2,  2]);
  }
}

sub generate_region {
  my ($x, $y, $primary) = @_;
  $world{Point::coord($x, $y)} = one($primary{$primary});

  my @region = full_hexes($x, $y);
  my $terrain;

  for (1..9) {
    my $coordinates = pick_unassigned($x, $y, @region);
    $terrain = one($primary{$primary});
    verbose(" primary   $coordinates => $terrain");
    $world{$coordinates} = $terrain;
  }

  for (1..6) {
    my $coordinates = pick_unassigned($x, $y, @region);
    $terrain =  one($secondary{$primary});
    verbose(" secondary $coordinates => $terrain");
    $world{$coordinates} = $terrain;
  }

  for my $coordinates (pick_remaining($x, $y, @region)) {
    if (rand > 0.1) {
      $terrain = one($tertiary{$primary});
      verbose(" tertiary  $coordinates => $terrain");
    } else {
      $terrain = one($wildcard{$primary});
      verbose(" wildcard  $coordinates => $terrain");
    }
    $world{$coordinates} = $terrain;
  }

  for my $coordinates (pick_remaining($x, $y, half_hexes($x, $y))) {
    my $random = rand 6;
    if ($random < 3) {
      $terrain = one($primary{$primary});
      verbose("  halfhex primary   $coordinates => $terrain");
    } elsif ($random < 5) {
      $terrain = one($secondary{$primary});
      verbose("  halfhex secondary $coordinates => $terrain");
    } else {
      $terrain = one($tertiary{$primary});
      verbose("  halfhex tertiary  $coordinates => $terrain");
    }
    $world{$coordinates} = $terrain;
  }
}

sub seed_region {
  my ($seeds, $terrain) = @_;
  my $terrain_above;
  for my $hex (@$seeds) {
    verbose("seed_region (" . $hex->[0] . "," . $hex->[1] . ") with $terrain");
    generate_region($hex->[0], $hex->[1], $terrain);
    populate_region($hex, $terrain);
    my $random = rand 12;
    # pick next terrain based on the previous one (to the left); or the one
    # above if in the first column
    my $next;
    $terrain = $terrain_above if $hex->[0] == 1 and $terrain_above;
    if ($random < 6) {
      $next = one($primary{$terrain});
      verbose("picked primary $next");
    } elsif ($random < 9) {
      $next = one($secondary{$terrain});
      verbose("picked secondary $next");
    } elsif ($random < 11) {
      $next = one($tertiary{$terrain});
      verbose("picked tertiary $next");
    } else {
      $next = one($wildcard{$terrain});
      verbose("picked wildcard $next");
    }
    $terrain_above = $terrain if $hex->[0] == 1;
    die "Terrain lacks reverse_lookup: $next\n" unless $reverse_lookup{$next};
    $terrain = $reverse_lookup{$next};
  }
}

sub agriculture {
  for my $hex (@needs_fields) {
    verbose("looking to plant fields near " . Point::coord($hex->[0], $hex->[1]));
    my $delta = [[[-1,  0], [ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1]],  # x is even
		 [[-1, -1], [ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0]]]; # x is odd
    my @plains;
    for my $i (0 .. 5) {
      my ($x, $y) = ($hex->[0] + $delta->[$hex->[0] % 2]->[$i]->[0],
		     $hex->[1] + $delta->[$hex->[0] % 2]->[$i]->[1]);
      my $coordinates = Point::coord($x, $y);
      if ($world{$coordinates}) {
	my ($color, $terrain) = split(' ', $world{$coordinates}, 2);
	verbose("  $coordinates is " . $world{$coordinates} . " ie. " . $reverse_lookup{$world{$coordinates}});
	if ($reverse_lookup{$world{$coordinates}} eq 'plains') {
	  verbose("   $coordinates is a candidate");
	  push(@plains, $coordinates);
	}
      }
    }
    next unless @plains;
    my $target = one(@plains);
    $world{$target} = one('light-soil fields', 'soil fields');
    verbose(" $target planted with " . $world{$target});
  }
}

sub generate_map {
  my ($bw, $width, $height) = @_;
  $width = 20 if not defined $width or $width < 1 or $width > 100;
  $height = 10 if not defined $height or $height < 1 or $height > 100;

  my $seeds;
  for (my $y = 1; $y < $height + 2; $y += 5) {
    for (my $x = 1; $x < $width + 2; $x += 5) {
      # [1,1] [6,3], [11,1], [16,3]
      my $y0 = $y + int(($x % 10) / 3);
      push(@$seeds, [$x, $y0]);
    }
  }

  %world = (); # reinitialize!

  my @seed_terrain = keys %primary;
  seed_region($seeds, one(@seed_terrain));
  agriculture();

  # delete extra hexes we generated to fill the gaps
  for my $coordinates (keys %world) {
    $coordinates =~ /(..)(..)/;
    delete $world{$coordinates} if $1 < 1 or $2 < 1;
    delete $world{$coordinates} if $1 > $width or $2 > $height;
  }

  if ($bw) {
    for my $coordinates (keys %world) {
      my ($color, $rest) = split(' ', $world{$coordinates}, 2);
      if ($rest) {
	$world{$coordinates} = $rest;
      } else {
	delete $world{$coordinates};
      }
    }
  }

  return join("\n", map { $_ . " " . $world{$_} } sort keys %world) . "\n"
    . "include $contrib/gnomeyland.txt\n";
}

package Schroeder::Base;
use Modern::Perl '2018';
use Mojo::Base -role;

# We're assuming that $width and $height have two digits (10 <= n <= 99).

has width => 30;
has height => 10;

sub xy {
  my $self = shift;
  my $coordinates = shift;
  return (substr($coordinates, 0, 2), substr($coordinates, 2));
}

sub coordinates {
  my ($x, $y) = @_;
  return Point::coord($x, $y);
}

sub legal {
  my $self = shift;
  my ($x, $y) = @_;
  ($x, $y) = $self->xy($x) if not defined $y;
  return @_ if $x > 0 and $x <= $self->width and $y > 0 and $y <= $self->height;
}


sub remove_closer_than {
  my $self = shift;
  my ($limit, @hexes) = @_;
  my @filtered;
 HEX:
  for my $hex (@hexes) {
    my ($x1, $y1) = $self->xy($hex);
    # check distances with all the hexes already in the list
    for my $existing (@filtered) {
      my ($x2, $y2) = $self->xy($existing);
      my $distance = $self->distance($x1, $y1, $x2, $y2);
      # warn "Distance between $x1$y1 and $x2$y2 is $distance\n";
      next HEX if $distance < $limit;
    }
    # if this hex wasn't skipped, it goes on to the list
    push(@filtered, $hex);
  }
  return @filtered;
}

sub flat {
  my $self = shift;
  # initialize the altitude map; this is required so that we have a list of
  # legal hex coordinates somewhere
  my ($altitude) = @_;
  for my $y (1 .. $self->height) {
    for my $x (1 .. $self->width) {
      my $coordinates = coordinates($x, $y);
      $altitude->{$coordinates} = 0;
    }
  }
}

sub direction {
  my $self = shift;
  my ($from, $to) = @_;
  for my $i ($self->neighbors()) {
    return $i if $to eq coordinates($self->neighbor($from, $i));
  }
}

package Schroeder::Alpine;
use Modern::Perl '2018';
use Mojo::Base -base;
use Role::Tiny::With;
with 'Schroeder::Base';

use List::Util 'shuffle';

has 'steepness';
has 'peaks';
has 'peak';
has 'bumps';
has 'bump';
has 'bottom';
has 'arid';

sub place_peak {
  my $self = shift;
  my $altitude = shift;
  my $count = shift;
  my $current_altitude = shift;
  my @queue;
  # place some peaks and put them in a queue
  for (1 .. $count) {
    # try to find an empty hex
    for (1 .. 6) {
      my $x = int(rand($self->width)) + 1;
      my $y = int(rand($self->height)) + 1;
      my $coordinates = coordinates($x, $y);
      next if $altitude->{$coordinates};
      $altitude->{$coordinates} = $current_altitude;
      $log->debug("placed $current_altitude at $coordinates");
      push(@queue, $coordinates);
      last;
    }
  }
  return @queue;
}

sub grow_mountains {
  my $self = shift;
  my $altitude = shift;
  my @queue = @_;
  # go through the queue and add adjacent lower altitude hexes, if possible; the
  # hexes added are to the end of the queue
  while (@queue) {
    my $coordinates = shift @queue;
    my $current_altitude = $altitude->{$coordinates};
    next unless $current_altitude > 0;
    # pick some random neighbors based on variable steepness
    my $n = $self->steepness;
    # round up based on fraction
    $n += 1 if rand() < $n - int($n);
    $n = int($n);
    next if $n < 1;
    for (1 .. $n) {
      # try to find an empty neighbor; abort after six attempts
      for (1 .. 6) {
	my ($x, $y) = $self->neighbor($coordinates, $self->random_neighbor());
	next unless $self->legal($x, $y);
	my $other = coordinates($x, $y);
	# if this is taken, look further
	if ($altitude->{$other}) {
	  ($x, $y) = $self->neighbor2($coordinates, $self->random_neighbor2());
	  next unless $self->legal($x, $y);
	  $other = coordinates($x, $y);
	  # if this is also taken, try again
	  next if $altitude->{$other};
	}
	# if we found an empty neighbor, set its altitude
	$altitude->{$other} = $current_altitude > 0 ? $current_altitude - 1 : 0;
	push(@queue, $other);
	last;
      }
    }
  }
}

sub fix_altitude {
  my $self = shift;
  my $altitude = shift;
  # go through all the hexes
  for my $coordinates (sort keys %$altitude) {
    # find hexes that we missed and give them the height of a random neighbor
    if (not defined $altitude->{$coordinates}) {
      # warn "identified a hex that was skipped: $coordinates\n";
      # try to find a suitable neighbor
      for (1 .. 6) {
	my ($x, $y) = $self->neighbor($coordinates, $self->random_neighbor());
	next unless $self->legal($x, $y);
	my $other = coordinates($x, $y);
	next unless defined $altitude->{$other};
	$altitude->{$coordinates} = $altitude->{$other};
	last;
      }
      # if we didn't find one in the last six attempts, just make it hole in the ground
      if (not defined $altitude->{$coordinates}) {
	$altitude->{$coordinates} = 0;
      }
    }
  }
}

sub altitude {
  my $self = shift;
  my ($world, $altitude) = @_;
  my @queue = $self->place_peak($altitude, $self->peaks, $self->peak);
  $self->grow_mountains($altitude, @queue);
  $self->fix_altitude($altitude);
  # note height for debugging purposes
  for my $coordinates (sort keys %$altitude) {
    $world->{$coordinates} = "height$altitude->{$coordinates}";
  }
}

sub bumps {
  my $self = shift;
  my ($world, $altitude) = @_;
  for (1 .. $self->bumps) {
    for my $delta (-$self->bump, $self->bump) {
      # six attempts to try and find a good hex
      for (1 .. 6) {
	my $x = int(rand($self->width)) + 1;
	my $y = int(rand($self->height)) + 1;
	my $coordinates = coordinates($x, $y);
	my $current_altitude = $altitude->{$coordinates} + $delta;
	next if $current_altitude > 10 or $current_altitude < 0;
	# bump it up or down
	$altitude->{$coordinates} = $current_altitude;
	$world->{$coordinates} = "height$altitude->{$coordinates}";
	$log->debug("bumped altitude of $coordinates by $delta to $current_altitude");
	# if the bump was +2 or -2, bump the neighbours by +1 or -1
	if ($delta < -1 or $delta > 1) {
	  my $delta = $delta - $delta / abs($delta);
	  for my $i ($self->neighbors()) {
	    my ($x, $y) = $self->neighbor($coordinates, $i);
	    my $legal = $self->legal($x, $y);
	    my $other = coordinates($x, $y);
	    next if not $legal;
	    $current_altitude = $altitude->{$other} + $delta;
	    next if $current_altitude > 10 or $current_altitude < 0;
	    $altitude->{$other} = $current_altitude;
	    $world->{$other} = "height$altitude->{$other}";
	    $log->debug("$i bumped altitude of $other by $delta to $current_altitude");
	  }
	}
	# if we have found a good hex, don't go through all the other attempts
	last;
      }
    }
  }
}

sub water {
  my $self = shift;
  my ($world, $altitude, $water) = @_;
  # reset in case we run this twice
  # go through all the hexes
  for my $coordinates (sort keys %$altitude) {
    next if $altitude->{$coordinates} <= $self->bottom;
    # note preferred water flow by identifying lower lying neighbors
    my ($lowest, $direction);
    # look at neighbors in random order
  NEIGHBOR:
    for my $i (shuffle $self->neighbors()) {
      my ($x, $y) = $self->neighbor($coordinates, $i);
      my $legal = $self->legal($x, $y);
      my $other = coordinates($x, $y);
      next if $legal and $altitude->{$other} > $altitude->{$coordinates};
      # don't point head on to another arrow
      next if $legal and $water->{$other} and $water->{$other} == ($i-3) % 6;
      # don't point into loops
      my %loop = ($coordinates => 1, $other => 1);
      my $next = $other;
      $log->debug("Loop detection starting with $coordinates and $other");
      while ($next) {
	# no water flow known is also good;
	$log->debug("water for $next: " . ($water->{$next} || "none"));
	last unless defined $water->{$next};
	($x, $y) = $self->neighbor($next, $water->{$next});
	# leaving the map is good
	$log->debug("legal for $next: " . $self->legal($x, $y));
	last unless $self->legal($x, $y);
	$next = coordinates($x, $y);
	# skip this neighbor if this is a loop
	$log->debug("is $next in a loop? " . ($loop{$next} || "no"));
	next NEIGHBOR if $loop{$next};
	$loop{$next} = 1;
      }
      if (not defined $direction
	  or not $legal and $altitude->{$coordinates} < $lowest
	  or $legal and $altitude->{$other} < $lowest) {
	$lowest = $legal ? $altitude->{$other} : $altitude->{$coordinates};
	$direction = $i;
	$log->debug("Set lowest to $lowest ($direction)");
      }
    }
    if (defined $direction) {
      $water->{$coordinates} = $direction;
      $world->{$coordinates} =~ s/arrow\d/arrow$water->{$coordinates}/
	  or $world->{$coordinates} .= " arrow$water->{$coordinates}";
    }
  }
}

sub mountains {
  my $self = shift;
  my ($world, $altitude) = @_;
  # place the types
  for my $coordinates (keys %$altitude) {
    if ($altitude->{$coordinates} >= 10) {
      $world->{$coordinates} = "white mountains";
    } elsif ($altitude->{$coordinates} >= 9) {
      $world->{$coordinates} = "white mountain";
    } elsif ($altitude->{$coordinates} >= 8) {
      $world->{$coordinates} = "light-grey mountain";
    }
  }
}

sub ocean {
  my $self = shift;
  my ($world, $altitude) = @_;
  for my $coordinates (sort keys %$altitude) {
    if ($altitude->{$coordinates} <= $self->bottom) {
      my $ocean = 1;
      for my $i ($self->neighbors()) {
	my ($x, $y) = $self->neighbor($coordinates, $i);
	my $legal = $self->legal($x, $y);
	my $other = coordinates($x, $y);
	next if not $legal or $altitude->{$other} <= $self->bottom;
	$ocean = 0;
      }
      $world->{$coordinates} = $ocean ? "ocean" : "water";
    }
  }
}

sub lakes {
  my $self = shift;
  my ($world, $altitude, $water) = @_;
  # any areas without water flow are lakes
  for my $coordinates (sort keys %$altitude) {
    if (not defined $water->{$coordinates}
	and $world->{$coordinates} ne "ocean") {
      $world->{$coordinates} = "water";
    }
  }
}

sub swamps {
  my $self = shift;
  # any area with water flowing to a neighbor at the same altitude is a swamp
  my ($world, $altitude, $water, $flow) = @_;
 HEX:
  for my $coordinates (keys %$altitude) {
    # don't turn lakes into swamps and skip bogs
    next if $world->{$coordinates} =~ /ocean|water|swamp/;
    # swamps require a river
    next unless $flow->{$coordinates};
    # look at the neighbor the water would flow to
    my ($x, $y) = $self->neighbor($coordinates, $water->{$coordinates});
    # skip if water flows off the map
    next unless $self->legal($x, $y);
    my $other = coordinates($x, $y);
    # skip if water flows downhill
    next if $altitude->{$coordinates} > $altitude->{$other};
    # if there was no lower neighbor, this is a swamp
    if ($altitude->{$coordinates} >= 6) {
      $world->{$coordinates} =~ s/height\d+/grey swamp/;
    } else {
      $world->{$coordinates} =~ s/height\d+/dark-grey swamp/;
    }
  }
}

sub flood {
  my $self = shift;
  my ($world, $altitude, $water) = @_;
  # backtracking information: $from = $flow{$to}
  my %flow;
  # allow easy skipping
  my %seen;
  # start with a list of hexes to look at; as always, keys is a source of
  # randomness that's independent of srand which is why we shuffle sort
  my @lakes = shuffle sort grep { not defined $water->{$_} } keys %$world;
  return unless @lakes;
  my $start = shift(@lakes);
  my @candidates = ($start);
  while (@candidates) {
    # Prefer candidates outside the map with altitude 0; reshuffle because
    # candidates at the same height are all equal and early or late discoveries
    # should not matter (not shuffling means it matters whether candidates are
    # pushed or unshifted because this is a stable sort)
    @candidates = sort {
      ($altitude->{$a}||0) <=> ($altitude->{$b}||0)
    } shuffle @candidates;
    $log->debug("Candidates @candidates");
    my $coordinates;
    do {
      $coordinates = shift(@candidates);
    } until not $coordinates or not $seen{$coordinates};
    last unless $coordinates;
    $seen{$coordinates} = 1;
    $log->debug("Looking at $coordinates");
    if ($self->legal($coordinates) and $world->{$coordinates} ne "ocean") {
      # if we're still on the map, check all the unknown neighbors
      my $from = $coordinates;
      for my $i ($self->neighbors()) {
	my $to = coordinates($self->neighbor($from, $i));
	next if $seen{$to};
	$log->debug("Adding $to to our candidates");
	$flow{$to} = $from;
	# adding to the front as we keep pushing forward (I hope)
	push(@candidates, $to);
      }
      next;
    }
    $log->debug("We left the map at $coordinates");
    my $to = $coordinates;
    my $from = $flow{$to};
    while ($from) {
      my $i = $self->direction($from, $to);
      if (not defined $water->{$from}
	  or $water->{$from} != $i) {
	$log->debug("Arrow for $from now points to $to");
	$water->{$from} = $i;
	$world->{$from} =~ s/arrow\d/arrow$i/
	    or $world->{$from} .= " arrow$i";
      } else {
	$log->debug("Arrow for $from already points $to");
      }
      $to = $from;
      $from = $flow{$to};
    }
    # pick the next lake
    do {
      $start = shift(@lakes);
      $log->debug("Next lake is $start") if $start;
    } until not $start or not defined $water->{$start};
    last unless $start;
    %seen = %flow = ();
    @candidates = ($start);
  }
}

sub rivers {
  my $self = shift;
  my ($world, $altitude, $water, $flow, $level) = @_;
  # $flow are the sources points of rivers, or 1 if a river flows through them
  my @growing = map {
    $world->{$_} = "light-grey forest-hill" unless $world->{$_} =~ /mountain|swamp|water|ocean/;
    # warn "Started a river at $_ ($altitude->{$_} == $level)\n";
    $flow->{$_} = [$_]
  } sort grep {
    $altitude->{$_} == $level and not $flow->{$_}
  } keys %$altitude;
  return $self->grow_rivers(\@growing, $water, $flow);
}

sub grow_rivers {
  my $self = shift;
  my ($growing, $water, $flow) = @_;
  my @rivers;
  while (@$growing) {
    # warn "Rivers: " . @growing . "\n";
    # pick a random growing river and grow it
    my $n = int(rand(scalar @$growing));
    my $river = $growing->[$n];
    # warn "Picking @$river\n";
    my $coordinates = $river->[-1];
    my $end = 1;
    if (defined $water->{$coordinates}) {
      my $other = coordinates($self->neighbor($coordinates, $water->{$coordinates}));
      die "Adding $other leads to an infinite loop in river @$river\n" if grep /$other/, @$river;
      # if we flowed into a hex with a river
      if (ref $flow->{$other}) {
	# warn "Prepending @$river to @{$flow->{$other}}\n";
	# prepend the current river to the other river
	unshift(@{$flow->{$other}}, @$river);
	# move the source marker
	$flow->{$river->[0]} = $flow->{$other};
	$flow->{$other} = 1;
	# and remove the current river from the growing list
	splice(@$growing, $n, 1);
	# warn "Flow at $river->[0]: @{$flow->{$river->[0]}}\n";
	# warn "Flow at $other: $flow->{$other}\n";
      } else {
	$flow->{$coordinates} = 1;
	push(@$river, $other);
      }
    } else {
      # stop growing this river
      # warn "Stopped river: @$river\n" if grep(/0914/, @$river);
      push(@rivers, splice(@$growing, $n, 1));
    }
  }
  return @rivers;
}

sub canyons {
  my $self = shift;
  my ($world, $altitude, $rivers) = @_;
  my @canyons;
  # using a reference to an array so that we can leave pointers in the %seen hash
  my $canyon = [];
  # remember which canyon flows through which hex
  my %seen;
  for my $river (@$rivers) {
    my $last = $river->[0];
    my $current_altitude = $altitude->{$last};
    $log->debug("Looking at @$river ($current_altitude)");
    for my $coordinates (@$river) {
      $log->debug("Looking at $coordinates");
      if ($seen{$coordinates}) {
	# the rest of this river was already looked at, so there is no need to
	# do the rest of this river; if we're in a canyon, prepend it to the one
	# we just found before ending
	if (@$canyon) {
	  my @other = @{$seen{$coordinates}};
	  if ($other[0] eq $canyon->[-1]) {
	    $log->debug("Canyon @$canyon of river @$river merging with @other at $coordinates");
	    unshift(@{$seen{$coordinates}}, @$canyon[0 .. @$canyon - 2]);
	  } else {
	    $log->debug("Canyon @$canyon of river @$river stumbled upon existing canyon @other at $coordinates");
	    while (@other) {
	      my $other = shift(@other);
	      next if $other ne $coordinates;
	      push(@$canyon, $other, @other);
	      last;
	    }
	    $log->debug("Canyon @$canyon");
	    push(@canyons, $canyon);
	  }
	  $canyon = [];
	}
	$log->debug("We've seen the rest: @{$seen{$coordinates}}");
	last;
      }
      # no canyons through water!
      if ($altitude->{$coordinates} and $current_altitude < $altitude->{$coordinates}
	  and $world->{$coordinates} !~ /water|ocean/) {
	# river is digging a canyon; if this not the start of the river and it
	# is the start of a canyon, prepend the last step
	push(@$canyon, $last) unless @$canyon;
	push(@$canyon, $coordinates);
	$log->debug("Growing canyon @$canyon");
	$seen{$coordinates} = $canyon;
      } else {
	# if we just left a canyon, append the current step
	if (@$canyon) {
	  push(@$canyon, $coordinates);
	  push(@canyons, $canyon);
	  $log->debug("Looking at river @$river");
	  $log->debug("Canyon @$canyon");
	  $canyon = [];
	  last;
	}
	# not digging a canyon
	$last = $coordinates;
	$current_altitude = $altitude->{$coordinates};
      }
    }
  }
  return @canyons;
}

sub wet {
  my $self = shift;
  # a hex is wet if there is a river, a swamp or a forest within 2 hexes
  my ($coordinates, $world, $flow) = @_;
  for my $i ($self->neighbors()) {
    my ($x, $y) = $self->neighbor($coordinates, $i);
    # next unless $self->legal($x, $y);
    my $other = coordinates($x, $y);
    return 0 if $flow->{$other};
  }
  for my $i ($self->neighbors2()) {
    my ($x, $y) = $self->neighbor2($coordinates, $i);
    # next unless $self->legal($x, $y);
    my $other = coordinates($x, $y);
    return 0 if $flow->{$other};
  }
  return 1;
}

sub grow_forest {
  my $self = shift;
  my ($coordinates, $world, $altitude) = @_;
  my @candidates = ($coordinates);
  my $n = $self->arid;
  # fractions are allowed
  $n += 1 if rand() < $self->arid - int($self->arid);
  $n = int($n);
  $log->debug("Arid: $n");
  if ($n >= 1) {
    for my $i ($self->neighbors()) {
      my ($x, $y) = $self->neighbor($coordinates, $i);
      next unless $self->legal($x, $y);
      my $other = coordinates($x, $y);
      push(@candidates, $other) if $world->{$other} !~ /mountain|hill|water|ocean|swamp/;
    }
  }
  if ($n >= 2) {
    for my $i ($self->neighbors2()) {
      my ($x, $y) = $self->neighbor2($coordinates, $i);
      next unless $self->legal($x, $y);
      my $other = coordinates($x, $y);
      push(@candidates, $other) if $world->{$other} !~ /mountain|hill|water|ocean|swamp/;
    }
  }
  for $coordinates (@candidates) {
    if ($altitude->{$coordinates} >= 7) {
      $world->{$coordinates} = "light-green fir-forest";
    } elsif ($altitude->{$coordinates} >= 6) {
      $world->{$coordinates} = "green fir-forest";
    } elsif ($altitude->{$coordinates} >= 4) {
      $world->{$coordinates} = "green forest";
    } else {
      $world->{$coordinates} = "dark-green forest";
    }
  }
}

sub forests {
  my $self = shift;
  my ($world, $altitude, $flow) = @_;
  # empty hexes with a river flowing through them are forest filled valleys
  for my $coordinates (keys %$flow) {
    if ($world->{$coordinates} !~ /mountain|hill|water|ocean|swamp/) {
      $self->grow_forest($coordinates, $world, $altitude);
    }
  }
}

sub dry {
  my $self = shift;
  # a hex is dry if there is no river within 2 hexes of it
  my ($coordinates, $flow) = @_;
  for my $i ($self->neighbors()) {
    my ($x, $y) = $self->neighbor($coordinates, $i);
    # next unless $self->legal($x, $y);
    my $other = coordinates($x, $y);
    return 0 if $flow->{$other};
  }
  for my $i ($self->neighbors2()) {
    my ($x, $y) = $self->neighbor2($coordinates, $i);
    # next unless $self->legal($x, $y);
    my $other = coordinates($x, $y);
    return 0 if $flow->{$other};
  }
  return 1;
}

sub bogs {
  my $self = shift;
  my ($world, $altitude, $water, $flow) = @_;
 HEX:
  for my $coordinates (keys %$altitude) {
    # limit ourselves to altitude 7
    next if $altitude->{$coordinates} != 7;
    # don't turn lakes into bogs
    next if $world->{$coordinates} =~ /water|ocean/;
    # look at the neighbor the water would flow to
    my ($x, $y) = $self->neighbor($coordinates, $water->{$coordinates});
    # skip if water flows off the map
    next unless $self->legal($x, $y);
    my $other = coordinates($x, $y);
    # skip if water flows downhill
    next if $altitude->{$coordinates} > $altitude->{$other};
    # if there was no lower neighbor, this is a bog
    $world->{$coordinates} =~ s/height\d+/grey swamp/;
  }
}

sub bushes {
  my $self = shift;
  my ($world, $altitude, $water, $flow) = @_;
  # as always, keys is a source of randomness that's independent of srand which
  # is why we sort
  for my $coordinates (sort keys %$world) {
    if ($world->{$coordinates} !~ /mountain|hill|water|ocean|swamp|forest|firs|trees/) {
      my $thing = "bushes";
      my $rand = rand();
      if ($altitude->{$coordinates} >= 3 and $rand < 0.2) {
	$thing = "hill";
      } elsif ($altitude->{$coordinates} <= 3 and $rand < 0.6) {
	  $thing = "grass";
      }
      my $colour = "light-green";
      $colour = "light-grey" if $altitude->{$coordinates} >= 6;
      $world->{$coordinates} = "$colour $thing";
    }
  }
}

sub settlements {
  my $self = shift;
  my ($world, $flow) = @_;
  my @settlements;
  my $max = $self->height * $self->width;
  # do not match forest-hill
  my @candidates = shuffle sort grep { $world->{$_} =~ /\b(fir-forest|forest(?!-hill))\b/ } keys %$world;
  @candidates = $self->remove_closer_than(2, @candidates);
  @candidates = @candidates[0 .. int($max/10 - 1)] if @candidates > $max/10;
  push(@settlements, @candidates);
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/fir-forest/firs thorp/
	or $world->{$coordinates} =~ s/forest(?!-hill)/trees thorp/;
  }
  @candidates = shuffle sort grep { $world->{$_} =~ /(?<!fir-)forest(?!-hill)/ and $flow->{$_}} keys %$world;
  @candidates = $self->remove_closer_than(5, @candidates);
  @candidates = @candidates[0 .. int($max/20 - 1)] if @candidates > $max/20;
  push(@settlements, @candidates);
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/forest/trees village/;
  }
  @candidates = shuffle sort grep { $world->{$_} =~ /(?<!fir-)forest(?!-hill)/ and $flow->{$_} } keys %$world;
  @candidates = $self->remove_closer_than(10, @candidates);
  @candidates = @candidates[0 .. int($max/40 - 1)] if @candidates > $max/40;
  push(@settlements, @candidates);
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/forest/trees town/;
  }
  @candidates = shuffle sort grep { $world->{$_} =~ /white mountain\b/ } keys %$world;
  @candidates = $self->remove_closer_than(10, @candidates);
  @candidates = @candidates[0 .. int($max/40 - 1)] if @candidates > $max/40;
  push(@settlements, @candidates);
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/white mountain\b/white mountain law/;
  }
  @candidates = shuffle sort grep { $world->{$_} =~ /swamp/ } keys %$world;
  @candidates = $self->remove_closer_than(10, @candidates);
  @candidates = @candidates[0 .. int($max/40 - 1)] if @candidates > $max/40;
  push(@settlements, @candidates);
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/swamp/swamp2 chaos/;
  }
  return @settlements;
}

sub trails {
  my $self = shift;
  my ($altitude, $settlements) = @_;
  # look for a neighbor that is as low as possible and nearby
  my %trails;
  my @from = shuffle @$settlements;
  my @to = shuffle @$settlements;
  for my $from (@from) {
    my ($best, $best_distance, $best_altitude);
    for my $to (@to) {
      next if $from eq $to;
      my $distance = $self->distance($from, $to);
      $log->debug("Considering $from-$to: distance $distance, altitude " . $altitude->{$to});
      if ($distance <= 3
	  and (not $best_distance or $distance <= $best_distance)
	  and (not $best or $altitude->{$to} < $best_altitude)) {
	$best = $to;
	$best_altitude = $altitude->{$best};
	$best_distance = $distance;
      }
    }
    next if not $best;
    # skip if it already exists in the other direction
    next if $trails{"$best-$from"};
    $trails{"$from-$best"} = 1;
    $log->debug("Trail $from-$best");
  }
  return keys %trails;
}

sub cliffs {
  my $self = shift;
  my ($world, $altitude) = @_;
  my @neighbors = $self->neighbors();
  # hexes with altitude difference bigger than 1 have cliffs
  for my $coordinates (keys %$world) {
    next if $altitude->{$coordinates} <= $self->bottom;
    for my $i (@neighbors) {
      my ($x, $y) = $self->neighbor($coordinates, $i);
      next unless $self->legal($x, $y);
      my $other = coordinates($x, $y);
      if ($altitude->{$coordinates} - $altitude->{$other} >= 2) {
	if (@neighbors == 6) {
	  $world->{$coordinates} .= " cliff$i";
	} else { # square
	  $world->{$coordinates} .= " cliffs$i";
	}
      }
    }
  }
}

sub generate {
  my $self = shift;
  my ($world, $altitude, $water, $rivers, $settlements, $trails, $canyons, $step) = @_;
  # %flow indicates that there is actually a river in this hex
  my $flow = {};

  my @code = (
    sub { $self->flat($altitude);
	  $self->altitude($world, $altitude); },
    sub { $self->bumps($world, $altitude); },
    sub { $self->mountains($world, $altitude); },
    sub { $self->ocean($world, $altitude); },
    sub { $self->water($world, $altitude, $water); },
    sub { $self->lakes($world, $altitude, $water); },
    sub { $self->flood($world, $altitude, $water); },
    sub { $self->bogs($world, $altitude, $water, $flow); },
    sub { push(@$rivers, $self->rivers($world, $altitude, $water, $flow, 8));
	  push(@$rivers, $self->rivers($world, $altitude, $water, $flow, 7)); },
    sub { push(@$canyons, $self->canyons($world, $altitude, $rivers)); },
    sub { $self->swamps($world, $altitude, $water, $flow); },
    sub { $self->forests($world, $altitude, $flow); },
    sub { $self->bushes($world, $altitude, $water, $flow); },
    sub { $self->cliffs($world, $altitude); },
    sub { push(@$settlements, $self->settlements($world, $flow)); },
    sub { push(@$trails, $self->trails($altitude, $settlements)); },
    # make sure you look at "alpine_document.html.ep" if you change this list!
    # make sure you look at '/alpine/document' if you add to this list
      );

  # $step 0 runs all the code; note that we can't simply cache those results
  # because we need to start over with the same seed!
  my $i = 1;
  while (@code) {
    shift(@code)->();
    return if $step == $i++;
  }
}

sub generate_map {
  my $self = shift;
  # The parameters turn into class variables.
  $self->width(shift // 30);
  $self->height(shift // 10);
  $self->steepness(shift // 3);
  $self->peaks(shift // int($self->width * $self->height / 40));
  $self->peak(shift // 10);
  $self->bumps(shift // int($self->width * $self->height / 40));
  $self->bump(shift // 2);
  $self->bottom(shift // 0);
  $self->arid(shift // 2);
  my $seed = shift||time;
  my $url = shift;
  my $step = shift||0;

  # For documentation purposes, I want to be able to set the pseudo-random
  # number seed using srand and rely on rand to reproduce the same sequence of
  # pseudo-random numbers for the same seed. The key point to remember is that
  # the keys function will return keys in random order. So if we look over the
  # result of keys, we need to look at the code in the loop: If order is
  # important, that wont do. We need to sort the keys. If we want the keys to be
  # pseudo-shuffled, use shuffle sort keys.
  srand($seed);

  # keys for all hashes are coordinates such as "0101".
  # %world is the description with values such as "green forest".
  # %altitude is the altitude with values such as 3.
  # %water is the preferred direction water would take with values such as 0
  # (north west); 0 means we need to use "if defined".
  # @rivers are the rivers with values such as ["0102", "0202"]
  # @settlements are are the locations of settlements such as "0101"
  # @trails are the trails connecting these with values as "0102-0202"
  # $step is how far we want map generation to go where 0 means all the way
  my ($world, $altitude, $water, $rivers, $settlements, $trails, $canyons) =
      ({}, {}, {}, [], [], [], []);
  $self->generate($world, $altitude, $water, $rivers, $settlements, $trails, $canyons, $step);

  # when documenting or debugging, do this before collecting lines
  if ($step > 0) {
    # add a height label at the very end
    if ($step) {
      for my $coordinates (keys %$world) {
	$world->{$coordinates} .= ' "' . $altitude->{$coordinates} . '"';
      }
    }
  }
  if ($step < 1 or $step > 8) {
    # remove arrows – these should not be rendered but they are because #arrow0
    # is present in other SVG files in the same document
    for my $coordinates (keys %$world) {
      $world->{$coordinates} =~ s/ arrow\d//;
    }
  }

  local $" = "-"; # list items separated by -
  my @lines;
  push(@lines, map { $_ . " " . $world->{$_} } sort keys %$world);
  push(@lines, map { "@$_ canyon" } @$canyons);
  push(@lines, map { "@$_ river" } @$rivers);
  push(@lines, map { "$_ trail" } @$trails);
  push(@lines, "include $contrib/gnomeyland.txt");

  # when documenting or debugging, add some more lines at the end
  if ($step > 0) {
    # visualize height
    push(@lines,
	 map {
	   my $n = int(25.5 * $_);
	   qq{height$_ attributes fill="rgb($n,$n,$n)"};
	 } (0 .. 10));
    # visualize water flow
    push(@lines, $self->arrows());
  }

  push(@lines, "# Seed: $seed");
  push(@lines, "# Documentation: " . $url) if $url;
  my $map = join("\n", @lines);
  return $map;
}

package Schroeder::Island;
use Modern::Perl '2018';
use Mojo::Base 'Schroeder::Alpine';
use Role::Tiny::With;
with 'Schroeder::Base';
use List::Util qw'shuffle min max';

has 'bottom' => 0;
has 'top' => 10;
has 'radius' => 5;
has 'hotspot';

sub ocean {
  my $self = shift;
  my ($world, $altitude) = @_;
  for my $coordinates (sort keys %$altitude) {
    if ($altitude->{$coordinates} <= $self->bottom) {
      my $ocean = 1;
      for my $i ($self->neighbors()) {
	my ($x, $y) = $self->neighbor($coordinates, $i);
	my $legal = $self->legal($x, $y);
	my $other = coordinates($x, $y);
	next if not $legal or $altitude->{$other} <= $self->bottom;
	$ocean = 0;
      }
      $world->{$coordinates} = $ocean ? "ocean" : "water";
    }
  }
}

sub change {
  my $self = shift;
  return if $self->hotspot->[0] > $self->width - 2 * $self->radius;
  my $world = shift;
  my $altitude = shift;
  # advance hotspot
  if (rand() < 0.2) {
    $self->hotspot->[0] += 1.5 * $self->radius;
  } else {
    $self->hotspot->[0]++;
  }
  if (rand() < 0.5) {
    if (rand() > $self->hotspot->[1] / $self->height) {
      $self->hotspot->[1]++;
    } else {
      $self->hotspot->[1]--;
    }
  }
  # figure out who goes up and who goes down, if the hotspot is active
  my %hot;
  for my $x (max(1, $self->hotspot->[0] - $self->radius) .. min($self->width, $self->hotspot->[0] + $self->radius)) {
    for my $y (max(1, $self->hotspot->[1] - $self->radius) .. min($self->height, $self->hotspot->[1] + $self->radius)) {
      if ($self->distance($x, $y, @{$self->hotspot}) <= $self->radius) {
	my $coordinates = coordinates($x, $y);
	$hot{$coordinates} = 1;
      }
    }
  }
  # change the land
  for my $coordinates (keys %$altitude) {
    my $change = 0;
    if ($hot{$coordinates}) {
      # on the hotspot the land rises
      $change = 1 if rand() < 0.2;
    } else {
      # off the hotspot the land sinks
      $change = -1 if rand() < 0.2;
    }
    next unless $change;
    # rising from the ocean atop the hotspot
    $altitude->{$coordinates} += $change;
    $altitude->{$coordinates} = $self->bottom if $altitude->{$coordinates} < $self->bottom;
    $altitude->{$coordinates} = $self->top if $altitude->{$coordinates} > $self->top;
  }
  # land with higher neighbours on the hotspot goes up
  for my $coordinates (keys %hot) {
    my $change = 0;
    for my $i ($self->neighbors()) {
      my ($x, $y) = $self->neighbor($coordinates, $i);
      next unless $self->legal($x, $y);
      my $other = coordinates($x, $y);
      $change = 1 if $altitude->{$other} - $altitude->{$coordinates} > 1;
      last;
    }
    $altitude->{$coordinates}++ if $change;
  }
  # note height for debugging purposes
  for my $coordinates (keys %$altitude) {
    $world->{$coordinates} = "height$altitude->{$coordinates}";
  }
}

sub forests {
  my $self = shift;
  my ($world, $altitude) = @_;
  # higher up is forests
  for my $coordinates (keys %$altitude) {
    next unless $altitude->{$coordinates}; # skip ocean
    next if $world->{$coordinates} =~ /mountain|lake/;
    if ($altitude->{$coordinates} == 1) {
      $world->{$coordinates} = "light-grey bushes";
    } elsif ($altitude->{$coordinates} == 2) {
      $world->{$coordinates} = "light-green trees";
    } elsif ($altitude->{$coordinates} == 3) {
      $world->{$coordinates} = "green forest";
    } elsif ($altitude->{$coordinates} == 4) {
      $world->{$coordinates} = "dark-green forest";
    } elsif ($altitude->{$coordinates} > 4) {
      $world->{$coordinates} = "dark-green mountains";
    }
  }
}

sub lakes {
  my $self = shift;
  my ($world, $altitude) = @_;
  # any areas surrounded by higher land is a lake
 HEX:
  for my $coordinates (sort keys %$altitude) {
    for my $i ($self->neighbors()) {
      my ($x, $y) = $self->neighbor($coordinates, $i);
      next unless $self->legal($x, $y);
      my $other = coordinates($x, $y);
      next HEX if $altitude->{$other} == 0;
      next HEX if $altitude->{$coordinates} > $altitude->{$other};
    }
    $world->{$coordinates} = "green lake";
  }
}

sub islands {
  my $self = shift;
  my ($world, $altitude) = @_;
  # any areas surrounded by water is an island
 HEX:
  for my $coordinates (sort keys %$altitude) {
    next if $altitude->{$coordinates} == 0;
    for my $i ($self->neighbors()) {
      my ($x, $y) = $self->neighbor($coordinates, $i);
      next unless $self->legal($x, $y);
      my $other = coordinates($x, $y);
      next HEX if $altitude->{$other} > 0;
    }
    $world->{$coordinates} = "water mountains";
  }
}

sub generate {
  my $self = shift;
  my ($world, $altitude, $settlements, $trails, $step) = @_;
  # %flow indicates that there is actually a river in this hex
  my $flow = {};

  $self->hotspot([int($self->radius / 2), int($self->height / 3 + rand() * $self->height / 3)]);

  my @code = (sub { $self->flat($altitude) });
  for (1 .. $self->width - 2 * $self->radius) {
    push(@code, sub { $self->change($world, $altitude) });
  }
  push(@code, sub { $self->ocean($world, $altitude) });

  push(@code,
    sub { $self->lakes($world, $altitude); },
    sub { $self->islands($world, $altitude); },
    sub { $self->forests($world, $altitude); },
    sub { push(@$settlements, $self->settlements($world, $flow)); },
    sub { push(@$trails, $self->trails($altitude, $settlements)); },
      );

  # $step 0 runs all the code; note that we can't simply cache those results
  # because we need to start over with the same seed!
  my $i = 1;
  while (@code) {
    shift(@code)->();
    $log->debug($step);
    return if $step == $i++;
  }
}

sub generate_map {
  my $self = shift;
  # The parameters turn into class variables.
  $self->width(shift // 40);
  $self->height(shift // 15);
  $self->radius(shift // 4);
  my $seed = shift||time;
  my $url = shift;
  my $step = shift||0;

  # For documentation purposes, I want to be able to set the pseudo-random
  # number seed using srand and rely on rand to reproduce the same sequence of
  # pseudo-random numbers for the same seed. The key point to remember is that
  # the keys function will return keys in random order. So if we look over the
  # result of keys, we need to look at the code in the loop: If order is
  # important, that wont do. We need to sort the keys. If we want the keys to be
  # pseudo-shuffled, use shuffle sort keys.
  srand($seed);

  # keys for all hashes are coordinates such as "0101".
  # %world is the description with values such as "green forest".
  # %altitude is the altitude with values such as 3.
  # @settlements are are the locations of settlements such as "0101"
  # @trails are the trails connecting these with values as "0102-0202"
  # $step is how far we want map generation to go where 0 means all the way
  my ($world, $altitude, $settlements, $trails) =
      ({}, {}, [], []);
  $self->generate($world, $altitude, $settlements, $trails, $step);

  # when documenting or debugging, do this before collecting lines
  if ($step > 0) {
    # add a height label at the very end
    if ($step) {
      for my $coordinates (keys %$world) {
	$world->{$coordinates} .= ' "' . $altitude->{$coordinates} . '"';
      }
    }
  }

  local $" = "-"; # list items separated by -
  my @lines;
  push(@lines, map { $_ . " " . $world->{$_} } sort keys %$world);
  push(@lines, map { "$_ trail" } @$trails);
  push(@lines, "include $contrib/gnomeyland.txt");

  # when documenting or debugging, add some more lines at the end
  if ($step > 0) {
    # visualize height
    push(@lines,
	 map {
	   my $n = int(25.5 * $_);
	   qq{height$_ attributes fill="rgb($n,$n,$n)"};
	 } (0 .. 10));
    # visualize water flow
    push(@lines, $self->arrows());
  }

  push(@lines, "# Seed: $seed");
  push(@lines, "# Documentation: " . $url) if $url;
  my $map = join("\n", @lines);
  return $map;
}

package Schroeder::Archipelago;
use Modern::Perl '2018';
use Mojo::Base -base;
use Role::Tiny::With;
with 'Schroeder::Base';
use List::Util qw'shuffle min max';

has 'bottom' => 0;
has 'top' => 10;
has 'radius' => 5;
has 'width' => 30;
has 'height' => 10;
has 'concentration' => 0.1;
has 'eruptions' => 0.03;
has 'world' => sub { { } };
has 'altitude' => sub { {} };

sub flat {
  my $self = shift;
  $log->debug("initializing altitude map");
  # initialize the altitude map; this is required so that we have a list of
  # legal hex coordinates somewhere
  for my $y (1 .. $self->height) {
    for my $x (1 .. $self->width) {
      my $coordinates = coordinates($x, $y);
      $self->altitude->{$coordinates} = 0;
      $self->world->{$coordinates} = "height0";
    }
  }
}

sub ocean {
  my $self = shift;
  $log->debug("placing ocean and water");
  for my $coordinates (sort keys %{$self->altitude}) {
    if ($self->altitude->{$coordinates} <= $self->bottom) {
      my $ocean = 1;
      for my $i ($self->neighbors()) {
	my ($x, $y) = $self->neighbor($coordinates, $i);
	my $legal = $self->legal($x, $y);
	my $other = coordinates($x, $y);
	next if not $legal or $self->altitude->{$other} <= $self->bottom;
	$ocean = 0;
      }
      $self->world->{$coordinates} = $ocean ? "ocean" : "water";
    }
  }
}

sub eruption {
  my $self = shift;
  my $cx = int $self->width * rand();
  my $cy = int $self->height * (rand() + rand()) / 2;
  $log->debug("eruption at " . $self->coordinates($cx, $cy));
  my $top = 1 + int($self->top * $cx / $self->width);
  $top-- if $top > 2 and rand() < 0.6;
  for my $coordinates (keys %{$self->altitude}) {
    my $d = $self->distance($self->xy($coordinates), $cx, $cy);
    if ($d <= $top) {
      my $h = $top - $d;
      $self->altitude->{$coordinates} = $h if $h > $self->altitude->{$coordinates};
      $self->world->{$coordinates} = "height" . $self->altitude->{$coordinates};
    }
  }
}

sub generate {
  my $self = shift;
  my $step = shift;
  my @code = (sub { $self->flat() });
  for (1 .. $self->width * $self->height * $self->eruptions) {
    push(@code, sub { $self->eruption() });
  }
  push(@code, sub { $self->ocean() });

  # $step 0 runs all the code; note that we can't simply cache those results
  # because we need to start over with the same seed!
  my $i = 1;
  while (@code) {
    shift(@code)->();
    return if $step == $i++;
  }
}

sub generate_map {
  my $self = shift;
  # If provided, the arguments override the defaults
  $self->width(shift // $self->width);
  $self->height(shift // $self->height);
  $self->concentration(shift // $self->concentration);
  $self->eruptions(shift // $self->eruptions);
  $self->top(shift // $self->top);
  $self->bottom(shift // $self->bottom);
  my $seed = shift||time;
  my $url = shift;
  my $step = shift||0;

  # For documentation purposes, I want to be able to set the pseudo-random
  # number seed using srand and rely on rand to reproduce the same sequence of
  # pseudo-random numbers for the same seed. The key point to remember is that
  # the keys function will return keys in random order. So if we loop over the
  # result of keys, we need to look at the code in the loop: If order is
  # important, that wont do. We need to sort the keys. If we want the keys to be
  # pseudo-shuffled, use shuffle sort keys.
  srand($seed);

  # keys for all hashes are coordinates such as "0101".
  $self->generate($step);

  # when documenting or debugging, do this before collecting lines
  if ($step > 0) {
    # add a height label at the very end
    if ($step) {
      for my $coordinates (keys %{$self->altitude}) {
	$self->world->{$coordinates} .= ' "' . $self->altitude->{$coordinates} . '"';
      }
    }
  }

  local $" = "-"; # list items separated by -
  my @lines;
  push(@lines, map { $_ . " " . $self->world->{$_} } sort keys %{$self->world});
  # push(@lines, map { "$_ trail" } @$trails);
  push(@lines, "include $contrib/gnomeyland.txt");

  # when documenting or debugging, add some more lines at the end
  if ($step > 0) {
    # visualize height
    push(@lines,
	 map {
	   my $n = int(255 / $self->top * $_);
	   qq{height$_ attributes fill="rgb($n,$n,$n)"};
	 } (0 .. $self->top));
    # visualize water flow
    push(@lines, $self->arrows());
  }

  push(@lines, "# Seed: $seed");
  push(@lines, "# Documentation: " . $url) if $url;
  my $map = join("\n", @lines);
  return $map;
}

package Schroeder::Hex;
use Modern::Perl '2018';
use Mojo::Base -role;

sub neighbors { 0 .. 5 }

sub neighbors2 { 0 .. 11 }

sub random_neighbor { int(rand(6)) }

sub random_neighbor2 { int(rand(12)) }

my $delta_hex = [
  # x is even
  [[-1,  0], [ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1]],
  # x is odd
  [[-1, -1], [ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0]]];

sub neighbor {
  my $self = shift;
  # $hex is [x,y] or "0x0y" and $i is a number 0 .. 5
  my ($hex, $i) = @_;
  die join(":", caller) . ": undefined direction for $hex\n" unless defined $i;
  $hex = [$self->xy($hex)] unless ref $hex;
  return ($hex->[0] + $delta_hex->[$hex->[0] % 2]->[$i]->[0],
	  $hex->[1] + $delta_hex->[$hex->[0] % 2]->[$i]->[1]);
}

my $delta_hex2 = [
  # x is even
  [[-2, +1], [-2,  0], [-2, -1], [-1, -1], [ 0, -2], [+1, -1],
   [+2, -1], [+2,  0], [+2, +1], [+1, +2], [ 0, +2], [-1, +2]],
  # x is odd
  [[-2, +1], [-2,  0], [-2, -1], [-1, -2], [ 0, -2], [+1, -2],
   [+2, -1], [+2,  0], [+2, +1], [+1, +1], [ 0, +2], [-1, +1]]];

sub neighbor2 {
  my $self = shift;
  # $hex is [x,y] or "0x0y" and $i is a number 0 .. 11
  my ($hex, $i) = @_;
  die join(":", caller) . ": undefined direction for $hex\n" unless defined $i;
  $hex = [$self->xy($hex)] unless ref $hex;
  return ($hex->[0] + $delta_hex2->[$hex->[0] % 2]->[$i]->[0],
	  $hex->[1] + $delta_hex2->[$hex->[0] % 2]->[$i]->[1]);
}

sub distance {
  my $self = shift;
  my ($x1, $y1, $x2, $y2) = @_;
  if (@_ == 2) {
    ($x1, $y1, $x2, $y2) = map { $self->xy($_) } @_;
  }
  # transform the coordinate system into a decent system with one axis tilted by
  # 60°
  $y1 = $y1 - POSIX::ceil($x1/2);
  $y2 = $y2 - POSIX::ceil($x2/2);
  if ($x1 > $x2) {
    # only consider moves from left to right and transpose start and
    # end point to make it so
    my ($t1, $t2) = ($x1, $y1);
    ($x1, $y1) = ($x2, $y2);
    ($x2, $y2) = ($t1, $t2);
  }
  if ($y2>=$y1) {
    # if it the move has a downwards component add Δx and Δy
    return $x2-$x1 + $y2-$y1;
  } else {
    # else just take the larger of Δx and Δy
    return $x2-$x1 > $y1-$y2 ? $x2-$x1 : $y1-$y2;
  }
}

sub arrows {
  my $self = shift;
  return
      qq{<marker id="arrow" markerWidth="6" markerHeight="6" refX="6" refY="3" orient="auto"><path d="M6,0 V6 L0,3 Z" style="fill: black;" /></marker>},
      map {
	my $angle = 60 * $_;
	qq{<path id="arrow$_" transform="rotate($angle)" d="M-11.5,-5.8 L11.5,5.8" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
  } ($self->neighbors());
}

package Schroeder::Square;
use Modern::Perl '2018';
use Mojo::Base -role;

sub neighbors { 0 .. 3 }

sub neighbors2 { 0 .. 7 }

sub random_neighbor { int(rand(4)) }

sub random_neighbor2 { int(rand(8)) }

my $delta_square = [[-1,  0], [ 0, -1], [+1,  0], [ 0, +1]];

sub neighbor {
  my $self = shift;
  # $hex is [x,y] or "0x0y" and $i is a number 0 .. 3
  my ($hex, $i) = @_;
  die join(":", caller) . ": undefined direction for $hex\n" unless defined $i;
  $hex = [$self->xy($hex)] unless ref $hex;
  return ($hex->[0] + $delta_square->[$i]->[0],
	  $hex->[1] + $delta_square->[$i]->[1]);
}

my $delta_square2 = [
  [-2,  0], [-1, -1], [ 0, -2], [+1, -1],
  [+2,  0], [+1, +1], [ 0, +2], [-1, +1]];

sub neighbor2 {
  my $self = shift;
  # $hex is [x,y] or "0x0y" and $i is a number 0 .. 7
  my ($hex, $i) = @_;
  die join(":", caller) . ": undefined direction for $hex\n" unless defined $i;
  die join(":", caller) . ": direction $i not supported for square $hex\n" if $i > 7;
  $hex = [$self->xy($hex)] unless ref $hex;
  return ($hex->[0] + $delta_square2->[$i]->[0],
	  $hex->[1] + $delta_square2->[$i]->[1]);
}

sub distance {
  my $self = shift;
  my ($x1, $y1, $x2, $y2) = @_;
  if (@_ == 2) {
    ($x1, $y1, $x2, $y2) = map { $self->xy($_) } @_;
  }
  return abs($x2 - $x1) + abs($y2 - $y1);
}

sub arrows {
  my $self = shift;
  return
      qq{<marker id="arrow" markerWidth="6" markerHeight="6" refX="6" refY="3" orient="auto"><path d="M6,0 V6 L0,3 Z" style="fill: black;" /></marker>},
      map {
	my $angle = 90 * $_;
	qq{<path id="arrow$_" transform="rotate($angle)" d="M-15,0 H30" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
  } ($self->neighbors());
}


package Gridmapper;

use Modern::Perl '2018';
use List::Util qw'shuffle none any min max all';
use List::MoreUtils qw'pairwise';
use URI::Escape;
use Mojo::Base -base;

# This is the meta grid for the geomorphs. Normally this is (3,3) for simple
# dungeons. We need to recompute these when smashing geomorphs together.
has 'dungeon_dimensions';
has 'dungeon_geomorph_size';

# This is the grid for a particular geomorph. This is space for actual tiles.
has 'room_dimensions';

# Rows and columns, for the tiles. Add two tiles for the edges, so the first
# two rows and the last two rows, and the first two columns and the last two
# columns should be empty. This is the empty space where stairs can be added.
# (0,0) starts at the top left and goes rows before columns, like text. Max
# tiles is the maximum number of tiles. We need to recompute these values when
# smashing two geomorphs together.
has 'row';
has 'col';
has 'max_tiles';

sub init {
  my $self = shift;
  $self->dungeon_geomorph_size(3);   # this stays the same
  $self->dungeon_dimensions([3, 3]); # this will change
  $self->room_dimensions([5, 5]);
  $self->recompute();
}

sub recompute {
  my $self = shift;
  $self->row($self->dungeon_dimensions->[0]
	     * $self->room_dimensions->[0]
	     + 4);
  $self->col($self->dungeon_dimensions->[1]
	     * $self->room_dimensions->[1]
	     + 4);
  $self->max_tiles($self->row * $self->col - 1);
}

sub generate_map {
  my $self = shift;
  my $pillars = shift;
  my $n = shift;
  my $caves = shift;
  $self->init;
  my $rooms = [map { $self->generate_room($_, $pillars, $caves) } (1 .. $n)];
  my ($shape, $stairs) = $self->shape(scalar(@$rooms));
  my $tiles = $self->add_rooms($rooms, $shape);
  $tiles = $self->add_corridors($tiles, $shape);
  $tiles = $self->add_doors($tiles) unless $caves;
  $tiles = $self->add_stair($tiles, $stairs) unless $caves;
  $tiles = $self->add_small_stair($tiles, $stairs) if $caves;
  $tiles = $self->fix_corners($tiles);
  $tiles = $self->fix_pillars($tiles) if $pillars;
  $tiles = $self->to_rocks($tiles) if $caves;
  return $self->to_text($tiles);
}

sub generate_room {
  my $self = shift;
  my $num = shift;
  my $pillars = shift;
  my $caves = shift;
  my $r = rand();
  if ($r < 0.9) {
    return $self->generate_random_room($num);
  } elsif ($r < 0.95 and $pillars or $caves) {
    return $self->generate_pillar_room($num);
  } else {
    return $self->generate_fancy_corner_room($num);
  }
}

sub generate_random_room {
  my $self = shift;
  my $num = shift;
  # generate the tiles necessary for a single geomorph
  my @tiles;
  my @dimensions = (2 + int(rand(3)), 2 + int(rand(3)));
  my @start = pairwise { int(rand($b - $a)) } @dimensions, @{$self->room_dimensions};
  # $log->debug("New room starting at (@start) for dimensions (@dimensions)");
  for my $x ($start[0] .. $start[0] + $dimensions[0] - 1) {
    for my $y ($start[1] .. $start[1] + $dimensions[1] - 1) {
      $tiles[$x + $y * $self->room_dimensions->[0]] = ["empty"];
    }
  }
  my $x = $start[0] + int($dimensions[0]/2);
  my $y = $start[1] + int($dimensions[1]/2);
  push(@{$tiles[$x + $y * $self->room_dimensions->[0]]}, "\"$num\"");
  return \@tiles;
}

sub generate_fancy_corner_room {
  my $self = shift;
  my $num = shift;
  my @tiles;
  my @dimensions = (3 + int(rand(2)), 3 + int(rand(2)));
  my @start = pairwise { int(rand($b - $a)) } @dimensions, @{$self->room_dimensions};
  # $log->debug("New room starting at (@start) for dimensions (@dimensions)");
  for my $x ($start[0] .. $start[0] + $dimensions[0] - 1) {
    for my $y ($start[1] .. $start[1] + $dimensions[1] - 1) {
      push(@{$tiles[$x + $y * $self->room_dimensions->[0]]}, "empty");
      # $log->debug("$x $y @{$tiles[$x + $y * $self->room_dimensions->[0]]}");
    }
  }
  my $type = rand() < 0.5 ? "arc" : "diagonal";
  $tiles[$start[0] + $start[1] * $self->room_dimensions->[0]] = ["$type-se"];
  $tiles[$start[0] + $dimensions[0] + $start[1] * $self->room_dimensions->[0] -1] = ["$type-sw"];
  $tiles[$start[0] + ($start[1] + $dimensions[1] - 1) * $self->room_dimensions->[0]] = ["$type-ne"];
  $tiles[$start[0] + $dimensions[0] + ($start[1] + $dimensions[1] - 1) * $self->room_dimensions->[0] - 1] = ["$type-nw"];
  my $x = $start[0] + int($dimensions[0]/2);
  my $y = $start[1] + int($dimensions[1]/2);
  push(@{$tiles[$x + $y * $self->room_dimensions->[0]]}, "\"$num\"");
  return \@tiles;
}

sub generate_pillar_room {
  my $self = shift;
  my $num = shift;
  my @tiles;
  my @dimensions = (3 + int(rand(2)), 3 + int(rand(2)));
  my @start = pairwise { int(rand($b - $a)) } @dimensions, @{$self->room_dimensions};
  # $log->debug("New room starting at (@start) for dimensions (@dimensions)");
  my $type = "|";
  for my $x ($start[0] .. $start[0] + $dimensions[0] - 1) {
    for my $y ($start[1] .. $start[1] + $dimensions[1] - 1) {
      if ($type eq "|" and ($x == $start[0] or $x == $start[0] + $dimensions[0] - 1)
	  or $type eq "-" and ($y == $start[1] or $y == $start[1] + $dimensions[1] - 1)) {
	push(@{$tiles[$x + $y * $self->room_dimensions->[0]]}, "pillar");
      } else {
	push(@{$tiles[$x + $y * $self->room_dimensions->[0]]}, "empty");
	# $log->debug("$x $y @{$tiles[$x + $y * $self->room_dimensions->[0]]}");
      }
    }
  }
  my $x = $start[0] + int($dimensions[0]/2);
  my $y = $start[1] + int($dimensions[1]/2);
  push(@{$tiles[$x + $y * $self->room_dimensions->[0]]}, "\"$num\"");
  return \@tiles;
}

sub one {
  return $_[int(rand(scalar @_))];
}

sub five_room_shape {
  my $self = shift;
  return $self->shape_flip(one(
    # The Nine Forms of the Five Room Dungeon
    # https://gnomestew.com/the-nine-forms-of-the-five-room-dungeon/
    #
    # The Railroad
    #
    #       5        5     4--5         5--4
    #       |        |     |               |
    #       4     3--4     3       5--4    3
    #       |     |        |          |    |
    # 1--2--3  1--2     1--2    1--2--3 1--2
    [[0, 2], [1, 2], [2, 2], [2, 1], [2, 0]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 0]],
    [[0, 2], [1, 2], [1, 1], [1, 0], [2, 0]],
    [[0, 2], [1, 2], [2, 2], [2, 1], [1, 1]],
    [[0, 2], [1, 2], [1, 1], [1, 0], [0, 0]],
    #
    # Note how whenever there is a non-linear connection, there is a an extra
    # element pointing to the "parent". This is necessary for all but the
    # railroads.
    #
    # Foglio's Snail
    #
    #    5  4
    #    |  |
    # 1--2--3
    [[0, 2], [1, 2], [2, 2], [2, 1], [1, 1, 1]],
    #
    # The Fauchard Fork
    #
    #    5       5
    #    |       |
    #    3--4 4--3 5--3--4
    #    |       |    |
    # 1--2    1--2 1--2
    [[0, 2], [1, 2], [1, 1], [2, 1], [1, 0, 2]],
    [[0, 2], [1, 2], [1, 1], [0, 1], [1, 0, 2]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [0, 1, 2]],
    #
    # The Moose
    #
    #            4
    #            |
    # 5     4 5  3
    # |     | |  |
    # 1--2--3 1--2
    [[0, 2], [1, 2], [2, 2], [2, 1], [0, 1, 0]],
    [[0, 2], [1, 2], [1, 1], [1, 0], [0, 1, 0]],
    #
    # The Paw
    #
    #    5
    #    |
    # 3--2--4
    #    |
    #    1
    [[1, 2], [1, 1], [0, 1], [2, 1, 1], [1, 0, 1]],
    #
    # The Arrow
    #
    #    3
    #    |
    #    2
    #    |
    # 5--1--4
    [[1, 2], [1, 1], [1, 0], [2, 2, 0], [0, 2, 0]],
    #
    # The Cross
    #
    #    5
    #    |
    # 3--1--4
    #    |
    #    2
    [[1, 1], [1, 2], [0, 1, 0], [2, 1, 0], [1, 0, 0]],
    #
    # The Nose Ring
    #
    #    5--4  2--3--4
    #    |  |  |  |
    # 1--2--3  1--5
    [[0, 2], [1, 2], [2, 2], [2, 1], [1, 1, 1, 3]],
    [[0, 2], [0, 1], [1, 1], [2, 1], [1, 2, 0, 2]],
      ));
}

sub seven_room_shape {
  my $self = shift;
  return $self->shape_flip(one(
    #
    # The Snake
    #
    # 7--6--5  7--6--5     4--5 7
    #       |        |     |  | |
    #       4     3--4     3  6 6--5--4
    #       |     |        |  |       |
    # 1--2--3  1--2     1--2  7 1--2--3
    [[0, 2], [1, 2], [2, 2], [2, 1], [2, 0], [1, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 0], [1, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [1, 0], [2, 0], [2, 1], [2, 2]],
    [[0, 2], [1, 2], [2, 2], [2, 1], [1, 1] ,[0, 1], [0, 0]],
    #
    # Note how whenever there is a non-linear connection, there is a an extra
    # element pointing to the "parent". This is necessary for all but the
    # railroads.
    #
    # The Fork
    #
    #    7  5 7     5 7-----5
    #    |  | |     | |     |
    #    6  4 6     4 6     4
    #    |  | |     | |     |
    # 1--2--3 1--2--3 1--2--3
    [[0, 2], [1, 2], [2, 2], [2, 1], [2, 0], [1, 1, 1], [1, 0]],
    [[0, 2], [1, 2], [2, 2], [2, 1], [2, 0], [0, 1, 0], [0, 0]],
    [[0, 2], [1, 2], [2, 2], [2, 1], [2, 0], [0, 1, 0], [0, 0, 5, 4]],
    #
    # The Sidequest
    #
    # 6--5       5--6 7     5 6--5       5--6 7     5
    # |  |       |  | |     | |  |       |  | |     |
    # 7  3--4 4--3  7 6--3--4 7  3--4 4--3  7 6--3--4
    #    |       |       |    |  |    |  |    |  |
    # 1--2    1--2    1--2    1--2    1--2    1--2
    [[0, 2], [1, 2], [1, 1], [2, 1], [1, 0, 2], [0, 0], [0, 1]],
    [[0, 2], [1, 2], [1, 1], [0, 1], [1, 0, 2], [2, 0], [2, 1]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 0], [0, 1, 2], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [1, 0, 2], [0, 0], [0, 1, 5, 0]],
    [[0, 2], [1, 2], [1, 1], [0, 1, 2, 0], [1, 0, 2], [2, 0], [2, 1]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 0], [0, 1, 2, 0], [0, 0]],
    #
    # The Unbalanced Fork
    #
    # 7     5 7  4--5 7     5 7        7  4--5 7     5 7
    # |     | |  |    |     | |        |  |    |     | |
    # 6     4 6  3    6  3--4 6  3--4  6--3    6--3--4 6--3--4
    # |     | |  |    |  |    |  |  |  |  |    |  |    |  |  |
    # 1--2--3 1--2    1--2    1--2  5  1--2    1--2    1--2  5
    [[0, 2], [1, 2], [2, 2], [2, 1], [2, 0], [0, 1, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [1, 0], [2, 0], [0, 1, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 0], [0, 1, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 2], [0, 1, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [1, 0], [2, 0], [0, 1, 2, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 0], [0, 1, 2, 0], [0, 0]],
    [[0, 2], [1, 2], [1, 1], [2, 1], [2, 2], [0, 1, 2, 0], [0, 0]],
    #
    # The Triplet
    #
    # 4  5  7     5  7     5     4--5  7     5  7     5
    # |  |  |     |  |     |     |  |  |     |  |     |
    # 3--2--6  3--2--6  3--2--6  3--2--6  3--2--6  3--2--6
    #    |     |  |     |  |  |     |     |  |     |  |  |
    #    1     4  1     4  1  7     1     4--1     4--1  7
    [[1, 2], [1, 1], [0, 1], [0, 0], [1, 0, 1], [2, 1, 1], [2, 0]],
    [[1, 2], [1, 1], [0, 1], [0, 2], [1, 0, 1], [2, 1, 1], [2, 0]],
    [[1, 2], [1, 1], [0, 1], [0, 2], [1, 0, 1], [2, 1, 1], [2, 2]],
    [[1, 2], [1, 1], [0, 1], [0, 0], [1, 0, 1, 3], [2, 1, 1], [2, 0]],
    [[1, 2], [1, 1], [0, 1], [0, 2, 2, 0], [1, 0, 1], [2, 1, 1], [2, 0]],
    [[1, 2], [1, 1], [0, 1], [0, 2, 2, 0], [1, 0, 1], [2, 1, 1], [2, 2]],
    #
    # The Fake Fork
    #
    # 7  3    7        7  3    7
    # |  |    |        |  |    |
    # 6  2    6  2--3  6--2    6--2--3
    # |  |    |  |     |  |    |  |
    # 5--1--4 5--1--4  5--1--4 5--1--4
    [[1, 2], [1, 1], [1, 0], [2, 2, 0], [0, 2, 0], [0, 1], [0, 0]],
    [[1, 2], [1, 1], [2, 1], [2, 2, 0], [0, 2, 0], [0, 1], [0, 0]],
    [[1, 2], [1, 1], [1, 0], [2, 2, 0], [0, 2, 0], [0, 1, 4, 1], [0, 0]],
    [[1, 2], [1, 1], [2, 1], [2, 2, 0], [0, 2, 0], [0, 1, 4, 1], [0, 0]],
    #
    # The Shuriken
    #
    # 5  6--7  5  6--7  5--6    5--6--7  5--6--7  5--6
    # |  |     |  |     |       |  |     |  |     |
    # 4--1     4--1     4--1--7 4--1     4--1     4--1--7
    #    |        |        |       |        |     |  |
    # 3--2        2--3  3--2    3--2        2--3  3--2
    [[1, 1], [1, 2], [0, 2], [0, 1, 0], [0, 0], [1, 0, 0], [2, 0]],
    [[1, 1], [1, 2], [2, 2], [0, 1, 0], [0, 0], [1, 0, 0], [2, 0]],
    [[1, 1], [1, 2], [0, 2], [0, 1, 0], [0, 0], [1, 0], [2, 1, 0]],
    [[1, 1], [1, 2], [0, 2], [0, 1, 0], [0, 0], [1, 0, 4, 0], [2, 0]],
    [[1, 1], [1, 2], [2, 2], [0, 1, 0], [0, 0], [1, 0, 4, 0], [2, 0]],
    [[1, 1], [1, 2], [0, 2], [0, 1, 2, 0], [0, 0], [1, 0], [2, 1, 0]],
    #
    # The Noose
    #
    #    6--5  3--4     3--4
    #    |  |  |  |     |  |
    #    7  4  2  5     2  5--7
    #    |  |  |  |     |  |
    # 1--2--3  1--6--7  1--6
    [[0, 2], [1, 2], [2, 2], [2, 1], [2, 0], [1, 0], [1, 1, 1, 5]],
    [[0, 2], [0, 1], [0, 0], [1, 0], [1, 1], [1, 2, 0, 4], [2, 2, 5]],
    [[0, 2], [0, 1], [0, 0], [1, 0], [1, 1], [1, 2, 0, 4], [2, 1, 4]],
      ));
}

sub shape_flip {
  my $self = shift;
  my $shape = shift;
  my $r = rand;
  # in case we are debugging
  # $r = 1;
  if ($r < 0.20) {
    # flip vertically
    $shape = [map{ $_->[1] = $self->dungeon_dimensions->[1] - 1 - $_->[1]; $_ } @$shape];
    # $log->debug("flip vertically: " . join(", ", map { "[@$_]"} @$shape));
  } elsif ($r < 0.4) {
    # flip horizontally
    $shape = [map{ $_->[0] = $self->dungeon_dimensions->[0] - 1 - $_->[0]; $_ } @$shape];
    # $log->debug("flip horizontally: " . join(", ", map { "[@$_]"} @$shape));
  } elsif ($r < 0.6) {
    # flip diagonally
    $shape = [map{ my $t = $_->[1]; $_->[1] = $_->[0]; $_->[0] = $t; $_ } @$shape];
    # $log->debug("flip diagonally: " . join(", ", map { "[@$_]"} @$shape));
  } elsif ($r < 0.8) {
    # flip diagonally
    $shape = [map{ $_->[0] = $self->dungeon_dimensions->[0] - 1 - $_->[0];
		   $_->[1] = $self->dungeon_dimensions->[1] - 1 - $_->[1];
		   $_ } @$shape];
    # $log->debug("flip both: " . join(", ", map { "[@$_]"} @$shape));
  }
  return $shape;
}

sub shape_merge {
  my $self = shift;
  my @shapes = @_;
  my $result = [];
  my $cols = POSIX::ceil(sqrt(@shapes));
  my $shift = [0, 0];
  my $rooms = 0;
  for my $shape (@shapes) {
    # $log->debug(join(" ", "Shape", map { "[@$_]" } @$shape));
    my $n = @$shape;
    # $log->debug("Number of rooms for this shape is $n");
    # $log->debug("Increasing coordinates by ($shift->[0], $shift->[1])");
    for my $room (@$shape) {
      $room->[0] += $shift->[0] * $self->dungeon_geomorph_size;
      $room->[1] += $shift->[1] * $self->dungeon_geomorph_size;
      for my $i (2 .. $#$room) {
	# $log->debug("Increasing room reference $i ($room->[$i]) by $rooms");
	$room->[$i] += $rooms;
      }
      push(@$result, $room);
    }
    $self->shape_reconnect($result, $n) if $n < @$result;
    if ($shift->[0] == $cols -1) {
      $shift = [0, $shift->[1] + 1];
    } else {
      $shift = [$shift->[0] + 1, $shift->[1]];
    }
    $rooms += $n;
  }
  # Update globals
  for my $dim (0, 1) {
    $self->dungeon_dimensions->[$dim] = max(map { $_->[$dim] } @$result) + 1;
  }
  # $log->debug("Dimensions of the dungeon are (" . join(", ", map { $self->dungeon_dimensions->[$_] } 0, 1) . ")");
  $self->recompute();
  return $result;
}

sub shape_reconnect {
  my ($self, $result, $n) = @_;
  my $rooms = @$result;
  my $first = $rooms - $n;
  # Disconnect the old room by adding an invalid self-reference to the first
  # room of the last shape added; if there are just two numbers there, it would
  # otherwise mean that the first room of the new shape connects to the last
  # room of the previous shape and that is wrong.
  # $log->debug("First of the shape is @{$result->[$first]}");
  push(@{$result->[$first]}, $first) if @{$result->[$first]} == 2;
  # New connections can be either up or left, therefore only the rooms within
  # this shape that are at the left or the upper edge need to be considered.
  my @up_candidates;
  my @left_candidates;
  my $min_up;
  my $min_left;
  for my $start ($first .. $rooms - 1) {
    my $x = $result->[$start]->[0];
    my $y = $result->[$start]->[1];
    # Check up: if we find a room in our set, this room is disqualified; if we
    # find another room, record the distance, and the destination.
    for my $end (0 .. $first - 1) {
      next if $start == $end;
      next if $result->[$end]->[0] != $x;
      my $d = $y - $result->[$end]->[1];
      next if $min_up and $d > $min_up;
      if (not $min_up or $d < $min_up) {
	# $log->debug("$d for $start → $end is smaller than $min_up: ") if defined $min_up;
	$min_up = $d;
	@up_candidates = ([$start, $end]);
      } else {
	# $log->debug("$d for $start → $end is the same as $min_up");
	push(@up_candidates, [$start, $end]);
      }
    }
    # Check left: if we find a room in our set, this room is disqualified; if we
    # find another room, record the distance, and the destination.
    for my $end (0 .. $first - 1) {
      next if $start == $end;
      next if $result->[$end]->[1] != $y;
      my $d = $x - $result->[$end]->[0];
      next if $min_left and $d > $min_left;
      if (not $min_left or $d < $min_left) {
	$min_left = $d;
	@left_candidates = ([$start, $end]);
      } else {
	push(@left_candidates, [$start, $end]);
      }
    }
  }
  # $log->debug("up candidates: " . join(", ", map { join(" → ", map { $_ < 10 ? $_ : chr(55 + $_) } @$_) } @up_candidates));
  # $log->debug("left candidates: " . join(", ", map { join(" → ", map { $_ < 10 ? $_ : chr(55 + $_) } @$_) } @left_candidates));
  for (one(@up_candidates), one(@left_candidates)) {
    next unless $_;
    # $log->debug("Connecting " . join(" → ", map { $_ < 10 ? $_ : chr(55 + $_) } @$_));
    my ($start, $end) = @$_;
    if (@{$result->[$start]} == 3 and $result->[$start]->[2] == $start) {
      # remove the fake connection if there is one
      pop(@{$result->[$start]});
    } else {
      # connecting to the previous room (otherwise the new connection replaces
      # the implicit connection to the previous room)
      push(@{$result->[$start]}, $start - 1);
    }
    # connect to the new one
    push(@{$result->[$start]}, $end);
  }
}

sub debug_shapes {
  my $self = shift;
  my $shapes = shift;
  my $map = [map { [ map { " " } 0 .. $self->dungeon_dimensions->[0] - 1] } 0 .. $self->dungeon_dimensions->[1] - 1];
  $log->debug(join(" ", " ", 0 .. $self->dungeon_dimensions->[0] - 1));
  for my $n (0 .. $#$shapes) {
    my $shape = $shapes->[$n];
    $map->[ $shape->[1] ]->[ $shape->[0] ] = $n < 10 ? $n : chr(55 + $n);
  }
  for my $y (0 .. $self->dungeon_dimensions->[1] - 1) {
    $log->debug(join(" ", "$y", @{$map->[$y]}));
  }
}

sub shape {
  my $self = shift;
  # note which rooms get stairs (identified by label!)
  my $stairs;
  # return an array of deltas to shift rooms around
  my $num = shift;
  my $shape = [];
  # attempt to factor into 5 and 7 rooms
  my $sevens = int($num/7);
  my $rest = $num - 7 * $sevens; # $num % 7
  while ($sevens > 0 and $rest % 5) {
    $sevens--;
    $rest = $num - 7 * $sevens;
  }
  my $fives = int($rest/5);
  my @sequence = shuffle((5) x $fives, (7) x $sevens);
  @sequence = (5) unless @sequence;
  $shape = $self->shape_merge(map { $_ == 5 ? $self->five_room_shape() : $self->seven_room_shape() } @sequence);
  for (my $n = 0; @sequence; $n += shift(@sequence)) {
    push(@$stairs, $n + 1);
  }
  $log->debug(join(" ", "Stairs", @$stairs));
  if (@$stairs > 2) {
    @$stairs = shuffle(@$stairs);
    my $n = POSIX::floor(log($#$stairs));
    @$stairs = @$stairs[0 .. $n];
  }
  $self->debug_shapes($shape) if $log->level eq 'debug';
  $log->debug(join(", ", map { "[@$_]"} @$shape));
  die("No appropriate dungeon shape found for $num rooms") unless @$shape;
  return $shape, $stairs;
}

sub debug_tiles {
  my $self = shift;
  my $tiles = shift;
  my $i = 0;
  $log->debug(
    join('', " " x 5,
	 map {
	   sprintf("% " . $self->room_dimensions->[0] . "d", $_ * $self->room_dimensions->[0])
	 } 1 .. $self->dungeon_dimensions->[0]));
  while ($i < @$tiles) {
    $log->debug(
      sprintf("%4d ", $i)
      . join('', map { $_ ? "X" : " " } @$tiles[$i .. $i + $self->row - 1]));
    $i += $self->row;
  }
}

sub add_rooms {
  my $self = shift;
  # Get the rooms and the deltas, draw it all on a big grid. Don't forget the
  # two-tile border around it all.
  my $rooms = shift;
  my $deltas = shift;
  my @tiles;
  pairwise {
    my $room = $a;
    my $delta = $b;
    # $log->debug("Draw room shifted by delta (@$delta)");
    # copy the room, shifted appropriately
    for my $x (0 .. $self->room_dimensions->[0] - 1) {
      for my $y (0 .. $self->room_dimensions->[0] - 1) {
	# my $v =
	$tiles[$x + $delta->[0] * $self->room_dimensions->[0] + 2
	       + ($y + $delta->[1] * $self->room_dimensions->[1] + 2)
	       * $self->row]
	    = $room->[$x + $y * $self->room_dimensions->[0]];
      }
    }
  } @$rooms, @$deltas;
  # $self->debug_tiles(\@tiles) if $log->level eq 'debug';
  return \@tiles;
}

sub add_corridors {
  my $self = shift;
  my $tiles = shift;
  my $shapes = shift;    # reference to the original
  my @shapes = @$shapes; # a copy that gets shorter
  my $from = shift(@shapes);
  my $delta;
  for my $to (@shapes) {
    if (@$to == 3
	and $to->[0] == $shapes->[$to->[2]]->[0]
	and $to->[1] == $shapes->[$to->[2]]->[1]) {
      # If the preceding shape is pointing to ourselves, then this room is
      # disconnected: don't add a corridor.
      # $log->debug("No corridor from @$from to @$to");
      $from = $to;
    } elsif (@$to == 2) {
      # The default case is that the preceding shape is our parent. A simple
      # railroad!
      # $log->debug("Regular from @$from to @$to");
      $tiles = $self->add_corridor($tiles, $from, $to, $self->get_delta($from, $to));
      $from = $to;
    } else {
      # In case the shapes are not connected in order, the parent shapes are
      # available as extra elements.
      for my $from (map { $shapes->[$_] } @$to[2 .. $#$to]) {
	# $log->debug("Branch from @$from to @$to");
	$tiles = $self->add_corridor($tiles, $from, $to, $self->get_delta($from, $to));
      }
      $from = $to;
    }
  }
  $self->debug_tiles($tiles) if $log->level eq 'debug';
  return $tiles;
}

sub get_delta {
  my $self = shift;
  my $from = shift;
  my $to = shift;
  # Direction: north is minus an entire row, south is plus an entire row, east
  # is plus one, west is minus one. Return an array reference with three
  # elements: how to get the next element and how to get the two elements to the
  # left and right.
  if ($to->[0] < $from->[0]) {
    # $log->debug("west");
    return [-1, - $self->row, $self->row];
  } elsif ($to->[0] > $from->[0]) {
    # $log->debug("east");
    return [1, - $self->row, $self->row];
  } elsif ($to->[1] < $from->[1]) {
    # $log->debug("north");
    return [- $self->row, 1, -1];
  } elsif ($to->[1] > $from->[1]) {
    # $log->debug("south");
    return [$self->row, 1, -1];
  } else {
    $log->warn("unclear direction: bogus shape?");
  }
}

sub position_in {
  my $self = shift;
  # Return a position in the big array corresponding to the midpoint in a room.
  # Don't forget the two-tile border.
  my $delta = shift;
  my $x = int($self->room_dimensions->[0]/2) + 2;
  my $y = int($self->room_dimensions->[1]/2) + 2;
  return $x + $delta->[0] * $self->room_dimensions->[0]
      + ($y + $delta->[1] * $self->room_dimensions->[1]) * $self->row;
}

sub add_corridor {
  my $self = shift;
  # In the example below, we're going east from F to T. In order to make sure
  # that we also connect rooms in (0,0)-(1,1), we start one step earlier (1,2)
  # and end one step later (8,2).
  #
  #  0123456789
  # 0
  # 1
  # 2  F    T
  # 3
  # 4
  my $tiles = shift;
  my $from = shift;
  my $to = shift;
  # $log->debug("Drawing a corridor [@$from]-[@$to]");
  # Delta has three elements: forward, left and right indexes.
  my $delta = shift;
  # Convert $from and $to to indexes into the tiles array.
  $from = $self->position_in($from) - 2 * $delta->[0];
  $to = $self->position_in($to) + 2 * $delta->[0];
  my $n = 0;
  my $contact = 0;
  my $started = 0;
  my @undo;
  # $log->debug("Drawing a corridor $from-$to");
  while (not grep { $to == ($from + $_) } @$delta) {
    $from += $delta->[0];
    # contact is if we're on a room, or to the left or right of a room (but not in front of a room)
    $contact = any { $self->something($tiles, $from, $_) } 0, $delta->[1], $delta->[2];
    if ($contact) {
      $started = 1;
      @undo = ();
    } else {
      push(@undo, $from);
    }
    $tiles->[$from] = ["empty"] if $started and not $tiles->[$from];
    last if $n++ > 20; # safety!
  }
  for (@undo) {
    $tiles->[$_] = undef;
  }
  return $tiles;
}

sub add_doors {
  my $self = shift;
  my $tiles = shift;
  # Doors can be any tile that has three or four neighbours, including
  # diagonally:
  #
  # ▓▓   ▓▓
  # ▓▓▒▓ ▓▓▒▓
  #      ▓▓
  my @types = qw(door door door door door door secret secret archway concealed);
  # first two neighbours must be clear, the next two must be set, and one of the others must be set as well
  my %test = (n => [-1, 1, -$self->row, $self->row, -$self->row + 1, -$self->row - 1],
	      e => [-$self->row, $self->row, -1, 1, $self->row + 1, -$self->row + 1],
	      s => [-1, 1, -$self->row, $self->row, $self->row + 1, $self->row - 1],
	      w => [-$self->row, $self->row, -1, 1, $self->row - 1, -$self->row - 1]);
  my @doors;
  for my $here (shuffle 1 .. scalar(@$tiles) - 1) {
    for my $dir (shuffle qw(n e s w)) {
      if ($tiles->[$here]
	  and not $self->something($tiles, $here, $test{$dir}->[0])
	  and not $self->something($tiles, $here, $test{$dir}->[1])
	  and $self->something($tiles, $here, $test{$dir}->[2])
	  and $self->something($tiles, $here, $test{$dir}->[3])
	  and ($self->something($tiles, $here, $test{$dir}->[4])
	       or $self->something($tiles, $here, $test{$dir}->[5]))
	  and not $self->doors_nearby($here, \@doors)) {
	$log->warn("$here content isn't 'empty'") unless $tiles->[$here]->[0] eq "empty";
	my $type = one(@types);
	my $variant = $dir;
	my $target = $here;
	# this makes sure doors are on top
	if ($dir eq "s") { $target += $self->row; $variant = "n"; }
	elsif ($dir eq "e") { $target += 1; $variant = "w"; }
	push(@{$tiles->[$target]}, "$type-$variant");
	push(@doors, $here);
      }
    }
  }
  return $tiles;
}

sub doors_nearby {
  my $self = shift;
  my $here = shift;
  my $doors = shift;
  for my $door (@$doors) {
    return 1 if $self->distance($door, $here) < 2;
  }
  return 0;
}

sub distance {
  my $self = shift;
  my $from = shift;
  my $to = shift;
  my $dx = $to % $self->row - $from % $self->row;
  my $dy = int($to/$self->row) - int($from/$self->row);
  return sqrt($dx * $dx + $dy * $dy);
}

sub add_stair {
  my $self = shift;
  my $tiles = shift;
  my $stairs = shift;
 STAIR:
  for my $room (@$stairs) {
    # find the middle using the label
    my $start;
    for my $i (0 .. scalar(@$tiles) - 1) {
      next unless $tiles->[$i];
      $start = $i;
      last if grep { $_ eq qq{"$room"} } @{$tiles->[$i]};
    }
    # The first test refers to a tile that must be set to "empty" (where the stair
    # will end), all others must be undefined. Note that stairs are anchored at
    # the top end, and we're placing a stair that goes *down*. So what we're
    # looking for is the point (4,1) in the image below:
    #
    #   12345
    # 1 EE<<
    # 2 EE
    #
    # Remember, +1 is east, -1 is west, -$row is north, +$row is south. The anchor
    # point we're testing is already known to be undefined.
    my %test = (n => [-2 * $self->row,
		      -$self->row - 1, -$self->row, -$self->row + 1,
		      -1, +1,
		      +$self->row - 1, +$self->row, +$self->row + 1],
		e => [+2,
		      -$self->row + 1, +1, +$self->row + 1,
		      -$self->row, +$self->row,
		      -$self->row - 1, -1, +$self->row - 1]);
    $test{s} = [map { -$_ } @{$test{n}}];
    $test{w} = [map { -$_ } @{$test{e}}];
    # First round: limit ourselves to stair positions close to the start.
    my %candidates;
    for my $here (shuffle 0 .. scalar(@$tiles) - 1) {
      next if $tiles->[$here];
      my $distance = $self->distance($here, $start);
      $candidates{$here} = $distance if $distance <= 4;
    }
    # Second round: for each candidate, test stair placement and record the
    # distance of the landing to the start and the direction of every successful
    # stair.
    my $stair;
    my $stair_dir;
    my $stair_distance = $self->max_tiles;
    for my $here (sort {$a cmp $b} keys %candidates) {
      # push(@{$tiles->[$here]}, "red");
      for my $dir (shuffle qw(n e w s)) {
	my @test = @{$test{$dir}};
	my $first = shift(@test);
	if (# the first test is an empty tile: this the stair's landing
	    $self->empty($tiles, $here, $first)
	    # and the stair is surrounded by empty space
	    and none { $self->something($tiles, $here, $_) } @test) {
	  my $distance = $self->distance($here + $first, $start);
	  if ($distance < $stair_distance) {
	    # $log->debug("Considering stair-$dir for $here ($distance)");
	    $stair = $here;
	    $stair_dir = $dir;
	    $stair_distance = $distance;
	  }
	}
      }
    }
    if (defined $stair) {
      push(@{$tiles->[$stair]}, "stair-$stair_dir");
      next STAIR;
    }
    # $log->debug("Unable to place a regular stair, trying to place a spiral staircase");
    for my $here (shuffle 0 .. scalar(@$tiles) - 1) {
      next unless $tiles->[$here];
      if (# close by
	  $self->distance($here, $start) < 3
	  # and the landing is empty (no statue, doors n or w)
	  and @{$tiles->[$here]} == 1
	  and $tiles->[$here]->[0] eq "empty"
	  # and the landing to the south has no door n
	  and not grep { /-n$/ } @{$tiles->[$here+$self->row]}
	  # and the landing to the east has no door w
	  and not grep { /-w$/ } @{$tiles->[$here+1]}) {
	$log->debug("Placed spiral stair at $here");
	$tiles->[$here]->[0] = "stair-spiral";
	next STAIR;
      }
    }
    $log->warn("Unable to place a stair!");
    next STAIR;
  }
  return $tiles;
}

sub add_small_stair {
  my $self = shift;
  my $tiles = shift;
  my $stairs = shift;
  my %delta = (n => -$self->row, e => 1, s => $self->row, w => -1);
 STAIR:
  for my $room (@$stairs) {
    # find the middle using the label
    my $start;
    for my $i (0 .. scalar(@$tiles) - 1) {
      next unless $tiles->[$i];
      $start = $i;
      last if grep { $_ eq qq{"$room"} } @{$tiles->[$i]};
    }
    for (shuffle qw(n e w s)) {
      if (grep { $_ eq "empty" } @{$tiles->[$start + $delta{$_}]}) {
	push(@{$tiles->[$start + $delta{$_}]}, "stair-spiral");
	next STAIR;
      }
    }
  }
  return $tiles;
}

sub fix_corners {
  my $self = shift;
  my $tiles = shift;
  my %look = (n => -$self->row, e => 1, s => $self->row, w => -1);
  for my $here (0 .. scalar(@$tiles) - 1) {
    for (@{$tiles->[$here]}) {
      if (/^(arc|diagonal)-(ne|nw|se|sw)$/) {
	my $dir = $2;
	# debug_neighbours($tiles, $here);
	if (substr($dir, 0, 1) eq "n" and $here + $self->row < $self->max_tiles and $tiles->[$here + $self->row] and @{$tiles->[$here + $self->row]}
	    or substr($dir, 0, 1) eq "s" and $here > $self->row and $tiles->[$here - $self->row] and @{$tiles->[$here - $self->row]}
	    or substr($dir, 1) eq "e" and $here > 0 and $tiles->[$here - 1] and @{$tiles->[$here - 1]}
	    or substr($dir, 1) eq "w" and $here < $self->max_tiles and $tiles->[$here + 1] and @{$tiles->[$here + 1]}) {
	  $_ = "empty";
	}
      }
    }
  }
  return $tiles;
}

sub fix_pillars {
  my $self = shift;
  my $tiles = shift;
  # This is: $test{n}->[0] is straight ahead (e.g. looking north), $test{n}->[1]
  # is to the left (e.g. looking north-west), $test{n}->[2] is to the right
  # (e.g. looking north-east).
  my %test = (n => [-$self->row, -$self->row - 1, -$self->row + 1],
	      e => [1, 1 - $self->row, 1 + $self->row],
	      s => [$self->row, $self->row - 1, $self->row + 1],
	      w => [-1, -1 - $self->row, -1 + $self->row]);
  for my $here (0 .. scalar(@$tiles) - 1) {
  TILE:
    for (@{$tiles->[$here]}) {
      if ($_ eq "pillar") {
	# $log->debug("$here: $_");
	# debug_neighbours($tiles, $here);
	for my $dir (qw(n e w s)) {
	  if ($self->something($tiles, $here, $test{$dir}->[0])
	      and not $self->something($tiles, $here, $test{$dir}->[1])
	      and not $self->something($tiles, $here, $test{$dir}->[2])) {
	    # $log->debug("Removing pillar $here");
	    $_ = "empty";
	    next TILE;
	  }
	}
      }
    }
  }
  return $tiles;
}

sub to_rocks {
  my $self = shift;
  my $tiles = shift;
  # These are the directions we know (where m is the center). Order is important
  # so that list comparison is made easy.
  my @dirs = qw(n e w s);
  my %delta = (n => -$self->row, e => 1, s => $self->row, w => -1);
  # these are all the various rock configurations we know about; listed are the
  # fields that must be "empty" for this to work
  my %rocks = ("rock-n" => [qw(e w s)],
	       "rock-ne" => [qw(w s)],
	       "rock-ne-alternative" => [qw(w s)],
	       "rock-e" => [qw(n w s)],
	       "rock-se" => [qw(n w)],
	       "rock-se-alternative" => [qw(n w)],
	       "rock-s" => [qw(n e w)],
	       "rock-sw" => [qw(n e)],
	       "rock-sw-alternative" => [qw(n e)],
	       "rock-w" => [qw(n e s)],
	       "rock-nw" => [qw(e s)],
	       "rock-nw-alternative" => [qw(e s)],
	       "rock-dead-end-n" => [qw(s)],
	       "rock-dead-end-e" => [qw(w)],
	       "rock-dead-end-s" => [qw(n)],
	       "rock-dead-end-w" => [qw(e)],
	       "rock-corridor-n" => [qw(n s)],
	       "rock-corridor-s" => [qw(n s)],
	       "rock-corridor-e" => [qw(e w)],
	       "rock-corridor-w" => [qw(e w)], );
  # my $first = 1;
  for my $here (0 .. scalar(@$tiles) - 1) {
  TILE:
    for (@{$tiles->[$here]}) {
      next unless grep { $_ eq "empty" } @{$tiles->[$here]};
      if (not $_) {
	$_ = "rock" if all { grep { $_ } $self->something($tiles, $here, $_) } qw(n e w s);
      } else {
	# loop through all the rock tiles and compare the patterns
      ROCK:
	for my $rock (keys %rocks) {
	  my $expected = $rocks{$rock};
	  my @actual = grep {
	    my $dir = $_;
	     $self->something($tiles, $here, $delta{$dir});
	  } @dirs;
	  if (list_equal($expected, \@actual)) {
	    $_ = $rock;
	    # $_ = $first ? "pillar" : $rock; $first = 0;
	    $log->warn("(" . $self->coordinates($here) . ") $_: @$expected vs @actual");
	    next TILE;
	  }
        }
      }
    }
  }
  return $tiles;
}

sub list_equal {
  my $a1 = shift;
  my $a2 = shift;
  return 0 if @$a1 ne @$a2;
  for (my $i = 0; $i <= $#$a1; $i++) {
    return unless $a1->[$i] eq $a2->[$i];
  }
  return 1;
}

sub coordinates {
  my $self = shift;
  my $here = shift;
  return sprintf("%d,%d", int($here/$self->row), $here % $self->row);
}

sub legal {
  my $self = shift;
  # is this position on the map?
  my $here = shift;
  my $delta = shift;
  return if $here + $delta < 0 or $here + $delta > $self->max_tiles;
  return if $here % $self->row == 0 and $delta == -1;
  return if $here % $self->row == $self->row and $delta == 1;
  return 1;
}

sub something {
  my $self = shift;
  # Is there something at this legal position? Off the map means there is
  # nothing at the position.
  my $tiles = shift;
  my $here = shift;
  my $delta = shift;
  return if not $self->legal($here, $delta);
  return @{$tiles->[$here + $delta]} if $tiles->[$here + $delta];
}

sub empty {
  my $self = shift;
  # Is this position legal and empty? We're looking for the "empty" tile!
  my $tiles = shift;
  my $here = shift;
  my $delta = shift;
  return if not $self->legal($here, $delta);
  return grep { $_ eq "empty" } @{$tiles->[$here + $delta]};
}

sub debug_neighbours {
  my $self = shift;
  my $tiles = shift;
  my $here = shift;
  my @n;
  if ($here > $self->row and $tiles->[$here - $self->row] and @{$tiles->[$here - $self->row]}) {
    push(@n, "n: @{$tiles->[$here - $self->row]}");
  }
  if ($here + $self->row <= $self->max_tiles and $tiles->[$here + $self->row] and @{$tiles->[$here + $self->row]}) {
    push(@n, "s: @{$tiles->[$here + $self->row]}");
  }
  if ($here > 0 and $tiles->[$here - 1] and @{$tiles->[$here - 1]}) {
    push(@n, "w: @{$tiles->[$here - 1]}");
  }
  if ($here < $self->max_tiles and $tiles->[$here + 1] and @{$tiles->[$here + 1]}) {
    push(@n, "e: @{$tiles->[$here + 1]}");
  }
  $log->debug("Neighbours of $here: @n");
  for (-$self->row-1, -$self->row, -$self->row+1, -1, +1, $self->row-1, $self->row, $self->row+1) {
    eval { $log->debug("Neighbours of $here+$_: @{$tiles->[$here + $_]}") };
  }
}

sub to_text {
  my $self = shift;
  # Don't forget the border of two tiles.
  my $tiles = shift;
  my $text = "include $contrib/gridmapper.txt\n";
  for my $x (0 .. $self->row - 1) {
    for my $y (0 .. $self->col - 1) {
      my $tile = $tiles->[$x + $y * $self->row];
      if ($tile) {
	$text .= sprintf("%02d%02d @$tile\n", $x + 1, $y + 1);
      }
    }
  }
  # The following is matched in /gridmapper/random!
  my $url = $self->to_gridmapper_link($tiles);
  $text .= qq{other <text x="-20em" y="0" font-size="40pt" transform="rotate(-90)" style="stroke:blue">}
  . qq{<a xlink:href="$url">Edit in Gridmapper</a></text>\n};
  $text .= "# Gridmapper link: $url\n";
  return $text;
}

sub to_gridmapper_link {
  my $self = shift;
  my $tiles = shift;
  my $code;
  my $pen = 'up';
  for my $y (0 .. $self->col - 1) {
    for my $x (0 .. $self->row - 1) {
      my $tile = $tiles->[$x + $y * $self->row];
      if (not $tile or @$tile == 0) {
	my $next = $tiles->[$x + $y * $self->row + 1];
	if ($pen eq 'down' and $next and @$next) {
	  $code .= ' ';
	} else {
	  $pen = 'up';
	}
	next;
      }
      if ($pen eq 'up') {
	$code .= "($x,$y)";
	$pen = 'down';
      }
      my $finally = " ";
      # $log->debug("[$x,$y] @$tile");
      for (@$tile) {
	if ($_ eq "empty") { $finally = "f" }
	elsif ($_ eq "pillar") { $code .= "p" }
	elsif (/^"(\d+)"$/) { $code .= $1 }
	elsif ($_ eq "arc-se") { $code .= "a" }
	elsif ($_ eq "arc-sw") { $code .= "aa" }
	elsif ($_ eq "arc-nw") { $code .= "aaa" }
	elsif ($_ eq "arc-ne") { $code .= "aaaa" }
	elsif ($_ eq "diagonal-se") { $code .= "n" }
	elsif ($_ eq "diagonal-sw") { $code .= "nn" }
	elsif ($_ eq "diagonal-nw") { $code .= "nnn" }
	elsif ($_ eq "diagonal-ne") { $code .= "nnnn" }
	elsif ($_ eq "door-w") { $code .= "d" }
	elsif ($_ eq "door-n") { $code .= "dd" }
	elsif ($_ eq "door-e") { $code .= "ddd" }
	elsif ($_ eq "door-s") { $code .= "dddd" }
	elsif ($_ eq "secret-w") { $code .= "dv" }
	elsif ($_ eq "secret-n") { $code .= "ddv" }
	elsif ($_ eq "secret-e") { $code .= "dddv" }
	elsif ($_ eq "secret-s") { $code .= "ddddv" }
	elsif ($_ eq "concealed-w") { $code .= "dvv" }
	elsif ($_ eq "concealed-n") { $code .= "ddvv" }
	elsif ($_ eq "concealed-e") { $code .= "dddvv" }
	elsif ($_ eq "concealed-s") { $code .= "ddddvv" }
	elsif ($_ eq "archway-w") { $code .= "dvvvv" }
	elsif ($_ eq "archway-n") { $code .= "ddvvvv" }
	elsif ($_ eq "archway-e") { $code .= "dddvvvv" }
	elsif ($_ eq "archway-s") { $code .= "ddddvvvv" }
	elsif ($_ eq "stair-s") { $code .= "s" }
	elsif ($_ eq "stair-w") { $code .= "ss" }
	elsif ($_ eq "stair-n") { $code .= "sss" }
	elsif ($_ eq "stair-e") { $code .= "ssss" }
	elsif ($_ eq "stair-spiral") { $code .= "svv" }
	elsif ($_ eq "rock") { $finally = "g" }
	elsif ($_ eq "rock-n") { $finally = "g" }
	elsif ($_ eq "rock-ne") { $finally = "g" }
	elsif ($_ eq "rock-ne-alternative") { $finally = "g" }
	elsif ($_ eq "rock-e") { $finally = "g" }
	elsif ($_ eq "rock-se") { $finally = "g" }
	elsif ($_ eq "rock-se-alternative") { $finally = "g" }
	elsif ($_ eq "rock-s") { $finally = "g" }
	elsif ($_ eq "rock-sw") { $finally = "g" }
	elsif ($_ eq "rock-sw-alternative") { $finally = "g" }
	elsif ($_ eq "rock-w") { $finally = "g" }
	elsif ($_ eq "rock-nw") { $finally = "g" }
	elsif ($_ eq "rock-nw-alternative") { $finally = "g" }
	elsif ($_ eq "rock-dead-end-n") { $finally = "g" }
	elsif ($_ eq "rock-dead-end-e") { $finally = "g" }
	elsif ($_ eq "rock-dead-end-s") { $finally = "g" }
	elsif ($_ eq "rock-dead-end-w") { $finally = "g" }
	elsif ($_ eq "rock-corridor-n") { $finally = "g" }
	elsif ($_ eq "rock-corridor-s") { $finally = "g" }
	elsif ($_ eq "rock-corridor-e") { $finally = "g" }
	elsif ($_ eq "rock-corridor-w") { $finally = "g" }
	else {
	  $log->warn("Tile $_ not known for Gridmapper link");
	}
      }
      $code .= $finally;
    }
    $pen = 'up';
  }
  $log->debug("Gridmapper: $code");
  my $url = 'https://campaignwiki.org/gridmapper?' . uri_escape($code);
  $log->debug($url);
  return $url;
}

package Apocalypse;

use Modern::Perl '2018';
use List::Util qw(shuffle any none);
use Mojo::Base -base;

has 'rows' => 10;
has 'cols' => 20;
has 'region_size' => 5;
has 'settlement_chance' => 0.1;

my @tiles = qw(forest desert mountain jungle swamp grass);
my @settlements = qw(ruin fort cave);

sub generate_map {
  my $self = shift;
  my @coordinates = shuffle(0 .. $self->rows * $self->cols - 1);
  my $seeds = $self->rows * $self->cols / $self->region_size;
  my $tiles = [];
  $tiles->[$_] = [$tiles[int(rand(@tiles))]] for splice(@coordinates, 0, $seeds);
  $tiles->[$_] = [$self->close_to($_, $tiles)] for @coordinates;
  # warn "$_\n" for $self->neighbours(0);
  # push(@{$tiles->[$_]}, "red") for map { $self->neighbours($_) } 70, 75;
  # push(@{$tiles->[$_]}, "red") for map { $self->neighbours($_) } 3, 8, 60, 120;
  # push(@{$tiles->[$_]}, "red") for map { $self->neighbours($_) } 187, 194, 39, 139;
  # push(@{$tiles->[$_]}, "red") for map { $self->neighbours($_) } 0, 19, 180, 199;
  # push(@{$tiles->[$_]}, "red") for map { $self->neighbours($_) } 161;
  for my $tile (@$tiles) {
    push(@$tile, $settlements[int(rand(@settlements))]) if rand() < $self->settlement_chance;
  }
  my $rivers = $self->rivers($tiles);
  return $self->to_text($tiles, $rivers);
}

sub neighbours {
  my $self = shift;
  my $coordinate = shift;
  my @offsets;
  if ($coordinate % 2) {
    @offsets = (-1, +1, $self->cols, -$self->cols, $self->cols -1, $self->cols +1);
    $offsets[3] = undef if $coordinate < $self->cols; # top edge
    $offsets[2] = $offsets[4] = $offsets[5] = undef if $coordinate >= ($self->rows - 1) * $self->cols; # bottom edge
    $offsets[0] = $offsets[4] = undef if $coordinate % $self->cols == 0; # left edge
    $offsets[1] = $offsets[5] = undef if $coordinate % $self->cols == $self->cols - 1; # right edge
  } else {
    @offsets = (-1, +1, $self->cols, -$self->cols, -$self->cols -1, -$self->cols +1);
    $offsets[3] = $offsets[4] = $offsets[5] = undef if $coordinate < $self->cols; # top edge
    $offsets[2] = undef if $coordinate >= ($self->rows - 1) * $self->cols; # bottom edge
    $offsets[0] = $offsets[4] = undef if $coordinate % $self->cols == 0; # left edge
    $offsets[1] = $offsets[5] = undef if $coordinate % $self->cols == $self->cols - 1; # right edge
  }
  # die "@offsets" if any { $coordinate + $_ < 0 or $coordinate + $_ >= $self->cols * $self->rows } @offsets;
  return map { $coordinate + $_ } shuffle grep {$_} @offsets;
}

sub close_to {
  my $self = shift;
  my $coordinate = shift;
  my $tiles = shift;
  for ($self->neighbours($coordinate)) {
    return $tiles->[$_]->[0] if $tiles->[$_];
  }
  return $tiles[int(rand(@tiles))];
}

sub rivers {
  my $self = shift;
  my $tiles = shift;
  # the array of rivers has a cell for each coordinate: if there are no rivers,
  # it is undef; else it is a reference to the river
  my $rivers = [];
  for my $source (grep { $self->is_source($_, $tiles) } 0 .. $self->rows * $self->cols - 1) {
    $log->debug("River starting at " . $self->xy($source) . " (@{$tiles->[$source]})");
    my $river = [$source];
    $self->grow_river($source, $river, $rivers, $tiles);
  }
  return $rivers;
}

sub grow_river {
  my $self = shift;
  my $coordinate = shift;
  my $river = shift;
  my $rivers = shift;
  my $tiles = shift;
  my @destinations = shuffle grep { $self->is_destination($_, $river, $rivers, $tiles) } $self->neighbours($coordinate);
  return unless @destinations; # this is a dead end
  for my $next (@destinations) {
    push(@$river, $next);
    $log->debug(" " . $self->xy($river));
    if ($rivers->[$next]) {
      $log->warn(" merge!");
      my @other = @{$rivers->[$next]};
      while ($other[0] != $next) { shift @other };
      shift @other; # get rid of the duplicate $next
      push(@$river, @other);
      return $self->mark_river($river, $rivers);
    } elsif ($self->is_sink($next, $tiles)) {
      $log->debug("  done!");
      return $self->mark_river($river, $rivers);
    } else {
      my $result = $self->grow_river($next, $river, $rivers, $tiles);
      return $result if $result;
      $log->debug("  dead end!");
      $rivers->[$next] = 0; # prevents this from being a destination
      pop(@$river);
    }
  }
  return; # all destinations were dead ends
}

sub mark_river {
  my $self = shift;
  my $river = shift;
  my $rivers = shift;
  for my $coordinate (@$river) {
    $rivers->[$coordinate] = $river;
  }
  return $river;
}

sub is_source {
  my $self = shift;
  my $coordinate = shift;
  my $tiles = shift;
  return any { $_ eq 'mountain' } (@{$tiles->[$coordinate]});
}

sub is_destination {
  my $self = shift;
  my $coordinate = shift;
  my $river = shift;
  my $rivers = shift;
  my $tiles = shift;
  return 0 if defined $rivers->[$coordinate] and $rivers->[$coordinate] == 0;
  return 0 if grep { $_ == $coordinate } @$river;
  return none { $_ eq 'mountain' or $_ eq 'desert' } (@{$tiles->[$coordinate]});
}

sub is_sink {
  my $self = shift;
  my $coordinate = shift;
  my $tiles = shift;
  return any { $_ eq 'swamp' } (@{$tiles->[$coordinate]});
}

sub to_text {
  my $self = shift;
  my $tiles = shift;
  my $rivers = shift;
  my $text = "";
  for my $i (0 .. $self->rows * $self->cols - 1) {
    $text .= $self->xy($i) . " @{$tiles->[$i]}\n" if $tiles->[$i];
  }
  for my $river (@$rivers) {
    $text .= $self->xy($river) . " river\n" if ref($river) and @$river > 1;
  }
  $text .= "\ninclude $contrib/apocalypse.txt\n";
  return $text;
}

sub xy {
  my $self = shift;
  return join("-", map { sprintf("%02d%02d", $_ % $self->cols + 1, int($_ / $self->cols) + 1) } @_) if @_ > 1;
  return sprintf("%02d%02d", $_[0] % $self->cols + 1, int($_[0] / $self->cols) + 1) unless ref($_[0]);
  return join("-", map { sprintf("%02d%02d", $_ % $self->cols + 1, int($_ / $self->cols) + 1) } @{$_[0]});
}

package Traveller;

use Modern::Perl '2018';
use List::Util qw(shuffle max any);
use Mojo::Base -base;

has 'rows' => 10;
has 'cols' => 8;
has 'digraphs';

sub generate_map {
  my $self = shift;
  $self->digraphs($self->compute_digraphs);
  # coordinates are an index into the system array
  my @coordinates = (0 .. $self->rows * $self->cols - 1);
  my @randomized =  shuffle(@coordinates);
  # %systems maps coordinates to arrays of tiles
  my %systems = map { $_ => $self->system() } grep { roll1d6() > 3 } @randomized; # density
  my $comms = $self->comms(\%systems);
  my $tiles = [map { $systems{$_} || ["empty"] } (@coordinates)];
  return $self->to_text($tiles, $comms);
}

# Each system is an array of tiles, e.g. ["size-1", "population-3", ...]
sub system {
  my $self = shift;
  my $size = roll2d6() - 2;
  my $atmosphere = max(0, roll2d6() - 7 + $size);
  $atmosphere = 0 if $size == 0;
  my $hydro = roll2d6() - 7 + $atmosphere;
  $hydro -= 4 if $atmosphere < 2 or $atmosphere >= 10;
  $hydro = 0 if $hydro < 0 or $size < 2;
  $hydro = 10 if $hydro > 10;
  my $population = roll2d6() - 2;
  my $government = max(0, roll2d6() - 7 + $population);
  my $law = max(0, roll2d6() - 7 + $government);
  my $starport = roll2d6();
  my $naval_base = 0;
  my $scout_base = 0;
  my $research_base = 0;
  my $pirate_base = 0;
  my $tech = roll1d6();
  if ($starport <= 4) {
    $starport = "A";
    $tech += 6;
    $scout_base = 1 if roll2d6() >= 10;
    $naval_base = 1 if roll2d6() >= 8;
    $research_base = 1 if roll2d6() >= 8;
  } elsif ($starport <= 6)  {
    $starport = "B";
    $tech += 4;
    $scout_base = 1 if roll2d6() >=  9;
    $naval_base = 1 if roll2d6() >= 8;
    $research_base = 1 if roll2d6() >= 10;
  } elsif ($starport <= 8)  {
    $starport = "C";
    $tech += 2;
    $scout_base = 1 if roll2d6() >=  8;
    $research_base = 1 if roll2d6() >= 10;
    $pirate_base = 1 if roll2d6() >= 12;
  } elsif ($starport <= 9)  {
    $starport = "D";
    $scout_base = 1 if roll2d6() >=  7;
    $pirate_base = 1 if roll2d6() >= 10;
  } elsif ($starport <= 11) {
    $starport = "E";
    $pirate_base = 1 if roll2d6() >= 10;
  } else {
    $starport = "X";
    $tech -= 4;
  }
  $tech += 1 if $size <= 4;
  $tech += 1 if $size <= 1; # +2 total
  $tech += 1 if $atmosphere <= 3 or $atmosphere >= 10;
  $tech += 1 if $hydro >= 9;
  $tech += 1 if $hydro >= 10; # +2 total
  $tech += 1 if $population >= 1 and $population <= 5;
  $tech += 2 if $population >= 9;
  $tech += 2 if $population >= 10; # +4 total
  $tech += 1 if $government == 0 or $government == 5;
  $tech -= 2 if $government == 13; # D
  $tech = 0 if $tech < 0;
  my $gas_giant = roll1d6() <= 9;
  my $name = $self->compute_name();
  $name = uc($name) if $population >= 9;
  my $uwp = join("", $starport, map { code($_) } $size, $atmosphere, $hydro, $population, $law, $government) . "-" . code($tech);
  # these things determine the order in which text is generated by Hex Describe
  my @tiles;
  push(@tiles, "gas") if $gas_giant;
  push(@tiles, "size-" . code($size));
  push(@tiles, "asteroid")
      if $size == 0;
  push(@tiles, "atmosphere-" . code($atmosphere));
  push(@tiles, "vacuum")
      if $atmosphere == 0;
  push(@tiles, "hydrosphere-" . code($hydro));
  push(@tiles, "water")
      if $hydro eq "A";
  push(@tiles, "desert")
      if $atmosphere >= 2
      and $hydro == 0;
  push(@tiles, "ice")
      if $hydro >= 1
      and $atmosphere <= 1;
  push(@tiles, "fluid")
      if $hydro >= 1
      and $atmosphere >= 10;
  push(@tiles, "population-" . code($population));
  push(@tiles, "barren")
      if $population eq 0
      and $law eq 0
      and $government eq 0;
  push(@tiles, "low")
      if $population >= 1 and $population <= 3;
  push(@tiles, "high")
      if $population >= 9;
  push(@tiles, "agriculture")
      if $atmosphere >= 4 and $atmosphere <= 9
      and $hydro >= 4 and $hydro <= 8
      and $population >= 5 and $population <= 7;
  push(@tiles, "non-agriculture")
      if $atmosphere <= 3
      and $hydro <= 3
      and $population >= 6;
  push(@tiles, "industrial")
      if any { $atmosphere == $_ } 0, 1, 2, 4, 7, 9
      and $population >= 9;
  push(@tiles, "non-industrial")
      if $population <= 6;
  push(@tiles, "rich")
      if $government >= 4 and $government <= 9
      and ($atmosphere == 6 or $atmosphere == 8)
      and $population >= 6 and $population <= 8;
  push(@tiles, "poor")
      if $atmosphere >= 2 and $atmosphere <= 5
      and $hydro <= 3;
  push(@tiles, "tech-" . code($tech));
  push(@tiles, "government-" . code($government));
  push(@tiles, "starport-$starport");
  push(@tiles, "law-" . code($law));
  push(@tiles, "naval") if $naval_base;
  push(@tiles, "scout") if $scout_base;
  push(@tiles, "research") if $research_base;
  push(@tiles, "pirate", "red") if $pirate_base;
  push(@tiles, "amber")
      if not $pirate_base
      and ($atmosphere >= 10
	   or $population and $government == 0
	   or $population and $law == 0
	   or $government == 7
	   or $government == 10
	   or $law >= 9);
  # last is the name
  push(@tiles, qq{name="$name"}, qq{uwp="$uwp"});
  return \@tiles;
}

sub code {
  my $code = shift;
  return $code if $code <= 9;
  return chr(55+$code); # 10 is A
}

sub compute_digraphs {
  my @first = qw(b c d f g h j k l m n p q r s t v w x y z
		 b c d f g h j k l m n p q r s t v w x y z .
		 sc ng ch gh ph rh sh th wh zh wr qu
		 st sp tr tw fl dr pr dr);
  # make missing vowel rare
  my @second = qw(a e i o u a e i o u a e i o u .);
  my @d;
  for (1 .. 10+rand(20)) {
    push(@d, one(@first));
    push(@d, one(@second));
  }
  return \@d;
}

sub compute_name {
  my $self = shift;
  my $max = scalar @{$self->digraphs};
  my $length = 3 + rand(3); # length of name before adding one more
  my $name = '';
  while (length($name) < $length) {
    my $i = 2*int(rand($max/2));
    $name .= $self->digraphs->[$i];
    $name .= $self->digraphs->[$i+1];
  }
  $name =~ s/\.//g;
  return ucfirst($name);
}

sub one {
  return $_[int(rand(scalar @_))];
}

sub roll1d6 {
  return 1+int(rand(6));
}

sub roll2d6 {
  return roll1d6() + roll1d6();
}

sub xy {
  my $self = shift;
  my $i = shift;
  my $y = int($i / $self->cols);
  my $x = $i % $self->cols;
  $log->debug("$i ($x, $y)");
  return $x + 1, $y + 1;
}

sub label {
  my ($self, $from, $to, $d, $label) = @_;
  return sprintf("%02d%02d-%02d%02d $label", @$from[0..1], @$to[0..1]);
}

# Communication routes have distance 1–2 and connect navy bases and A-class
# starports.
sub comms {
  my $self = shift;
  my %systems = %{shift()};
  my @coordinates = map { [ $self->xy($_), $systems{$_} ] } keys(%systems);
  my @comms;
  my @trade;
  my @rich_trade;
  while (@coordinates) {
    my $from = shift(@coordinates);
    my ($x1, $y1, $system1) = @$from;
    next if any { /^starport-X$/ } @$system1; # skip systems without starports
    for my $to (@coordinates) {
      my ($x2, $y2, $system2) = @$to;
      next if any { /^starport-X$/ } @$system2; # skip systems without starports
      my $d = $self->distance($x1, $y1, $x2, $y2);
      if ($d <= 2 and match(qr/^(starport-[AB]|naval)$/, qr/^(starport-[AB]|naval)$/, $system1, $system2)) {
	push(@comms, [$from, $to, $d]);
      }
      if ($d <= 2
	  # many of these can be eliminated, but who knows, perhaps one day
	  # directionality will make a difference
	  and (match(qr/^agriculture$/,
		     qr/^(agriculture|astroid|desert|high|industrial|low|non-agriculture|rich)$/,
		     $system1, $system2)
	       or match(qr/^asteroid$/,
			qr/^(asteroid|industrial|non-agriculture|rich|vacuum)$/,
			$system1, $system2)
	       or match(qr/^desert$/,
			qr/^(desert|non-agriculture)$/,
			$system1, $system2)
	       or match(qr/^fluid$/,
			qr/^(fluid|industrial)$/,
			$system1, $system2)
	       or match(qr/^high$/,
			qr/^(high|low|rich)$/,
			$system1, $system2)
	       or match(qr/^ice$/,
			qr/^industrial$/,
			$system1, $system2)
	       or match(qr/^industrial$/,
			qr/^(agriculture|astroid|desert|fluid|high|industrial|non-industrial|poor|rich|vacuum|water)$/,
			$system1, $system2)
	       or match(qr/^low$/,
			qr/^(industrial|rich)$/,
			$system1, $system2)
	       or match(qr/^non-agriculture$/,
			qr/^(asteroid|desert|vacuum)$/,
			$system1, $system2)
	       or match(qr/^non-industrial$/,
			qr/^industrial$/,
			$system1, $system2)
	       or match(qr/^rich$/,
			qr/^(agriculture|desert|high|industrial|non-agriculture|rich)$/,
			$system1, $system2)
	       or match(qr/^vacuum$/,
			qr/^(asteroid|industrial|vacuum)$/,
			$system1, $system2)
	       or match(qr/^water$/,
			qr/^(industrial|rich|water)$/,
			$system1, $system2))) {
	push(@trade, [$from, $to, $d]);
      }
      if ($d <= 3
	  # subsidized liners only
	  and match(qr/^rich$/,
		    qr/^(asteroid|agriculture|desert|high|industrial|non-agriculture|water|rich|low)$/,
		    $system1, $system2)) {
	push(@rich_trade, [$from, $to, $d]);
      }
    }
  }
  @comms = sort map { $self->label(@$_, "communication") } @{$self->minimal_spanning_tree(@comms)};
  @trade = sort map { $self->label(@$_, "trade") } @{$self->minimal_spanning_tree(@trade)};
  @rich_trade = sort map { $self->label(@$_, "rich") } @{$self->minimal_spanning_tree(@rich_trade)};
  return [@rich_trade, @comms, @trade];
}

sub match {
  my ($re1, $re2, $sys1, $sys2) = @_;
  return 1 if any { /$re1/ } @$sys1 and any { /$re2/ } @$sys2;
  return 1 if any { /$re2/ } @$sys1 and any { /$re1/ } @$sys2;
  return 0;
}

sub minimal_spanning_tree {
  # http://en.wikipedia.org/wiki/Kruskal%27s_algorithm
  my $self = shift;
  # Initialize a priority queue Q to contain all edges in G, using the
  # weights as keys.
  my @Q = sort { @{$a}[2] <=> @{$b}[2] } @_;
  # Define a forest T ← Ø; T will ultimately contain the edges of the MST
  my @T;
  # Define an elementary cluster C(v) ← {v}.
  my %C;
  my $id;
  foreach my $edge (@Q) {
    # edge u,v is the minimum weighted route from u to v
    my ($u, $v) = @{$edge};
    # prevent cycles in T; add u,v only if T does not already contain
    # a path between u and v; also silence warnings
    if (not $C{$u} or not $C{$v} or $C{$u} != $C{$v}) {
      # Add edge (v,u) to T.
      push(@T, $edge);
      # Merge C(v) and C(u) into one cluster, that is, union C(v) and C(u).
      if ($C{$u} and $C{$v}) {
	my @group;
	foreach (keys %C) {
	  push(@group, $_) if $C{$_} == $C{$v};
	}
	$C{$_} = $C{$u} foreach @group;
      } elsif ($C{$v} and not $C{$u}) {
	$C{$u} = $C{$v};
      } elsif ($C{$u} and not $C{$v}) {
	$C{$v} = $C{$u};
      } elsif (not $C{$u} and not $C{$v}) {
	$C{$v} = $C{$u} = ++$id;
      }
    }
  }
  return \@T;
}

sub to_text {
  my $self = shift;
  my $tiles = shift;
  my $comms = shift;
  my $text = "";
  for my $x (0 .. $self->cols - 1) {
    for my $y (0 .. $self->rows - 1) {
      my $tile = $tiles->[$x + $y * $self->cols];
      if ($tile) {
	$text .= sprintf("%02d%02d @$tile\n", $x + 1, $y + 1);
      }
    }
  }
  $text .= join("\n", @$comms, "include $contrib/traveller.txt\n");
  return $text;
}

package Mojolicious::Command::render;

use Modern::Perl '2018';
use Mojo::Base 'Mojolicious::Command';

has description => 'Render map from STDIN';

has usage => <<EOF;
Usage example:
perl text-mapper.pl render < contrib/forgotten-depths.txt > forgotten-depths.svg

This reads a map description from STDIN and prints the resulting SVG map to
STDOUT.
EOF

sub run {
  my ($self, @args) = @_;
  local $/ = undef;
  my $map = new Mapper::Hex;
  $map->initialize(<STDIN>);
  print $map->svg;
}

package Mojolicious::Command::random;

use Modern::Perl '2018';
use Mojo::Base 'Mojolicious::Command';

has description => 'Print a random map to STDOUT';

has usage => <<EOF;
Usage example:
perl text-mapper.pl random > map.txt

This prints a random map description to STDOUT.

You can also pipe this:

perl text-mapper.pl random | perl text-mapper.pl render > map.svg

EOF

sub run {
  my ($self, @args) = @_;
  print Smale::generate_map();
}

package main;

use Modern::Perl '2018';
use Mojolicious::Lite;
use Mojo::DOM;
use Mojo::Util qw(xml_escape);
use Pod::Simple::HTML;
use Pod::Simple::Text;
use List::Util qw(none);

plugin Config => {default => {
  loglevel => 'warn',
  logfile => undef,
  contrib => 'https://campaignwiki.org/contrib', }};

$log = Mojo::Log->new;
$log->level(app->config('loglevel'));
$log->path(app->config('logfile'));

$debug = $log->level eq 'debug';
$contrib = app->config('contrib');

get '/' => sub {
  my $c = shift;
  my $param = $c->param('map');
  if ($param) {
    my $map;
    if ($c->param('type') and $c->param('type') eq 'square') {
      $map = new Mapper::Square;
    } else {
      $map = new Mapper::Hex;
    }
    $map->initialize($param);
    $c->render(text => $map->svg, format => 'svg');
  } else {
    $c->render(template => 'edit', map => Mapper::example());
  }
};

any '/edit' => sub {
  my $c = shift;
  my $map = $c->param('map') || Mapper::example();
  $c->render(map => $map);
};

any '/render' => sub {
  my $c = shift;
  my $map;
  if ($c->param('type') and $c->param('type') eq 'square') {
    $map = new Mapper::Square;
  } else {
    $map = new Mapper::Hex;
  }
  $map->initialize($c->param('map'));
  $c->render(text => $map->svg, format => 'svg');
};

get '/:type/redirect' => sub {
  my $self = shift;
  my $type = $self->param('type');
  my $rooms = $self->param('rooms');
  my $seed = $self->param('seed');
  my $caves = $self->param('caves');
  my %params = ();
  $params{rooms} = $rooms if $rooms;
  $params{seed} = $seed if $seed;
  $params{caves} = $caves if $caves;
  $self->redirect_to($self->url_for($type . "random")->query(%params));
} => 'redirect';

# alias for /smale
get '/random' => sub {
  my $c = shift;
  my $bw = $c->param('bw');
  my $width = $c->param('width');
  my $height = $c->param('height');
  $c->render(template => 'edit', map => Smale::generate_map($bw, $width, $height));
};

get '/smale' => sub {
  my $c = shift;
  my $bw = $c->param('bw');
  my $width = $c->param('width');
  my $height = $c->param('height');
  if ($c->stash('format')||'' eq 'txt') {
    $c->render(text => Smale::generate_map(undef, $width, $height));
  } else {
    $c->render(template => 'edit',
	       map => Smale::generate_map($bw, $width, $height));
  }
};

get '/smale/random' => sub {
  my $c = shift;
  my $bw = $c->param('bw');
  my $width = $c->param('width');
  my $height = $c->param('height');
  my $svg = Mapper::Hex->new()
      ->initialize(Smale::generate_map($bw, $width, $height))
      ->svg();
  $c->render(text => $svg, format => 'svg');
};

get '/smale/random/text' => sub {
  my $c = shift;
  my $bw = $c->param('bw');
  my $width = $c->param('width');
  my $height = $c->param('height');
  my $text = Smale::generate_map($bw, $width, $height);
  $c->render(text => $text, format => 'txt');
};

sub alpine_map {
  my $c = shift;
  # must be able to override this for the documentation
  my $step = shift // $c->param('step');
  # need to compute the seed here so that we can send along the URL
  my $seed = $c->param('seed') || int(rand(1000000000));
  my $url = $c->url_with('alpinedocument')->query({seed => $seed})->to_abs;
  my @params = ($c->param('width'),
		$c->param('height'),
		$c->param('steepness'),
		$c->param('peaks'),
		$c->param('peak'),
		$c->param('bumps'),
		$c->param('bump'),
		$c->param('bottom'),
		$c->param('arid'),
		$seed,
		$url,
		$step,
      );
  my $type = $c->param('type') // 'hex';
  if ($type eq 'hex') {
    return Schroeder::Alpine->with_roles('Schroeder::Hex')->new()->generate_map(@params);
  } else {
    return Schroeder::Alpine->with_roles('Schroeder::Square')->new()->generate_map(@params);
  }
}

get '/alpine' => sub {
  my $c = shift;
  my $map = alpine_map($c);
  if ($c->stash('format') || '' eq 'txt') {
    $c->render(text => $map);
  } else {
    $c->render(template => 'edit', map => $map);
  }
};

get '/alpine/random' => sub {
  my $c = shift;
  my $map = alpine_map($c);
  my $type = $c->param('type') // 'hex';
  my $mapper;
  if ($type eq 'hex') {
    $mapper = Mapper::Hex->new();
  } else {
    $mapper = Mapper::Square->new();
  }
  my $svg = $mapper->initialize($map)->svg;
  $c->render(text => $svg, format => 'svg');
};

get '/alpine/random/text' => sub {
  my $c = shift;
  my $map = alpine_map($c);
  $c->render(text => $map, format => 'txt');
};

get '/alpine/document' => sub {
  my $c = shift;
  # prepare a map for every step
  my @maps;
  my $type = $c->param('type') || 'hex';
  # use the same seed for all the calls
  my $seed = $c->param('seed');
  $seed = $c->param('seed' => int(rand(1000000000))) unless defined $seed;
  for my $step (1 .. 16) {
    my $map = alpine_map($c, $step);
    my $mapper;
    if ($type eq 'hex') {
      $mapper = Mapper::Hex->new();
    } else {
      $mapper = Mapper::Square->new();
    }
    my $svg = $mapper->initialize($map)->svg;
    $svg =~ s/<\?xml version="1.0" encoding="UTF-8" standalone="no"\?>\n//g;
    push(@maps, $svg);
  };
  $c->stash("maps" => \@maps);

  # the documentation needs all the defaults of Alpine::generate_map (but
  # we'd like to use a smaller map because it is so slow)
  my $width = $c->param('width') // 20;
  my $height = $c->param('height') // 5; # instead of 10
  my $steepness = $c->param('steepness') // 3;
  my $peaks = $c->param('peaks') // int($width * $height / 40);
  my $peak = $c->param('peak') // 10;
  my $bumps = $c->param('bumps') // int($width * $height / 40);
  my $bump = $c->param('bump') // 2;
  my $bottom = $c->param('bottom') // 0;
  my $arid = $c->param('arid') // 2;

  $c->render(template => 'alpine_document',
	     seed => $seed,
	     width => $width,
	     height => $height,
	     steepness => $steepness,
	     peaks => $peaks,
	     peak => $peak,
	     bumps => $bumps,
	     bump => $bump,
	     bottom => $bottom,
	     arid => $arid);
};

get '/alpine/parameters' => sub {
  my $c = shift;
  $c->render(template => 'alpine_parameters');
};

sub border_modification {
  my ($map, $top, $left, $right, $bottom, $empty) = @_;
  my (@lines, @temp, %seen);
  my ($x, $y, $points, $text);
  my ($minx, $miny, $maxx, $maxy);
  # shift map around
  foreach (split(/\r?\n/, $map)) {
    if (($x, $y, $text) = /^(\d\d)(\d\d)\s+(.*)/) {
      $minx = $x if not defined $minx or $x < $minx;
      $miny = $y if not defined $miny or $y < $miny;
      $maxx = $x if not defined $maxx or $x > $maxx;
      $maxy = $y if not defined $maxy or $y > $maxy;
      my $point = Point->new(x => $x + $left, y => $y + $top);
      $seen{$point->coordinates} = 1 if $empty;
      push(@lines, [$point, $text]);
    } elsif (($points, $text) = /^(-?\d\d-?\d\d(?:--?\d\d-?\d\d)+)\s+(.*)/) {
      my @numbers = $points =~ /\G(-?\d\d)(-?\d\d)-?/cg;
      my @points;
      while (@numbers) {
	my ($x, $y) = splice(@numbers, 0, 2);
	push(@points, Point->new(x => $x + $left, y => $y + $top));
      }
      push(@lines, [Line->new(points => \@points), $text]);
    } else {
      push(@lines, $_);
    }
  }
  # only now do we know the extent of the map
  $maxx += $left + $right;
  $maxy += $top + $bottom;
  # with that information we can now determine what lies outside the map
  @temp = ();
  foreach (@lines) {
    if (ref) {
      my ($it, $text) = @$_;
      if (ref($it) eq 'Point') {
	if ($it->x <= $maxx and $it->x >= $minx
	    and $it->y <= $maxy and $it->y >= $miny) {
	  push(@temp, $_);
	}
      } else { # Line
	my $outside = none {
	  ($_->x <= $maxx and $_->x >= $minx
	   and $_->y <= $maxy and $_->y >= $miny)
	} @{$it->points};
	push(@temp, $_) unless $outside;
      }
    } else {
      push(@temp, $_);
    }
  }
  @lines = @temp;
  # add missing hexes, if requested
  if ($empty) {
    for $x ($minx .. $maxx) {
      for $y ($miny .. $maxy) {
	my $point = Point->new(x => $x, y => $y);
	if (not $seen{$point->coordinates}) {
	  push(@lines, [$point, "empty"]);
	}
      }
    }
    # also, sort regions before trails before others
    @lines = sort {
      (# arrays before strings
       ref($b) cmp ref($a)
       # string comparison if both are strings
       or not(ref($a)) and not(ref($b)) and $a cmp $b
       # if we get here, we know both are arrays
       # points before lines
       or ref($b->[0]) cmp ref($a->[0])
       # if both are points, compare the coordinates
       or ref($a->[0]) eq 'Point' and $a->[0]->cmp($b->[0])
       # if both are lines, compare the first two coordinates (the minimum line length)
       or ref($a->[0]) eq 'Line' and ($a->[0]->points->[0]->cmp($b->[0]->points->[0])
				      or $a->[0]->points->[1]->cmp($b->[0]->points->[1]))
       # if bot are the same point (!) …
       or 0)
    } @lines;
  }
  $map = join("\n",
	      map {
		if (ref) {
		  my ($it, $text) = @$_;
		  if (ref($it) eq 'Point') {
		    Point::coord($it->x, $it->y) . " " . $text
		  } else {
		    my $points = $it->points;
		    join("-",
			 map { Point::coord($_->x, $_->y) } @$points)
			. " " . $text;
		  }
		} else {
		  $_;
		}
	      } @lines) . "\n";
  return $map;
}

any '/borders' => sub {
  my $c = shift;
  my $map = border_modification(map { $c->param($_) } qw(map top left right bottom empty));
  $c->param('map', $map);
  $c->render(template => 'edit', map => $map);
};

sub island_map {
  my $c = shift;
  # must be able to override this for the documentation
  my $step = shift // $c->param('step');
  # need to compute the seed here so that we can send along the URL
  my $seed = $c->param('seed') || int(rand(1000000000));
  my $url = $c->url_with('islanddocument')->query({seed => $seed})->to_abs;
  my @params = ($c->param('width'),
		$c->param('height'),
		$c->param('radius'),
		$seed,
		$url,
		$step,
      );
  my $type = $c->param('type') // 'hex';
  if ($type eq 'hex') {
    return Schroeder::Island->with_roles('Schroeder::Hex')->new()->generate_map(@params);
  } else {
    return Schroeder::Island->with_roles('Schroeder::Square')->new()->generate_map(@params);
  }
}

get '/island' => sub {
  my $c = shift;
  my $map = island_map($c);
  if ($c->stash('format') || '' eq 'txt') {
    $c->render(text => $map);
  } else {
    $c->render(template => 'edit', map => $map);
  }
};

get '/island/random' => sub {
  my $c = shift;
  my $map = island_map($c);
  my $type = $c->param('type') // 'hex';
  my $mapper;
  if ($type eq 'hex') {
    $mapper = Mapper::Hex->new();
  } else {
    $mapper = Mapper::Square->new();
  }
  my $svg = $mapper->initialize($map)->svg;
  $c->render(text => $svg, format => 'svg');
};

sub archipelago_map {
  my $c = shift;
  # must be able to override this for the documentation
  my $step = shift // $c->param('step');
  # need to compute the seed here so that we can send along the URL
  my $seed = $c->param('seed') || int(rand(1000000000));
  my $url = $c->url_with('archipelagodocument')->query({seed => $seed})->to_abs;
  my @params = ($c->param('width'),
		$c->param('height'),
		$c->param('concentration'),
		$c->param('eruptions'),
		$c->param('top'),
		$c->param('bottom'),
		$seed,
		$url,
		$step,
      );
  my $type = $c->param('type') // 'hex';
  if ($type eq 'hex') {
    return Schroeder::Archipelago->with_roles('Schroeder::Hex')->new()->generate_map(@params);
  } else {
    return Schroeder::Archipelago->with_roles('Schroeder::Square')->new()->generate_map(@params);
  }
}

get '/archipelago' => sub {
  my $c = shift;
  my $map = archipelago_map($c);
  if ($c->stash('format') || '' eq 'txt') {
    $c->render(text => $map);
  } else {
    $c->render(template => 'edit', map => $map);
  }
};

get '/archipelago/random' => sub {
  my $c = shift;
  my $map = archipelago_map($c);
  my $type = $c->param('type') // 'hex';
  my $mapper;
  if ($type eq 'hex') {
    $mapper = Mapper::Hex->new();
  } else {
    $mapper = Mapper::Square->new();
  }
  my $svg = $mapper->initialize($map)->svg;
  $c->render(text => $svg, format => 'svg');
};

sub gridmapper_map {
  my $c = shift;
  my $seed = $c->param('seed') || int(rand(1000000000));
  my $pillars = $c->param('pillars') // 1;
  my $rooms = $c->param('rooms') // 5;
  my $caves = $c->param('caves') // 0;
  srand($seed);
  return Gridmapper->new()->generate_map($pillars, $rooms, $caves);
}

get '/gridmapper' => sub {
  my $c = shift;
  my $map = gridmapper_map($c);
  if ($c->stash('format') || '' eq 'txt') {
    $c->render(text => $map);
  } else {
    $c->render(template => 'edit', map => $map);
  }
};

get '/gridmapper/random' => sub {
  my $c = shift;
  my $map = gridmapper_map($c);
  my $mapper = Mapper::Square->new();
  my $svg = $mapper->initialize($map)->svg;
  $c->render(text => $svg, format => 'svg');
};

get '/gridmapper/random/text' => sub {
  my $c = shift;
  my $map = gridmapper_map($c);
  $c->render(text => $map, format => 'txt');
};

sub apocalypse_map {
  my $c = shift;
  my $seed = $c->param('seed') || int(rand(1000000000));
  srand($seed);
  return Apocalypse->new()->generate_map();
}

get '/apocalypse' => sub {
  my $c = shift;
  my $map = apocalypse_map($c);
  if ($c->stash('format') || '' eq 'txt') {
    $c->render(text => $map);
  } else {
    $c->render(template => 'edit', map => $map);
  }
};

get '/apocalypse/random' => sub {
  my $c = shift;
  my $map = apocalypse_map($c);
  my $mapper = Mapper::Hex->new();
  my $svg = $mapper->initialize($map)->svg;
  $c->render(text => $svg, format => 'svg');
};

get '/apocalypse/random/text' => sub {
  my $c = shift;
  my $map = apocalypse_map($c);
  $c->render(text => $map, format => 'txt');
};

sub star_map {
  my $c = shift;
  my $seed = $c->param('seed') || int(rand(1000000000));
  srand($seed);
  return Traveller->with_roles('Schroeder::Hex')->new()->generate_map();
}

get '/traveller' => sub {
  my $c = shift;
  my $map = star_map($c);
  if ($c->stash('format') || '' eq 'txt') {
    $c->render(text => $map);
  } else {
    $c->render(template => 'edit', map => $map);
  }
};

get '/traveller/random' => sub {
  my $c = shift;
  my $map = star_map($c);
  my $mapper = Mapper::Hex->new();
  my $svg = $mapper->initialize($map)->svg;
  $c->render(text => $svg, format => 'svg');
};

get '/traveller/random/text' => sub {
  my $c = shift;
  my $map = star_map($c);
  $c->render(text => $map, format => 'txt');
};

get '/source' => sub {
  my $c = shift;
  seek(DATA,0,0);
  local $/ = undef;
  $c->render(text => <DATA>, format => 'txt');
};

get '/help' => sub {
  my $c = shift;

  seek(DATA,0,0);
  local $/ = undef;
  my $pod = <DATA>;
  $pod =~ s/\$contrib/$contrib/g;
  my $parser = Pod::Simple::HTML->new;
  $parser->html_header_after_title('');
  $parser->html_header_before_title('');
  $parser->title_prefix('<!--');
  $parser->title_postfix('-->');
  my $html;
  $parser->output_string(\$html);
  $parser->parse_string_document($pod);

  my $dom = Mojo::DOM->new($html);
  for my $pre ($dom->find('pre')->each) {
    my $map = $pre->text;
    $map =~ s/^    //mg;
    next if $map =~ /^perl/; # how to call it
    my $url = $c->url_for('render')->query(map => $map);
    $pre->replace("<pre>" . xml_escape($map) . "</pre>\n"
		  . qq{<p class="example"><a href="$url">Render this example</a></p>});
  }

  $c->render(html => $dom);
};

app->start;

__DATA__

=encoding utf8

=head1 Text Mapper

The script parses a text description of a hex map and produces SVG output. Use
your browser to view SVG files and use Inkscape to edit them.

Here's a small example:

    grass attributes fill="green"
    0101 grass

We probably want lighter colors.

    grass attributes fill="#90ee90"
    0101 grass

First, we defined the SVG attributes of a hex B<type> and then we
listed the hexes using their coordinates and their type. Adding more
types and extending the map is easy:

    grass attributes fill="#90ee90"
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass
    0202 sea

You might want to define more SVG attributes such as a border around
each hex:

    grass attributes fill="#90ee90" stroke="black" stroke-width="1px"
    0101 grass

The attributes for the special type B<default> will be used for the
hex layer that is drawn on top of it all. This is where you define the
I<border>.

    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass
    0202 sea

You can define the SVG attributes for the B<text> in coordinates as
well.

    text font-family="monospace" font-size="10pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass
    0202 sea

You can provide a text B<label> to use for each hex:

    text font-family="monospace" font-size="10pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass "promised land"
    0202 sea

To improve legibility, the SVG output gives you the ability to define an "outer
glow" for your labels by printing them twice and using the B<glow> attributes
for the one in the back. In addition to that, you can use B<label> to control
the text attributes used for these labels. If you append a number to the label,
it will be used as the new font-size.

    text font-family="monospace" font-size="10pt"
    label font-family="sans-serif" font-size="12pt"
    glow fill="none" stroke="white" stroke-width="3pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass "promised land"
    0202 sea "deep blue sea" 20

You can define SVG B<path> elements to use for your map. These can be
independent of a type (such as an icon for a settlement) or they can
be part of a type (such as a bit of grass).

Here, we add a bit of grass to the appropriate hex type:

    text font-family="monospace" font-size="10pt"
    label font-family="sans-serif" font-size="12pt"
    glow fill="none" stroke="white" stroke-width="3pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    grass path attributes stroke="#458b00" stroke-width="5px"
    grass path M -20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass "promised land"
    0202 sea "deep blue sea" 20

If you want to read up on the SVG Path syntax, check out the official
L<specification|https://www.w3.org/TR/SVG11/paths.html>. You can use a tool like
L<Linja Lili|https://campaignwiki.org/linja-lili> to work on it: paste “M
-20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40” in the the Path field, use the
default transform of “scale(2) translate(50,50)” and import it. Make some
changes, export it, and copy the result from the Path field back into your map.
Linja Lili was written just for this! 😁

Here, we add a settlement. The village doesn't have type attributes (it never
says C<village attributes>) and therefore it's not a hex type.

    text font-family="monospace" font-size="10pt"
    label font-family="sans-serif" font-size="12pt"
    glow fill="none" stroke="white" stroke-width="3pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    grass path attributes stroke="#458b00" stroke-width="5px"
    grass path M -20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40
    village path attributes fill="none" stroke="black" stroke-width="5px"
    village path M -40,-40 v 80 h 80 v -80 z
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass village "Beachton"
    0202 sea "deep blue sea" 20

As you can see, you can have multiple types per coordinate, but
obviously only one of them should have the "fill" property (or they
must all be somewhat transparent).

As we said above, the village is an independent shape. As such, it also gets the
glow we defined for text. In our example, the glow has a stroke-width of 3pt and
the village path has a stroke-width of 5px which is why we can't see it. If had
used a thinner stroke, we would have seen a white outer glow. Here's the same
example with a 1pt stroke-width for the village.

    text font-family="monospace" font-size="10pt"
    label font-family="sans-serif" font-size="12pt"
    glow fill="none" stroke="white" stroke-width="3pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    grass path attributes stroke="#458b00" stroke-width="5px"
    grass path M -20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40
    village path attributes fill="none" stroke="black" stroke-width="1pt"
    village path M -40,-40 v 80 h 80 v -80 z
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass village "Beachton"
    0202 sea "deep blue sea" 20

You can also have lines connecting hexes. In order to better control the flow of
these lines, you can provide multiple hexes through which these lines must pass.
You can append a label to these, too. These lines can be used for borders,
rivers or roads, for example.

    text font-family="monospace" font-size="10pt"
    label font-family="sans-serif" font-size="12pt"
    glow fill="none" stroke="white" stroke-width="3pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="#90ee90"
    grass path attributes stroke="#458b00" stroke-width="5px"
    grass path M -20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40
    village path attributes fill="none" stroke="black" stroke-width="5px"
    village path M -40,-40 v 80 h 80 v -80 z
    sea attributes fill="#afeeee"
    0101 grass
    0102 sea
    0201 grass village "Beachton"
    0202 sea "deep blue sea" 20
    border path attributes stroke="red" stroke-width="15" stroke-opacity="0.5" fill-opacity="0"
    0002-0200 border "The Wall"
    road path attributes stroke="black" stroke-width="3" fill-opacity="0" stroke-dasharray="10 10"
    0000-0301 road

=head2 Colours and Transparency

Let me return for a moment to the issue of colours. We've used 24 bit colours in
the examples above, that is: red-green-blue (RGB) definitions of colours where
very colour gets a number between 0 and 255, but written as a hex using the
digites 0-9 and A-F: no red, no green, no blue is #000000; all red, all green,
all blue is #FFFFFF; just red is #FF0000.

    text font-family="monospace" font-size="20px"
    label font-family="monospace" font-size="20px"
    glow fill="none" stroke="white" stroke-width="4px"
    default attributes fill="none" stroke="black" stroke-width="1px"
    sea attributes fill="#000000"
    land attributes fill="#ffffff"
    fire attributes fill="#ff0000"
    0101 sea
    0102 sea
    0103 sea
    0201 sea
    0202 sea "black sea"
    0203 sea
    0301 land
    0302 land "lands of Dis"
    0303 sea
    0401 fire "gate of fire"
    0402 land
    0403 sea

But of course, we can write colours in all the ways L<allowed on the
web|https://en.wikipedia.org/wiki/Web_colors>: using just three digits (#F00 for
red), using the predefined SVG colour names (just "red"), RGB values
("rgb(255,0,0)" for red), RGB percentages ("rgb(100%,0%,0%)" for red).

What we haven't mentioned, however, is the alpha channel: you can always add a
fourth number that specifies how transparent the colour is. It's tricky, though:
the colour is black (#000000) then it doesn't matter how transparent it is: a
value of zero doesn't change. But it's different when the colour is white!
Therefore, we can define an attribute that is simply a semi-transparent white
and use it to lighten things up. You can even use it multiple times!

    text font-family="monospace" font-size="20px"
    label font-family="monospace" font-size="20px"
    glow fill="none" stroke="white" stroke-width="4px"
    default attributes fill="none" stroke="black" stroke-width="1px"
    sea attributes fill="#000000"
    land attributes fill="#ffffff"
    fire attributes fill="#ff0000"
    lighter attributes fill="rgb(100%,100%,100%,40%)"
    0101 sea
    0102 sea
    0103 sea
    0201 sea lighter
    0202 sea lighter "black sea"
    0203 sea lighter
    0301 land
    0302 land "lands of Dis"
    0303 sea lighter lighter
    0401 fire "gate of fire"
    0402 land
    0403 sea lighter lighter lighter

Thanks to Eric Scheid for showing me this trick.

=head2 Include a Library

Since these definitions get unwieldy, require a lot of work (the path
elements), and to encourage reuse, you can use the B<include>
statement with an URL.

    include $contrib/default.txt
    0102 sand
    0103 sand
    0201 sand
    0202 jungle "oasis"
    0203 sand
    0302 sand
    0303 sand

You can find more files ("libraries") to include in the C<contrib>
directory:
L<https://alexschroeder.ch/cgit/hex-mapping/tree/contrib>.


=head3 Default library

Source of the map:
L<http://themetalearth.blogspot.ch/2011/03/opd-entry.html>

Example data:
L<$contrib/forgotten-depths.txt>

Library:
L<$contrib/default.txt>

Result:
L<https://campaignwiki.org/text-mapper?map=include+$contrib/forgotten-depths.txt>

=head3 Gnomeyland library

Example data:
L<$contrib/gnomeyland-example.txt>

Library:
L<$contrib/gnomeyland.txt>

Result:
L<https://campaignwiki.org/text-mapper?map=include+$contrib/gnomeyland-example.txt>

=head3 Traveller library

Example:
L<$contrib/traveller-example.txt>

Library:
L<$contrib/traveller.txt>

Result:
L<https://campaignwiki.org/text-mapper?map=include+$contrib/traveller-example.txt>

=head3 Dungeons library

Example:
L<$contrib/gridmapper-example.txt>

Library:
L<$contrib/gridmapper.txt>

Result:
L<https://campaignwiki.org/text-mapper?type=square&map=include+$contrib/gridmapper-example.txt>

=head2 Large Areas

If you want to surround a piece of land with a round shore line, a
forest with a large green shadow, you can achieve this using a line
that connects to itself. These "closed" lines can have C<fill> in
their path attributes. In the following example, the oasis is
surrounded by a larger green area.

    include $contrib/default.txt
    0102 sand
    0103 sand
    0201 sand
    0203 sand
    0302 sand
    0303 sand
    0102-0201-0302-0303-0203-0103-0102 green
    green path attributes fill="#9acd32"
    0202 jungle "oasis"

Confusingly, the "jungle path attributes" are used to draw the palm
tree, so we cannot use it do define the area around the oasis. We need
to define the green path attributes in order to do that.

I<Order is important>: First we draw the sand, then the green area,
then we drop a jungle on top of the green area.

=head2 SVG

You can define shapes using arbitrary SVG. Your SVG will end up in the
B<defs> section of the SVG output. You can then refer to the B<id>
attribute in your map definition. For the moment, all your SVG needs to
fit on a single line.

    <circle id="thorp" fill="#ffd700" stroke="black" stroke-width="7" cx="0" cy="0" r="15"/>
    0101 thorp

Shapes can include each other:

    <circle id="settlement" fill="#ffd700" stroke="black" stroke-width="7" cx="0" cy="0" r="15"/>
    <path id="house" stroke="black" stroke-width="7" d="M-15,0 v-50 m-15,0 h60 m-15,0 v50 M0,0 v-37"/>
    <use id="thorp" xlink:href="#settlement" transform="scale(0.6)"/>
    <g id="village" transform="scale(0.6), translate(0,40)"><use xlink:href="#house"/><use xlink:href="#settlement"/></g>
    0101 thorp
    0102 village

When creating new shapes, remember the dimensions of the hex. Your shapes must
be centered around (0,0). The width of the hex is 200px, the height of the hex
is 100 √3 = 173.2px. A good starting point would be to keep it within (-50,-50)
and (50,50).

=head2 Other

You can add even more arbitrary SVG using the B<other> keyword. This
keyword can be used multiple times.

    grass attributes fill="#90ee90"
    0101 grass
    0201 grass
    0302 grass
    other <text x="150" y="20" font-size="40pt" transform="rotate(30)">Tundra of Sorrow</text>

The B<other> keyword causes the item to be added to the end of the
document. It can be used for frames and labels that are not connected
to a single hex.

You can make labels link to web pages using the B<url> keyword.

    grass attributes fill="#90ee90"
    0101 grass "Home"
    url https://campaignwiki.org/wiki/NameOfYourWiki/

This will make the label X link to
C<https://campaignwiki.org/wiki/NameOfYourWiki/X>. You can also use
C<%s> in the URL and then this placeholder will be replaced with the
(URL encoded) label.

=head2 License

This program is copyright (C) 2007-2019 Alex Schroeder <alex@gnu.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.

The maps produced by the program are obviously copyrighted by I<you>,
the author. If you're using SVG icons, these I<may> have a separate
license. Thus, if you produce a map using the I<Gnomeyland> icons by
Gregory B. MacKenzie, the map is automatically licensed under the
Creative Commons Attribution-ShareAlike 3.0 Unported License. To view
a copy of this license, visit
L<http://creativecommons.org/licenses/by-sa/3.0/>.

You can add arbitrary SVG using the B<license> keyword (without a
tile). This is what the Gnomeyland library does, for example.

    grass attributes fill="#90ee90"
    0101 grass
    license <text>Public Domain</text>

There can only be I<one> license keyword. If you use multiple
libraries or want to add your own name, you will have to write your
own.

There's a 50 pixel margin around the map, here's how you might
conceivably use it for your own map that uses the I<Gnomeyland> icons
by Gregory B. MacKenzie:

    grass attributes fill="#90ee90"
    0101 grass
    0201 grass
    0301 grass
    0401 grass
    0501 grass
    license <text x="50" y="-33" font-size="15pt" fill="#999999">Copyright Alex Schroeder 2013. <a style="fill:#8888ff" xlink:href="http://www.busygamemaster.com/art02.html">Gnomeyland Map Icons</a> Copyright Gregory B. MacKenzie 2012.</text><text x="50" y="-15" font-size="15pt" fill="#999999">This work is licensed under the <a style="fill:#8888ff" xlink:href="http://creativecommons.org/licenses/by-sa/3.0/">Creative Commons Attribution-ShareAlike 3.0 Unported License</a>.</text>

Unfortunately, it all has to go on a single line.

The viewport for the map is determined by the hexes of the map. You need to take
this into account when putting a license onto the map. Thus, if your map does
not include the hex 0101, you can't use coordinates for the license text around
the origin at (0,0) – you'll have to move it around.

=head2 Random

The Random button generates a random landscape based on the algorithm
developed by Erin D. Smale. See
L<http://www.welshpiper.com/hex-based-campaign-design-part-1/> and
L<http://www.welshpiper.com/hex-based-campaign-design-part-2/> for
more information. The output uses the I<Gnomeyland> icons by Gregory
B. MacKenzie. These are licensed under the Creative Commons
Attribution-ShareAlike 3.0 Unported License. To view a copy of this
license, visit L<http://creativecommons.org/licenses/by-sa/3.0/>.

If you're curious: (11,11) is the starting hex.

=head2 Alpine

The Alpine button generates a random landscape based on an algorithm developed
by Alex Schroeder. The output also uses the I<Gnomeyland> icons by Gregory B.
MacKenzie. These are licensed under the Creative Commons Attribution-ShareAlike
3.0 Unported License. To view a copy of this license, visit
L<http://creativecommons.org/licenses/by-sa/3.0/>.

=head2 Gridmapper

The Gridmapper button generates a random mini-dungeon based on the algorithm by
Alex Schroeder and based on geomorph sketches by Robin Green.

=head2 Islands

The Island links generate a random landscape based on the algorithm by Alex
Schroeder. The output also uses the I<Gnomeyland> icons by Gregory B. MacKenzie.
These are licensed under the Creative Commons Attribution-ShareAlike 3.0
Unported License. To view a copy of this license, visit
L<http://creativecommons.org/licenses/by-sa/3.0/>.

=head2 Traveller

The Traveller link generates a random landscape based on Classic Traveller with
additions by Vicky Radcliffe and Alex Schroeder.

=head2 Border Adjustments

The border adjustments can be a little unintuitive. Let's assume the default map
and think through some of the operations.

    0101 mountain "mountain"
    0102 swamp "swamp"
    0103 hill "hill"
    0104 forest "forest"
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
    0501 mountain cave "cave"
    0502 sand "sand"
    0205-0103-0202-0303-0402 road
    0101-0203 river
    0401-0303-0403 border
    include https://campaignwiki.org/contrib/default.txt
    license <text>Public Domain</text>

Basically, we're adding and removing rows and columns using the left, top,
bottom, right parameters. Thus, “left +2” means adding two columns at the left.
The mountains at 0101 thus turn into mountains at 0301.

    0301 mountain "mountain"
    0302 swamp "swamp"
    0303 hill "hill"
    0304 forest "forest"
    0401 empty pyramid "pyramid"
    0402 tundra "tundra"
    0403 coast "coast"
    0404 empty house "house"
    0501 woodland "woodland"
    0502 wetland "wetland"
    0503 plain "plain"
    0504 sea "sea"
    0601 hill tower "tower"
    0602 sand house "house"
    0603 jungle "jungle"
    0701 mountain cave "cave"
    0702 sand "sand"
    0405-0303-0402-0503-0602 road
    0301-0403 river
    0601-0503-0603 border
    include https://campaignwiki.org/contrib/default.txt
    license <text>Public Domain</text>

Conversely, “left -2” means removing the two columns at the left. The mountains
at 0101 and the pyramid at 0201 would therefore disappear and the woodland at
0301 would turn into the woodland at 0101.

    0101 woodland "woodland"
    0102 wetland "wetland"
    0103 plain "plain"
    0104 sea "sea"
    0201 hill tower "tower"
    0202 sand house "house"
    0203 jungle "jungle"
    0301 mountain cave "cave"
    0302 sand "sand"
    0005--0103-0002-0103-0202 road
    0201-0103-0203 border
    include https://campaignwiki.org/contrib/default.txt
    license <text>Public Domain</text>

The tricky part is when “add empty” is not checked and you first add two columns
on the left, and then remove two columns on the left. If you do this, you’re not
undoing the addition of the two columns because the code just considers the
actual columns and thus removes the columns with the mountain which moved from
0101 to 0301 and the pyramid which moved from 0201 to 0401, leaving the woodland
in 0301.

    0301 woodland "woodland"
    0302 wetland "wetland"
    0303 plain "plain"
    0304 sea "sea"
    0401 hill tower "tower"
    0402 sand house "house"
    0403 jungle "jungle"
    0501 mountain cave "cave"
    0502 sand "sand"
    0205-0103-0202-0303-0402 road
    0401-0303-0403 border
    include https://campaignwiki.org/contrib/default.txt
    license <text>Public Domain</text>

This problem disappears if you check “add empty” as you add the two columns
at the left because now all the gaps are filled, starting at 0101. You’re
getting two empty columns on the left:

    0101 empty
    0102 empty
    0103 empty
    0104 empty
    0201 empty
    0202 empty
    0203 empty
    0204 empty
    0301 mountain "mountain"
    0302 swamp "swamp"
    0303 hill "hill"
    0304 forest "forest"
    0401 empty pyramid "pyramid"
    0402 tundra "tundra"
    0403 coast "coast"
    0404 empty house "house"
    0501 woodland "woodland"
    0502 wetland "wetland"
    0503 plain "plain"
    0504 sea "sea"
    0601 hill tower "tower"
    0602 sand house "house"
    0603 jungle "jungle"
    0604 empty
    0701 mountain cave "cave"
    0702 sand "sand"
    0703 empty
    0704 empty
    0301-0403 river
    0405-0303-0402-0503-0602 road
    0601-0503-0603 border
    include https://campaignwiki.org/contrib/default.txt
    license <text>Public Domain</text>

When you remove two columns in the second step, you’re removing the two empty
columns you just added. But “add empty” fills all the gaps, so in the example
map, it also adds all the missing hexes in columns 04 and 05, so you can only
use this option if you want those empty hexes added…

    0101 mountain "mountain"
    0102 swamp "swamp"
    0103 hill "hill"
    0104 forest "forest"
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
    0404 empty
    0501 mountain cave "cave"
    0502 sand "sand"
    0503 empty
    0504 empty
    0101-0203 river
    0205-0103-0202-0303-0402 road
    0401-0303-0403 border
    include https://campaignwiki.org/contrib/default.txt
    license <text>Public Domain</text>

=head2 Configuration

As a Mojolicious application, it will read a config file called
F<text-mapper.conf> in the same directory, if it exists. As the default log
level is 'warn', one use of the config file is to change the log level using
the C<loglevel> key.

The libraries are loaded from the F<contrib> URL. You can change the default
using the C<contrib> key. This is necessary when you want to develop locally,
for example.

    {
      loglevel => 'debug',
      contrib => 'file://contrib',
    };

=head2 Command Line

You can call the script from the command line. The B<render> command reads a map
description from STDIN and prints it to STDOUT.

    perl text-mapper.pl render < contrib/forgotten-depths.txt > forgotten-depths.svg

The B<random> command prints a random map description to STDOUT.

    perl text-mapper.pl random > map.txt

Thus, you can pipe the random map in order to render it:

    perl text-mapper.pl random | perl text-mapper.pl render > map.svg

You can read this documentation in a text terminal, too:

    pod2text text-mapper.pl

Alternatively:

    perl text-mapper.pl get /help | w3m -T text/html

=cut


@@ help.html.ep
% layout 'default';
% title 'Text Mapper: Help';
<%== $html %>


@@ edit.html.ep
% layout 'default';
% title 'Text Mapper';
<h1>Text Mapper</h1>
<p>Submit your text description of the map.</p>
%= form_for render => (method => 'POST') => begin
%= text_area map => (cols => 60, rows => 15) => begin
<%= $map =%>
% end

<p>
%= radio_button type => 'hex', id => 'hex', checked => undef
%= label_for hex => 'Hex'
%= radio_button type => 'square', id => 'square'
%= label_for square => 'Square'
<p>
%= submit_button "Generate Map"

<p>
Add (or remove if negative) rows or columns:
%= label_for top => 'top'
%= number_field top => 0, class => 'small', id => 'top'
%= label_for left => 'left'
%= number_field left => 0, class => 'small', id => 'left'
%= label_for right => 'right'
%= number_field right => 0, class => 'small', id => 'right'
%= label_for bottom => 'bottom'
%= number_field bottom => 0, class => 'small', id => 'bottom'
%= label_for empty => 'add empty'
%= check_box empty => 1, id => 'empty'
<p>
%= submit_button "Modify Map Data", 'formaction' => $c->url_for('borders')
%= end
<p>
See the <%= link_to url_for('help')->fragment('Border_Adjustments') => begin %>documentation<% end %>
for an explanation of what these parameters do.

<hr>
<p>
<%= link_to smale => begin %>Random<% end %>
will generate map data based on Erin D. Smale's <em>Hex-Based Campaign Design</em>
(<a href="http://www.welshpiper.com/hex-based-campaign-design-part-1/">Part 1</a>,
<a href="http://www.welshpiper.com/hex-based-campaign-design-part-2/">Part 2</a>).
You can also generate a random map
<%= link_to url_for('smale')->query(bw => 1) => begin %>with no background colors<% end %>.
Click the submit button to generate the map itself. Or just keep reloading
<%= link_to smalerandom => begin %>this link<% end %>.
You'll find the map description in a comment within the SVG file.
</p>
%= form_for smale => begin
<table>
<tr><td>Width:</td><td>
%= number_field width => 20, min => 5, max => 99
</td></tr><tr><td>Height:</td><td>
%= number_field height => 10, min => 5, max => 99
</td></tr></table>
<p>
%= submit_button "Generate Map Data"
% end

<hr>
<p>
<%= link_to alpine => begin %>Alpine<% end %> will generate map data based on Alex
Schroeder's algorithm that's trying to recreate a medieval Swiss landscape, with
no info to back it up, whatsoever. See it
<%= link_to url_for('alpinedocument')->query(height => 5) => begin %>documented<% end %>.
Click the submit button to generate the map itself. Or just keep reloading
<%= link_to alpinerandom => begin %>this link<% end %>.
You'll find the map description in a comment within the SVG file.
</p>
%= form_for alpine => begin
<table>
<tr><td>Width:</td><td>
%= number_field width => 20, min => 5, max => 99
</td><td>Bottom:</td><td>
%= number_field bottom => 0, min => 0, max => 10
</td><td>Peaks:</td><td>
%= number_field peaks => 5, min => 0, max => 100
</td><td>Bumps:</td><td>
%= number_field bumps => 2, min => 0, max => 100
</td></tr><tr><td>Height:</td><td>
%= number_field height => 10, min => 5, max => 99
</td><td>Steepness:</td><td>
%= number_field steepness => 3, min => 1, max => 6
</td><td>Peak:</td><td>
%= number_field peak => 10, min => 7, max => 10
</td><td>Bump:</td><td>
%= number_field bump => 2, min => 1, max => 2
</td></tr><tr><td>Arid:</td><td>
%= number_field arid => 2, min => 0, max => 2
</td><td><td>
</td><td></td><td>
</td></tr></table>
<p>
See the <%= link_to alpineparameters => begin %>documentation<% end %> for an
explanation of what these parameters do.
<p>
%= radio_button type => 'hex', id => 'hex', checked => undef
%= label_for hex => 'Hex'
%= radio_button type => 'square', id => 'square'
%= label_for square => 'Square'
<p>
%= submit_button "Generate Map Data"
</p>
% end

<hr>
<p>
<%= link_to url_for('gridmapper')->query(type => 'square') => begin %>Gridmapper<% end %>
will generate dungeon map data based on geomorph sketches by Robin Green. Or
just keep reloading one of these links:
<%= link_to url_for('gridmapperrandom')->query(rooms => 5) => begin %>5 rooms<% end %>,
<%= link_to url_for('gridmapperrandom')->query(rooms => 10) => begin %>10 rooms<% end %>,
<%= link_to url_for('gridmapperrandom')->query(rooms => 20) => begin %>20 rooms<% end %>.
Each map contains a “Edit in Gridmapper” link which will open the same map in the <a
href="https://campaignwiki.org/gridmapper.svg">Gridmapper web app</a> itself.
%= form_for gridmapper => begin
<p>
<label>
%= check_box pillars => 0
No rooms with pillars
</label>
<label>
%= check_box caves => 1
Just caves
</label>
%= hidden_field type => 'square'
<table>
<tr><td>Rooms:</td><td>
%= number_field rooms => 5, min => 1
</td></tr></table>
<p>
%= submit_button "Generate Map Data"
% end

<hr>

<p>Ideas and work in progress…

<p><%= link_to url_for('apocalypse') => begin %>Apocalypse<% end %> generates a post-apocalyptic map.
<%= link_to url_for('apocalypserandom') => begin %>Reload<% end %> for lots of post-apocalyptic maps.
You'll find the map description in a comment within the SVG file.

<p><%= link_to url_for('traveller') => begin %>Traveller<% end %> generates a star map.
<%= link_to url_for('travellerrandom') => begin %>Reload<% end %> for lots of random star maps.
You'll find the map description in a comment within the SVG file.

<p><%= link_to url_for('island') => begin %>Island<% end %> generates a hotspot-inspired island chain.
Reload <%= link_to url_for('islandrandom') => begin %>Hex Island<% end %>
or <%= link_to url_for('islandrandom')->query(type => 'square') => begin %>Square Island<% end %>
for lots of random islands.
You'll find the map description in a comment within the SVG file.

<p><%= link_to url_for('archipelago') => begin %>Archipelago<% end %> is an experimenting with alternative hex heights.
Reload <%= link_to url_for('archipelagorandom') => begin %>Hex Archipelago<% end %>
or <%= link_to url_for('archipelagorandom')->query(type => 'square') => begin %>Square Archipelago<% end %>
for lots of random archipelagos.
You'll find the map description in a comment within the SVG file.

@@ render.svg.ep


@@ alpine_parameters.html.ep
% layout 'default';
% title 'Alpine Parameters';
<h1>Alpine Parameters</h1>

<p>
This page explains what the parameters for the <em>Alpine</em> map generation
will do.
</p>
<p>
The parameters <strong>width</strong> and <strong>height</strong> determine how
big the map is.
</p>
<p>
Example:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15) => begin %>15×10 map<% end %>.
</p>
<p>
The number of peaks we start with is controlled by the <strong>peaks</strong>
parameter (default is 2½% of the hexes). Note that you need at least one peak in
order to get any land at all.
</p>
<p>
Examples:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 1) => begin %>lonely mountain<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 2) => begin %>twin peaks<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 15) => begin %>here be glaciers<% end %>
</p>
<p>
The number of bumps we start with is controlled by the <strong>bumps</strong>
parameter (default is 1% of the hexes). These are secondary hills and hollows.
</p>
<p>
Examples:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 1, bumps => 0) => begin %>lonely mountain, no bumps<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 1, bumps => 4) => begin %>lonely mountain and four bumps<% end %>
</p>
<p>
When creating elevations, we surround each hex with a number of other hexes at
one altitude level lower. The number of these surrounding lower levels is
controlled by the <strong>steepness</strong> parameter (default 3). Lower means
steeper. Floating points are allowed. Please note that the maximum numbers of
neighbors considered is the 6 immediate neighbors and the 12 neighbors one step
away.
</p>
<p>
Examples:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, steepness => 0) => begin %>ice needles map<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, steepness => 2) => begin %>steep mountains map<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, steepness => 4) => begin %>big mountains map<% end %>
</p>
<p>
The sea level is set to altitude 0. That's how you sometimes get a water hex at
the edge of the map. You can simulate global warming and set it to something
higher using the <strong>bottom</strong> parameter.
</p>
<p>
Example:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, steepness => 2, bottom => 5) => begin %>steep mountains and higher water level map<% end %>
</p>
<p>
You can also control how high the highest peaks will be using the
<strong>peak</strong> parameter (default 10). Note that nothing special happens
to a hex with an altitude above 10. It's still mountain peaks. Thus, setting the
parameter to something higher than 10 just makes sure that there will be a lot
of mountain peaks.
</p>
<p>
Examples:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peak => 11) => begin %>big mountains<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, steepness => 3, bottom => 3, peak => 8) => begin %>old country<% end %>
</p>
<p>
You can also control how high the extra bumps will be using the
<strong>bump</strong> parameter (default 2).
</p>
<p>
Examples:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 1, bump => 1) => begin %>small bumps<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 1, bump => 2) => begin %>bigger bumps<% end %>
</p>
<p>
You can also control forest growth (as opposed to grassland) by using the
<strong>arid</strong> parameter (default 2). That's how many hexes surrounding a
river hex will grow forests. Smaller means more arid and thus more grass.
Fractions are allowed. Thus, 0.5 means half the river hexes will have forests
grow to their neighbouring hexes.
</p>
<p>
Examples:
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 2, stepness => 2, arid => 2) => begin %>fewer, steeper mountains<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 2, stepness => 2, arid => 1) => begin %>less forest<% end %>,
<%= link_to url_for('alpinerandom')->query(height => 10, width => 15, peaks => 2, stepness => 2, arid => 0) => begin %>very arid<% end %>
</p>


@@ alpine_document.html.ep
% layout 'default';
% title 'Alpine Documentation';
<h1>Alpine Map: How does it get created?</h1>

<p>How do we get to the following map?
<%= link_to url_for('alpinedocument')->query(width => $width, height => $height, steepness => $steepness, peaks => $peaks, peak => $peak, bumps => $bumps, bump => $bump, bottom => $bottom, arid => $arid) => begin %>Reload<% end %>
to get a different one. If you like this particular map, bookmark
<%= link_to url_for('alpinerandom')->query(seed => $seed, width => $width, height => $height, steepness => $steepness, peaks => $peaks, peak => $peak, bumps => $bumps, bump => $bump, bottom => $bottom, arid => $arid) => begin %>this link<% end %>,
and edit it using
<%= link_to url_for('alpine')->query(seed => $seed, width => $width, height => $height, steepness => $steepness, peaks => $peaks, peak => $peak, bumps => $bumps, bump => $bump, bottom => $bottom, arid => $arid) => begin %>this link<% end %>,
</p>

%== $maps->[$#$maps]

<p>First, we pick <%= $peaks %> peaks and set their altitude to <%= $peak %>.
Then we loop down to 1 and for every hex we added in the previous run, we add
<%= $steepness %> neighbors at a lower altitude, if possible. We actually vary
steepness, so the steepness given is just an average. We'll also consider
neighbors one step away. If our random growth missed any hexes, we just copy the
height of a neighbor. If we can't find a suitable neighbor within a few tries,
just make a hole in the ground (altitude 0).</p>

<p>The number of peaks can be changed using the <em>peaks</em> parameter. Please
note that 0 <em>peaks</em> will result in no land mass.</p>

<p>The initial altitude of those peaks can be changed using the <em>peak</em>
parameter. Please note that a <em>peak</em> smaller than 7 will result in no
sources for rivers.</p>

<p>The number of adjacent hexes at a lower altitude can be changed using the
<em>steepness</em> parameter. Floating points are allowed. Please note that the
maximum numbers of neighbors considered is the 6 immediate neighbors and the 12
neighbors one step away.</p>

%== shift(@$maps)

<p>Next, we pick <%= $bumps %> bumps and shift their altitude by -<%= $bump %>,
and <%= $bumps %> bumps and shift their altitude by +<%= $bump %>. If the shift
is bigger than 1, then we shift the neighbours by one less.</p>

%== shift(@$maps)

<p>Mountains are the hexes at high altitudes: white mountains (altitude 10),
white mountain (altitude 9), light-grey mountain (altitude 8).</p>

%== shift(@$maps)

<p>Oceans are whatever lies at the bottom (<%= $bottom %>) and is surrounded by
regions at the same altitude.</p>

%== shift(@$maps)

<p>We determine the flow of water by having water flow to one of the lowest
neighbors if possible. Water doesn't flow upward, and if there is already water
coming our way, then it won't flow back. It has reached a dead end.</p>

%== shift(@$maps)

<p>Any of the dead ends we found in the previous step are marked as lakes.</p>

%== shift(@$maps)

<p>We still need to figure out how to drain lakes. In order to do that, we start
"flooding" lakes, looking for a way to the edge of the map. If we're lucky, our
search will soon hit upon a sequence of arrows that leads to ever lower
altitudes and to the edge of the map. An outlet! We start with all the hexes
that don't have an arrow. For each one of those, we look at its neighbors. These
are our initial candidates. We keep expanding our list of candidates as we add
at neighbors of neighbors. At every step we prefer the lowest of these
candidates. Once we have reached the edge of the map, we backtrack and change
any arrows pointing the wrong way.</p>

%== shift(@$maps)

<p>We add bogs (altitude 7) if the water flows into a hex at the same altitude.
It is insufficiently drained. We use grey swamps to indicate this.</p>

%== shift(@$maps)

<p>We add a river sources high up in the mountains (altitudes 7 and 8), merging
them as appropriate. These rivers flow as indicated by the arrows. If the river
source is not a mountain (altitude 8) or a bog (altitude 7), then we place a
forested hill at the source (thus, they're all at altitude 7).</p>

%== shift(@$maps)

<p>Remember how the arrows were changed at some points such that rivers don't
always flow downwards. We're going to assume that in these situations, the
rivers have cut canyons into the higher lying ground and we'll add a little
shadow.</p>

%== shift(@$maps)

<p>Any hex <em>with a river</em> that flows towards a neighbor at the same
altitude is insufficiently drained. These are marked as swamps. The background
color of the swamp depends on the altitude: grey if altitude 6 and higher,
otherwise dark-grey.</p>

%== shift(@$maps)

<p>Wherever there is water and no swamp, forests will form. The exact type again
depends on the altitude: light green fir-forest (altitude 7 and higher), green
fir-forest (altitude 6), green forest (altitude 4–5), dark-green forest
(altitude 3 and lower). Once a forest is placed, it expands up to <%= $arid %> hexes
away, even if those hexes have no water flowing through them. You probably need
fewer peaks on your map to verify this (a <%= link_to
url_with('alpinerandom')->query({peaks => 1}) => begin %>lonely mountain<% end
%> map, for example).</p>

%== shift(@$maps)

<p>Any remaining hexes have no water nearby and are considered to be little more
arid. They get bushes, a hill (20% of the time at altitudes 3 or higher), or
some grass (60% of the time at altitudes 3 and lower). Higher up, these are
light grey (altitude 6–7), otherwise they are light green (altitude 5 and
below).</p>

%== shift(@$maps)

<p>Cliffs form wherever the drop is more than just one level of altitude.</p>

%== shift(@$maps)

<p>Wherenver there is forest, settlements will be built. These reduce the
density of the forest. There are three levels of settlements: thorps, villages
and towns.</p>

<table>
<tr><th>Settlement</th><th>Forest</th><th>Number</th><th>Minimum Distance</th></tr>
<tr><td>Thorp</td><td>fir-forest, forest</td><td class="numeric">10%</td><td class="numeric">2</td></tr>
<tr><td>Village</td><td>forest &amp; river</td><td class="numeric">5%</td><td class="numeric">5</td></tr>
<tr><td>Town</td><td>forest &amp; river</td><td class="numeric">2½%</td><td class="numeric">10</td></tr>
<tr><td>Law</td><td>white mountain</td><td class="numeric">2½%</td><td class="numeric">10</td></tr>
<tr><td>Chaos</td><td>swamp</td><td class="numeric">2½%</td><td class="numeric">10</td></tr>
</table>

%== shift(@$maps)

<p>Trails connect every settlement to any neighbor that is one or two hexes
away. If no such neighbor can be found, we try to find neighbors that are three
hexes away.</p>

%== shift(@$maps)

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
%= stylesheet '/text-mapper.css'
%= stylesheet begin
body {
  padding: 1em;
  font-family: "Palatino Linotype", "Book Antiqua", Palatino, serif;
}
textarea {
  width: 100%;
}
td, th {
  padding-right: 0.5em;
}
.example {
  font-size: smaller;
}
.numeric {
  text-align: center;
}
.small {
  width: 3em;
}
% end
<meta name="viewport" content="width=device-width">
</head>
<body>
<%= content %>
<hr>
<p>
<a href="https://campaignwiki.org/text-mapper">Text Mapper</a>&#x2003;
<%= link_to 'Help' => 'help' %>&#x2003;
<%= link_to 'Source' => 'source' %>&#x2003;
<a href="https://alexschroeder.ch/cgit/hex-mapping/about/#text-mapper">Git</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

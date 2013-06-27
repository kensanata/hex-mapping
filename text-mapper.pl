#!/usr/bin/perl

# This code started out as a fork of old-school-hex.pl.

use CGI qw/:standard/;
use LWP::UserAgent;
use strict;

my $verbose = 0;

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
  my $data = "    <path $attributes d='$path'/>\n";
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

my @hex = ([-$dx, 0], [-$dx/2, $dy/2], [$dx/2, $dy/2],
	   [$dx, 0], [$dx/2, -$dy/2], [-$dx/2, -$dy/2]);

sub corners {
  return @hex;
}

sub svg_hex {
  my ($self, $attributes) = @_;
  my $x = $self->x * $dx * 3/2;
  my $y = $self->y * $dy - $self->x % 2 * $dy/2;
  my $id = "hex" . $self->x . $self->y;
  my $points = join(" ", map {
    sprintf("%.1f,%.1f", $x + $_->[0], $y + $_->[1]) } $self->corners());
  return qq{    <polygon id="$id" $attributes points="$points" />\n}
}

sub svg_type {
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
  $data .= ' ' . $self->map->text_attributes . '>';
  $data .= sprintf(qq{%02d.%02d}, $x, $y);
  $data .= qq{</text>\n};
  return $data;
}

sub svg_label {
  my $self = shift;
  return unless $self->label;
  my $x = $self->x;
  my $y = $self->y;
  my $data = sprintf(qq{    <g><text text-anchor="middle" x="%.1f" y="%.1f" %s %s>}
		   . $self->label
		   . qq{</text>},
		   $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 + $dy * 0.4,
		   $self->map->label_attributes,
		   $self->map->glow_attributes);
  $data .= sprintf(qq{<text text-anchor="middle" x="%.1f" y="%.1f" %s>}
		   . $self->label
		   . qq{</text></g>\n},
		   $x * $dx * 3/2, $y * $dy - $x%2 * $dy/2 + $dy * 0.4,
		   $self->map->label_attributes);
  return $data;
}

package Mapper;

use Class::Struct;

struct Mapper => {
		  hexes => '@',
		  attributes => '%',
		  xml => '%',
		  lib => '%',
		  map => '$',
		  path => '%',
		  lines => '@',
		  path_attributes => '%',
		  text_attributes => '$',
		  glow_attributes => '$',
		  label_attributes => '$',
		  messages => '@',
		  seen => '%',
		  license => '$',
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
license <text>Public Domain</text>
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
    } elsif (/^(\S+)\s+lib\s+(.*)/) {
      $self->lib($1, $2);
    } elsif (/^(\S+)\s+xml\s+(.*)/) {
      $self->xml($1, $2);
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
    } elsif (/^license\s+(.*)/) {
      $self->license($1);
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

sub svg_header {
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
    map { int($_) } ($minx * $dx * 3/2 - $dx - 60, ($miny - 1.0) * $dy - 50,
		     $maxx * $dx * 3/2 + $dx + 60, ($maxy + 0.5) * $dy + 100);
  my ($width, $height) = ($vx2 - $vx1, $vy2 - $vy1);

  return qq{<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     viewBox="$vx1 $vy1 $vx2 $vy2">
  <!-- min ($minx, $miny), max ($maxx, $maxy) -->
};
}

sub svg_defs {
  my ($self) = @_;
  my $doc = "  <defs>\n";
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
  # also collect all the types with XML definition as these may be referenced
  foreach my $type (keys %{$self->lib}) {
    $types{$type} = 1;
  }
  # now go through them all
  foreach my $type (keys %types) {
    my $path = $self->path($type);
    my $attributes = merge_attributes($self->attributes($type));
    my $path_attributes = merge_attributes($self->path_attributes('default'),
					   $self->path_attributes($type));
    my $lib = $self->lib($type);
    my $xml = $self->xml($type);
    my $glow_attributes = $self->glow_attributes;
    if ($path || $attributes || $lib || $xml) {
      $doc .= qq{    <g id='$type'>\n};
      # just shapes get an outline such as a house (must come first)
      $doc .= qq{      <path $glow_attributes d='$path' />\n}
	if $path && !$attributes;
      # hex with shapes get a hex around them, eg. plains and grass
      if ($attributes && !$lib) {
	my $points = join(" ", map {
	  sprintf("%.1f,%.1f", $_->[0], $_->[1]) } Hex::corners());
	$doc .= qq{      <polygon $attributes points='$points' />\n}
      };
      # the shape
      $doc .= qq{      <path $path_attributes d='$path' />\n}
	if $path;
      $doc .= qq{      $lib\n} if $lib;
      $doc .= qq{      $xml\n} if $xml;
      # close
      $doc .= qq{    </g>\n};
    } else {
      # nothing
    }
  }
  $doc .= qq{  </defs>\n};
}

sub svg_types {
  my $self = shift;
  my $doc = qq{  <g id="types">\n};
  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg_type();
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg_coordinates {
  my $self = shift;
  my $doc = qq{  <g id="coordinates">\n};
  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg_coordinates();
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

sub svg_hexes {
  my ($self) = @_;
  my $doc = qq{  <g id="hexes">\n};
  my $attributes = $self->attributes('default') || qq{fill="none"};
  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg_hex($attributes);
  }
  $doc .= qq{  </g>\n};
}

sub svg_labels {
  my $self = shift;
  my $doc = qq{  <g id="labels">\n};
  foreach my $hex (@{$self->hexes}) {
    $doc .= $hex->svg_label();
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg {
  my ($self) = @_;

  my $doc = $self->svg_header();
  $doc .= $self->svg_defs();
  $doc .= $self->svg_types(); # opaque backgrounds and icons
  $doc .= $self->svg_coordinates();
  $doc .= $self->svg_lines();
  $doc .= $self->svg_hexes();
  $doc .= $self->svg_labels();
  $doc .= $self->license();

  # error messages
  my $y = 10;
  foreach my $msg (@{$self->messages}) {
    $doc .= "  <text x='0' y='$y'>$msg</text>\n";
    $y += 10;
  }

  # source code
  $doc .= "<!-- Source\n" . $self->map() . "\n-->\n";
  $doc .= qq{</svg>\n};

  return $doc;
}

package main;

my %world = ();

my %primary = ("water" => ["water"],
	       "grey swamp" => ["grey swamp"],
	       "sand" => ["sand"],
	       "light-grey grass" => ["light-grey grass"],
	       "green forest" => ["green forest", "green forest",
				  "dark-green forest"],
	       "light-grey hill" => ["light-grey hill"], # canyon?
	       "light-grey mountain" => ["light-grey mountain"]);

my %secondary = ("water" => ["soil", "soil bushes"], # coastal?
		 "grey swamp" => ["light-grey grass", "grey grass"],
		 "sand" => ["light-grey hill", "light-grey hill", "sand hill"],
		 "light-grey grass" => ["green forest"],
		 "green forest" => ["light-green grass", "light-green bush"],
		 "light-grey hill" => ["light-grey mountain",
				       "light-grey mountains"],
		 "light-grey mountain" => ["light-grey hill"]);

my %tertiary = ("water" => ["green forest",
			    "light-green trees", "light-green trees"],
		"grey swamp" => ["green forest"],
		"sand" => ["light-grey grass"],
		"light-grey grass" => ["light-grey hill"],
		"green forest" => ["light-green forest-hill",
				   "light-grey forest-hill",
				   "light-grey hill"],
		"light-grey hill" => ["light-grey grass"],
		"light-grey mountain" => ["green forest", "green trees",
					  "light-green forest-mountains"]);

my %wildcard = ("water" => ["grey swamp", "sand", "light-grey hill"],
		"grey swamp" => ["water"],
		"sand" => ["water", "light-grey mountain"],
		"light-grey grass" => ["water", "grey swamp", "sand"],
		"green forest" => ["water", "grey swamp",
				   "water", "grey swamp",
				   "water", "grey swamp",
				   "light-grey mountains",
				   "light-grey mountains",
				   "light-grey forest-mountains"],
		"light-grey hill" => ["water", "sand",
				      "water", "sand",
				      "water", "sand",
				      "green forest",
				      "green forest",
				      "light-grey forest-hill"],
		"light-grey mountain" => ["sand"]);

my %reverse_lookup = ("water" => "water",
		      "grey swamp" => "grey swamp",
		      "sand" => "sand",
		      "light-grey grass" => "light-grey grass",
		      "grey grass" => "light-grey grass",
		      "soil" => "light-grey grass",
		      "soil bushes" => "light-grey grass",
		      "light-green bush" => "light-grey grass",
		      "light-green grass" => "light-grey grass",
		      "green forest" => "green forest",
		      "dark-green forest" => "green forest",
		      "light-green trees" => "green forest",
		      "green trees" => "green forest",
		      "light-green forest-mountains" => "green forest",
		      "light-grey forest-hill" => "green forest",
		      "light-grey hill" => "light-grey hill",
		      "sand hill" => "light-grey hill",
		      "light-green forest-hill" => "light-grey hill",
		      "light-grey mountain" => "light-grey mountain",
		      "light-grey mountains" => "light-grey mountain",
		      "light-grey forest-mountains" => "light-grey mountain");

sub pick_terrain {
  my $arrayref = shift;
  return $arrayref->[rand @$arrayref];
}

# Precomputed for speed

# Brute forcing by picking random sub hexes until we found an
# unassigned one.

sub pick_unassigned {
  my ($x, $y, @region) = @_;
  my $hex = $region[rand @region];
  my $coordinates = sprintf("%02d%02d", $x + $hex->[0], $y + $hex->[1]);
  while ($world{$coordinates}) {
    $hex = $region[rand @region];
    $coordinates = sprintf("%02d%02d", $x + $hex->[0], $y + $hex->[1]);
  }
  return $coordinates;
}

sub pick_remaining {
  my ($x, $y, @region) = @_;
  my @coordinates = ();
  for my $hex (@region) {
    my $coordinates = sprintf("%02d%02d", $x + $hex->[0], $y + $hex->[1]);
    push(@coordinates, $coordinates) unless $world{$coordinates};
  }
  return @coordinates;
}

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
  $world{sprintf("%02d%02d", $x, $y)} = pick_terrain($primary{$primary});

  my @region = full_hexes($x, $y);
  my $terrain;

  for (1..9) {
    my $coordinates = pick_unassigned($x, $y, @region);
    $terrain = pick_terrain($primary{$primary});
    warn " primary   $coordinates => $terrain\n" if $verbose;
    $world{$coordinates} = $terrain;
  }

  for (1..6) {
    my $coordinates = pick_unassigned($x, $y, @region);
    $terrain =  pick_terrain($secondary{$primary});
    warn " secondary $coordinates => $terrain\n" if $verbose;
    $world{$coordinates} = $terrain;
  }

  for my $coordinates (pick_remaining($x, $y, @region)) {
    if (rand > 0.1) {
      $terrain = pick_terrain($tertiary{$primary});
      warn " tertiary  $coordinates => $terrain\n" if $verbose;
    } else {
      $terrain = pick_terrain($wildcard{$primary});
      warn " wildcard  $coordinates => $terrain\n" if $verbose;
    }
    $world{$coordinates} = $terrain;
  }

  for my $coordinates (pick_remaining($x, $y, half_hexes($x, $y))) {
    my $random = rand 6;
    if ($random < 3) {
      $terrain = pick_terrain($primary{$primary});
      warn "  halfhex primary   $coordinates => $terrain\n" if $verbose;
    } elsif ($random < 5) {
      $terrain = pick_terrain($secondary{$primary});
      warn "  halfhex secondary $coordinates => $terrain\n" if $verbose;
    } else {
      $terrain = pick_terrain($tertiary{$primary});
      warn "  halfhex tertiary  $coordinates => $terrain\n" if $verbose;
    }
    $world{$coordinates} = $terrain;
  }
}

sub seed_region {
  my ($seeds, $primary) = @_;
  my $hex = shift @$seeds;
  warn "seed_region [" . $hex->[0] . "," . $hex->[1] . "] with $primary\n" if $verbose;
  generate_region($hex->[0], $hex->[1], $primary);
  for my $seed (@$seeds) {
    my $terrain;
    my $random = rand 12;
    if ($random < 6) {
      $terrain = pick_terrain($primary{$primary});
      warn " picked primary $terrain\n" if $verbose;
    } elsif ($random < 9) {
      $terrain = pick_terrain($secondary{$primary});
      warn " picked seconary $terrain\n" if $verbose;
    } elsif ($random < 11) {
      $terrain = pick_terrain($tertiary{$primary});
      warn " picked tertiary $terrain\n" if $verbose;
    } else {
      $terrain = pick_terrain($wildcard{$primary});
      warn " picked wildcard $terrain\n" if $verbose;
    }
    die "Terrain lacks reverse_lookup: $terrain\n" unless $reverse_lookup{$terrain};
    seed_region($seed, $reverse_lookup{$terrain});
  }
}

sub generate_map {
  # random seeds

  # for my $x (0..4) {
  #   for my $y (0..3) {
  #     generate_region($x * 5 + 1, $y * 5 + 1 + $x % 2 * 2,
  # 		      $seed_terrain[rand @seed_terrain]);
  #   }
  # }

  # use a spread from the center at [11, 11]
  my $seeds = [[11, 11],
	       [[6, 8],
	        [[1, 6]],
		[[6, 3],
		 [[1,1]]]],
	       [[11, 6],
		[[11, 1]],
		[[16, 3],
		 [[21, 1]]]],
	       [[16, 8],
		[[21, 6]],
		[[21, 11]]],
	       [[16, 13],
		[[21, 16]],
		[[16, 18]]],
	       [[11, 16],
		[[6, 18]]],
	       [[6, 13],
		[[1, 16]],
		[[1, 11]]]];

  my @seed_terrain = keys %primary;
  seed_region($seeds, $seed_terrain[rand @seed_terrain]);

  # delete extra hexes we generated to fill the gaps
  for my $coordinates (keys %world) {
    $coordinates =~ /(..)(..)/;
    delete $world{$coordinates} if $1 < 1 or $2 < 1;
    delete $world{$coordinates} if $1 > 23 or $2 > 18;
  }

  return join("\n", map { $_ . " " . $world{$_} } sort keys %world) . "\n"
    . (url(-base=>1) =~ /localhost/
       ? "include file:///Users/alex/Source/hex-mapping/contrib/gnomeyland.txt\n"
       : "include http://alexschroeder.ch/contrib/gnomeyland.txt\n");
}

sub print_map {
  print header(-type=>'image/svg+xml', -charset=>'utf-8');
  my $map = new Mapper;
  $map->initialize(shift);
  print $map->svg;
}

sub footer {
  return hr()
    . p(a({-href=>'http://www.alexschroeder.ch/wiki/About'},
	  'Alex Schroeder'),
	a({-href=>url() . '/help'}, 'Help'),
	a({-href=>url() . '/source'}, 'Source'),
	a({-href=>'https://github.com/kensanata/hex-mapping'},
	  'GitHub'))
    . end_html();
}

sub print_html {
  print header(-type=>'text/html; charset=UTF-8'),
	start_html(-encoding=>'UTF-8', -title=>'Text Mapper',
		    -author=>'kensanata@gmail.com'),
	h1('Text Mapper'),
	p('Submit your text desciption of the map.'),
	start_form(-method=>'POST'),
	p(textarea(-style => 'width:100%',
		   -name => 'map',
		   -default => Mapper::example(),
		   -rows => 15,
		   -columns => 60, )),
	p(submit(-name => 'submit', -label => 'Submit'),
	  submit(-name => 'generate', -label => 'Random')),
	end_form(),
        footer();
}

sub help {
  eval {
    require Pod::Simple::HTML;
    print header(-type=>'text/html; charset=UTF-8');
    $Pod::Simple::HTML::Doctype_decl =
      q{<!DOCTYPE html>};
    $Pod::Simple::HTML::Content_decl =
      q{<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" >};
    my $parser = Pod::Simple::HTML->new;
    my $html;
    $parser->output_string(\$html);
    $parser->html_footer(footer());
    $parser->html_header_after_title(
      q{</title>
<style type="text/css">
pre {white-space: pre-wrap}
</style>
</head>
<body>});
    seek(DATA,0,0);
    undef $/;
    $parser->parse_string_document(<DATA>);
    print $html;
  };
  if ($@) {
    print header(-type=>'text/plain; charset=UTF-8');
    print "$@\n";
    undef $/;
    print <DATA>;
  }
}

sub main {
  binmode(STDOUT, ':ut8');
  my $map = param('map');
  if (param('generate')) {
    param('map', generate_map());
    print_html();
  } elsif ($map) {
    print_map($map);
  } elsif (path_info() eq '/source') {
    print header(-type=>'text/plain; charset=UTF-8');
    seek(DATA,0,0);
    undef $/;
    print <DATA>;
  } elsif (path_info() eq '/help') {
    help();
  } else {
    print_html();
  }
}

main ();

__DATA__

=head1 Text Mapper

The script parses a text description of a hex map and produces SVG
output.

Here's a small example:

    grass attributes fill="green"
    0101 grass

First, we defined the SVG attributes of a hex B<type> and then we
listed the hexes using their coordinates and their type. Adding more
types and extending the map is easy:

    grass attributes fill="green"
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass
    0202 sea

You might want to define more SVG attributes such as a border around
each hex:

    grass attributes fill="green" stroke="black" stroke-width="1px"
    0101 grass

The attributes for the special type B<default> will be used for the
hex layer that is drawn on top of it all. This is where you define the
I<border>.

    default attributes stroke="black" stroke-width="1px"
    grass attributes fill="green"
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass
    0202 sea

You can define the SVG attributes for the B<text> in coordinates as
well.

    text font-family="monospace" font-size="10pt" dy="-4pt"
    default attributes stroke="black" stroke-width="1px"
    grass attributes fill="green"
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass
    0202 sea

You can provide a text B<label> to use for each hex:

    text font-family="monospace" font-size="10pt" dy="-4pt"
    default attributes stroke="black" stroke-width="1px"
    grass attributes fill="green"
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass
    0202 sea "deep blue sea"

To improve legibility, the SVG output gives you the ability to define
an "outer glow" for your labels by printing them twice and using the
B<glow> attributes for the one in the back. In addition to that, you
can use B<label> to control the text attributes used for these labels.

    text font-family="monospace" font-size="10pt" dy="-4pt"
    label font-family="sans-serif" font-size="12pt"
    glow stroke="white" stroke-width="3pt"
    default attributes stroke="black" stroke-width="1px"
    grass attributes fill="green"
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass
    0202 sea "deep blue sea"

You can define SVG B<path> elements to use for your map. These can be
independent of a type (such as an icon for a settlement) or they can
be part of a type (such as a bit of grass).

Here, we add a bit of grass to the appropriate hex type:

    text font-family="monospace" font-size="10pt" dy="-4pt"
    label font-family="sans-serif" font-size="12pt"
    glow stroke="white" stroke-width="3pt"
    default attributes stroke="black" stroke-width="1px"
    grass attributes fill="green"
    grass path attributes stroke="#458b00" stroke-width="5px"
    grass path M -20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass
    0202 sea "deep blue sea"

Here, we add a settlement:

    text font-family="monospace" font-size="10pt" dy="-4pt"
    label font-family="sans-serif" font-size="12pt"
    glow stroke="white" stroke-width="3pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="green"
    grass path attributes stroke="#458b00" stroke-width="5px"
    grass path M -20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40
    village path attributes fill="none" stroke="black" stroke-width="5px"
    village path M -40,-40 v 80 h 80 v -80 z
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass village "Beachton"
    0202 sea "deep blue sea"

As you can see, you can have multiple types per coordinate, but
obviously only one of them should have the "fill" property (or they
must all be somewhat transparent).

You can also have lines connecting hexes. In order to better control
the flow of these lines, you can provide multiple hexes through which
these lines must pass. These lines can be used for borders, rivers or
roads, for example.

    text font-family="monospace" font-size="10pt" dy="-4pt"
    label font-family="sans-serif" font-size="12pt"
    glow stroke="white" stroke-width="3pt"
    default attributes fill="none" stroke="black" stroke-width="1px"
    grass attributes fill="green"
    grass path attributes stroke="#458b00" stroke-width="5px"
    grass path M -20,-20 l 10,40 M 0,-20 v 40 M 20,-20 l -10,40
    village path attributes fill="none" stroke="black" stroke-width="5px"
    village path M -40,-40 v 80 h 80 v -80 z
    sea attributes fill="blue"
    0101 grass
    0102 sea
    0201 grass village "Beachton"
    0202 sea "deep blue sea"
    border path attributes stroke="red" stroke-width="15" stroke-opacity="0.5" fill-opacity="0"
    0002-0200 border
    road path attributes stroke="black" stroke-width="3" fill-opacity="0" stroke-dasharray="10 10"
    0000-0301 road

Since these definitions get unwieldy, require a lot of work (the path
elements), and to encourage reuse, you can use the B<include>
statement with an URL.

    include http://alexschroeder.ch/contrib/default.txt
    0102 sand
    0103 sand
    0201 sand
    0202 jungle "oasis"
    0203 sand
    0302 sand
    0303 sand

You can find more files ("libraries") to include in the C<contrib>
directory:
L<https://github.com/kensanata/hex-mapping/tree/master/contrib>.

=head2 Random

There's a button to generate a random landscape based on the algorithm
developed by Erin D. Smale. See
L<http://www.welshpiper.com/hex-based-campaign-design-part-1/> for
more information. The output uses the I<Gnomeyland> icons by Gregory
B. MacKenzie. These are licensed under the Creative Commons
Attribution-ShareAlike 3.0 Unported License. To view a copy of this
license, visit L<http://creativecommons.org/licenses/by-sa/3.0/>.

=head2 SVG

You can define shapes using arbitrary SVG using the B<lib> and B<xml>
keywords.

    some-type lib <svg>...</svg>
    some-type xml <svg>...</svg>

The B<lib> keyword causes the item to be included in the resulting
definitions. It acts can be referenced in the B<xml> elements, for
example.

=head2 License

This program is copyright (C) 2007-2013 Alex Schroeder <alex@gnu.org>.

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

    license <text>Public Domain</text>

There can only be I<one> license keyword. If you use multiple
libraries or want to add your own name, you will have to write your
own.

There's a 50 pixel margin around the map, here's how you might
conceivably use it for your own map that uses the I<Gnomeyland> icons
by Gregory B. MacKenzie:

    <license <text x="50" y="-33" font-size="15pt" fill="#999999">Copyright Alex Schroeder 2013. <a style="fill:#8888ff" xlink:href="http://www.busygamemaster.com/art02.html">Gnomeyland Map Icons</a> Copyright Gregory B. MacKenzie 2012.</text><text x="50" y="-15" font-size="15pt" fill="#999999">This work is licensed under the <a style="fill:#8888ff" xlink:href="http://creativecommons.org/licenses/by-sa/3.0/">Creative Commons Attribution-ShareAlike 3.0 Unported License</a>.</text>

Unfortunately, it all has to go on a single line.

=head2 Command Line

You can call the script from the command line. Most likely you'll want
to strip the HTTP headers.

If you specify the map directly, you'll need to replace the newlines
with the URL-escaped variant, %0a. This also means that your map
shouldn't contain any percentage characters. You also need to make
sure you surround the entire map with a whatever quote character you
I<didn't> use in your map.

    perl text-mapper.pl map="grass all='green' stroke='black' stroke-width='1px'%0a0101 grass" | tail -n +3

This quickly gets tedious. Here's how to use the map from a file,
assuming you are using the C<bash> shell.

    perl text-mapper.pl map="$(cat contrib/forgotten-depths.txt)" | tail -n +3

=cut

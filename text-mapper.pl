#!/usr/bin/env perl

package main;
use Modern::Perl;

my $verbose = $ENV{VERBOSE};
my $debug = $ENV{DEBUG};
my $output;
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
	my $a = $current->partway($next, 0.3);
	my $b = $current->partway($next, 0.5);
	my $c = $points[$#points-1]->partway($current, 0.7);
	my $d = $points[$#points-1]->partway($current, 0.5);
	$path = "M$d C$c $a $b";
      } else {
	# continue curve
	my $a = $current->partway($next, 0.3);
	my $b = $current->partway($next, 0.5);
	$path .= " S$a $b";
      }
    }
  } else {
    for my $i (0 .. $#points - 1) {
      $current = $points[$i];
      $next = $points[$i+1];
      if (!$path) {
	# line from a to b; control point a required for following S commands
	my $a = $current->partway($next, 0.3);
	my $b = $current->partway($next, 0.5);
	$path = "M$a C$b $a $b";
      } else {
	# continue curve
	my $a = $current->partway($next, 0.3);
	my $b = $current->partway($next, 0.5);
	$path .= " S$a $b";
      }
    }
    # end with a little stub
    $path .= " L" . $current->partway($next, 0.7);
  }

  my $type = $self->type;
  my $attributes = $self->map->path_attributes($type);
  my $data = "    <path $attributes d='$path'/>\n";
  $data .= $self->debug($closed) if $debug;
  return $data;
}

sub debug {
  my ($self, $closed) = @_;
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

  my ($x, $y) = $points[0]->pixels; $y += 30;
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

package Hex;

use Class::Struct;

struct Hex => {
	       x => '$',
	       y => '$',
	       type => '$',
	       label => '$',
	       size => '$',
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
  $data .= sprintf(qq{%02d.%02d}, $x, $y);
  $data .= qq{</text>\n};
  return $data;
}

sub url_encode {
  my $str = shift;
  return '' unless $str;
  utf8::encode($str); # turn to byte string
  my @letters = split(//, $str);
  my %safe = map {$_ => 1} ('a' .. 'z', 'A' .. 'Z', '0' .. '9', '-', '_', '.', '!', '~', '*', "'", '(', ')', '#');
  foreach my $letter (@letters) {
    $letter = sprintf("%%%02x", ord($letter)) unless $safe{$letter};
  }
  return join('', @letters);
}

sub svg_label {
  my ($self, $url) = @_;
  return '' unless $self->label;
  my $attributes = $self->map->label_attributes;
  if ($self->size) {
    if (not $attributes =~ s/\bfont-size="\d+pt"/'font-size="' . $self->size . 'pt"'/e) {
      $attributes .= ' font-size="' . $self->size . '"';
    }
  }
  $url =~ s/\%s/url_encode($self->label)/e or $url .= url_encode($self->label) if $url;
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

package Mapper;

use Class::Struct;
use LWP::UserAgent;

struct Mapper => {
		  hexes => '@',
		  attributes => '%',
		  defs => '@',
		  map => '$',
		  path => '%',
		  lines => '@',
		  things => '@',
		  path_attributes => '%',
		  text_attributes => '$',
		  glow_attributes => '$',
		  label_attributes => '$',
		  messages => '@',
		  seen => '%',
		  license => '$',
		  other => '@',
		  url => '$',
		 };

my $example = <<'EOT';
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
0502 sand "sand"
0205-0103-0202-0303-0402 road
0101-0203 river
0401-0303-0403 border
include https://campaignwiki.org/contrib/default.txt
license <text>Public Domain</text>
EOT

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
    if (/^(\d\d)(\d\d)(?:\s+([^"\r\n]+)?\s*(?:"(.+)"(?:\s+(\d+))?)?|$)/) {
      my $hex = Hex->new(x => $1, y => $2, map => $self);
      $hex->label($4);
      $hex->size($5);
      my @types = split(' ', $3);
      $hex->type(\@types);
      push(@{$self->hexes}, $hex);
      push(@{$self->things}, $hex);
    } elsif (/^(\d\d\d\d(?:-\d\d\d\d)+)\s+(\S+)/) {
      my $line = Line->new(map => $self);
      $line->type($2);
      my @points = map { my $point = Point->new(x => substr($_, 0, 2),
						y => substr($_, 2, 2));
		       } split(/-/, $1);
      $line->points(\@points);
      push(@{$self->lines}, $line);
      push(@{$self->things}, $line);
    } elsif (/^(\S+)\s+attributes\s+(.*)/) {
      $self->attributes($1, $2);
    } elsif (/^(\S+)\s+lib\s+(.*)/) {
      $self->def(qq{<g id="$1">$2</g>});
    } elsif (/^(\S+)\s+xml\s+(.*)/) {
      $self->def(qq{<g id="$1">$2</g>});
    } elsif (/^(<.*>)/) {
      $self->def($1);
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
    } elsif (/^other\s+(.*)/) {
      push(@{$self->other()}, $1);
    } elsif (/^url\s+(\S+)/) {
      $self->url($1);
    } elsif (/^include\s+(\S*)/) {
      if (scalar keys %{$self->seen} > 5) {
	push(@{$self->messages},
	     "Includes are limited to five to prevent loops");
      } elsif ($self->seen($1)) {
	push(@{$self->messages}, "$1 was included twice");
      } else {
	$self->seen($1, 1);
	my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 1 });
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

  if (defined($minx) and defined($maxx) and defined($miny) and defined($maxy)) {

    my ($vx1, $vy1, $vx2, $vy2) =
        map { int($_) } ($minx * $dx * 3/2 - $dx - 60, ($miny - 1.0) * $dy - 50,
                         $maxx * $dx * 3/2 + $dx + 60, ($maxy + 0.5) * $dy + 100);
    my ($width, $height) = ($vx2 - $vx1, $vy2 - $vy1);

    $header .= qq{     viewBox="$vx1 $vy1 $width $height">\n};
    $header .= qq{     <!-- min ($minx, $miny), max ($maxx, $maxy) -->\n};
  }

  return $header;
}

sub svg_defs {
  my ($self) = @_;
  # All the definitions are included by default.
  my $doc = "  <defs>\n";
  $doc .= "    " . join("\n    ", @{$self->defs}) if @{$self->defs};
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
  foreach my $type (sort keys %types) {
    my $path = $self->path($type);
    my $attributes = merge_attributes($self->attributes($type));
    my $path_attributes = merge_attributes($self->path_attributes('default'),
					   $self->path_attributes($type));
    my $glow_attributes = $self->glow_attributes;
    if ($path || $attributes) {
      $doc .= qq{    <g id='$type'>\n};
      # just shapes get a glow such, eg. a house (must come first)
      if ($path && !$attributes) {
	$doc .= qq{      <path $glow_attributes d='$path' />\n}
      }
      # hex with shapes get a hex around them, eg. plains and grass
      if ($attributes) {
	my $points = join(" ", map {
	  sprintf("%.1f,%.1f", $_->[0], $_->[1]) } Hex::corners());
	$doc .= qq{      <polygon $attributes points='$points' />\n}
      };
      # the shape
      $doc .= qq{      <path $path_attributes d='$path' />\n}
	if $path;
      # close
      $doc .= qq{    </g>\n};
    } else {
      # nothing
    }
  }
  $doc .= qq{  </defs>\n};
}

sub svg_things {
  my $self = shift;
  my $doc = qq{  <g id="things">\n};
  foreach my $thing (@{$self->things}) {
    $doc .= $thing->svg();
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
    $doc .= $hex->svg_label($self->url);
  }
  $doc .= qq{  </g>\n};
  return $doc;
}

sub svg {
  my ($self) = @_;

  my $doc = $self->svg_header();
  $doc .= $self->svg_defs();
  $doc .= $self->svg_lines();
  $doc .= $self->svg_things(); # opaque backgrounds, icons, lines
  $doc .= $self->svg_coordinates();
  $doc .= $self->svg_hexes();
  $doc .= $self->svg_labels();
  $doc .= $self->license() ||'';
  $doc .= join("\n", @{$self->other()}) . "\n";

  # error messages
  my $y = 10;
  foreach my $msg (@{$self->messages}) {
    $doc .= "  <text x='0' y='$y'>$msg</text>\n";
    $y += 10;
  }

  # source code
  $doc .= "<!-- Source\n" . $self->map() . "\n-->\n";
  $doc .= "<!-- Output\n" . $output . "\n-->\n" if $output;
  $doc .= qq{</svg>\n};

  return $doc;
}

package Smale;
    
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
  return unless $verbose;
  my $str = shift;
  warn $str;
}

sub place_major {
  my ($x, $y, $encounter) = @_;
  my $thing = one(@{$encounters{$encounter}});
  return unless $thing;
  verbose("placing $thing ($encounter) at ($x,$y)\n");
  my $hex = one(full_hexes($x, $y));
  $x += $hex->[0];
  $y += $hex->[1];
  my $coordinates = sprintf("%02d%02d", $x, $y);
  my $primary = $reverse_lookup{$world{$coordinates}};
  my ($color, $terrain) = split(' ', $world{$coordinates}, 2);
  if ($encounter eq 'settlement') {
    if ($primary eq 'plains') {
      $color = one('light-soil', 'soil');
      verbose(" " . $world{$coordinates} . " is $primary and was changed to $color\n");
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
  my $coordinates = sprintf("%02d%02d", $x + $hex->[0], $y + $hex->[1]);
  while ($world{$coordinates}) {
    $hex = one(@region);
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
  $world{sprintf("%02d%02d", $x, $y)} = one($primary{$primary});

  my @region = full_hexes($x, $y);
  my $terrain;

  for (1..9) {
    my $coordinates = pick_unassigned($x, $y, @region);
    $terrain = one($primary{$primary});
    verbose(" primary   $coordinates => $terrain\n");
    $world{$coordinates} = $terrain;
  }

  for (1..6) {
    my $coordinates = pick_unassigned($x, $y, @region);
    $terrain =  one($secondary{$primary});
    verbose(" secondary $coordinates => $terrain\n");
    $world{$coordinates} = $terrain;
  }

  for my $coordinates (pick_remaining($x, $y, @region)) {
    if (rand > 0.1) {
      $terrain = one($tertiary{$primary});
      verbose(" tertiary  $coordinates => $terrain\n");
    } else {
      $terrain = one($wildcard{$primary});
      verbose(" wildcard  $coordinates => $terrain\n");
    }
    $world{$coordinates} = $terrain;
  }

  for my $coordinates (pick_remaining($x, $y, half_hexes($x, $y))) {
    my $random = rand 6;
    if ($random < 3) {
      $terrain = one($primary{$primary});
      verbose("  halfhex primary   $coordinates => $terrain\n");
    } elsif ($random < 5) {
      $terrain = one($secondary{$primary});
      verbose("  halfhex secondary $coordinates => $terrain\n");
    } else {
      $terrain = one($tertiary{$primary});
      verbose("  halfhex tertiary  $coordinates => $terrain\n");
    }
    $world{$coordinates} = $terrain;
  }
}

sub seed_region {
  my ($seeds, $primary) = @_;
  my $hex = shift @$seeds;
  verbose("seed_region (" . $hex->[0] . "," . $hex->[1] . ") with $primary\n");
  generate_region($hex->[0], $hex->[1], $primary);
  for my $seed (@$seeds) {
    my $terrain;
    my $random = rand 12;
    if ($random < 6) {
      $terrain = one($primary{$primary});
      verbose("picked primary $terrain\n");
    } elsif ($random < 9) {
      $terrain = one($secondary{$primary});
      verbose("picked secondary $terrain\n");
    } elsif ($random < 11) {
      $terrain = one($tertiary{$primary});
      verbose("picked tertiary $terrain\n");
    } else {
      $terrain = one($wildcard{$primary});
      verbose("picked wildcard $terrain\n");
    }
    die "Terrain lacks reverse_lookup: $terrain\n" unless $reverse_lookup{$terrain};
    seed_region($seed, $reverse_lookup{$terrain});
  }
  populate_region($hex, $primary);
}

sub agriculture {
  for my $hex (@needs_fields) {
    verbose("looking to plant fields near " . sprintf("%02d%02d", $hex->[0], $hex->[1]) . "\n");
    my $delta = [[[-1,  0], [ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1]],  # x is even
		 [[-1, -1], [ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0]]]; # x is odd
    my @plains;
    for my $i (0 .. 5) {
      my ($x, $y) = ($hex->[0] + $delta->[$hex->[0] % 2]->[$i]->[0],
		     $hex->[1] + $delta->[$hex->[0] % 2]->[$i]->[1]);
      my $coordinates = sprintf("%02d%02d", $x, $y);
      if ($world{$coordinates}) {
	my ($color, $terrain) = split(' ', $world{$coordinates}, 2);
	verbose("  $coordinates is " . $world{$coordinates} . " ie. " . $reverse_lookup{$world{$coordinates}} . "\n");
	if ($reverse_lookup{$world{$coordinates}} eq 'plains') {
	  verbose("   $coordinates is a candidate\n");
	  push(@plains, $coordinates);
	}
      }
    }
    next unless @plains;
    my $target = one(@plains);
    $world{$target} = one('light-soil fields', 'soil fields');
    verbose(" $target planted with " . $world{$target} . "\n");
  }
}

sub generate_map {
  my $bw = shift;

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

  %world = (); # reinitialize!

  my @seed_terrain = keys %primary;
  seed_region($seeds, one(@seed_terrain));
  agriculture();
  
  # delete extra hexes we generated to fill the gaps
  for my $coordinates (keys %world) {
    $coordinates =~ /(..)(..)/;
    delete $world{$coordinates} if $1 < 1 or $2 < 1;
    delete $world{$coordinates} if $1 > 23 or $2 > 18;
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
    . "include https://campaignwiki.org/contrib/gnomeyland.txt\n";
}

package Schroeder;
use Modern::Perl;
use List::Util 'shuffle';
    
# The world is a reference to a hash where the key are the coordinates in the
# form "0105" and the value is whatever is the map description, so it can be a
# number of types, plus a label, plus maybe a font size, etc.

# We're assuming that $width and $height have two digits (10 <= n <= 99).

my $width = 20;
my $height = 10;

my $delta = [[[-1,  0], [ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1]],  # x is even
	     [[-1, -1], [ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0]]]; # x is odd

sub neighbor {
  # $hex is [x,y] or "0x0y" and $i is a number 0 .. 5
  my ($hex, $i) = @_;
  $hex = [substr($hex, 0, 2), substr($hex, 2)] unless ref $hex;
  return ($hex->[0] + $delta->[$hex->[0] % 2]->[$i]->[0],
	  $hex->[1] + $delta->[$hex->[0] % 2]->[$i]->[1]);
}

sub distance {
  my ($x1, $y1, $x2, $y2) = @_;
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

sub remove_closer_than {
  my ($limit, @hexes) = @_;
  my @filtered;
 HEX:
  for my $hex (@hexes) {
    my ($x1, $y1) = (substr($hex, 0, 2), substr($hex, 2));
    # check distances with all the hexes already in the list
    for my $existing (@filtered) {
      my ($x2, $y2) = (substr($existing, 0, 2), substr($existing, 2));
      my $distance = distance($x1, $y1, $x2, $y2);
      # warn "Distance between $x1$y1 and $x2$y2 is $distance\n";
      next HEX if $distance < $limit;
    }
    # if this hex wasn't skipped, it goes on to the list
    push(@filtered, $hex);
  }
  return @filtered;
}

sub flat {
  # initialize the altitude map
  my ($world, $altitude) = @_;
  for my $y (1 .. $height) {
    for my $x (1 .. $width) {
      my $coordinates = sprintf("%02d%02d", $x, $y);
      $world->{$coordinates} = 'empty';
      $altitude->{$coordinates} = 0;
    }
  }
}

sub height {
  my ($world, $altitude) = @_;
  my $current_altitude = 10;
  my @batch;
  # place some peaks and put them in a batch
  for (1 .. int($width * $height / 20)) {
    # try to find an empty hex
    for (1 .. 6) {
      my $x = int(rand($width)) + 1;
      my $y = int(rand($height)) + 1;
      my $coordinates = sprintf("%02d%02d", $x, $y);
      next if $altitude->{$coordinates};
      $altitude->{$coordinates} = $current_altitude;
      push(@batch, [$x, $y]);
      $world->{$coordinates} = qq{mountains "$current_altitude"};
      # warn "Peak $coordinates\n";
      last;
    }
  }
  # go through the batch and add adjacent lower altitude hexes, if possible; the
  # hexes added are the next batch to look at
  while (--$current_altitude >= 0) {
    # warn "Altitude $current_altitude\n";
    my @next;
    for my $hex (@batch) {
      my @plains;
      # pick some random neighbors
      for (1 .. 2) {
	# try to find an empty neighbor; abort after six attempts
	for (1 .. 6) {
	  my ($x, $y) = neighbor($hex, int(rand(6)));
	  next if $x <= 0 or $x > $width or $y <= 0 or $y > $height;
	  my $coordinates = sprintf("%02d%02d", $x, $y);
	  next if $altitude->{$coordinates};
	  # if we found an empty neighbor, set its altitude
	  $altitude->{$coordinates} = $current_altitude;
	  # warn "picked $coordinates near $hex->[0]$hex->[1]\n";
	  push(@next, [$x, $y]);
	  if ($current_altitude >= 9) {
	    $world->{$coordinates} = qq{mountain "$current_altitude"};
	  } elsif ($current_altitude >= 8) {
	    $world->{$coordinates} = qq{light-grey mountain "$current_altitude"};
	  } else {
	    $world->{$coordinates} = qq{empty "$current_altitude"}; # must be overwritten!
	  }
	  last;
	}
      }
    }
    last unless @next;
    @batch = @next;
  }
  # find hexes that we missed and give them the height of a random neighbor
  for my $coordinates (keys %$altitude) {
    if (not $altitude->{$coordinates}) {
      # warn "identified a hex that was skipped: $coordinates\n";
      # keep trying until we find one
      while (1) {
	my ($x, $y) = neighbor($coordinates, int(rand(6)));
	next if $x <= 0 or $x > $width or $y <= 0 or $y > $height;
	my $other = sprintf("%02d%02d", $x, $y);
	next unless $altitude->{$other};
	$altitude->{$coordinates} = $altitude->{$other};
	$world->{$coordinates} = qq{empty "height$altitude->{$other}"};
	last;
      }
    }
  }
}

sub lakes {
  # local minima of exactly size 1 are lakes
  my ($world, $altitude) = @_;
 HEX:
  for my $coordinates (keys %$altitude) {
    for my $i (0 .. 5) {
      my ($x, $y) = neighbor($coordinates, $i);
      # there are no lakes at the edge of the map
      next HEX if $x <= 0 or $x > $width or $y <= 0 or $y > $height;
      my $other = sprintf("%02d%02d", $x, $y);
      next HEX if $altitude->{$other} <= $altitude->{$coordinates};
    }
    # if no lower neighbor was found, this is a lake
    $world->{$coordinates} = qq{water "$altitude->{$coordinates}"};
  }  
}

sub swamps {
  # swamps form whenever there is no immediate neighbor that is lower
  my ($world, $altitude) = @_;
 HEX:
  for my $coordinates (keys %$altitude) {
    next if $world->{$coordinates} =~ /^water/;
    # check the neighbors
    for my $i (0 .. 5) {
      my ($x, $y) = neighbor($coordinates, $i);
      # ignore neighbors beyond the edge of the map
      next if $x <= 0 or $x > $width or $y <= 0 or $y > $height;
      my $other = sprintf("%02d%02d", $x, $y);
      next HEX if $altitude->{$other} < $altitude->{$coordinates};
    }
    # if there was no lower neighbor, this is a swamp
    if ($altitude->{$coordinates} >= 6) {
      $world->{$coordinates} = qq{grey swamp "$altitude->{$coordinates}"};
    } else {
      $world->{$coordinates} = qq{dark-grey swamp "$altitude->{$coordinates}"};
    }
  }
}

sub river_mouths {
  my ($altitude) = @_;
  # hexes along the edge of the map in a random order
  my @hexes = shuffle(grep /^01|^$width|01$|$height$/, keys %$altitude);
  # sort by altitude since we want low lying edge hexes
  @hexes = sort { $altitude->{$a} <=> $altitude->{$b} } @hexes;
  # remove hexes that are too close to each other
  @hexes = remove_closer_than(10, @hexes);
  # limit to a smaller number proportional to the map circumference
  # warn "Hexes unlimited: @hexes\n";
  @hexes = @hexes[0 .. $height * $width / 100 - 1] if @hexes > $height * $width / 100;
  # warn "River mouths: @hexes\n";
  # rivers look better if we start them outside of the map
  for my $hex (@hexes) {
    $hex =~ s/^01/00/ or $hex =~ s/01$/00/
	or $hex =~s/^$width/$width+1/e
	or $hex =~s/$height$/$height+1/e;
  }
  # warn "Hexes outside: @hexes\n";
  return @hexes;
}

sub flow {
  my ($world, $altitude, $water, $rivers, $growing, $n) = @_;
  # $rivers lists the rivers that have finished growing; $growing lists the
  # rivers actively growing; $n is the current river in this list, the head of
  # the river is the current position; $water shows if there is a river in that
  # hex
  my $coordinates = $growing->[$n]->[0];
  my @up;
  # check the neighbors
  for my $i (0 .. 5) {
    my ($x, $y) = neighbor($coordinates, $i);
    # ignore neighbors beyond the edge of the map
    next if $x <= 0 or $x > $width or $y <= 0 or $y > $height;
    # ignore neighbors that already have a river in them
    my $other = sprintf("%02d%02d", $x, $y);
    next if defined $water->{$other};
    # ignore neighbors that are high up
    next if $altitude->{$other} >= 9;
    # collect candidates
    if (not defined $altitude->{$coordinates} # possibly outside the map!
	or $altitude->{$other} >= $altitude->{$coordinates}
	or $world->{$other} =~ /water/) {
      push(@up, [$i, $other]);
    }
  }
  # warn "up from $coordinates: " . join(', ', map { $_->[1] } @up) . "\n";
  # add one of the candidates to the head of the list
  my $first = shift(@up);
  # add a copy of the river for the rest
  for my $next (@up) {
    my $i = $next->[0];
    my $other = $next->[1];
    $water->{$other} = $i;
    # warn "adding a new river: " . join('-', $other, @{$growing->[$n]}) . "\n";
    push(@$growing, [$other, @{$growing->[$n]}]);
  }
  if ($first) {
    my $i = $first->[0];
    my $other = $first->[1];
    $water->{$other} = $i;
    unshift(@{$growing->[$n]}, $other);
    # warn "extending river $n: @{$growing->[$n]}\n";
  } else {
    # if we're no longer growing, remove this river from the growing list and
    # add it to the done rivers
    my @done = splice(@$growing, $n, 1);
    push(@$rivers, @done);
    # and place a hill at the source
    if ($world->{$coordinates} !~ /mountain|swamp/) {
      if ($altitude->{$coordinates} >= 6) {
	$world->{$coordinates} = qq{light-grey fir-hill "$altitude->{$coordinates}"};
      } else {
	$world->{$coordinates} = qq{grey forest-hill "$altitude->{$coordinates}"};
      }
    }
  }
}

sub rivers {
  my ($world, $altitude, $water, $rivers) = @_;
  my @mouths = river_mouths($altitude);
  # warn "River mouths: @mouths\n";
  my @growing = map { [$_] } @mouths;
  # don't just grow one river until you're done or it will take up all the map
  while (@growing) {
    my $n = int(rand(scalar @growing));
    # warn "looking to extend river $n, currently @{$growing[$n]}\n";
    flow($world, $altitude, $water, $rivers, \@growing, $n);
  }
  # add arrows to the map to visualize in which direction water wants to flow
  # for my $coordinates (keys %$world) {
  #   my $i = $water->{$coordinates};
  #   $world->{$coordinates} =~ s/ / arrow$i / if defined $i;
  # }
}

sub forests {
  my ($world, $altitude, $water) = @_;
  # empty hexes with a river flowing through them are forest filled valleys
  for my $coordinates (keys %$world) {
    if ($world->{$coordinates} =~ /empty/ and defined $water->{$coordinates}) {
      if ($altitude->{$coordinates} >= 6) {
	$world->{$coordinates} = qq{light-green fir-forest "$altitude->{$coordinates}"};
      } elsif ($altitude->{$coordinates} >= 4) {
	$world->{$coordinates} = qq{green forest "$altitude->{$coordinates}"};
      } else {
	$world->{$coordinates} = qq{dark-green forest "$altitude->{$coordinates}"};
      }
    }
  }
}

sub cities {
  my ($world) = @_;
  my $max = $height * $width;
  my @candidates = grep { $world->{$_} =~ /^light-green fir-forest / } keys %$world;
  @candidates = remove_closer_than(2, @candidates);
  @candidates = @candidates[0 .. int($max/10 - 1)] if @candidates > $max/10;
  # warn "thorps: @candidates\n";
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/fir-forest/firs thorp/;
  }
  @candidates = grep { $world->{$_} =~ /^green forest / } keys %$world;
  @candidates = remove_closer_than(5, @candidates);
  @candidates = @candidates[0 .. int($max/20 - 1)] if @candidates > $max/20;
  # warn "villages: @candidates\n";
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/forest/trees village/;
  }
  @candidates = grep { $world->{$_} =~ /^dark-green forest / } keys %$world;
  @candidates = remove_closer_than(10, @candidates);
  @candidates = @candidates[0 .. int($max/40 - 1)] if @candidates > $max/40;
  # warn "towns: @candidates\n";
  for my $coordinates (@candidates) {
    $world->{$coordinates} =~ s/forest/trees town/;
  }
}

sub plains {
  my ($world, $altitude, $water) = @_;
  for my $coordinates (keys %$world) {
    if ($world->{$coordinates} =~ /empty/) {
      if ($altitude->{$coordinates} >= 7) {
	$world->{$coordinates} = qq{light-grey grass "$altitude->{$coordinates}"};
      } else {
	$world->{$coordinates} = qq{light-green grass "$altitude->{$coordinates}"};
      }
    }
  }
}

sub generate_map {
  my (%world, %altitude, %water, @rivers);
  flat(\%world, \%altitude);
  height(\%world, \%altitude);
  lakes(\%world, \%altitude);
  swamps(\%world, \%altitude);
  rivers(\%world, \%altitude, \%water, \@rivers);
  forests(\%world, \%altitude, \%water);
  cities(\%world);
  plains(\%world, \%altitude, \%water);
  return join("\n",
	      # qq{<marker id="arrow" markerWidth="6" markerHeight="6" refX="6" refY="3" orient="auto"><path d="M6,0 V6 L0,3 Z" style="fill: black;" /></marker>},
	      # qq{<path id="arrow0" d="M11.5,5.8 L-11.5,-5.8" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
	      # qq{<path id="arrow1" d="M0,10 V-20" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
	      # qq{<path id="arrow2" d="M-11.5,5.8 L11.5,-5.8" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
	      # qq{<path id="arrow3" d="M-11.5,-5.8 L11.5,5.8" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
	      # qq{<path id="arrow4" d="M0,-10 V20" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
	      # qq{<path id="arrow5" d="M11.5,-5.8 L-11.5,5.8" style="stroke: black; stroke-width: 3px; fill: none; marker-start: url(#arrow);"/>},
	      # (map {
	      # 	my $n = int(25.5 * $_);
	      # 	qq{height$_ attributes fill="rgb($n,$n,$n)"};
	      # } (0 .. 10)),
	      # (map {
	      # 	my $n = int(25.5 * $_);
	      # 	qq{lake$_ attributes fill="rgb($n,$n,255)"};
	      #  } (0 .. 10)),
	      # (map {
	      # 	my $n = int(20 * $_);
	      # 	my $g = $n + 50;
	      # 	qq{swamp$_ attributes fill="rgb($n,$g,$n)"};
	      #  } (0 .. 10)),
	      (map { $_ . " " . $world{$_} } sort keys %world),
	      qq{river path attributes transform="translate(20,10)" stroke="#6ebae7" stroke-width="8" fill="none" opacity="0.7"},
	      (map { join('-', @$_) . " river" } @rivers),
	      "include https://campaignwiki.org/contrib/gnomeyland.txt\n");
}

package Mojolicious::Command::render;
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
  my $map = new Mapper;
  $map->initialize(<STDIN>);
  print $map->svg;
}

package Mojolicious::Command::random;
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

use Mojolicious::Lite;
use Mojo::DOM;
use Mojo::Util qw(xml_escape);
use Pod::Simple::HTML;
use Pod::Simple::Text;

get '/' => sub {
  my $c = shift;
  my $param = $c->param('map');
  if ($param) {
    my $map = new Mapper;
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
  my $map = new Mapper;
  $map->initialize($c->param('map'));
  $c->render(text => $map->svg, format => 'svg');
};

get '/random' => sub {
  my $c = shift;
  my $bw = $c->param('bw');
  $c->render(template => 'edit', map => Smale::generate_map($bw));
};

get '/alpine' => sub {
  my $c = shift;
  $c->render(template => 'edit', map => Schroeder::generate_map());
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

You can also have lines connecting hexes. In order to better control
the flow of these lines, you can provide multiple hexes through which
these lines must pass. These lines can be used for borders, rivers or
roads, for example.

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
    0002-0200 border
    road path attributes stroke="black" stroke-width="3" fill-opacity="0" stroke-dasharray="10 10"
    0000-0301 road

=head3 Include a Library

Since these definitions get unwieldy, require a lot of work (the path
elements), and to encourage reuse, you can use the B<include>
statement with an URL.

    include https://campaignwiki.org/contrib/default.txt
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

=head3 Large Areas

If you want to surround a piece of land with a round shore line, a
forest with a large green shadow, you can achieve this using a line
that connects to itself. These "closed" lines can have C<fill> in
their path attributes. In the following example, the oasis is
surrounded by a larger green area.

    include https://campaignwiki.org/contrib/default.txt
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

=head2 Random

There's a button to generate a random landscape based on the algorithm
developed by Erin D. Smale. See
L<http://www.welshpiper.com/hex-based-campaign-design-part-1/> and
L<http://www.welshpiper.com/hex-based-campaign-design-part-2/> for
more information. The output uses the I<Gnomeyland> icons by Gregory
B. MacKenzie. These are licensed under the Creative Commons
Attribution-ShareAlike 3.0 Unported License. To view a copy of this
license, visit L<http://creativecommons.org/licenses/by-sa/3.0/>.

If you're curious: (11,11) is the starting hex.

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

This program is copyright (C) 2007-2016 Alex Schroeder <alex@gnu.org>.

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

=head2 Examples

=head3 Default

Source of the map:
L<http://themetalearth.blogspot.ch/2011/03/opd-entry.html>

Example data:
L<https://campaignwiki.org/contrib/forgotten-depths.txt>

Library:
L<https://campaignwiki.org/contrib/default.txt>

Result:
L<https://campaignwiki.org/text-mapper?map=include+https://campaignwiki.org/contrib/forgotten-depths.txt>

=head3 Gnomeyland

Example data:
L<https://campaignwiki.org/contrib/gnomeyland-example.txt>

Library:
L<https://campaignwiki.org/contrib/gnomeyland.txt>

Result:
L<https://campaignwiki.org/text-mapper?map=include+https://campaignwiki.org/contrib/gnomeyland-example.txt>

=head3 Traveller

Example:
L<https://campaignwiki.org/contrib/traveller-example.txt>

Library:
L<https://campaignwiki.org/contrib/traveller.txt>

Result:
L<https://campaignwiki.org/text-mapper?map=include+https://campaignwiki.org/contrib/traveller-example.txt>

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
<p>Submit your text desciption of the map.</p>
%= form_for render => (method => 'POST') => begin
%= text_area map => (cols => 60, rows => 15) => begin
<%= $map =%>
% end

<p>
%= submit_button 'Submit', name => 'submit'
%= end
</p>

<p>
<%= link_to random => begin %>Random<% end %>
will generate map data based on Erin D. Smale's <em>Hex-Based Campaign Design</em>
(<a href="http://www.welshpiper.com/hex-based-campaign-design-part-1/">Part 1</a>,
<a href="http://www.welshpiper.com/hex-based-campaign-design-part-2/">Part 2</a>).
You can also generate a random map
<%= link_to link_to url_for('random')->query(bw => 1)->to_abs => begin %>with no background colors<% end %>. Click the submit button to generate the map itself.
</p>
<p>
<%= link_to alpine => begin %>Alpine<% end %> will generate map data based on Alex
Schroeder's algorithm that's trying to recreate a medieval Swiss landscape, with
no info to back it up, whatsoever. Click the submit button to generate the map itself.
</p>

@@ render.svg.ep


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
<a href="https://campaignwiki.org/text-mapper">Text Mapper</a>&#x2003;
<%= link_to 'Help' => 'help' %>&#x2003;
<%= link_to 'Source' => 'source' %>&#x2003;
<a href="https://github.com/kensanata/hex-mapping/blob/master/text-mapper.pl">GitHub</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

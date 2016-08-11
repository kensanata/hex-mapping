#! /home/alex/perl5/perlbrew/perls/perl-5.25.1/bin/perl
# Copyright (C) 2011  Alex Schroeder <alex@gnu.org>
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
use POSIX qw(INT_MAX);
use CGI qw(:standard);
use SVG;
use Math::Geometry::Voronoi;
use Math::Fractal::Noisemaker;

my $points = 3000;
my $width  = 1000;
my $height =  550;
my $center_x = $width / 2;
my $center_y = $height / 2;
my $radius = 500;

my %color = (beach => '#a09077',
	     grass => '#88aa55',
	     forest => '#679459',
	     taiga => '#99aa77',
	     tundra => '#bbbbaa',
	     snow => '#ffffff',
	     glacier => '#eeeeee',
	     bare => '#888888',
	     ocean => '#44447a',
	     coast => '#55559a',
	     lake => '#336699',
	     swamp => '#337755', );

package World;
use Class::Struct;
use List::Util qw(min max);
use Memoize;

struct World => { points  => '@',
		  centroids => '@', # matches points
		  voronoi => '$',
		  height  => '@', # matches points
		  terrain => '@', # matches points
		  border  => '@', # matches points
		  visible => '@', # matches points
		  water   => '@', # matches points
		  downslope   => '@', # matches points
		};

sub neighbours {
  my ($world, $i) = @_;
  my @points;
  foreach my $line (@{$world->voronoi->lines}) {
    push(@points, $line->[3]) if $i == $line->[4];
    push(@points, $line->[4]) if $i == $line->[3];
  }
  return \@points;
}

memoize('neighbours');

sub add_border {
  my ($world) = @_;
  foreach my $polygon ($world->voronoi->polygons) {
    my ($i, @corners) = @$polygon; # see Math::Geometry::Voronoi
    my $visible = 0;
    my $border = 0;
    foreach my $corner (@corners) {
      my $x = $corner->[0];
      my $y = $corner->[1];
      if (!$visible and $x >= 0 and $y >= 0 and $x <= $width and $y <= $height) {
	$visible = 1;
      }
      if ($x < 0 or $y < 0 or $x > $width or $y > $height) {
	$border = 1;
	last if $visible; # got all the info
      }
    }
    $world->border($i, $border);
    $world->visible($i, $visible);
  }
}

sub add_random_points {
  my ($world) = @_;
  for my $i (1 .. $points) {
    push(@{$world->points}, [rand($width), rand($height)]);
  };
  return $world;
}

sub add_voronoi {
  my ($world) = @_;
  $world->voronoi(Math::Geometry::Voronoi->new(points => $world->points));
  $world->voronoi->compute;
}

sub add_centroids {
  my ($world) = @_;
  $world->centroids([]); # clear
  foreach my $polygon ($world->voronoi->polygons) {
    push(@{$world->centroids}, centroid($polygon));
  }
}

sub centroid {
  my ($cx, $cy) = (0, 0);
  my $A = 0;
  my $polygon = shift;
  my ($point_index, @points) = @$polygon; # see Math::Geometry::Voronoi
  my $point = $points[$#points];
  my ($x0, $y0) = ($point->[0], $point->[1]);
  for $point (@points) {
    my ($x1, $y1) = ($point->[0], $point->[1]);
    $cx += ($x0 + $x1) * ($x0 * $y1 - $x1 * $y0);
    $cy += ($y0 + $y1) * ($x0 * $y1 - $x1 * $y0);
    $A += ($x0 * $y1 - $x1 * $y0);
    ($x0, $y0) = ($x1, $y1);
  }
  $A /= 2;
  $cx /= 6 * $A;
  $cy /= 6 * $A;
  return [$cx, $cy, $point_index];
}

sub add_height {
  my $world = shift;
  $Math::Fractal::Noisemaker::QUIET = 1;
  my $grid = Math::Fractal::Noisemaker::square();
  $world->height([]); # clear
  my $scale = max($height, $width); # grid is a square
  foreach my $point (@{$world->points}) {
    my $x = int($point->[0]*255/$scale);
    my $y = int($point->[1]*255/$scale);
    my $h = 0; # we must not skip any points!
    $h = $grid->[$x]->get($y) / 255
      unless $x < 0 or $y < 0 or $x > 255 or $y > 255;
    push(@{$world->height}, $h);
  }
}

sub raise_point {
  my ($world, $x, $y, $radius) = @_;
  my $i = 0;
  foreach my $point (@{$world->points}) {
    my $dx = $point->[0] - $x;
    my $dy = $point->[1] - $y;
    my $d = sqrt($dx * $dx + $dy * $dy);
    my $v = max(0, $world->height->[$i] - $d / $radius);
    $world->height($i, $v);
    $i++;
  }
}

sub scale_height {
  my ($world) = shift;
  my $top = 0;
  for my $i (0 .. $#{$world->points}) {
    $top = $world->height->[$i] if $world->height->[$i] > $top;
  }
  for my $i (0 .. $#{$world->points}) {
    $world->height($i, $world->height->[$i] / $top);
  }
}

sub add_ocean {
  my $world = shift;
  my @queue;
  for my $i (0 .. $#{$world->points}) {
    $world->terrain($i, '');
    if ($world->height->[$i] <= 0) {
      $world->water($i, 1);
      if ($world->border->[$i]) {
	$world->terrain($i, 'ocean');
	push(@queue, $i); # this is used to spread the ocean
      } else {
	$world->terrain($i, 'lake'); # inland sea is considered a lake
      }
    }
  }
  while (@queue) {
    my $p = shift(@queue);
    foreach my $i (@{$world->neighbours($p)}) {
      if ($world->water->[$i] and $world->terrain->[$i] ne 'ocean') {
  	$world->terrain($i, 'ocean');
  	push(@queue, $i);
      }
    }
  }
}

sub add_downslopes {
  my $world = shift;
  for my $i (0 .. $#{$world->points}) {
    next if $world->terrain->[$i] eq 'ocean';
    my $lowest;
    foreach my $neighbour (@{$world->neighbours($i)}) {
      if (not $lowest or $world->height->[$neighbour] < $world->height->[$i]) {
	$lowest = $neighbour;
      }
    }
    if ($world->height->[$lowest] < $world->height->[$i]) {
      $world->downslope($i, $lowest);
    }
  }
}

sub add_lakes {
  my $world = shift;
  for my $i (0 .. $#{$world->points}) {
    next if $world->water->[$i]; # lakes, oceans, coast, all at height 0
    next if $world->downslope->[$i];
    my @lake = ($i);
    $world->fill_lake($world->height->[$i], @lake);
  }
}

sub fill_lake {
  my ($world, $level, @lake) = @_;
  my %lake = map { $_ => 1 } @lake;
  my $lowest;
  foreach my $i (@lake) {
    foreach my $neighbour (@{$world->neighbours($i)}) {
      if (not $lake{$neighbour}
	  and (not $lowest or $world->height->[$neighbour] < $world->height->[$lowest])) {
	$lowest = $neighbour;
      }
    }
  }
  foreach my $i (@lake) {
    $world->height($i, $world->height->[$lowest]);
  }
  if ($world->height->[$lowest] < $level) {
    my @color = qw(swamp lake lake glacier);
    my $color = $color[level($level)];
    foreach my $i (@lake) {
      $world->water($i, 1);
      $world->terrain($i, $color);
      $world->downslope($i, $lowest);
    }
  } else {
    return $world->fill_lake($world->height->[$lowest], @lake, $lowest);
  }
}

sub add_terrain {
  my $world = shift;
  my @color = qw(grass forest taiga snow);
  foreach my $i (0 .. $#{$world->points}) {
    if (not $world->water->[$i]) {
      $world->terrain($i, $color[level($world->height->[$i])]);
    }
  }
}

sub level {
  my $height = shift;
  # The highest point is exactly 1.0; the lost point is still higher
  # than 0. Return results between 0 and 3.
  return int(min($height * 4, 3));
}

sub add_beach {
  my $world = shift;
  foreach my $i (0 .. $#{$world->points}) {
    # next if $world->terrain->[$i] eq 'ocean';
    next if $world->terrain->[$i] ne 'grass';
    foreach my $neighbour (@{$world->neighbours($i)}) {
      if ($world->terrain->[$neighbour] eq 'coast') {
	$world->terrain($i, 'beach');
	last;
      }
    }
  }
}

sub add_coast {
  my $world = shift;
  foreach my $i (0 .. $#{$world->points}) {
    next if $world->terrain->[$i] ne 'ocean';
    foreach my $neighbour (@{$world->neighbours($i)}) {
      if (not $world->water->[$neighbour]) {
	$world->terrain($i, 'coast');
	last;
      }
    }
  }
}

sub svg {
  my $world = shift;
  my $svg = new SVG(width => $width . "px",
		    height => $height . "px");
  foreach my $polygon ($world->voronoi->polygons) {
    my ($i, @points) = @$polygon; # see Math::Geometry::Voronoi
    if ($world->visible->[$i]) {
      my $color = $color{$world->terrain->[$i]};
      my $path = join(",", map { map { int } @$_ } @points);
      $svg->polygon(points => $path,
		    fill => $color,
		    style => { 'stroke-width' => 1,
			       'stroke' => 'black'});
    }
  }
  return $svg->xmlify();
}

package main;

sub response {
  print header(-type=>'image/svg+xml');
  print shift;
}

sub create_world {
  my $world = new World;
  $world->add_random_points($points);
  $world->add_voronoi();
  for (my $i = 2; $i--; ) {
    # Lloyd Relaxation
    $world->add_centroids();
    $world->points($world->centroids);
    $world->add_voronoi();
  }
  # create island
  $world->add_border();
  $world->add_height();
  $world->raise_point($center_x, $center_y, $radius);
  $world->scale_height();
  $world->add_ocean();
  $world->add_coast();
  $world->add_downslopes();
  $world->add_lakes() unless param('lakes');
  $world->add_terrain();
  $world->add_beach();
  # draw
  response($world->svg);
}

sub print_html {
  print (header(-type=>'text/html; charset=UTF-8'),
	 start_html(-encoding=>'UTF-8', -title=>'Monones Island Generator',
		    -author=>'kensanata@gmail.com'),
	 h1("Monones Island Generator"),
	 p("This script generates a new random map."),
	 start_form(-action=>url() . '/random'),
	 submit('map', 'Generate Map'),
	 end_form(),
	 hr(),
	 p(address(a({ -href=>'http://emacswiki.org/alex/About'},
		     'Alex Schröder')),
	   a({ -href=>url() . '/source'}, 'Source')),
	 end_html());
}

sub main {
  if (path_info eq '/source') {
    seek DATA, 0, 0;
    print "Content-type: text/plain; charset=UTF-8\r\n\r\n", <DATA>;
  } elsif (path_info =~ '/(\d+)') {
    srand($1);
    create_world();
  } elsif (path_info eq '/random') {
    print redirect(-uri=>url() . '/' . int(rand(INT_MAX)));
  } elsif (param('seed')) {
    print redirect(-uri=>url() . '/' . param('seed'));
  } else {
    print_html();
  }
}

main ();

__DATA__

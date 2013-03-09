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
use POSIX;
use LWP::UserAgent;

=head1 Traveller Mapper

A CGI script that will accept the UWP of a subsector and create an SVG
map.

=cut

my $debug;

package Hex;

use Class::Struct;

struct Hex => {
	       name => '$',
	       x => '$',
	       y => '$',
	       starport => '$',
	       size => '$',
	       population => '$',
	       consulate => '$',
	       pirate => '$',
	       TAS => '$',
	       research => '$',
	       naval => '$',
	       scout => '$',
	       gasgiant => '$',
	       code => '$',
	       url => '$',
	       map => 'Mapper',
	       comm => '@',
	       trade => '%',
	       routes => '@',
	      };

sub base {
  my ($self, $key) = @_;
  $key = uc($key);
  ($key eq 'C') ? $self->consulate(1)
  : ($key eq 'P') ? $self->pirate(1)
  : ($key eq 'T') ? $self->TAS(1)
  : ($key eq 'R') ? $self->research(1)
  : ($key eq 'N') ? $self->naval(1)
  : ($key eq 'S') ? $self->scout(1)
  : ($key eq 'G') ? $self->gasgiant(1)
  : undef;
}

sub at {
  my ($self, $x, $y) = @_;
  return $self->x == $x && $self->y == $y;
}

sub str {
  my $self = shift;
  sprintf "%-12s %02s%02s ", $self->name, $self->x, $self->y;
}

sub eliminate {
  my $from = shift;
  foreach my $to (@_) {
    # eliminate the communication $from -> $to
    my @ar1 = grep {$_ != $to} @{$from->comm};
    $from->comm(\@ar1);
    # eliminate the communication $to -> $from
    my @ar2 = grep {$_ != $from} @{$to->comm};
    $to->comm(\@ar2);
  }
}

sub comm_svg {
  my $self = shift;
  my $data = '';
  my $scale = 100;
  my ($x1, $y1) = ($self->x, $self->y);
  foreach my $to (@{$self->comm}) {
    my ($x2, $y2) = ($to->x, $to->y);
    $data .= sprintf(qq{    <line class="comm" x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" />\n},
		     (1 + ($x1-1) * 1.5) * $scale, ($y1 - $x1%2/2) * sqrt(3) * $scale,
		     (1 + ($x2-1) * 1.5) * $scale, ($y2 - $x2%2/2) * sqrt(3) * $scale);
  }
  return $data;
}

sub trade_svg {
  my $self = shift;
  my $data = '';
  my $scale = 100;
  foreach my $routeref (@{$self->routes}) {
    my $points = join(' ', map {
      sprintf("%.3f,%.3f",
	      (1 + ($_->x-1) * 1.5) * $scale, ($_->y - $_->x%2/2) * sqrt(3) * $scale);
    } $self, reverse @{$routeref});
    $data .= qq{    <polyline class="trade" points="$points" />\n};
  }
  return $data;
}

# The empty hex is centered around 0,0 and has a side length of 1, a
# maximum diameter of 2, and a minimum diameter of √3. The subsector
# is 10 hexes high and eight hexes wide. The 0101 corner is at the top
# left.
sub system_svg {
  my $self = shift;
  my $x = $self->x;
  my $y = $self->y;
  my $name = $self->name;
  my $display = ($self->population >= 9 ? uc($name) : $name);
  my $starport = $self->starport;
  my $size = $self->size;
  my $url = $self->url;
  my $lead = ($url ? '  ' : '');
  my $data = '';
  $data .= qq{  <a xlink:href="$url">\n} if $url;
  $data .= qq{$lead  <g id="$name">\n};
  my $scale = 100;
  # code red painted first, so it appears at the bottom
  $data .= sprintf(qq{$lead    <circle class="code red" cx="%.3f" cy="%.3f" r="%.3f" />\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2) * sqrt(3) * $scale, 0.52 * $scale)
    if $self->code eq 'R';
  $data .= sprintf(qq{$lead    <circle cx="%.3f" cy="%.3f" r="%.3f" />\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2) * sqrt(3) * $scale, 11 + $size);
  $data .= sprintf(qq{$lead    <circle class="code amber" cx="%.3f" cy="%.3f" r="%.3f" />\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2) * sqrt(3) * $scale, 0.52 * $scale)
    if $self->code eq 'A';
  $data .= sprintf(qq{$lead    <text class="starport" x="%.3f" y="%.3f">$starport</text>\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 - 0.17) * sqrt(3) * $scale);
  $data .= sprintf(qq{$lead    <text class="name" x="%.3f" y="%.3f">$display</text>\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 + 0.4) * sqrt(3) * $scale);
  $data .= sprintf(qq{$lead    <text class="consulate base" x="%.3f" y="%.3f">■</text>\n},
		   (0.6 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 + 0.25) * sqrt(3) * $scale)
    if $self->consulate;
  $data .= sprintf(qq{$lead    <text class="TAS base" x="%.3f" y="%.3f">☼</text>\n},
  		   (0.4 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 + 0.1) * sqrt(3) * $scale)
    if $self->TAS;
  $data .= sprintf(qq{$lead    <text class="pirate base" x="%.3f" y="%.3f">▲</text>\n},
  		   (0.4 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 - 0.1) * sqrt(3) * $scale)
    if $self->scout;
  $data .= sprintf(qq{$lead    <text class="naval base" x="%.3f" y="%.3f">★</text>\n},
  		   (0.6 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 - 0.25) * sqrt(3) * $scale)
    if $self->naval;
  $data .= sprintf(qq{$lead    <text class="gasgiant base" x="%.3f" y="%.3f">◉</text>\n},
   		   (1.4 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 - 0.25) * sqrt(3) * $scale)
    if $self->gasgiant;
  $data .= sprintf(qq{$lead    <text class="research base" x="%.3f" y="%.3f">π</text>\n},
   		   (1.6 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 - 0.1) * sqrt(3) * $scale)
    if $self->research;
  $data .= sprintf(qq{$lead    <text class="pirate base" x="%.3f" y="%.3f">☠</text>\n},
   		   (1.6 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2 + 0.1) * sqrt(3) * $scale)
    if $self->pirate;
  # last slot unused
  $data .= qq{$lead  </g>\n};
  $data .= qq{  </a>\n} if $url;
  return $data;
}

package Mapper;

use Class::Struct;
use Memoize;

struct Mapper => {
		  hexes => '@',
		  routes => '@',
		  source => "\$",
		 };

my $example = q!
Inedgeus     0101 D7A5579-8        G  Fl NI          A
Geaan        0102 E66A999-7        G  Hi Wa          A
Orgemaso     0103 C555875-5       SG  Ga Lt
Veesso       0105 C5A0369-8        G  De Lo          A
Ticezale     0106 B769799-7    T  SG  Ri             A
Maatonte     0107 C6B3544-8   C    G  Fl NI          A
Diesra       0109 D510522-8       SG  NI
Esarra       0204 E869100-8        G  Lo             A
Rience       0205 C687267-8        G  Ga Lo
Rearreso     0208 C655432-5   C    G  Ga Lt NI
Laisbe       0210 E354663-3           Ag Lt NI
Biveer       0302 C646576-9   C    G  Ag Ga NI
Labeveri     0303 A796100-9   CT N G  Ga Lo          A
Sotexe       0408 E544778-3        G  Ag Ga Lt       A
Zamala       0409 A544658-13   T N G  Ag Ga Ht NI
Sogeeran     0502 A200443-14  CT N G  Ht NI Va
Aanbi        0503 E697102-7        G  Ga Lo          A
Bemaat       0504 C643384-9   C R  G  Lo Po
Diare        0505 A254430-11   TRN G  NI             A
Esgeed       0507 A8B1579-11    RN G  Fl NI A        A
Leonbi       0510 B365789-9    T  SG  Ag Ri          A
Reisbeon     0604 C561526-8     R  G  NI
Atcevein     0605 A231313-11  CT   G  Lo Po
Usmabe       0607 A540A84-15   T   G  De Hi Ht In Po
Onbebior     0608 B220530-10       G  De NI Po       A
Raraxema     0609 B421768-8    T NSG  Na Po
Xeerri       0610 C210862-9        G  Na
Onreon       0702 D8838A9-2       S   Lt Ri          A
Ismave       0703 E272654-4           Lt NI
Lara         0704 C0008D9-5       SG  As Lt Na Va    A
Lalala       0705 C140473-9     R  G  De NI Po
Maxereis     0707 A55A747-12  CT NSG  Ht Wa
Requbire     0802 C9B4200-10       G  Fl Lo          A
Azaxe        0804 B6746B9-8   C    G  Ag Ga NI       A
Rieddige     0805 B355578-7        G  Ag NI          A
Usorce       0806 E736110-3        G  Lo Lt          A
Solacexe     0810 D342635-4  P    S   Lt NI Po       R
!;

sub example {
  return $example;
}

# The empty hex is centered around 0,0 and has a side length of 1,
# a maximum diameter of 2, and a minimum diameter of √3.
my @hex = (  -1,          0,
	   -0.5,  sqrt(3)/2,
	    0.5,  sqrt(3)/2,
	      1,          0,
	    0.5, -sqrt(3)/2,
	   -0.5, -sqrt(3)/2);

sub header {
  my $template = <<EOT;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="210mm"
     height="297mm"
     viewBox="%s %s %s %s">
  <desc>Traveller Subsector</desc>
  <defs>
    <style type="text/css"><![CDATA[
      text {
        font-size: 16pt;
        font-family: Optima, Helvetica, sans-serif;
        text-anchor: middle;
      }
      text a {
        fill: blue;
        text-decoration: underline;
      }
      .coordinates {
        fill-opacity: 0.5;
      }
      .starport, .base {
        font-size: 20pt;
      }
      .direction {
        font-size: 24pt;
      }
      .legend {
        text-anchor: start;
        font-size: 14pt;
      }
      tspan.comm {
        fill: #ff6347; /* tomato */
      }
      line.comm {
        stroke-width: 10pt;
        stroke: #ff6347; /* tomato */
      }
      polyline.trade {
        stroke-width: 1pt;
        stroke-linecap: round;
        stroke-linejoin: round;
        stroke: grey;
        fill: none;
        display: none;
      }
      tspan.trade {
        fill: #afeeee; /* pale turquoise */
      }
      line.main {
        stroke-width: 6pt;
        stroke: #afeeee; /* pale turquoise */
        fill: none;
      }
      .code {
        opacity: 0.3;
      }
      .amber {
        fill: none;
        stroke-width: 1pt;
        stroke: black;
      }
      .red {
        fill: red;
      }
      #hex {
        stroke-width: 3pt;
        fill: none;
        stroke: black;
      }
    ]]></style>
    <polygon id="hex"
             points="%s,%s %s,%s %s,%s %s,%s %s,%s %s,%s" />
  </defs>
  <rect fill="white" stroke="black" stroke-width="10" id="frame"
        x="%s" y="%s" width="%s" height="%s" />

EOT
  my $scale = 100;
  return sprintf($template,
		 map { sprintf("%.3f", $_ * $scale) }
		 # total width and height based on 8x10 hexes
		 # 0, 0, 2+7*1.5, 10.5*sqrt(3) -- but with some whitespace
		 # viewport
		 -0.5, -0.5, 3+7*1.5, 11.5*sqrt(3),
		 # empty hex
		 @hex,
		 # framing rectangle
		 -0.5, -0.5, 3+7*1.5, 11.5*sqrt(3));
}

sub grid {
  my $scale = 100;
  my $doc;
  # the 8x10 hex grid
  $doc .= join("\n",
	       map {
		 my $n = shift;
		 my $x = int($_/10+1);
		 my $y = $_%10 + 1;
		 my $svg = sprintf(qq{    <use xlink:href="#hex" x="%.3f" y="%.3f" />\n},
				   (1 + ($x-1) * 1.5) * $scale,
				   ($y - $x%2/2) * sqrt(3) * $scale);
		 $svg   .= sprintf(qq{    <text class="coordinates" x="%.3f" y="%.3f">}
		 		 . qq{%02d%02d</text>\n},
				   (1 + ($x-1) * 1.5) * $scale,
				   ($y - $x%2/2) * sqrt(3) * $scale - 0.6 * $scale,
				   $x, $y);
	       } (0..79));
  return $doc;
}

sub legend {
  my $self = shift;
  my $scale = 100;
  my $doc;
  my $uwp;
  if ($self->source) {
    $uwp = ' – <a xlink:href="' . $self->source . '">UWP</a>';
  }
  $doc .= sprintf(qq{    <text class="legend" x="%.3f" y="%.3f">◉ gas giant}
		  . qq{ – ■ imperial consulate – ☼ TAS – ▲ scout base}
		  . qq{ – ★ navy base – π research base – ☠ pirate base}
		  . qq{ – <tspan class="comm">▮</tspan> communication}
		  . qq{ – <tspan class="trade">▮</tspan> trade$uwp</text>\n},
		  -10, 11 * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text class="direction" x="%.3f" y="%.3f">coreward</text>\n},
		  6 * $scale, -0.13 * $scale);
  $doc .= sprintf(qq{    <text transform="translate(%.3f,%.3f) rotate(90)"}
		  . qq{ class="direction">trailing</text>\n},
		  12.6 * $scale, 5 * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text class="direction" x="%.3f" y="%.3f">rimward</text>\n},
		  6 * $scale, 10.7 * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text transform="translate(%.3f,%.3f) rotate(-90)"}
		  . qq{ class="direction">spinward</text>\n},
		  -0.1 * $scale, 5 * sqrt(3) * $scale);
  return $doc;
}

sub footer {
  my $doc;
  my $y = 10;
  for my $line (split(/\n/, $debug)) {
    $doc .= qq{<text xml:space="preserve" class="legend" y="$y" stroke="red">}
      . $line . qq{</text>\n};
    $y += 20;
  }
  $doc .= qq{</svg>\n};
  return $doc;
}

sub initialize {
  my ($self, $map, $wiki, $source) = @_;
  $self->source($source);
  foreach (split(/\n/, $map)) {
    # parse Traveller UWP
    my ($name, $x, $y,
	$starport, $size, $atmosphere, $hydrographic, $population,
	$government, $law, $tech, $bases, $rest) =
	  /([^>\r\n\t]*?)\s+(0?[1-8])(0[1-9]|10)\s+([A-EX])([0-9A])([0-9A-F])([0-9A])([0-9A-C])([0-9A-F])([0-9A-L])-(\d?\d|[A-Z])(?:\s+([PCTRNSG ]+)\b)?(.*)/;
    # alternative super simple name, coordinates, optional size (0-9), optional bases (PCTRNSG), optional warning codes (AR)
    ($name, $x, $y, $size, $bases, $rest) =
      /([^>\r\n\t]*?)\s+(0?[1-8])(0[1-9]|10)(?:\s+([0-9])\b)?(?:\s+([PCTRNSG ]+)\b)?(.*)/
	unless $name;
    next unless $name;
    my ($code) = /([AR])\s*$/;
    $rest =~ s/([AR])\s*$// if $code; # strip base (if any) from the rest
    my %trade = map { $_ => 1 }
      grep(/^(Ag|As|Ba|De|Fl|Ga|Hi|Ht|IC|In|Lo|Lt|Na|NI|Po|Ri|Wa|Va)$/,
	   split(' ', $rest));
    $bases .= join('', grep(/^[PCTRNSG]$/, split(' ', $rest))); # lone bases
    map { $$_ = hex($$_) } (\$size,
			    \$atmosphere,
			    \$hydrographic,
			    \$population,
			    \$government,
			    \$law);
    my $hex = Hex->new(name=>$name,
		       x=>$x,
		       y=>$y,
		       starport=>$starport,
		       population=>$population,
		       size=>$size,
		       code=>$code,
		       trade=>\%trade);
    $hex->url("$wiki$name") if $wiki;
    for my $base (split(//, $bases)) {
      $hex->base($base);
    }
    $self->add($hex);
  }
}

sub add {
  my ($self, $hex) = @_;
  push(@{$self->hexes}, $hex);
}

sub communications {
  # connect all the class A starports, naval bases, and imperial
  # consulates
  my ($self) = @_;
  my @candidates = ();
  foreach my $hex (@{$self->hexes}) {
    push(@candidates, $hex)
      if $hex->starport eq 'A'
	or $hex->naval
	or $hex->consulate;
  }
  # every system has a link to its neighbours
  foreach my $hex (@candidates) {
    my @ar = $self->nearby($hex, 2, \@candidates);
    $hex->comm(\@ar);
  }
  # eliminate all but the best connections if the system has code
  # amber or code red
  foreach my $hex (@candidates) {
    next unless $hex->code;
    my $best;
    foreach my $other (@{$hex->comm}) {
      if (not $best
	  or $other->starport lt $best->starport
	  or $other->starport eq $best->starport
	  and distance($hex, $other) < distance($hex, $best)) {
	$best = $other;
      }
    }
    $hex->eliminate(grep { $_ != $best } @{$hex->comm});
  }
}

sub trade {
  # connect In or Ht with As, De, IC, NI
  # connect Hi or Ri with Ag, Ga, Wa
  my ($self) = @_;
  # candidates need to be on a travel route, ie. must have fuel
  # available; skip worlds with a red travel code
  my @candidates = ();
  foreach my $hex (@{$self->hexes}) {
    push(@candidates, $hex)
      if ($hex->starport =~ /[A-D]/
	  or $hex->gasgiant
	  or $hex->trade->{Wa})
	and $hex->code ne 'R';
  }
  # every system has a link to its partners
  foreach my $hex (@candidates) {
    my @routes;
    if ($hex->trade->{In} or $hex->trade->{Ht}) {
      foreach my $other ($self->nearby($hex, 4, \@candidates)) {
	if ($other->trade->{As}
	    or $other->trade->{De}
	    or $other->trade->{IC}
	    or $other->trade->{NI}) {
	  my @route = $self->route($hex, $other, 4, \@candidates);
	  push(@routes, \@route) if @route;
	}
      }
    } elsif ($hex->trade->{Hi} or $hex->trade->{Ri}) {
      foreach my $other ($self->nearby($hex, 4, \@candidates)) {
	if ($other->trade->{Ag}
	    or $other->trade->{Ga}
	    or $other->trade->{Wa}) {
	  my @route = $self->route($hex, $other, 4, \@candidates);
	  push(@routes, \@route) if @route;
	}
      }
    }
    $hex->routes(\@routes);
  }
  my @main_routes = minimal_spanning_tree(edges(@candidates));
  $self->routes(\@main_routes);
}

sub edges {
  my @edges;
  my %seen;
  foreach my $hex (@_) {
    foreach my $route (@{$hex->routes}) {
      my ($start, @route) = @{$route};
      foreach my $end (@route) {
	# keep everything unidirectional
	next if exists $seen{$start}{$end} or exists $seen{$end}{$start};
	push(@edges, [$start, $end, distance($start,$end)]);
	$seen{$start}{$end} = 1;
	$start = $end;
      }
    }
  }
  return @edges;
}

sub minimal_spanning_tree {
  # http://en.wikipedia.org/wiki/Kruskal%27s_algorithm
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
    # $u = $u->name;
    # $v = $v->name;
    # prevent cycles in T; add u,v only if T does not already contain
    # a path between u and v
    if ($C{$u} != $C{$v} or not $C{$u} and not $C{$v}) {
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
  return @T;
}

sub route {
  # Compute the shortest route between two hexes no longer than a
  # certain distance and choosing intermediary steps from the array of
  # possible candidates.
  my ($self, $from, $to, $distance, $candidatesref, @seen) = @_;
  # my $indent = ' ' x (4-$distance);
  my @options;
  foreach my $hex ($self->nearby($from, $distance < 2 ? $distance : 2, $candidatesref)) {
    push (@options, $hex) unless in($hex, @seen);
  }
  return unless @options and $distance;
  if (in($to, @options)) {
    return @seen, $from, $to;
  }
  my @routes;
  foreach my $hex (@options) {
    my @route = $self->route($hex, $to, $distance - distance($from, $hex),
			     $candidatesref, @seen, $from);
    if (@route) {
      push(@routes, \@route);
    }
  }
  return unless @routes;
  # return the shortest one
  my @shortest;
  foreach my $route (@routes) {
    if ($#{$route} < $#shortest or not @shortest) {
      @shortest = @{$route};
    }
  }
  return @shortest;
}

sub in {
  my $item = shift;
  foreach (@_) {
    return $item if $item == $_;
  }
}

sub nearby {
  my ($self, $start, $distance, $candidatesref) = @_;
  my @candidates = @$candidatesref;
  $distance = 1 unless $distance; # default
  my @result = ();
  foreach my $hex (@candidates) {
    next if $hex == $start;
    if (distance($start, $hex) <= $distance) {
      push(@result, $hex);
    }
  }
  return @result;
}

memoize('nearby');

sub distance {
  my ($from, $to) = @_;
  my ($x1, $y1, $x2, $y2) = ($from->x, $from->y, $to->x, $to->y);
  # transform the stupid Traveller coordinate system into a decent
  # system with one axis tilted by 60°
  my $y1 = $y1 - POSIX::ceil($x1/2);
  my $y2 = $y2 - POSIX::ceil($x2/2);
  return d($x1, $y1, $x2, $y2);
}

memoize('distance');

sub d {
  my ($x1, $y1, $x2, $y2) = @_;
  if ($x1 > $x2) {
    # only consider moves from left to right and transpose start and
    # end point to make it so
    return d($x2, $y2, $x1, $y1);
  } elsif ($y2>=$y1) {
    # if it the move has a downwards component add Δx and Δy
    return $x2-$x1 + $y2-$y1;
  } else {
    # else just take the larger of Δx and Δy
    return $x2-$x1 > $y1-$y2 ? $x2-$x1 : $y1-$y2;
  }
}

sub trade_svg {
  my $self = shift;
  my $data = '';
  my $scale = 100;
  foreach my $edge (@{$self->routes}) {
    my $u = @{$edge}[0];
    my $v = @{$edge}[1];
    my ($x1, $y1) = ($u->x, $u->y);
    my ($x2, $y2) = ($v->x, $v->y);
    $data .= sprintf(qq{    <line class="main" x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" />\n},
		     (1 + ($x1-1) * 1.5) * $scale, ($y1 - $x1%2/2) * sqrt(3) * $scale,
		     (1 + ($x2-1) * 1.5) * $scale, ($y2 - $x2%2/2) * sqrt(3) * $scale);
  }
  return $data;
}

sub svg {
  my ($self) = @_;
  my $data = header();
  $data .= qq{  <g id='comm'>\n};
  foreach my $hex (@{$self->hexes}) {
    $data .= $hex->comm_svg();
  }
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='trade'>\n};
  foreach my $hex (@{$self->hexes}) {
    $data .= $hex->trade_svg();
  }
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='routes'>\n};
  $data .= $self->trade_svg();
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='grid'>\n};
  $data .= grid();
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='legend'>\n};
  $data .= $self->legend();
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='system'>\n};
  foreach my $hex (@{$self->hexes}) {
    $data .= $hex->system_svg();
  }
  $data .= qq{  </g>\n};
  $data .= footer();
  return $data;
}

sub text {
  my ($self) = @_;
  my $data;
  foreach my $edge (@{$self->routes}) {
    my $u = @{$edge}[0];
    my $v = @{$edge}[1];
    $data .= "Main route: " . $u->name . " - " . $v->name . "\n";
  }
  $data .= "\n";
  foreach my $hex (@{$self->hexes}) {
    foreach my $routeref (@{$hex->routes}) {
      $data .= join(' - ', map {$_->name} reverse @{$routeref}) . "\n";
    }
  }
  return $data;
}

package main;

sub print_map {
  print header(-type=>'image/svg+xml; charset=UTF-8');
  my $map = new Mapper;
  $map->initialize(@_);
  $map->communications();
  $map->trade();
  print $map->svg;
}

sub print_trade {
  print header(-type=>'text/plain');
  my $map = new Mapper;
  $map->initialize(@_);
  $map->trade();
  print $map->text;
}

sub print_html {
  print (header(-type=>'text/html; charset=UTF-8'),
	 start_html(-encoding=>'UTF-8', -title=>'Traveller Subsector Mapper',
		    -author=>'kensanata@gmail.com'),
	 h1('Traveller Subsector Mapper'),
	 p('Submit your UWP list of the subsector.'),
	 start_form(-method=>'POST'),
	 p(textarea('map', Mapper::example(), 20, 60)),
	 p('URL (optional):', textfield('wiki', 'http://campaignwiki.org/wiki/NameOfYourWiki/', 40)),
	 p(checkbox('trade', 0, 1, 'List trade routes in text format')),
	 p(submit('generate', 'Generate Map'), submit('random', 'Random Map')),
	 end_form(),
	 p(b('Format') . ':',
	   i('name') . ', some whitespace,',
	   i('coordinates'), '(four digits between 0101 and 0810),',
	   'some whitespace,',
	   i('starport'), '(A-E or X)',
	   i('size'), '(0-9 or A)',
	   i('atmosphere'), '(0-9 or A-F)',
	   i('hydrographic'), '(0-9 or A)',
	   i('population'), '(0-9 or A-C)',
	   i('government'), '(0-9 or A-F)',
	   i('law level'), '(0-9 or A-L)',
	   'a dash,',
	   i('tech level'), '(0-99)',
	   'optionally a non-standard group of bases',
	   'and a gas giant indicator,',
	   'optionally separated by whitespace:',
	   i('pirate base'), '(P)',
	   i('imperial consulate'), '(C)',
	   i('TAS base'), '(T)',
	   i('research base'), '(R)',
	   i('naval base'), '(N)',
	   i('scout base'), '(S)',
	   i('gas giant'), '(G),',
	   'followed by trade codes (see below), and optionally a',
	   i('travel code'), '(A or R).',
	   'Whitespace can be one or more spaces and tabs.'),
	 p('Trade codes:'),
	 pre('
    Ag Agricultural     Hi High Population    Na Non-Agricultural
    As Asteroid         Ht High Technology    NI Non-Industrial
    Ba Barren           IC Ice-Capped         Po Poor
    De Desert           In Industrial         Ri Rich
    Fl Fluid Oceans     Lo Low Population     Wa Water World
    Ga Garden           Lt Low Technology     Va Vacuum'),
	 p(b('Alternative format for quick maps') . ':',
	   i('name') . ', some whitespace,',
	   i('coordinates'), '(four digits between 0101 and 0810),',
	   'some whitespace,',
	   i('size'), '(0-9)',
	   'optionally a non-standard group of bases',
	   'and a gas giant indicator,',
	   'optionally separated by whitespace:',
	   i('pirate base'), '(P)',
	   i('imperial consulate'), '(C)',
	   i('TAS base'), '(T)',
	   i('research base'), '(R)',
	   i('naval base'), '(N)',
	   i('scout base'), '(S)',
	   i('gas giant'), '(G),',
	   'followed by trade codes (see below), and optionally a',
	   i('travel code'), '(A or R).'),
	 hr(),
	 p(a({ -href=>'http://emacswiki.org/alex/About'}, 'Alex Schröder'),
	   a({ -href=>url().'/source'}, 'Source'),
	   a({-href=>'https://github.com/kensanata/hex-mapping'},
	     'GitHub')),
	 end_html());
}

sub main {
  if (path_info eq '/source') {
    seek DATA, 0, 0;
    print "Content-type: text/plain; charset=UTF-8\r\n\r\n", <DATA>;
  } elsif (param('trade')) {
    print_trade(param('map'));
  } elsif (path_info =~ '/(\d+)' or param('random') or param('seed')) {
    my $seed = $1 || param('seed');
    my $wiki = param('wiki');
    my $uri = url();
    $uri =~ s/\/$seed$//;
    $uri =~ s/svg-map/uwp-generator/;
    $uri .= "/$seed" if $seed;
    my $ua = LWP::UserAgent->new;
    my $response = $ua->get($uri);
    print_map($response->content, $wiki, $response->request->uri);
  } elsif (param('map')) {
    print_map(param('map'), param('wiki'));
  } else {
    print_html();
  }
}

main ();

__DATA__

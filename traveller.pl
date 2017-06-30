#!/usr/bin/perl
# Copyright (C) 2009-2017  Alex Schroeder <alex@gnu.org>
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
#
# Algorithms based on Traveller ©2008 Mongoose Publishing.

use Modern::Perl;
use utf8;

my $debug;

################################################################################

package System;
use Class::Struct;

struct System => {
		  name => '$',
		  x => '$',
		  y => '$',
		  starport => '$',
		  size => '$',
		  atmosphere => '$',
		  temperature => '$',
		  hydro => '$',
		  population => '$',
		  government => '$',
		  law => '$',
		  tech => '$',
		  consulate => '$',
		  pirate => '$',
		  TAS => '$',
		  research => '$',
		  naval => '$',
		  scout => '$',
		  gasgiant => '$',
		  tradecodes => '$',
		  travelcode => '$',
		 };

my $digraphs = "fafemalunabararerixevivoine.n.q.pazizozutatetitotu..";
my $max = length($digraphs);

# Original Elite:
# "..lexegezacebisousesarmaindire.aeratenberalavetiedorquanteisrion";

sub compute_name {
  my $self = shift;
  my $length = 4 + rand(6); # 4-8
  my $name = '';
  while (length($name) < $length) {
    $name .= substr($digraphs, 2*int(rand($max/2)), 2);
  }
  $name =~ s/\.//g;
  return ucfirst($name);
}

sub roll1d6 {
  return 1+int(rand(6));
}

sub roll2d6 {
  return roll1d6() + roll1d6();
}

sub compute_starport {
  my $self = shift;
  my %map = ( 2=>'X', 3=>'E', 4=>'E', 5=>'D', 6=>'D', 7=>'C',
	      8=>'C', 9=>'B', 10=>'B', 11=>'A', 12=>'A' );
  return $map{roll2d6()};
}

sub compute_bases {
  my $self = shift;
  if ($self->starport eq 'A') {
    $self->naval(roll2d6() >= 8);
    $self->scout(roll2d6() >= 10);
    $self->research(roll2d6() >= 8);
    $self->TAS(roll2d6() >= 4);
    $self->consulate(roll2d6() >= 6);
  } elsif ($self->starport eq 'B') {
    $self->naval(roll2d6() >= 8);
    $self->scout(roll2d6() >= 8);
    $self->research(roll2d6() >= 10);
    $self->TAS(roll2d6() >= 6);
    $self->consulate(roll2d6() >= 8);
    $self->pirate(roll2d6() >= 12);
  } elsif ($self->starport eq 'C') {
    $self->scout(roll2d6() >= 8);
    $self->research(roll2d6() >= 10);
    $self->TAS(roll2d6() >= 10);
    $self->consulate(roll2d6() >= 10);
    $self->pirate(roll2d6() >= 10);
  } elsif ($self->starport eq 'D') {
    $self->scout(roll2d6() >= 7);
    $self->pirate(roll2d6() >= 12);
  } elsif ($self->starport eq 'E') {
    $self->pirate(roll2d6() >= 12);
  }
}

sub compute_atmosphere {
  my $self = shift;
  my $atmosphere = roll2d6() -7 + $self->size;
  $atmosphere = 0 if $atmosphere < 0;
  return $atmosphere;
}

sub compute_temperature {
  my $self = shift;
  my $temperature = roll2d6();
  my $atmosphere = $self->atmosphere;
  $temperature -= 2
    if $atmosphere == 2
    or $atmosphere == 3;
  $temperature -= 1
    if $atmosphere == 3
    or $atmosphere == 4
    or $atmosphere == 14;                      # E
  $temperature += 1
    if $atmosphere == 8
    or $atmosphere == 9;
  $temperature += 2
    if $atmosphere == 10                       # A
    or $atmosphere == 13                       # D
    or $atmosphere == 15;                      # F
  $temperature += 6
    if $atmosphere == 11                       # B
    or $atmosphere == 12;                      # C
  return $temperature;
}

sub compute_hydro {
  my $self = shift;
  my $hydro = roll2d6() - 7 + $self->size;
  $hydro -= 4
    if $self->atmosphere == 0
    or $self->atmosphere == 1
    or $self->atmosphere == 10                       # A
    or $self->atmosphere == 11                       # B
    or $self->atmosphere == 12;                      # C
  $hydro -= 2
    if $self->atmosphere != 13                      # D
    and $self->temperature >= 10
    and $self->temperature <= 11;
  $hydro -= 6
    if $self->atmosphere != 13                      # D
    and $self->temperature >= 12;
  $hydro = 0
    if $self->size <= 1
    or $hydro < 0;
  return $hydro;
}

sub compute_government {
  my $self = shift;
  my $government = roll2d6() - 7 + $self->population; # max 15
  $government = 0
    if $government < 0
    or $self->population == 0;
  return $government;
}

sub compute_law {
  my $self = shift;
  my $law = roll2d6()-7+$self->government; # max 20!
  $law = 0
    if $law < 0
    or $self->population == 0;
  return $law;
}

sub compute_tech {
  my $self = shift;
  my $tech = roll1d6();
  $tech += 6 if $self->starport eq 'A';
  $tech += 4 if $self->starport eq 'B';
  $tech += 2 if $self->starport eq 'C';
  $tech -= 4 if $self->starport eq 'X';
  $tech += 2 if $self->size <= 1;
  $tech += 1 if $self->size >= 2 and $self->size <= 4;
  $tech += 1 if $self->atmosphere <= 3 or $self->atmosphere >= 10;
  $tech += 1 if $self->hydro == 0 or $self->hydro == 9;
  $tech += 2 if $self->hydro == 10;
  $tech += 1 if $self->population >= 1 and $self->population <= 5;
  $tech += 1 if $self->population == 9;
  $tech += 2 if $self->population == 10;
  $tech += 3 if $self->population == 11;
  $tech += 4 if $self->population == 12;
  $tech += 1 if $self->government == 0 or $self->government == 5;
  $tech += 2 if $self->government == 7;
  $tech -= 2 if $self->government == 13 or $self->government == 14;
  $tech = 0 if $self->population == 0;
  $tech = 15 if $tech > 15;
  return $tech;
}

sub check_doom {
  my $self = shift;
  my $doomed = 0;
  $doomed = 1 if $self->atmosphere <= 1 and $self->tech < 8;
  $doomed = 1 if $self->atmosphere <= 3 and $self->tech < 5;
  $doomed = 1 if ($self->atmosphere == 4
		  or $self->atmosphere == 7
		  or $self->atmosphere == 9) and $self->tech < 3;
  $doomed = 1 if $self->atmosphere == 10 and $self->tech < 8;
  $doomed = 1 if $self->atmosphere == 11 and $self->tech < 9;
  $doomed = 1 if $self->atmosphere == 12 and $self->tech < 10;
  $doomed = 1 if ($self->atmosphere == 13
		  and $self->atmosphere == 14) and $self->tech < 5;
  $doomed = 1 if $self->atmosphere == 15 and $self->tech < 8;
  if ($doomed) {
    $self->population(0);
    $self->government(0);
    $self->law(0);
    $self->tech(0);
  }
}

sub compute_tradecodes {
  my $self = shift;
  my $tradecodes = '';
  $tradecodes .= " Ag" if $self->atmosphere >= 4 and $self->atmosphere <= 9
    and $self->hydro >= 4 and $self->hydro <= 8
    and $self->population >= 5 and $self->population <= 7;
  $tradecodes .= " As" if $self->size == 0 and $self->atmosphere == 0 and $self->hydro == 0;
  $tradecodes .= " Ba" if $self->population == 0 and $self->government == 0 and $self->law == 0;
  $tradecodes .= " De" if $self->atmosphere >= 2 and $self->hydro == 0;
  $tradecodes .= " Fl" if $self->atmosphere >= 10 and $self->hydro >= 1;
  $tradecodes .= " Ga" if $self->size >= 5
    and $self->atmosphere >= 4 and $self->atmosphere <= 9
    and $self->hydro >= 4 and $self->hydro <= 8;
  $tradecodes .= " Hi" if $self->population >= 9;
  $tradecodes .= " Ht" if $self->tech >= 12;
  $tradecodes .= " IC" if $self->atmosphere <= 1 and $self->hydro >= 1;
  $tradecodes .= " In" if $self->atmosphere =~ /[012479]/ and $self->population >= 9;
  $tradecodes .= " Lo" if $self->population >= 1 and $self->population <= 3;
  $tradecodes .= " Lt" if $self->tech >= 1 and $self->tech <= 5;
  $tradecodes .= " Na" if $self->atmosphere <= 3 and $self->hydro <= 3
    and $self->population >= 6;
  $tradecodes .= " NI" if $self->population >= 4 and $self->population <= 6;
  $tradecodes .= " Po" if $self->atmosphere >= 2 and $self->atmosphere <= 5
    and $self->hydro <= 3;
  $tradecodes .= " Ri" if $self->atmosphere =~ /[68]/ and $self->population =~ /[678]/;
  $tradecodes .= " Wa" if $self->hydro >= 10;
  $tradecodes .= " Va" if $self->atmosphere == 0;
  return $tradecodes;
}

sub compute_travelcode {
  my $self = shift;
  my $danger = 0;
  $danger++ if $self->atmosphere >= 10;
  $danger++ if $self->population and $self->government == 0;
  $danger++ if $self->government == 7;
  $danger++ if $self->government == 10;
  $danger++ if $self->population and $self->law == 0;
  $danger++ if $self->law >= 9;
  return 'R' if $danger and $self->pirate;
  return 'A' if $danger;
}

sub init {
  my $self = shift;
  $self->x(shift);
  $self->y(shift);
  $self->name($self->compute_name);
  $self->starport($self->compute_starport);
  $self->compute_bases;
  $self->size(roll2d6()-2);
  $self->atmosphere($self->compute_atmosphere);
  $self->temperature($self->compute_temperature);
  $self->hydro($self->compute_hydro);
  $self->population(roll2d6()-2); # How to get to B and C in the table?
  $self->government($self->compute_government);
  $self->law($self->compute_law);
  $self->tech($self->compute_tech);
  $self->check_doom;
  $self->tradecodes($self->compute_tradecodes);
  $self->travelcode($self->compute_travelcode);
  return $self;

}

sub code {
  my $num = shift;
  return $num if $num < 10;
  return chr(65-10+$num);
}

sub str {
  my $self = shift;
  my $uwp = sprintf("%-16s %02d%02d  ", $self->name, $self->x, $self->y);
  $uwp .= $self->starport;
  $uwp .= code($self->size);
  $uwp .= code($self->atmosphere);
  $uwp .= code($self->hydro);
  $uwp .= code($self->population);
  $uwp .= code($self->government);
  $uwp .= code($self->law);
  $uwp .= '-';
  $uwp .= sprintf("%-2d", $self->tech);
  my $bases = '';
  $bases .= 'N' if $self->naval;
  $bases .= 'S' if $self->scout;
  $bases .= 'R' if $self->research;
  $bases .= 'T' if $self->TAS;
  $bases .= 'C' if $self->consulate;
  $bases .= 'P' if $self->pirate;
  $uwp .= sprintf("%7s", $bases);
  $uwp .= '  ' . $self->tradecodes;
  $uwp .= ' ' . $self->travelcode if $self->travelcode;
  return $uwp;
}

################################################################################

package Subsector;
use Class::Struct;

struct Subsector => { systems => '@' };

sub add {
  my ($self, $system) = @_;
  push(@{$self->systems}, $system);
}

sub init {
  my $self = shift;
  for my $x (1..8) {
    for my $y (1..10) {
      if (int(rand(2))) {
	$self->add(new System()->init($x, $y));
      }
    }
  }
  return $self;
}

sub str {
  my $self = shift;
  my $subsector;
  foreach my $system (@{$self->systems}) {
    $subsector .= $system->str . "\n";
  }
  return $subsector;
}

################################################################################

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
  $data .= sprintf(qq{$lead    <text class="scout base" x="%.3f" y="%.3f">▲</text>\n},
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

################################################################################

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
  my $debug = ''; # for developers
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
    # avoid uninitialized values warnings in the rest of the code
    map { $$_ //= '' } (\$size,
			\$atmosphere,
			\$hydrographic,
			\$population,
			\$government,
			\$law,
			\$starport,
			\$code);
    # get "hex" values, but accept letters beyond F!
    map { $$_ = $$_ ge 'A' ? 10 + ord($$_) - 65
	      : $$_ eq '' ? 0
	      : $$_ } (\$size,
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
  $y1 = $y1 - POSIX::ceil($x1/2);
  $y2 = $y2 - POSIX::ceil($x2/2);
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
  my $data = "Trade Routes";
  foreach my $edge (@{$self->routes}) {
    my $u = @{$edge}[0];
    my $v = @{$edge}[1];
    $data .= $u->name . " - " . $v->name . "\n";
  }
  $data .= "\n";
  $data .= "Raw Data:\n";
  foreach my $hex (@{$self->hexes}) {
    foreach my $routeref (@{$hex->routes}) {
      $data .= join(' - ', map {$_->name} reverse @{$routeref}) . "\n";
    }
  }
  $data .= "\n";
  $data .= "Communications:\n";
  foreach my $hex (@{$self->hexes}) {
    foreach my $comm (@{$hex->comm}) {
      $data .= $hex->name . " - " . $comm->name . "\n";;
    }
  }
  return $data;
}

################################################################################

package main;

use Mojolicious::Lite;
use POSIX qw(INT_MAX);

get '/' => sub {
  my $c = shift;
  $c->redirect_to('edit');
};

get '/random' => sub {
  my $c = shift;
  $c->redirect_to('uwp', id => int(rand(INT_MAX)));
};

get '/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  $c->redirect_to('uwp', id => $id);
};

get '/uwp/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  srand($id);
  my $uwp = new Subsector()->init->str;
  $c->render(template => 'uwp', id => $id, uwp => $uwp);
} => 'uwp';

get '/source' => sub {
  my $c = shift;
  seek DATA, 0, 0;
  local undef $/;
  $c->render(text => <DATA>, format => 'text');
};

get '/edit' => sub {
  my $c = shift;
  $c->render(template => 'edit');
};

get '/map/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $id = $c->param('id');
  srand($id);
  my $uwp = new Subsector()->init->str;
  my $map = new Mapper;
  $map->initialize($uwp, $wiki, $c->url_for('uwp', id => $id));
  $map->communications();
  $map->trade();
  $c->render(text => $map->svg, format => 'svg');
} => 'map';

get '/trade/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $id = $c->param('id');
  srand($id);
  my $uwp = new Subsector()->init->str;
  my $map = new Mapper;
  $map->initialize($uwp, $wiki, $c->url_for('uwp', id => $id));
  $map->communications();
  $map->trade();
  $c->render(text => $map->text, format => 'txt');
} => 'map';

app->start;

__DATA__

=encoding utf8

@@ uwp.html.ep
% layout 'default';
% title 'Traveller Subsector UWP List Generator';
<h1>Traveller Subsector UWP List Generator (<%= $id =%>)</h1>
<pre>
<%= $uwp =%>
                       ||||||| |
Ag Agricultural        ||||||| |            In Industrial
As Asteroid            ||||||| +- Tech      Lo Low Population
Ba Barren              ||||||+- Law         Lt Low Technology
De Desert              |||||+- Government   Na Non-Agricultural
Fl Fluid Oceans        ||||+- Population    NI Non-Industrial
Ga Garden              |||+- Hydro          Po Poor
Hi High Population     ||+- Atmosphere      Ri Rich
Ht High Technology     |+- Size             Wa Water World
IC Ice-Capped          +- Starport          Va Vacuum

Bases: Naval – Scout – Research – TAS – Consulate – Pirate
</pre>
<p>
<%= link_to 'Generate UWP' => 'random' %>
<%= link_to 'Generate Map' => 'map' %>
</p>

@@ edit.html.ep
% layout 'default';
% title 'Traveller Subsector Mapper';
<p>
TODO
</p>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
%= stylesheet '/uwp-generator.css'
%= stylesheet begin
body {
  padding: 1em;
  font-family: "Palatino Linotype", "Book Antiqua", Palatino, serif;
}
form {
  display: inline;
}
textarea {
  width: 100%;
}
table {
  padding-bottom: 1em;
}
td, th {
  padding-right: 0.5em;
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
<a href="https://campaignwiki.org/traveller">Subsector Generator</a>&#x2003;
<%= link_to 'Source' => 'source' %>&#x2003;
<a href="https://github.com/kensanata/hex-mapping/blob/master/uwp-generator.pl">GitHub</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

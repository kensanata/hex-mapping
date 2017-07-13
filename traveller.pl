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

package Traveller::System;
use Class::Struct;

struct 'Traveller::System' => {
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
  my $self = shift;
  return $self->roll1d6() + $self->roll1d6();
}

sub compute_starport {
  my $self = shift;
  my %map = ( 2=>'X', 3=>'E', 4=>'E', 5=>'D', 6=>'D', 7=>'C',
	      8=>'C', 9=>'B', 10=>'B', 11=>'A', 12=>'A' );
  return $map{$self->roll2d6()};
}

sub compute_bases {
  my $self = shift;
  if ($self->starport eq 'A') {
    $self->naval($self->roll2d6() >= 8);
    $self->scout($self->roll2d6() >= 10);
    $self->research($self->roll2d6() >= 8);
    $self->TAS($self->roll2d6() >= 4);
    $self->consulate($self->roll2d6() >= 6);
  } elsif ($self->starport eq 'B') {
    $self->naval($self->roll2d6() >= 8);
    $self->scout($self->roll2d6() >= 8);
    $self->research($self->roll2d6() >= 10);
    $self->TAS($self->roll2d6() >= 6);
    $self->consulate($self->roll2d6() >= 8);
    $self->pirate($self->roll2d6() >= 12);
  } elsif ($self->starport eq 'C') {
    $self->scout($self->roll2d6() >= 8);
    $self->research($self->roll2d6() >= 10);
    $self->TAS($self->roll2d6() >= 10);
    $self->consulate($self->roll2d6() >= 10);
    $self->pirate($self->roll2d6() >= 10);
  } elsif ($self->starport eq 'D') {
    $self->scout($self->roll2d6() >= 7);
    $self->pirate($self->roll2d6() >= 12);
  } elsif ($self->starport eq 'E') {
    $self->pirate($self->roll2d6() >= 12);
  }
}

sub compute_atmosphere {
  my $self = shift;
  my $atmosphere = $self->roll2d6() -7 + $self->size;
  $atmosphere = 0 if $atmosphere < 0;
  return $atmosphere;
}

sub compute_temperature {
  my $self = shift;
  my $temperature = $self->roll2d6();
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
  my $hydro = $self->roll2d6() - 7 + $self->size;
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
  $hydro = 10 if $hydro > 10;
  return $hydro;
}

sub compute_government {
  my $self = shift;
  my $government = $self->roll2d6() - 7 + $self->population; # max 15
  $government = 0
    if $government < 0
    or $self->population == 0;
  return $government;
}

sub compute_law {
  my $self = shift;
  my $law = $self->roll2d6()-7+$self->government; # max 20!
  $law = 0
    if $law < 0
    or $self->population == 0;
  return $law;
}

sub compute_tech {
  my $self = shift;
  my $tech = $self->roll1d6();
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
  $tech += 3 if $self->population == 11; # impossible?
  $tech += 4 if $self->population == 12; # impossible?
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
  $self->size($self->roll2d6()-2);
  $self->atmosphere($self->compute_atmosphere);
  $self->temperature($self->compute_temperature);
  $self->hydro($self->compute_hydro);
  $self->population($self->roll2d6()-2); # How to get to B and C in the table?
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

package Traveller::System::Classic;
use Moose;
extends 'Traveller::System';

sub compute_starport {
  my $self = shift;
  my %map = ( 2=>'A', 3=>'A', 4=>'A', 5=>'B', 6=>'B', 7=>'C',
	      8=>'C', 9=>'D', 10=>'E', 11=>'E', 12=>'X' );
  return $map{$self->roll2d6()};
}

sub compute_bases {
  my $self = shift;
  if ($self->starport eq 'A'
      or $self->starport eq 'B') {
    $self->naval($self->roll2d6() >= 8);
  }
  if ($self->starport eq 'A') {
    $self->scout($self->roll2d6() >= 10);
  } elsif ($self->starport eq 'B') {
    $self->scout($self->roll2d6() >= 9);
  } elsif ($self->starport eq 'C') {
    $self->scout($self->roll2d6() >= 8);
  } elsif ($self->starport eq 'D') {
    $self->scout($self->roll2d6() >= 7);
  }
}

sub compute_temperature {
  # do nothing
}

sub compute_hydro {
  my $self = shift;
  my $hydro = $self->roll2d6() - 7 + $self->size;
  $hydro -= 4
    if $self->atmosphere == 0
      or $self->atmosphere == 1
      or $self->atmosphere >= 10;
  $hydro = 0
    if $self->size <= 1
      or $hydro < 0;
  $hydro = 10 if $hydro > 10;
  return $hydro;
}

sub compute_tech {
  my $self = shift;
  my $tech = $self->roll1d6();
  $tech += 6 if $self->starport eq 'A';
  $tech += 4 if $self->starport eq 'B';
  $tech += 2 if $self->starport eq 'C';
  $tech -= 4 if $self->starport eq 'X';
  $tech += 2 if $self->size <= 1;
  $tech += 1 if $self->size >= 2 and $self->size <= 4;
  $tech += 1 if $self->atmosphere <= 3 or $self->atmosphere >= 10;
  $tech += 1 if $self->hydro == 9;
  $tech += 2 if $self->hydro == 10;
  $tech += 1 if $self->population >= 1 and $self->population <= 5;
  $tech += 2 if $self->population == 9;
  $tech += 4 if $self->population == 10;
  $tech += 1 if $self->government == 0 or $self->government == 5;
  $tech -= 2 if $self->government == 13;
  $tech = 0 if $self->population == 0;
  return $tech;
}

sub check_doom {
  # do nothing
}

sub compute_travelcode {
  # do nothing
}

sub compute_tradecodes {
  my $self = shift;
  my $tradecodes = '';
  $tradecodes .= " Ag" if $self->atmosphere >= 4 and $self->atmosphere <= 9
      and $self->hydro >= 4 and $self->hydro <= 8
      and $self->population >= 5 and $self->population <= 7;
  $tradecodes .= " Na" if $self->atmosphere <= 3 and $self->hydro <= 3
      and $self->population >= 6;
  $tradecodes .= " In" if $self->atmosphere =~ /[012479]/ and $self->population >= 9;
  $tradecodes .= " NI" if $self->population <= 6;
  $tradecodes .= " Ri" if $self->atmosphere =~ /[68]/ and $self->population =~ /[678]/
      and $self->government =~ /[456789]/;
  $tradecodes .= " Po" if $self->atmosphere >= 2 and $self->atmosphere <= 5
    and $self->hydro <= 3;
  $tradecodes .= " Wa" if $self->hydro == 10;
  $tradecodes .= " De" if $self->atmosphere >= 2 and $self->hydro == 0;
  $tradecodes .= " Va" if $self->atmosphere == 0;
  $tradecodes .= " As" if $self->size == 0;
  $tradecodes .= " IC" if $self->atmosphere <= 1 and $self->hydro >= 1;
  return $tradecodes;
}

################################################################################

package Traveller::Subsector;
use Class::Struct;

struct 'Traveller::Subsector' => { systems => '@' };

sub add {
  my ($self, $system) = @_;
  push(@{$self->systems}, $system);
}

sub init {
  my ($self, $width, $height, $classic) = @_;
  $width //= 8;
  $height //= 10;
  for my $x (1..$width) {
    for my $y (1..$height) {
      if (int(rand(2))) {
	if ($classic) {
	  $self->add(new Traveller::System::Classic()->init($x, $y));
	} else {
	  $self->add(new Traveller::System()->init($x, $y));
	}
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

package Traveller::Hex;
use Class::Struct;

struct 'Traveller::Hex' => {
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
  map => 'Traveller::Mapper',
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

package Traveller::Mapper;
use Class::Struct;
use Memoize;

struct 'Traveller::Mapper' => {
  hexes => '@',
  routes => '@',
  source => '$',
  width => '$',
  height => '$',
};

my $example = q!Inedgeus     0101 D7A5579-8        G  Fl NI          A
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
  my $self = shift;
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
      tspan.trade {
        fill: #afeeee; /* pale turquoise */
      }
      line.trade {
        stroke-width: 6pt;
        stroke: #afeeee; /* pale turquoise */
        fill: none;
      }
      line.d1 {
        stroke-width: 6pt;
        stroke: #FF4242; /* eucalyptus */
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
		 # viewport
		 -0.5, -0.5, 3 + ($self->width - 1) * 1.5, ($self->height + 1.5) * sqrt(3),
		 # empty hex
		 @hex,
		 # framing rectangle
		 -0.5, -0.5, 3 + ($self->width - 1) * 1.5, ($self->height + 1.5) * sqrt(3));
}

sub grid {
  my $self = shift;
  my $scale = 100;
  my $doc;
  $doc .= join("\n",
	       map {
		 my $n = shift;
		 my $x = int($_/$self->height+1);
		 my $y = $_ % $self->height + 1;
		 my $svg = sprintf(qq{    <use xlink:href="#hex" x="%.3f" y="%.3f" />\n},
				   (1 + ($x-1) * 1.5) * $scale,
				   ($y - $x%2/2) * sqrt(3) * $scale);
		 $svg   .= sprintf(qq{    <text class="coordinates" x="%.3f" y="%.3f">}
		 		 . qq{%02d%02d</text>\n},
				   (1 + ($x-1) * 1.5) * $scale,
				   ($y - $x%2/2) * sqrt(3) * $scale - 0.6 * $scale,
				   $x, $y);
	       } (0 .. $self->width * $self->height - 1));
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
		  -10, ($self->height + 1) * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text class="direction" x="%.3f" y="%.3f">coreward</text>\n},
		  $self->width/2 * 1.5 * $scale, -0.13 * $scale);
  $doc .= sprintf(qq{    <text transform="translate(%.3f,%.3f) rotate(90)"}
		  . qq{ class="direction">trailing</text>\n},
		  ($self->width + 0.4) * 1.5 * $scale, $self->height/2 * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text class="direction" x="%.3f" y="%.3f">rimward</text>\n},
		  $self->width/2 * 1.5 * $scale, ($self->height + 0.7) * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text transform="translate(%.3f,%.3f) rotate(-90)"}
		  . qq{ class="direction">spinward</text>\n},
		  -0.1 * $scale, $self->height/2 * sqrt(3) * $scale);
  return $doc;
}

sub footer {
  my $self = shift;
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
  $self->width(0);
  $self->height(0);
  foreach (split(/\n/, $map)) {
    # parse Traveller UWP
    my ($name, $x, $y,
	$starport, $size, $atmosphere, $hydrographic, $population,
	$government, $law, $tech, $bases, $rest) =
	  /([^>\r\n\t]*?)\s+(\d\d)(\d\d)\s+([A-EX])([0-9A])([0-9A-F])([0-9A])([0-9A-C])([0-9A-F])([0-9A-L])-(\d?\d|[A-Z])(?:\s+([PCTRNSG ]+)\b)?(.*)/;
    # alternative super simple name, coordinates, optional size (0-9), optional bases (PCTRNSG), optional warning codes (AR)
    ($name, $x, $y, $size, $bases, $rest) =
      /([^>\r\n\t]*?)\s+(\d\d)(\d\d)(?:\s+([0-9])\b)?(?:\s+([PCTRNSG ]+)\b)?(.*)/
	unless $name;
    next unless $name;
    $self->width($x) if $x > $self->width;
    $self->height($y) if $y > $self->height;
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
    my $hex = Traveller::Hex->new(name=>$name,
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
	  and $self->distance($hex, $other) < $self->distance($hex, $best)) {
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
  $self->routes($self->minimal_spanning_tree($self->edges(@candidates)));
}

sub edges {
  my $self = shift;
  my @edges;
  my %seen;
  foreach my $hex (@_) {
    foreach my $route (@{$hex->routes}) {
      my ($start, @route) = @{$route};
      foreach my $end (@route) {
	# keep everything unidirectional
	next if exists $seen{$start}{$end} or exists $seen{$end}{$start};
	push(@edges, [$start, $end, $self->distance($start,$end)]);
	$seen{$start}{$end} = 1;
	$start = $end;
      }
    }
  }
  return @edges;
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
  return \@T;
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
    my @route = $self->route($hex, $to, $distance - $self->distance($from, $hex),
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
    if ($self->distance($start, $hex) <= $distance) {
      push(@result, $hex);
    }
  }
  return @result;
}

memoize('nearby');

sub distance {
  my ($self, $from, $to) = @_;
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
    $data .= sprintf(qq{    <line class="trade" x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" />\n},
		     (1 + ($x1-1) * 1.5) * $scale, ($y1 - $x1%2/2) * sqrt(3) * $scale,
		     (1 + ($x2-1) * 1.5) * $scale, ($y2 - $x2%2/2) * sqrt(3) * $scale);
  }
  return $data;
}

sub svg {
  my ($self) = @_;
  my $data = $self->header;
  $data .= qq{  <g id='comm'>\n};
  foreach my $hex (@{$self->hexes}) {
    $data .= $hex->comm_svg();
  }
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='routes'>\n};
  $data .= $self->trade_svg();
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='grid'>\n};
  $data .= $self->grid;
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='legend'>\n};
  $data .= $self->legend();
  $data .= qq{  </g>\n\n};
  $data .= qq{  <g id='system'>\n};
  foreach my $hex (@{$self->hexes}) {
    $data .= $hex->system_svg();
  }
  $data .= qq{  </g>\n};
  $data .= $self->footer();
  return $data;
}

sub text {
  my ($self) = @_;
  my $data = "Trade Routes:\n";
  foreach my $edge (@{$self->routes}) {
    my $u = @{$edge}[0];
    my $v = @{$edge}[1];
    $data .= $u->name . " - " . $v->name . "\n";
  }
  $data .= "\n";
  $data .= "Raw Data:\n";
  foreach my $hex (@{$self->hexes}) {
    foreach my $routeref (@{$hex->routes}) {
      $data .= join(' - ', map {$_->name} @{$routeref}) . "\n";
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

package Traveller::Mapper::Classic;
use Moose;
extends 'Traveller::Mapper';

sub communications {
  # do nothing
}

sub trade {
  # connect starports to each other based on a table
  # see https://talestoastound.wordpress.com/2015/10/30/traveller-out-of-the-box-interlude-the-1977-edition-over-the-1981-edition/
  my ($self) = @_;
  my @edges;
  my @candidates = grep { $_->starport =~ /[A-E]/ } @{$self->hexes};
  my @others = @candidates;
  # every system has a link to its partners
  foreach my $hex (@candidates) {
    foreach my $other (@others) {
      next if $hex == $other;
      my $d = $self->distance($hex, $other) - 1;
      next if $d > 3; # 0-4!
      my ($from, $to) = sort $hex->starport, $other->starport;
      my $target;
      if ($from eq 'A' and $to eq 'A') {
	$target = [1,2,4,5]->[$d];
      } elsif ($from eq 'A' and $to eq 'B') {
	$target = [1,3,4,5]->[$d];
      } elsif ($from eq 'A' and $to eq 'C') {
	$target = [1,4,6]->[$d];
      } elsif ($from eq 'A' and $to eq 'D') {
	$target = [1,5]->[$d];
      } elsif ($from eq 'A' and $to eq 'E') {
	$target = [2]->[$d];
      } elsif ($from eq 'B' and $to eq 'B') {
	$target = [1,3,4,6]->[$d];
      } elsif ($from eq 'B' and $to eq 'C') {
	$target = [2,4,6]->[$d];
      } elsif ($from eq 'B' and $to eq 'D') {
	$target = [3,6]->[$d];
      } elsif ($from eq 'B' and $to eq 'E') {
	$target = [4]->[$d];
      } elsif ($from eq 'C' and $to eq 'C') {
	$target = [3,6]->[$d];
      } elsif ($from eq 'C' and $to eq 'D') {
	$target = [4]->[$d];
      } elsif ($from eq 'C' and $to eq 'E') {
	$target = [4]->[$d];
      } elsif ($from eq 'D' and $to eq 'D') {
	$target = [4]->[$d];
      } elsif ($from eq 'D' and $to eq 'E') {
	$target = [5]->[$d];
      } elsif ($from eq 'E' and $to eq 'E') {
	$target = [6]->[$d];
      }
      if ($target and Traveller::System::roll1d6() >= $target) {
	push(@edges, [$hex, $other, $d + 1]);
      }
    }
    shift(@others);
  }
  # $self->routes($self->minimal_spanning_tree(@edges));
  $self->routes(\@edges);
}

sub trade_svg {
  my $self = shift;
  my $data = '';
  my $scale = 100;
  foreach my $edge (sort { $b->[2] cmp $a->[2] } @{$self->routes}) {
    my $u = @{$edge}[0];
    my $v = @{$edge}[1];
    my $d = @{$edge}[2];
    my ($x1, $y1) = ($u->x, $u->y);
    my ($x2, $y2) = ($v->x, $v->y);
    $data .= sprintf(qq{    <line class="trade d$d" x1="%.3f" y1="%.3f" x2="%.3f" y2="%.3f" />\n},
		     (1 + ($x1-1) * 1.5) * $scale, ($y1 - $x1%2/2) * sqrt(3) * $scale,
		     (1 + ($x2-1) * 1.5) * $scale, ($y2 - $x2%2/2) * sqrt(3) * $scale);
  }
  return $data;
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
		  . qq{ – ▲ scout base}
		  . qq{ – ★ navy base}
		  . qq{ – <tspan class="trade">▮</tspan> trade$uwp</text>\n},
		  -10, ($self->height + 1) * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text class="direction" x="%.3f" y="%.3f">coreward</text>\n},
		  $self->width/2 * 1.5 * $scale, -0.13 * $scale);
  $doc .= sprintf(qq{    <text transform="translate(%.3f,%.3f) rotate(90)"}
		  . qq{ class="direction">trailing</text>\n},
		  ($self->width + 0.4) * 1.5 * $scale, $self->height/2 * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text class="direction" x="%.3f" y="%.3f">rimward</text>\n},
		  $self->width/2 * 1.5 * $scale, ($self->height + 0.7) * sqrt(3) * $scale);
  $doc .= sprintf(qq{    <text transform="translate(%.3f,%.3f) rotate(-90)"}
		  . qq{ class="direction">spinward</text>\n},
		  -0.1 * $scale, $self->height/2 * sqrt(3) * $scale);
  return $doc;
}

################################################################################

package Traveller;

use Mojolicious::Lite;
use POSIX qw(INT_MAX);

get '/' => sub {
  my $c = shift;
  $c->redirect_to('edit');
};

get '/random' => sub {
  my $c = shift;
  $c->redirect_to('uwp', id => int(rand(INT_MAX)));
} => 'random';

get '/random/sector' => sub {
  my $c = shift;
  my $sector = $c->param('sector');
  $c->redirect_to('uwp-sector', id => int(rand(INT_MAX)));
} => 'random-sector';

get '/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  $c->redirect_to('uwp', id => $id);
};

get '/uwp/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  my $classic = $c->param('classic');
  srand($id);
  my $uwp = new Traveller::Subsector()->init(8,10,$classic)->str;
  $c->render(template => 'uwp', id => $id, classic => $classic, uwp => $uwp);
} => 'uwp';

get '/uwp/sector/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  srand($id);
  my $uwp = new Traveller::Subsector()->init(32,40)->str;
  $c->render(template => 'uwp-sector', id => $id, uwp => $uwp, sector => 1);
} => 'uwp-sector';

get '/source' => sub {
  my $c = shift;
  seek DATA, 0, 0;
  local undef $/;
  $c->render(text => <DATA>, format => 'text');
};

get '/edit' => sub {
  my $c = shift;
  $c->render(template => 'edit', uwp => Traveller::Mapper::example());
} => 'main';

get '/edit/:id' => sub {
  my $c = shift;
  my $id = $c->param('id');
  srand($id);
  my $uwp = new Traveller::Subsector()->init->str;
  $c->render(template => 'edit', uwp => $uwp);
} => 'edit';

get '/edit/sector/:id' => sub {
  my $c = shift;
  my $id = $c->param('id');
  srand($id);
  my $uwp = new Traveller::Subsector()->init(32,40)->str;
  $c->render(template => 'edit-sector', uwp => $uwp);
} => 'edit-sector';

get '/map/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $id = $c->param('id');
  my $classic = $c->param('classic');
  srand($id);
  my $uwp = new Traveller::Subsector()->init(8,10,$classic)->str;
  my $map;
  if ($classic) {
    $map = new Traveller::Mapper::Classic;
  } else {
    $map = new Traveller::Mapper;
  }
  $map->initialize($uwp, $wiki, $c->url_for('uwp', id => $id)->query(classic => $classic));
  $map->communications();
  $map->trade();
  $c->render(text => $map->svg, format => 'svg');
} => 'map';

get '/map/sector/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $id = $c->param('id');
  srand($id);
  my $uwp = new Traveller::Subsector()->init(32,40)->str;
  my $map = new Traveller::Mapper;
  $map->initialize($uwp, $wiki, $c->url_for('uwp-sector', id => $id));
  $map->communications();
  $map->trade();
  $c->render(text => $map->svg, format => 'svg');
} => 'map-sector';

get '/trade/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $id = $c->param('id');
  my $classic = $c->param('classic');
  srand($id);
  my $uwp = new Traveller::Subsector()->init(8,10,$classic)->str;
  my $map;
  if ($classic) {
    $map = new Traveller::Mapper::Classic;
  } else {
    $map = new Traveller::Mapper;
  }
  $map->initialize($uwp, $wiki, $c->url_for('uwp', id => $id));
  $map->communications();
  $map->trade();
  $c->render(text => $map->text, format => 'txt');
} => 'trade';

any '/map' => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $trade = $c->param('trade');
  my $uwp = $c->param('map');
  my $source;
  if (!$uwp) {
    my $id = int(rand(INT_MAX));
    srand($id);
    $uwp = new Traveller::Subsector()->init->str;
    $source = $c->url_for('uwp', id => $id);
  }
  my $map = new Traveller::Mapper;
  $map->initialize($uwp, $wiki, $source);
  $map->communications();
  $map->trade();
  if ($trade) {
    $c->render(text => $map->text, format => 'txt');
  } else {
    $c->render(text => $map->svg, format => 'svg');
  }
} => 'random-map';

any '/map-sector' => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $trade = $c->param('trade');
  my $uwp = $c->param('map');
  my $source;
  if (!$uwp) {
    my $id = int(rand(INT_MAX));
    srand($id);
    $uwp = new Traveller::Subsector()->init(32,40)->str;
    $source = $c->url_for('uwp', id => $id);
  }
  my $map = new Traveller::Mapper;
  $map->initialize($uwp, $wiki, $source);
  $map->communications();
  $map->trade();
  if ($trade) {
    $c->render(text => $map->text, format => 'txt');
  } else {
    $c->render(text => $map->svg, format => 'svg');
  }
} => 'random-map-sector';

app->start;

__DATA__

=encoding utf8

@@ uwp-footer.html.ep
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

@@ uwp.html.ep
% layout 'default';
% title 'Traveller Subsector UWP List Generator';
<h1>Traveller Subsector UWP List Generator (<%= $id =%>)</h1>
<pre>
<%= $uwp =%>
<%= include 'uwp-footer' =%>
</pre>
<p>
<%= link_to url_for('map')->query(classic => $classic) => begin %>Generate Map<% end %>
<%= link_to 'Edit UWP' => 'edit' %>
<%= link_to 'Random Subsector' => 'random' %>
<%= link_to 'Random Sector' => 'random-sector' %>
</p>

@@ uwp-sector.html.ep
% layout 'default';
% title 'Traveller Sector UWP List Generator';
<h1>Traveller Sector UWP List Generator (<%= $id =%>)</h1>
<pre>
<%= $uwp =%>
<%= include 'uwp-footer' =%>
</pre>
<p>
<%= link_to 'Generate Map' => 'map-sector' %>
<%= link_to 'Edit UWP' => 'edit-sector' %>
<%= link_to 'Random Subsector' => 'random' %>
<%= link_to 'Random Sector' => 'random-sector' %>
</p>

@@ edit-footer.html.ep
<p>
<b>URL</b>:
If provided, every systems will be linked to an appropriate page.
Feel free to create a <a href="https://campaignwiki.org/">campaign wiki</a> for your game.
</p>
<p>
<b>Editing</b>:
If you generate a random map, there will be a link to its UWP at the bottom.
Click the link to print it, save it, or to make manual changes.
</p>
<p>
<b>Format</b>:
<i>name</i>, some whitespace,
<i>coordinates</i> (four digits between 0101 and 0810),
some whitespace,
<i>starport</i> (A-E or X)
<i>size</i> (0-9 or A)
<i>atmosphere</i> (0-9 or A-F)
<i>hydrographic</i> (0-9 or A)
<i>population</i> (0-9 or A-C)
<i>government</i> (0-9 or A-F)
<i>law level</i> (0-9 or A-L) a dash,
<i>tech level</i> (0-99) optionally a non-standard group of bases and a gas giant indicator, optionally separated by whitespace:
<i>pirate base</i> (P)
<i>imperial consulate</i> (C)
<i>TAS base</i> (T)
<i>research base</i> (R)
<i>naval base</i> (N)
<i>scout base</i> (S)
<i>gas giant</i> (G), followed by trade codes (see below), and optionally a
<i>travel code</i> (A or R).
Whitespace can be one or more spaces and tabs.
</p>
<p>Trade codes:</p>
<pre>
    Ag Agricultural     Hi High Population    Na Non-Agricultural
    As Asteroid         Ht High Technology    NI Non-Industrial
    Ba Barren           IC Ice-Capped         Po Poor
    De Desert           In Industrial         Ri Rich
    Fl Fluid Oceans     Lo Low Population     Wa Water World
    Ga Garden           Lt Low Technology     Va Vacuum
</pre>
<p>
<b>Alternative format for quick maps</b>:
<i>name</i>, some whitespace,
<i>coordinates</i> (four digits between 0101 and 0810), some whitespace,
<i>size</i> (0-9)
optionally a non-standard group of bases and a gas giant indicator,
optionally separated by whitespace:
<i>pirate base</i> (P)
<i>imperial consulate</i> (C)
<i>TAS base</i> (T)
<i>research base</i> (R)
<i>naval base</i> (N)
<i>scout base</i> (S)
<i>gas giant</i> (G),
followed by trade codes (see below),
and optionally a <i>travel code</i> (A or R).
</p>

@@ edit.html.ep
% layout 'default';
% title 'Traveller Subsector Generator';
<h1>Traveller Subsector Generator</h1>
<p>Submit your UWP list of the subsector.</p>
%= form_for 'random-map' => (method => 'POST') => begin
<p>
%= text_area 'map' => (cols => 60, rows => 20) => begin
<%= $uwp =%>
% end
</p>
<p>URL (optional):
%= text_field 'wiki' => 'http://campaignwiki.org/wiki/NameOfYourWiki/' => (id => 'wiki')
</p>
%= submit_button 'Generate Map'
%= submit_button 'Communication and Trade Routes', name => 'trade'
%= end
%= form_for 'random-map' => (method => 'POST') => begin
%= submit_button 'Random Subsector'
%= end
%= form_for 'random-map-sector' => (method => 'POST') => begin
%= submit_button 'Random Sector'
%= end
%= include 'edit-footer'

@@ edit-sector.html.ep
% layout 'default';
% title 'Traveller Subsector Generator';
<h1>Traveller Subsector Generator</h1>
<p>Submit your UWP list of the subsector.</p>
%= form_for 'random-map-sector' => (method => 'POST') => begin
<p>
%= text_area 'map' => (cols => 60, rows => 20) => begin
<%= $uwp =%>
% end
</p>
<p>URL (optional):
%= text_field 'wiki' => 'http://campaignwiki.org/wiki/NameOfYourWiki/' => (id => 'wiki')
</p>
%= submit_button 'Generate Map'
%= submit_button 'Communication and Trade Routes', name => 'trade'
%= end
%= form_for 'random-map' => (method => 'POST') => begin
%= submit_button 'Random Subsector'
%= end
%= form_for 'random-map-sector' => (method => 'POST') => begin
%= submit_button 'Random Sector'
%= end
%= include 'edit-footer'

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
%= stylesheet '/traveller.css'
%= stylesheet begin
body {
  width: 80ex;
  padding: 1em;
  font-family: "Palatino Linotype", "Book Antiqua", Palatino, serif;
}
form {
  display: inline;
}
textarea {
  width: 100%;
  font-family: "Andale Mono", Monaco, "Courier New", Courier, monospace, "Symbola";
  font-size: 100%;
}
#wiki {
  width: 40em;
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
<a href="https://github.com/kensanata/hex-mapping/blob/master/traveller.pl">GitHub</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

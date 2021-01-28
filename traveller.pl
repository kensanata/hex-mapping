#!/usr/bin/perl
# Copyright (C) 2009-2019  Alex Schroeder <alex@gnu.org>
# Copyright (C) 2020       Christian Carey
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

use 5.010_000; # ensure availability of // operator

my $debug;

################################################################################

package Traveller::Util;
use Moose::Role;
use Memoize;

# These functions work on things that have x and y members.

sub in {
  my $item = shift;
  foreach (@_) {
    return $item if $item == $_;
  }
}

__PACKAGE__->meta->add_method(
  nearby => memoize(
    sub {
      my ($start, $distance, $candidates) = @_;
      $distance = 1 unless $distance; # default
      my @result = ();
      foreach my $candidate (@$candidates) {
	next if $candidate == $start;
	if (distance($start, $candidate) <= $distance) {
	  push(@result, $candidate);
	}
      }
      return @result;
    }));

__PACKAGE__->meta->add_method(
  distance => memoize(
    sub {
      my ($from, $to) = @_;
      my ($x1, $y1, $x2, $y2) = ($from->x, $from->y, $to->x, $to->y);
      # transform the stupid Traveller coordinate system into a decent
      # system with one axis tilted by 60°
      $y1 = $y1 - POSIX::ceil($x1/2);
      $y2 = $y2 - POSIX::ceil($x2/2);
      return d($x1, $y1, $x2, $y2);
    }));

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

################################################################################

package Traveller::System;
use Moose;

has 'name' => (is => 'rw', isa => 'Str');
has 'x' => (is => 'rw', isa => 'Int');
has 'y' => (is => 'rw', isa => 'Int');
has 'starport' => (is => 'rw', isa => 'Str');
has 'size' => (is => 'rw', isa => 'Str');
has 'atmosphere' => (is => 'rw', isa => 'Str');
has 'temperature' => (is => 'rw', isa => 'Str');
has 'hydro' => (is => 'rw', isa => 'Str');
has 'population' => (is => 'rw', isa => 'Str');
has 'government' => (is => 'rw', isa => 'Str');
has 'law' => (is => 'rw', isa => 'Str');
has 'tech' => (is => 'rw', isa => 'Str');
has 'consulate' => (is => 'rw', isa => 'Str');
has 'pirate' => (is => 'rw', isa => 'Str');
has 'TAS' => (is => 'rw', isa => 'Str');
has 'research' => (is => 'rw', isa => 'Str');
has 'naval' => (is => 'rw', isa => 'Str');
has 'scout' => (is => 'rw', isa => 'Str');
has 'gasgiant' => (is => 'rw', isa => 'Str');
has 'tradecodes' => (is => 'rw', isa => 'Str');
has 'travelzone' => (is => 'rw', isa => 'Str');
has 'culture' => (is => 'rw', isa => 'Str');

sub compute_name {
  my $self = shift;
  my $digraphs = shift;
  my $max = scalar(@$digraphs);
  my $length = 3 + rand(3); # length of name before adding one more
  my $name = '';
  while (length($name) < $length) {
    my $i = 2*int(rand($max/2));
    $name .= $digraphs->[$i];
    $name .= $digraphs->[$i+1];
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
  $self->gasgiant($self->roll2d6() < 10);
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
  $tradecodes .= " Ic" if $self->atmosphere <= 1 and $self->hydro >= 1;
  $tradecodes .= " In" if $self->atmosphere =~ /^[012479]$/ and $self->population >= 9;
  $tradecodes .= " Lo" if $self->population >= 1 and $self->population <= 3;
  $tradecodes .= " Lt" if $self->tech >= 1 and $self->tech <= 5;
  $tradecodes .= " Na" if $self->atmosphere <= 3 and $self->hydro <= 3
    and $self->population >= 6;
  $tradecodes .= " Ni" if $self->population >= 4 and $self->population <= 6;
  $tradecodes .= " Po" if $self->atmosphere >= 2 and $self->atmosphere <= 5
    and $self->hydro <= 3;
  $tradecodes .= " Ri" if $self->atmosphere =~ /^[68]$/
    and $self->population >= 6 and $self->population <= 8;
  $tradecodes .= " Wa" if $self->hydro >= 10;
  $tradecodes .= " Va" if $self->atmosphere == 0;
  return $tradecodes;
}

sub compute_travelzone {
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
  $self->name($self->compute_name(shift));
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
  $self->travelzone($self->compute_travelzone);
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
  $bases .= 'G' if $self->gasgiant;
  $uwp .= sprintf("%7s", $bases);
  $uwp .= '  ' . $self->tradecodes;
  $uwp .= ' ' . $self->travelzone if $self->travelzone;
  if ($self->culture) {
    my $spaces = 20 - length($self->tradecodes);
    $spaces -= 1 + length($self->travelzone) if $self->travelzone;
    $uwp .= ' ' x $spaces;
    $uwp .= '[' . $self->culture . ']';
  }
  return $uwp;
}

################################################################################

package Traveller::System::Classic;
use List::Util qw(min max);
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
  if ($self->starport =~ /^[AB]$/) {
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
  $self->gasgiant($self->roll2d6() < 10);
}

sub compute_atmosphere {
  my $self = shift;
  my $atmosphere = $self->size == 0 ? 0 : ($self->roll2d6() - 7 + $self->size);
  $atmosphere = min(max($atmosphere, 0), 15);
  return $atmosphere;
}

sub compute_temperature {
  # do nothing
}

sub compute_hydro {
  my $self = shift;
  my $hydro = $self->roll2d6() - 7 + $self->atmosphere; # erratum
  $hydro -= 4
    if $self->atmosphere <= 1
      or $self->atmosphere >= 10;
  $hydro = 0 if $self->size <= 1;
  $hydro = min(max($hydro, 0), 10);
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
  return $tech;
}

sub check_doom {
  # do nothing
}

sub compute_travelzone {
  # do nothing
}

sub compute_tradecodes {
  my $self = shift;
  my $tradecodes = '';
  $tradecodes .= ' Ri' if $self->atmosphere =~ /^[68]$/
      and $self->population >= 6 and $self->population <= 8
      and $self->government >= 4 and $self->government <= 9;
  $tradecodes .= ' Po' if $self->atmosphere >= 2 and $self->atmosphere <= 5
      and $self->hydro <= 3;
  $tradecodes .= ' Ag' if $self->atmosphere >= 4 and $self->atmosphere <= 9
      and $self->hydro >= 4 and $self->hydro <= 8
      and $self->population >= 5 and $self->population <= 7;
  $tradecodes .= ' Na' if $self->atmosphere <= 3 and $self->hydro <= 3
      and $self->population >= 6;
  $tradecodes .= ' In' if $self->atmosphere =~ /^[012479]$/ and $self->population >= 9;
  $tradecodes .= ' Ni' if $self->population <= 6;
  $tradecodes .= ' Wa' if $self->hydro == 10;
  $tradecodes .= ' De' if $self->atmosphere >= 2 and $self->hydro == 0;
  $tradecodes .= ' Va' if $self->atmosphere == 0;
  $tradecodes .= ' As' if $self->size == 0;
  $tradecodes .= ' Ic' if $self->atmosphere <= 1 and $self->hydro >= 1;
  return $tradecodes;
}

sub code {
  my $num = shift;
  my $code = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'; # 'I' and 'O' are omitted
  return '?' if !defined $num or $num !~ /^\d{1,2}$/ or $num >= length($code);
  return substr($code, $num, 1);
}

sub str {
  my $self = shift;
  my $uwp = sprintf('%-16s %02u%02u  ', $self->name, $self->x, $self->y);
  $uwp .= $self->starport;
  $uwp .= code($self->size);
  $uwp .= code($self->atmosphere);
  $uwp .= code($self->hydro);
  $uwp .= code($self->population);
  $uwp .= code($self->government);
  $uwp .= code($self->law);
  $uwp .= '-';
  $uwp .= code($self->tech);
  my $bases = '';
  $bases .= 'N' if $self->naval;
  $bases .= 'S' if $self->scout;
  $bases .= 'R' if $self->research;
  $bases .= 'T' if $self->TAS;
  $bases .= 'C' if $self->consulate;
  $bases .= 'P' if $self->pirate;
  $bases .= 'G' if $self->gasgiant;
  $uwp .= sprintf('%7s', $bases);
  $uwp .= '  ' . $self->tradecodes;
  $uwp .= ' ' . $self->travelzone if $self->travelzone;
  if ($self->culture) {
    my $spaces = 20 - length($self->tradecodes);
    $spaces -= 1 + length($self->travelzone) if $self->travelzone;
    $uwp .= ' ' x $spaces;
    $uwp .= '[' . $self->culture . ']';
  }
  return $uwp;
}

################################################################################

package Traveller::System::Classic::MPTS;
use Moose;
extends 'Traveller::System::Classic';

sub compute_tradecodes {
  my $self = shift;
  my $tradecodes = '';
  $tradecodes .= ' Ag' if $self->atmosphere >= 4 and $self->atmosphere <= 9
      and $self->hydro >= 4 and $self->hydro <= 8
      and $self->population >= 5 and $self->population <= 7;
  $tradecodes .= ' As' if $self->size == 0
      and $self->atmosphere == 0
      and $self->hydro == 0;
  $tradecodes .= ' Ba' if $self->population == 0
      and $self->government == 0
      and $self->law == 0;
  $tradecodes .= ' De' if $self->atmosphere >= 2 and $self->hydro == 0;
  $tradecodes .= ' Fl' if $self->atmosphere =~ /^[ABC]$/ # erratum
      and $self->hydro >= 1;
  $tradecodes .= ' Hi' if $self->population >= 9;
  $tradecodes .= ' Ic' if $self->atmosphere <= 1 and $self->hydro >= 1;
  $tradecodes .= ' In' if $self->atmosphere =~ /^[012479]$/ and $self->population >= 9;
  $tradecodes .= ' Lo' if $self->population <= 3;
  $tradecodes .= ' Na' if $self->atmosphere <= 3 and $self->hydro <= 3
      and $self->population >= 6;
  $tradecodes .= ' Ni' if $self->population <= 6;
  $tradecodes .= ' Po' if $self->atmosphere >= 2 and $self->atmosphere <= 5
      and $self->hydro <= 3;
  $tradecodes .= ' Ri' if $self->atmosphere =~ /^[68]$/
      and $self->population >= 6 and $self->population <= 8
      and $self->government >= 4 and $self->government <= 9;
  $tradecodes .= ' Va' if $self->atmosphere == 0;
  $tradecodes .= ' Wa' if $self->hydro == 10;
  return $tradecodes;
}

################################################################################

package Traveller::Subsector;
use List::Util qw(shuffle);
use Moose;

with 'Traveller::Util';

has 'systems' => (
  is      => 'rw',
  isa     => 'ArrayRef[Traveller::System]',
  default => sub { [] });

sub one {
  my $i = int(rand(scalar @_));
  return $_[$i];
}

sub compute_digraphs {
  my @first = qw(b c d f g h j k l m n p q r s t v w x y z .
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

sub add {
  my ($self, $system) = @_;
  push(@{$self->systems}, $system);
}

sub init {
  my ($self, $width, $height, $rules, $density) = @_;
  $density ||= 0.5;
  my $digraphs = $self->compute_digraphs;
  $width //= 8;
  $height //= 10;
  for my $x (1..$width) {
    for my $y (1..$height) {
      if (rand() < $density) {
	my $system;
        if ($rules eq 'mpts') {
	  $system = Traveller::System::Classic::MPTS->new();
	} elsif ($rules eq 'ct') {
	  $system = Traveller::System::Classic->new();
	} else {
	  $system = Traveller::System->new();
	}
	$self->add($system->init($x, $y, $digraphs));
      }
    }
  }
  # Rename some systems: assume a jump-2 and a jump-1 culture per every
  # subsector of 8×10×½ systems. Go through the list in random order.
  for my $system (shuffle(grep { rand(20) < 1 } @{$self->systems})) {
    $self->spread(
      $system,
      $self->compute_digraphs,
      1 + int(rand(2)),  # jump distance
      1 + int(rand(3))); # jump number
  }
  return $self;
}

sub spread {
  my ($self, $system, $digraphs, $jump_distance, $jump_number) = @_;
  my $culture = $system->compute_name($digraphs);
  # warn sprintf("%02d%02d %s %d %d\n", $system->x, $system->y, $culture, $jump_distance, $jump_number);
  my $network = [$system];
  $self->grow($system, $jump_distance, $jump_number, $network);
  for my $other (@$network) {
    $other->culture($culture);
    $other->name($other->compute_name($digraphs));
  }
}

sub grow {
  my ($self, $system, $jump_distance, $jump_number, $network) = @_;
  my @new_neighbours =
      grep { not $_->culture or int(rand(2)) }
      grep { not Traveller::Util::in($_, @$network) }
  $self->neighbours($system, $jump_distance, $jump_number);
  # for my $neighbour (@new_neighbours) {
  #   warn sprintf(" added %02d%02d %d %d\n", $neighbour->x, $neighbour->y, $jump_distance, $jump_number);
  # }
  push(@$network, @new_neighbours);
  if ($jump_number > 0) {
    for my $neighbour (@new_neighbours) {
      $self->grow($neighbour, $jump_distance, $jump_number - 1, $network);
    }
  }
}

sub neighbours {
  my ($self, $system, $jump_distance, $jump_number) = @_;
  my @neighbours = nearby($system, $jump_distance, $self->systems);
  return @neighbours;
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
use Moose;

has 'name' => (is => 'ro', isa => 'Str');
has 'x' => (is => 'ro', isa => 'Int');
has 'y' => (is => 'ro', isa => 'Int');
has 'starport' => (is => 'ro', isa => 'Str');
has 'size' => (is => 'ro', isa => 'Str');
has 'population' => (is => 'ro', isa => 'Str');
has 'consulate' => (is => 'rw', isa => 'Str');
has 'pirate' => (is => 'rw', isa => 'Str');
has 'TAS' => (is => 'rw', isa => 'Str');
has 'research' => (is => 'rw', isa => 'Str');
has 'naval' => (is => 'rw', isa => 'Str');
has 'scout' => (is => 'rw', isa => 'Str');
has 'gasgiant' => (is => 'rw', isa => 'Str');
has 'travelzone' => (is => 'ro', isa => 'Str');
has 'url' => (is => 'rw', isa => 'Str');
has 'map' => (is => 'rw', isa => 'Traveller::Mapper');
has 'comm' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has 'trade' => (is => 'ro', isa => 'HashRef', default => sub { {} });
has 'routes' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has 'culture' => (is => 'ro', isa => 'Str');

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
  # travel zone red painted first, so it appears at the bottom
  $data .= sprintf(qq{$lead    <circle class="travelzone red" cx="%.3f" cy="%.3f" r="%.3f" />\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2) * sqrt(3) * $scale, 0.52 * $scale)
    if $self->travelzone eq 'R';
  $data .= sprintf(qq{$lead    <circle cx="%.3f" cy="%.3f" r="%.3f" />\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2) * sqrt(3) * $scale, 11 + $size);
  $data .= sprintf(qq{$lead    <circle class="travelzone amber" cx="%.3f" cy="%.3f" r="%.3f" />\n},
		   (1 + ($x-1) * 1.5) * $scale,
		   ($y - $x%2/2) * sqrt(3) * $scale, 0.52 * $scale)
    if $self->travelzone eq 'A';
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
use List::Util qw(shuffle reduce);
use Moose;
with 'Traveller::Util';

has 'hexes' => (is => 'rw', isa => 'ArrayRef[Traveller::Hex]', default => sub { [] });
has 'routes' => (is => 'rw', isa => 'ArrayRef', default => sub { [] });
has 'comm_set' => (is => 'rw', isa => 'Bool');
has 'trade_set' => (is => 'rw', isa => 'Bool');
has 'source' => (is => 'rw');
has 'width' => (is => 'rw', isa => 'Int');
has 'height' => (is => 'rw', isa => 'Int');

my $example = q!Inedgeus     0101 D7A5579-8        G  Fl Ni          A
Geaan        0102 E66A999-7        G  Hi Wa          A
Orgemaso     0103 C555875-5       SG  Ga Lt
Veesso       0105 C5A0369-8        G  De Lo          A
Ticezale     0106 B769799-7    T  SG  Ri             A
Maatonte     0107 C6B3544-8   C    G  Fl Ni          A
Diesra       0109 D510522-8       SG  Ni
Esarra       0204 E869100-8        G  Lo             A
Rience       0205 C687267-8        G  Ga Lo
Rearreso     0208 C655432-5   C    G  Ga Lt Ni
Laisbe       0210 E354663-3           Ag Lt Ni
Biveer       0302 C646576-9   C    G  Ag Ga Ni
Labeveri     0303 A796100-9   CT N G  Ga Lo          A
Sotexe       0408 E544778-3        G  Ag Ga Lt       A
Zamala       0409 A544658-13   T N G  Ag Ga Ht Ni
Sogeeran     0502 A200443-14  CT N G  Ht Ni Va
Aanbi        0503 E697102-7        G  Ga Lo          A
Bemaat       0504 C643384-9   C R  G  Lo Po
Diare        0505 A254430-11   TRN G  Ni             A
Esgeed       0507 A8B1579-11    RN G  Fl Ni          A
Leonbi       0510 B365789-9    T  SG  Ag Ri          A
Reisbeon     0604 C561526-8     R  G  Ni
Atcevein     0605 A231313-11  CT   G  Lo Po
Usmabe       0607 A540A84-15   T   G  De Hi Ht In Po
Onbebior     0608 B220530-10       G  De Ni Po       A
Raraxema     0609 B421768-8    T NSG  Na Po
Xeerri       0610 C210862-9        G  Na
Onreon       0702 D8838A9-2       S   Lt Ri          A
Ismave       0703 E272654-4           Lt Ni
Lara         0704 C0008D9-5       SG  As Lt Na Va    A
Lalala       0705 C140473-9     R  G  De Ni Po
Maxereis     0707 A55A747-12  CT NSG  Ht Wa
Requbire     0802 C9B4200-10       G  Fl Lo          A
Azaxe        0804 B6746B9-8   C    G  Ag Ga Ni       A
Rieddige     0805 B355578-7        G  Ag Ni          A
Usorce       0806 E736110-3        G  Lo Lt          A
Solacexe     0810 D342635-4  P    S   Lt Ni Po       R
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
  my ($self, $width, $height) = @_;
  # TO DO: support an option for North American “A” paper dimensions (width 215.9 mm, length 279.4 mm)
  $width //= 210;
  $height //= 297;
  my $template = <<EOT;
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1"
     xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${width}mm"
     height="${height}mm"
     viewBox="%s %s %s %s">
  <desc>Traveller Subsector</desc>
  <defs>
    <style type="text/css"><![CDATA[
      text {
        font-size: 16pt;
        font-family: Optima, "Optima Regular", Optima-Regular, Helvetica, sans-serif;
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
      .travelzone {
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
      #background {
        fill: inherit;
      }
      #bg {
        fill: inherit;
      }
      /* original culture */
      .culture0 { fill: white; }
      /* later cultures */
      .culture1  { fill: #d3d3d3; }
      .culture2  { fill: #f5f5f5; }
      .culture3  { fill: #eaeaea; }
      .culture4  { fill: #fffeb0; }
      .culture5  { fill: #fff0f5; }
      .culture6  { fill: #eee0e5; }
      .culture7  { fill: #ffe1ff; }
      .culture8  { fill: #eed2ee; }
      .culture9  { fill: #c6e2ff; }
      .culture10 { fill: #fdf5e6; }
      .culture11 { fill: #e0ffff; }
      .culture12 { fill: #d1eeee; }
      .culture13 { fill: #c5fff5; }
      .culture14 { fill: #eeeee0; }
      .culture15 { fill: #fff68f; }
      .culture16 { fill: #eee685; }
      .culture17 { fill: #fffacd; }
      .culture18 { fill: #eee9bf; }
      .culture19 { fill: #ffe7ba; }
      .culture20 { fill: #ffefdb; }
      .culture21 { fill: #ffe4e1; }
      .culture22 { fill: #eed5d2; }
      .culture23 { fill: #e6e6fa; }
      .culture24 { fill: #f0ffff; }
      .culture25 { fill: #c5ffd5; }
      .culture26 { fill: #e6ffe6; }
      .culture27 { fill: #d5ffc5; }
      .culture28 { fill: #f5f5dc; }
    ]]></style>
    <polygon id="hex" points="%s,%s %s,%s %s,%s %s,%s %s,%s %s,%s" />
    <polygon id="bg" points="%s,%s %s,%s %s,%s %s,%s %s,%s %s,%s" />
  </defs>
  <rect fill="white" stroke="black" stroke-width="10" id="frame"
        x="%s" y="%s" width="%s" height="%s" />

EOT
  my $scale = 100;
  return sprintf($template,
		 map { sprintf("%.3f", $_ * $scale) }
		 # viewport
		 -0.5, -0.5, 3 + ($self->width - 1) * 1.5, ($self->height + 1.5) * sqrt(3),
		 # empty hex, once for the backgrounds and once for the stroke
		 @hex,
		 @hex,
		 # framing rectangle
		 -0.5, -0.5, 3 + ($self->width - 1) * 1.5, ($self->height + 1.5) * sqrt(3));
}

sub background {
  my $self = shift;
  my $scale = 100;
  my $doc;
  # We want to colour cultures such that the same colours result from the same
  # names. The number of colours is given by the CSS. We must therefore hash all
  # the names to one of these colours; but index 0 is a white background, so
  # don't use that.
  my $colours = 28;
  my %id;
  my %seen;
  my %used;
  for my $hex (@{$self->hexes}) {
    if ($hex->culture) {
      my $coord = $hex->x . $hex->y;
      if ($seen{$hex->culture}) {
	$id{$coord} = $seen{$hex->culture};
      } else {
	my $colour = 1 + unpack("%32W*", lc $hex->culture) % $colours; # checksum
	# reduce collisions
	for (1 .. 3) {
	  last unless $used{$colour};
	  $colour = 1+ ($colour + 1) % $colours;
	}
	$seen{$hex->culture} = $id{$coord} = $colour;
	$used{$colour} = $hex->culture;
      }
    }
  }
  # warn scalar(keys %used) . " colours used\n";
  $doc .= join("\n",
	       map {
		 my $n = shift;
		 my $x = int($_/$self->height+1);
		 my $y = $_ % $self->height + 1;
		 my $coord = sprintf('%02d%02d', $x, $y);
		 my $class = $id{$coord} // 0;
		 my $svg = sprintf(qq{    <use xlink:href="#bg" x="%.3f" y="%.3f" class="culture$class"/>},
				   (1 + ($x-1) * 1.5) * $scale,
				   ($y - $x%2/2) * sqrt(3) * $scale);
	       }
	       (0 .. $self->width * $self->height - 1));
  return $doc;
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
		 my $svg = sprintf(qq{    <use xlink:href="#hex" x="%.3f" y="%.3f"/>\n},
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
  my $uwp = '';
  if ($self->source) {
    $uwp = ' – <a xlink:href="' . $self->source . '">UWP</a>';
  }
  $doc .= sprintf(qq{    <text class="legend" x="%.3f" y="%.3f">◉ gas giant}
		  . qq{ – ■ Imperial consulate – ☼ TAS facility – ▲ scout base}
		  . qq{ – ★ naval base – π research station – ☠ pirate base}
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
  my @lines = split(/\n/, $map);
  $self->initialize_map($wiki, \@lines);
  $self->initialize_routes(\@lines);
}

sub initialize_map {
  my ($self, $wiki, $lines) = @_;
  foreach (@$lines) {
    # parse Traveller UWP
    my ($name, $x, $y,
	$starport, $size, $atmosphere, $hydrographic, $population,
	$government, $law, $tech, $bases, $rest) =
	  /([^>\r\n\t]*?)\s+(\d\d)(\d\d)\s+([A-EX])([\dA])([\dA-F])([\dA])([\dA-C])([\dA-F])([\dA-L])-(\d{1,2}|[\dA-HJ-NP-Z])(?:\s+([PCTRNSG ]+)\b)?(.*)/;
    # alternative super simple name, coordinates, optional size (0-9), optional bases (PCTRNSG), optional travel zones (AR)
    ($name, $x, $y, $size, $bases, $rest) =
      /([^>\r\n\t]*?)\s+(\d\d)(\d\d)(?:\s+(\d)\b)?(?:\s+([PCTRNSG ]+)\b)?(.*)/
	unless $name;
    next unless $name;
    $self->width($x) if $x > $self->width;
    $self->height($y) if $y > $self->height;
    my @tokens = split(' ', $rest);
    my %trade = map { $_ => 1 } grep(/^[A-Z][A-Za-z]$/, @tokens);
    my ($culture) = grep /^\[.*\]$/, @tokens; # culture in square brackets
    my ($travelzone) = grep /^([AR])$/, @tokens;    # amber or red travel zone
    # avoid uninitialized values warnings in the rest of the code
    map { $$_ //= '' } (\$size,
			\$atmosphere,
			\$hydrographic,
			\$population,
			\$government,
			\$law,
			\$starport,
			\$travelzone);
    # get "hex" values, but accept letters beyond F! (excepting I and O)
    map { $$_ = $$_ ge 'P' and $$_ le 'Z' ? 23 + ord($$_) - 80
	      : $$_ ge 'J' and $$_ le 'N' ? 18 + ord($$_) - 74
	      : $$_ ge 'A' and $$_ le 'H' ? 10 + ord($$_) - 65
	      : $$_ eq '' ? 0
	      : $$_ } (\$size,
		       \$atmosphere,
		       \$hydrographic,
		       \$population,
		       \$government,
		       \$law);
    my $hex = Traveller::Hex->new(
      name => $name,
      x => $x,
      y => $y,
      starport => $starport,
      population => $population,
      size => $size,
      travelzone => $travelzone,
      trade => \%trade,
      culture => $culture // '');
    $hex->url("$wiki$name") if $wiki;
    if ($bases) {
      for my $base (split(//, $bases)) {
	$hex->base($base);
      }
    }
    $self->add($hex);
  }
}

sub add {
  my ($self, $hex) = @_;
  push(@{$self->hexes}, $hex);
}

sub initialize_routes {
  my ($self, $lines) = @_;
  foreach (@$lines) {
    # parse non-standard routes
    my ($from, $to, $type) = /^(\d\d\d\d)-(\d\d\d\d)\s+(C|T)\b/i;
    next unless $type;
    if (lc($type) eq 'c') {
      $self->comm_set(1); # at least one hex here has comm
      push(@{$self->at($from)->comm}, $self->at($to)); # a property of the hex
    } else {
      $self->trade_set(1); # at least one hex here has trade
      my $from_hex = $self->at($from);
      my $to_hex = $self->at($to);

      push(@{$self->routes}, [$from_hex, $to_hex]); # a property of the mapper
    }
  }
}

sub at {
  my ($self, $coord) = @_;
  my ($x, $y) = $coord =~ /(\d\d)(\d\d)/;
  foreach my $hex (@{$self->hexes}) {
    return $hex if $hex->x == $x and $hex->y == $y;
  }
}

sub communications {
  # connect all the class A starports, naval bases, and Imperial
  # consulates
  my ($self) = @_;
  return if $self->comm_set;
  my @candidates = ();
  foreach my $hex (@{$self->hexes}) {
    push(@candidates, $hex)
      if $hex->starport eq 'A'
	or $hex->naval
	or $hex->consulate;
  }
  # every system has a link to its neighbours
  foreach my $hex (@candidates) {
    my @ar = nearby($hex, 2, \@candidates);
    $hex->comm(\@ar);
  }
  # eliminate all but the best connections if the system has
  # amber or red travel zone
  foreach my $hex (@candidates) {
    next unless $hex->travelzone;
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
  # connect In or Ht with As, De, Ic, Ni
  # connect Hi or Ri with Ag, Ga, Wa
  my ($self) = @_;
  return if $self->trade_set;
  # candidates need to be on a travel route, i.e. must have fuel
  # available; skip worlds with a red travel zone
  my @candidates = ();
  foreach my $hex (@{$self->hexes}) {
    push(@candidates, $hex)
      if ($hex->starport =~ /^[A-D]$/
	  or $hex->gasgiant
	  or $hex->trade->{Wa})
	and $hex->travelzone ne 'R';
  }
  # every system has a link to its partners
  foreach my $hex (@candidates) {
    my @routes;
    if ($hex->trade->{In} or $hex->trade->{Ht}) {
      foreach my $other (nearby($hex, 4, \@candidates)) {
	if ($other->trade->{As}
	    or $other->trade->{De}
	    or $other->trade->{Ic}
	    or $other->trade->{Ni}) {
	  my @route = $self->route($hex, $other, 4, \@candidates);
	  push(@routes, \@route) if @route;
	}
      }
    } elsif ($hex->trade->{Hi} or $hex->trade->{Ri}) {
      foreach my $other (nearby($hex, 4, \@candidates)) {
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
  foreach my $hex (nearby($from, $distance < 2 ? $distance : 2, $candidatesref)) {
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
  my ($self, $width, $height) = @_;
  my $data = $self->header($width, $height);
  $data .= qq{  <g id='background'>\n};
  $data .= $self->background;
  $data .= qq{  </g>\n\n};
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
with 'Traveller::Util';

sub communications {
  # do nothing
}

sub trade {
  # connect starports to each other based on a table
  # see https://talestoastound.wordpress.com/2015/10/30/traveller-out-of-the-box-interlude-the-1977-edition-over-the-1981-edition/
  my ($self) = @_;
  return if $self->trade_set;
  my @edges;
  my @candidates = grep { $_->starport =~ /^[A-E]$/ } @{$self->hexes};
  my @others = @candidates;
  # every system has a link to its partners
  foreach my $hex (@candidates) {
    foreach my $other (@others) {
      next if $hex == $other;
      my $d = distance($hex, $other) - 1;
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
  $doc .= sprintf(qq{    <text class="legend" x="%.3f" y="%.3f">◉ gas giant}
		  . qq{ – ▲ scout base}
		  . qq{ – ★ navy base}
		  . qq{ – <tspan class="trade">▮</tspan> trade},
		  -10, ($self->height + 1) * sqrt(3) * $scale);
  if ($self->source) {
    $doc .= ' – <a xlink:href="' . $self->source . '">UWP</a>';
  }
  $doc .= qq{</text>\n};
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

package Traveller::Mapper::Classic::MPTS;
use Moose;
extends 'Traveller::Mapper::Classic';

################################################################################

package Traveller;

use Mojolicious::Lite;
use POSIX qw(INT_MAX);

get '/' => sub {
  my $c = shift;
  $c->redirect_to('main');
};

get '/random' => sub {
  my $c = shift;
  my $id = int(rand(INT_MAX));
  $c->redirect_to($c->url_for('uwp', size => 'subsector', rules => 'mgp', id => $id));
};

get '/random/:size' => [size => ['subsector', 'sector']] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $id = int(rand(INT_MAX));
  $c->redirect_to($c->url_for('uwp', size => $size, rules => 'mgp', id => $id));
};

get '/random/:size/:rules' => [size => ['subsector', 'sector']] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $rules = $c->param('rules');
  my $density = $c->param('density');
  my $id = int(rand(INT_MAX));
  $c->redirect_to($c->url_for('uwp', size => $size, rules => $rules, id => $id)->query(density => $density));
} => 'random';

get '/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  $c->redirect_to($c->url_for('uwp', size => 'subsector', rules => 'mgp', id => $id));
};

get '/uwp/:size/:id' => [size => ['subsector', 'sector']] => [id => qr/\d+/] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $id = $c->param('id');
  $c->redirect_to($c->url_for('uwp', size => $size, rules => 'mgp', id => $id));
};

get '/uwp/:size/:rules/:id' => [size => ['subsector', 'sector']] => [id => qr/\d+/] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $rules = $c->param('rules');
  my $id = $c->param('id');
  my $density = $c->param('density') || 50;
  srand($id);
  if ($size eq 'sector') {
    my $uwp = Traveller::Subsector->new()->init(32, 40, $rules, $density/100)->str;
    $c->render(template => 'uwp-sector', id => $id, rules => $rules, uwp => $uwp, density => $density);
  } else {
    my $uwp = Traveller::Subsector->new()->init(8, 10, $rules, $density/100)->str;
    $c->render(template => 'uwp', id => $id, rules => $rules, uwp => $uwp, density => $density);
  }
} => 'uwp';

any '/edit' => sub {
  my $c = shift;
  my $uwp = $c->param('map');
  $c->render(template => 'edit', uwp => Traveller::Mapper::example(), size => 'subsector', rules => 'mgp', id => '');
} => 'main';

get '/edit/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  $c->redirect_to($c->url_for('edit', size => 'subsector', rules => 'mgp', id => $id));
};

get '/edit/:size/:id' => [size => ['subsector', 'sector']] => [id => qr/\d+/] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $id = $c->param('id');
  $c->redirect_to($c->url_for('edit', size => $size, rules => 'mgp', id => $id));
};

get '/edit/:size/:rules/:id' => [size => ['subsector', 'sector']] => [id => qr/\d+/] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $rules = $c->param('rules');
  my $id = $c->param('id');
  my $density = $c->param('density');
  srand($id);
  if ($size eq 'sector') {
    my $uwp = Traveller::Subsector->new()->init(32, 40, $rules, $density)->str;
    $c->render(template => 'edit-sector', id => $id, rules => $rules, uwp => $uwp);
  } else {
    my $uwp = Traveller::Subsector->new()->init(8, 10, $rules, $density)->str;
    $c->render(template => 'edit', id => $id, rules => $rules, uwp => $uwp);
  }
} => 'edit';

get '/map' => sub {
  my $c = shift;
  $c->render(template => 'map', uwp => Traveller::Mapper::example(), size => 'subsector', rules => 'mgp');
};

get '/map/:id' => [id => qr/\d+/] => sub {
  my $c = shift;
  my $id = $c->param('id');
  $c->redirect_to($c->url_for('map', size => 'subsector', rules => 'mgp', id => $id));
};

get '/map/:size/:id' => [size => ['subsector', 'sector']] => [id => qr/\d+/] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $id = $c->param('id');
  $c->redirect_to($c->url_for('map', size => $size, rules => 'mgp', id => $id));
};

get '/map/:size/:rules/:id' => [size => ['subsector', 'sector']] => [id => qr/\d+/] => sub {
  my $c = shift;
  my $size = $c->param('size');
  my $rules = $c->param('rules');
  my $id = $c->param('id');
  my $wiki = $c->param('wiki');
  my $density = $c->param('density') || 50;
  srand($id);
  my $map = mapper($rules);
  my $uwp;
  if ($size eq 'sector') {
    $uwp = Traveller::Subsector->new()->init(32, 40, $rules, $density/100)->str;
  } else {
    $uwp = Traveller::Subsector->new()->init(8, 10, $rules, $density/100)->str;
  }
  my $url = $c->url_for('uwp', size => $size, rules => $rules, id => $id);
  $url = $url->query(density => $density) if $density and $density != 50;
  $map->initialize($uwp, $wiki, $url);
  $map->communications();
  $map->trade();
  $c->render(text => $map->svg, format => 'svg');
} => 'map_all';

post '/map' => sub {
  my $c = shift;
  my $wiki = $c->param('wiki');
  my $trade = $c->param('trade');
  my $uwp = $c->param('map');
  my $size = $c->param('size');
  my $rules = $c->param('rules');
  my $source;
  if (!$uwp) {
    my $id = int(rand(INT_MAX));
    srand($id);
    $uwp = new Traveller::Subsector->new()->init(8, 10, $rules)->str;
    $source = $c->url_for('uwp', id => $id);
  }
  my $map = mapper($rules);
  $map->initialize($uwp, $wiki, $source);
  $map->communications();
  $map->trade();
  if ($trade) {
    $c->render(text => $map->text, format => 'txt');
  } else {
    $c->render(text => $map->svg, format => 'svg');
  }
} => 'map';

get '/help' => sub {
  my $c = shift;
  my $classic = $c->param('classic');
  my $mpts = $c->param('mpts');
  $c->render(classic => $classic, mpts => $mpts);
};

get '/source' => sub {
  my $c = shift;
  seek DATA, 0, 0;
  local undef $/;
  $c->render(text => <DATA>, format => 'text');
};

sub mapper {
  my $rules = shift;
  if ($rules eq 'mpts') {
    return Traveller::Mapper::Classic::MPTS->new;
  } elsif ($rules eq 'ct') {
    return Traveller::Mapper::Classic->new;
  } else {
    return Traveller::Mapper->new;
  }
}

app->start;

__DATA__

=encoding utf8

@@ uwp-footer.html.ep
<% if ($rules eq 'mpts') { =%>
                       ||||||| |
Ag Agricultural        ||||||| +- Tech        In Industrial
As Asteroid            ||||||+- Law           Na Non-Agricultural
Ba Barren              |||||+- Government     Ni Non-Industrial
De Desert              ||||+- Population      Po Poor
Fl Fluid Oceans        |||+- Hydro            Ri Rich
Hi High Population     ||+- Atmosphere        Va Vacuum
Lo Low Population      |+- Size               Wa Water World
Ic Ice-Capped          +- Starport
<% } elsif ($rules eq 'ct') { =%>
                       ||||||| |
Ag Agricultural        ||||||| +- Tech        Ni Non-Industrial
As Asteroid            ||||||+- Law           Po Poor
De Desert              |||||+- Government     Ri Rich
Ic Ice-Capped          ||||+- Population      Va Vacuum
In Industrial          |||+- Hydro            Wa Water World
Na Non-Agricultural    ||+- Atmosphere
                       |+- Size
                       +- Starport
<% } else { =%>
                       ||||||| |       |
Ag Agricultural        ||||||| |    Bases     In Industrial
As Asteroid            ||||||| +- Tech        Lo Low Population
Ba Barren              ||||||+- Law           Lt Low Technology
De Desert              |||||+- Government     Na Non-Agricultural
Fl Fluid Oceans        ||||+- Population      Ni Non-Industrial
Ga Garden              |||+- Hydro            Po Poor
Hi High Population     ||+- Atmosphere        Ri Rich
Ht High Technology     |+- Size               Va Vacuum
Ic Ice-Capped          +- Starport            Wa Water World

Bases: Naval – Scout – Research – TAS – Consulate – Pirate – Gas Giant
% }

@@ uwp-links.html.ep
<p>
% if ($density and $density != 50) {
<%= link_to url_for('map_all', size => $size, rules => $rules, id => $id)->query(density => $density) => begin %>Generate Map<% end %>&#x2003;
<%= link_to url_for('edit', size => $size, rules => $rules, id => $id)->query(density => $density) => begin %>Edit UWP List<% end %>&#x2003;
<%= link_to url_for('random', size => 'subsector', rules => $rules)->query(density => $density) => begin %>Random Subsector<% end %>&#x2003;
<%= link_to url_for('random', size => 'sector', rules => $rules)->query(density => $density) => begin %>Random Sector<% end %>
% } else {
<%= link_to url_for('map_all', size => $size, rules => $rules, id => $id) => begin %>Generate Map<% end %>&#x2003;
<%= link_to url_for('edit', size => $size, rules => $rules, id => $id) => begin %>Edit UWP List<% end %>&#x2003;
<%= link_to url_for('random', size => 'subsector', rules => $rules) => begin %>Random Subsector<% end %>&#x2003;
<%= link_to url_for('random', size => 'sector', rules => $rules) => begin %>Random Sector<% end %>
% }
</p>
<p>
Or switch to
% if ($rules eq 'ct') {
<%= link_to url_for('random', size => $size, rules => 'mpg') => begin %>MGP<% end %> or
<%= link_to url_for('random', size => $size, rules => 'mpts') => begin %>MPTS<% end %>.
% } elsif ($rules eq 'mpts') {
<%= link_to url_for('random', size => $size, rules => 'mpg') => begin %>MGP<% end %> or
<%= link_to url_for('random', size => $size, rules => 'ct') => begin %>CT<% end %>.
% } else {
<%= link_to url_for('random', size => $size, rules => 'ct') => begin %>CT<% end %> or
<%= link_to url_for('random', size => $size, rules => 'mpts') => begin %>MPTS<% end %>.
% }
</p>
%= form_for random => begin
%= label_for density => 'Change system density: '
%= number_field density => 50, id => 'density', min => 1, max => 100
%= submit_button
% end

@@ uwp.html.ep
% layout 'default';
% title 'Traveller Subsector UWP List Generator';
<h1>Traveller Subsector UWP List Generator (<%= $id =%>)</h1>
<pre>
<%= $uwp =%>
<%= include 'uwp-footer' =%>
</pre>
<%= include 'uwp-links' =%>

@@ uwp-sector.html.ep
% layout 'default';
% title 'Traveller Sector UWP List Generator';
<h1>Traveller Sector UWP List Generator (<%= $id =%>)</h1>
<pre>
<%= $uwp =%>
<%= include 'uwp-footer' =%>
</pre>
<%= include 'uwp-links' =%>

@@ edit-footer.html.ep
<p>
<b>URL</b>:
If provided, every system will be linked to an appropriate page.
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
<i>starport</i> (A-E or X),
<i>size</i> (0-9 or A),
<i>atmosphere</i> (0-9 or A-F),
<i>hydrographic</i> (0-9 or A),
<i>population</i> (0-9 or A-C),
<i>government</i> (0-9 or A-F),
<i>law level</i> (0-9 or A-L), a dash,
<i>tech level</i> (0-99), optionally a non-standard group of bases and a gas giant indicator, optionally separated by whitespace:
<i>pirate base</i> (P),
<i>Imperial consulate</i> (C),
<i>Travellers’ Aid Society facility</i> (T),
<i>research station</i> (R),
<i>naval base</i> (N),
<i>scout base</i> (S),
<i>gas giant</i> (G), followed by <i>trade codes</i> (see below), and optionally a
<i>travel zone</i> (A or R).
Whitespace can be one or more spaces and tabs.
</p>
<p>Trade codes:</p>
<pre>
    Ag Agricultural     Hi High Population    Na Non-Agricultural
    As Asteroid         Ht High Technology    Ni Non-Industrial
    Ba Barren           Ic Ice-Capped         Po Poor
    De Desert           In Industrial         Ri Rich
    Fl Fluid Oceans     Lo Low Population     Va Vacuum
    Ga Garden           Lt Low Technology     Wa Water World
</pre>
<p>
<b>Alternative format for quick maps</b>:
<i>name</i>, some whitespace,
<i>coordinates</i> (four digits between 0101 and 0810), some whitespace,
<i>size</i> (0-9),
optionally a non-standard group of bases and a gas giant indicator,
optionally separated by whitespace:
<i>pirate base</i> (P),
<i>Imperial consulate</i> (C),
<i>Travellers’ Aid Society facility</i> (T),
<i>research station</i> (R),
<i>naval base</i> (N),
<i>scout base</i> (S),
<i>gas giant</i> (G),
followed by <i>trade codes</i> (see above),
and optionally a <i>travel zone</i> (A or R).
</p>
<p>Example:</p>
<pre>Inedgeus     0101 7 G  Fl Ni A
Geaan        0102 6 G  Hi Wa A</pre>
<p>
<b>Manual communication and trade routes</b>: If you don't want to rely on the
algorithm that creates these routes, you can provide your own using the
following format: <i>coordinates</i> (four digits between 0101 and 0810), a
minus, <i>coordinates</i>, some whitespace, and the <i>type</i> (the letter C or
T).
</p>
<p>Example:</p>
<pre>0101-0102 C
0102-0103 T</pre>

@@ edit.html.ep
% layout 'default';
% title 'Traveller Subsector Generator';
<h1>Traveller Subsector Generator</h1>
<p>Submit your UWP list, or generate a
<%= link_to url_for('random', size => 'subsector', rules => $rules) => begin %>Random Subsector<% end %> or a
<%= link_to url_for('random', size => 'sector', rules => $rules) => begin %>Random Sector<% end %>.
</p>
%= form_for 'map' => (method => 'POST') => begin
<p>
%= text_area 'map' => (cols => 60, rows => 20) => begin
<%= $uwp =%>
% end
</p>
<p>
%= label_for 'wiki' => begin
URL (optional):
% end
%= text_field 'wiki' => 'http://campaignwiki.org/wiki/NameOfYourWiki/' => (id => 'wiki')
</p>
%= hidden_field rules => $rules
%= submit_button 'Submit'
%= end

%= include 'edit-footer'

@@ edit-sector.html.ep
% layout 'default';
% title 'Traveller Sector Generator';
<h1>Traveller Sector Generator</h1>
<p>Submit your UWP list, or generate a
<%= link_to url_for('random', size => 'subsector', rules => $rules) => begin %>Random Subsector<% end %> or a
<%= link_to url_for('random', size => 'sector', rules => $rules) => begin %>Random Sector<% end %>.
</p>
%= form_for 'map' => (method => 'POST') => begin
<p>
%= text_area 'map' => (cols => 60, rows => 20) => begin
<%= $uwp =%>
% end
</p>
<p>
%= label_for 'wiki' => begin
URL (optional):
% end
%= text_field 'wiki' => 'http://campaignwiki.org/wiki/NameOfYourWiki/' => (id => 'wiki')
</p>
%= hidden_field rules => $rules
%= submit_button 'Submit'
%= end

%= include 'edit-footer'

@@ help.html.ep
% layout 'default';
% title 'Traveller Subsector Generator';
<h1>Traveller Subsector Generator</h1>
<p>This generator can generate the Universal World Profiles (UWP) for either 8×10
<%= link_to url_for('random', size => 'subsector') => begin %>random subsectors<% end %> or for 32×40
<%= link_to url_for('random', size => 'sector') => begin %>random sectors<% end %>.
This uses the <cite>Mongoose Traveller</cite> (MGT) rules (1st ed). Once you
have the UWP list generated, you’ll find links to switch to <cite>Classic
Traveller</cite> (CT) or to <cite>Classic Traveller</cite> with the
<cite>Merchant Prince</cite> trade system (CT+MPTS).</p>

<p>If you generate a random map, it will have a link to its UWP list at the
bottom of the map. It links back to the numeric seed used to generate the
list.</p>

<p>You can edit a randomly generated UWP list. In this case, however, there will
be no link back to the UWP list from the map, since the numeric seed is not
enough. You need to keep your edited UWP list safe in a text file on your system
somewhere.</p>

<h2>Trade</h2>
<p>For <cite>Classic Traveller</cite> (with or without the <cite>Merchant Prince</cite> trade system)
I’m using the 1977 rules to generate trade routes,
as discussed in the blog post <a href="https://talestoastound.wordpress.com/2015/10/30/traveller-out-of-the-box-interlude-the-1977-edition-over-the-1981-edition/"><cite>Interlude: Two
Points Where I Prefer the 1977 Edition Over the 1981 Edition</cite></a> by Chris Kubasik.

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
%= stylesheet '/traveller.css'
%= stylesheet begin
body {
  width: 600px;
  padding: 1em;
  font-family: "Palatino Linotype", PalatinoLinotype-Roman, "Book Antiqua", BookAntiqua, Palatino, Palatino-Roman, serif;
}
form {
  display: inline;
}
textarea, #wiki {
  width: 100%;
  font-family: "Andale Mono", AndaleMono, Monaco, "Courier New", CourierNewPSMT, Courier, Symbola, monospace;
  font-size: 80%;
}
table {
  padding-bottom: 1em;
}
td, th {
  padding-right: 0.5em;
}
cite {
  font-style: italic;
}
.example {
  font-size: smaller;
}
#density {
  width: 3em;
}
% end
<meta name="viewport" content="width=device-width">
</head>
<body>
<%= content %>
<hr>
<p>
<a href="https://campaignwiki.org/traveller">Subsector Generator</a>&#x2003;
<%= link_to 'Help' => 'help' %>&#x2003;
<%= link_to 'Source' => 'source' %>&#x2003;
<a href="https://alexschroeder.ch/cgit/hex-mapping/about/#traveller-subsector-generator">Git</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

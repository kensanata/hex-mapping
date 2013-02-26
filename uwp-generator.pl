#!/usr/bin/perl
# Copyright (C) 2009, 2010  Alex Schroeder <alex@gnu.org>
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
#
# $Id: uwp-generator.pl,v 1.7 2010/05/31 23:30:14 alex Exp $

use strict;
use POSIX qw(INT_MAX);

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
  my $tradecodes;
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
  my $bases;
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

package main;

use CGI qw/:standard/;

sub print_html {
  my $id = shift;
  print (header(-type=>'text/html; charset=UTF-8'),
	 start_html(-encoding=>'UTF-8', -title=>'Traveller Subsector UWP List Generator',
		    -author=>'kensanata@gmail.com'),
	 h1("Traveller Subsector UWP List Generator ($id)"),
	 pre(new Subsector()->init->str, <<EOT),
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
EOT
	 start_form(-action=>url()),
	 hidden('seed', $id),
	 submit('generate', 'Generate UWP'), ' ',
	 submit('map', 'Generate Map'),
	 end_form(),
	 hr(),
	 p(address(a({ -href=>'http://emacswiki.org/alex/About'}, 'Alex Schröder')),
	   a({ -href=>url().'/source'}, 'Source')),
	 end_html());
}

sub main {
  if (path_info eq '/source') {
    seek DATA, 0, 0;
    print "Content-type: text/plain; charset=UTF-8\r\n\r\n", <DATA>;
  } elsif (path_info =~ '/(\d+)') {
    srand($1);
    print_html($1);
  } elsif (param('seed') and not param('generate')) {
    my $uri = url();
    my $self = url(-relative=>1);
    $uri =~ s/$self/svg-map/;
    print redirect(-uri=>"$uri/" . param('seed'));
  } else {
    print redirect(-uri=>url() . '/' . int(rand(INT_MAX)));
  }
}

main ();

__DATA__

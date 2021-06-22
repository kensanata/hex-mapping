#!/usr/bin/env perl

# Copyright (C) 2019 Alex Schroeder <alex@gnu.org>

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
use Test::More;
use Test::Mojo;

# Note to self, this is how to print the actual result:
# die $t->get_ok('/rule' => form => { load => 'schroeder', rule => 'colour' })->tx->res->body;

require './hex-describe.pl';

my $t = Test::Mojo->new();

$t->get_ok('/')->status_is(200)->text_is('h1' => 'Hex Describe');

$t->get_ok('/rules')->status_is(200)->text_is('a' => 'Alex Schroeder');

like($t->get_ok('/schroeder/table')->status_is(200)->tx->res->text,
     qr'Written by Alex Schroeder and dedicated to the Public Domain');

# test the 'colour' rule for the schroeder table

$t->post_ok('/rules/list' => form => { load => 'schroeder' })->text_is(a => ' START');

$t->get_ok('/rule' => form => { load => 'schroeder', rule => 'simple colour' })
    ->text_like('.description p' => qr'red|orange|yellow|green|indigo|blue|purple|rose')
    ->text_is(a => 'simple colour')
    ->element_exists('form input[type="submit"][value="Markdown"]');

$t->post_ok('/rule' => form => { load => 'schroeder', rule => 'simple colour' })
    ->text_like('.description p' => qr'red|orange|yellow|green|indigo|blue|purple|rose')
    ->text_is(a => 'simple colour')
    ->element_exists('form input[type="submit"][value="Markdown"]');

my @colours = map { s/^\s+//; s/\s+$//; $_ } $t->tx->res->dom('.description p')->map('text')->each;
ok(@colours > 0, "Colours found");
my ($seed) = ($t->tx->res->dom('form input[name="seed"]')->map(attr => 'value')->[0] =~ /(\d+)/);
ok($seed, "Seed found");

my @result = split /\s*---+\s*/,
    $t->get_ok('/rule/markdown' => form => { load => 'schroeder', rule => 'simple colour', seed => $seed })->tx->res->text;

for my $i (0 .. 9) {
  is $colours[$i], $result[$i], "matching colour $i";
}

$t->get_ok('/rule/show' => form => { load => 'schroeder' })->text_is('#colour' => 'colour');

# test our own rule, this time without seed (lazy!)

my $table = ";one\n1,this is the item\n";

$t->post_ok('/rules/list' => form => { load => 'none', table => $table })
    ->element_exists('form p input[value="one"]');

$t->post_ok('/rules/list' => form => { load => 'none', table => $table })
    ->element_exists('form p input[value="one"]');

$t->post_ok('/rule' => form => { load => 'none', table => $table, rule => 'one' })
    ->text_is('.description p' => "this is the item\n")
    ->element_exists("form input[name=table][value='$table']");

$t->post_ok('/rule/show' => form => { load => 'none', table => $table, rule => 'one' })
    ->text_is('pre a[href="#one"]' => 'Jump to one')
    ->text_is('pre strong a#one' => 'one')
    ->text_like(pre => qr'1,this is the item');

my @result = split /\s*---+\s*/,
    $t->post_ok('/rule/markdown' => form => { load => 'none', table => $table, rule => 'one' })->tx->res->text;

for my $i (0 .. 9) {
  is "this is the item", $result[$i], "matching one $i";
}

done_testing;

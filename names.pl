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

use Mojolicious::Lite;
use Modern::Perl;

sub one {
  my $i = int(rand(scalar @_));
  return $_[$i];
}

sub compute_digraphs {
  my @first = qw(b c d f g h j k l m n p q r s t v w x y z .
		 sc ng ch ck gh ph rh sh th wh zh wr qu);
  # make missing vowel rare
  my @second = qw(a e i o u a e i o u a e i o u .);
  my @d;
  # duplication just increases frequency, so we're not going to check
  for (1 .. 10+rand(20)) {
    push(@d, one(@first));
    push(@d, one(@second));
  }
  return \@d;
}

sub parse_digraphs {
  $_ = shift;
  return unless $_;
  my @d;
  push(@d, $1||$2) while /\[([^]]+)\]|(.)/g;
  warn join('/', @d) . "\n";
  return \@d;
}

sub digraphs_string {
  my $d = shift;
  return join '', map {
    length($_) > 1 ? "[$_]" : $_;
  } @$d;
}

sub compute_name {
  my $digraphs = shift;
  my $max = scalar(@$digraphs);
  my $length = 4 + rand(6); # 4-8
  my $name = '';
  while (length($name) < $length) {
    my $i = 2*int(rand($max/2));
    $name .= $digraphs->[$i];
    $name .= $digraphs->[$i+1];
  }
  $name =~ s/\.//g;
  return ucfirst($name);
}

get '/' => sub {
  my $c = shift;
  my $digraphs = parse_digraphs($c->param('digraphs'));
  $digraphs = compute_digraphs() unless $digraphs;
  my @names = map { compute_name($digraphs) } (1 .. 20);
  $c->render('name', digraphs => digraphs_string($digraphs), names => \@names);
};

get '/help' => sub {
  my $c = shift;
  $c->render;
};

get '/source' => sub {
  my $c = shift;
  seek DATA, 0, 0;
  local undef $/;
  $c->render(text => <DATA>, format => 'text');
};

app->start;

__DATA__

@@ name.html.ep
% layout 'default';
% title 'Name Generator';
<h1>Name Generator</h1>

<p>This generator will first generate a string of digraphs and then generate a
bunch of names based on it. Feel free to add your own. See the <%= link_to Help => 'help' %>
page for more information.</p>

%= form_for '/' => begin
<p>
<%= text_area digraphs => (class => "mono") => begin %><%= $digraphs %><% end %>
<br/>
%= submit_button
</p>
% end

<p>Names:</p>
<ul>
% for my $name (@$names) {
<li><%= $name %></li>
% }
</ul>

@@ help.html.ep
% layout 'default';
% title 'Name Generator Help';
<h1>Name Generator</h1>

<p>This generator is based on the idea of the name generator in
<a href="http://www.iancgbell.clara.net/elite/text/index.htm">Text Elite</a>.
This is what it does:</p>

<ol>
<li>pick the length of the name (4-9)</li>
<li>pick an odd starting point in the string of digraphs and take two characters to create a syllable
<li>delete any dots
<li>capitalize it
</ol>

<p>Thus, if you want to generate Japanese sounding names, take some
<a href="https://en.wikipedia.org/wiki/Hiragana">Hiragana</a>
syllables and concatenate them, using a dot if there is no second character in
the syllable, ignoring trigraphs:</p>

<table>
% my $s;
% for my $c (qw(. k s t n h m r w g z d b p)) {
<tr>
% for my $v (qw(a i u e o)) {
% $s .= "$c$v";
<td><%= "$c$v" =%></td>
% }
</tr>
% }
% $s .= "yayuyon.";
<tr>
<td>ya</td><td></td>
<td>yu</td><td></td>
<td>yo</td>
</tr>
<tr>
<td>n.</td><td></td>
<td></td><td></td>
<td></td>
</tr>
</table>

<p><%= link_to url_for("/")->query(digraphs=>"$s") => begin %>Check it out<%= end %>.</p>

<p>If you're interested in Hawaiian sounding names, take a look at the <a
href="https://en.wikipedia.org/wiki/Hawaiian_alphabet">Hawaiian alphabet</a> and
its eight consonants, five vowels with or without macron, and eleven
diphthongs:</p>

<table>
% $s = '';
% for my $c (qw(h k l m n p w ')) {
<tr>
% for my $v (qw(a e i o u ā ē ī ō ū)) {
% $s .= "$c$v";
<td><%= "$c$v" =%></td>
% }
</tr>
% }
% for my $d (qw(ai ae ao au ei eu iu oe oi ou ui)) {
% $s .= "$d";
<td><%= "$d" =%></td>
% }
</table>

<p><%= link_to url_for("/")->query(digraphs=>"$s") => begin %>Check it out<%= end %>.</p>

<p>Or you could go with the arbitrary list of syllables
<a href="http://wiki.alioth.net/index.php/Classic_Elite_planet_descriptions">Elite</a>
used. This is from the
<a href="http://www.iancgbell.clara.net/elite/text/index.htm">Text Elite</a>
source code, but without the same random number generator:</p>

<pre>
char pairs[] = "..LEXEGEZACEBISO"
               "USESARMAINDIREA."
               "ERATENBERALAVETI"
               "EDORQUANTEISRION"; /* Dots should be nullprint characters */
</pre>

<p><%= link_to url_for("/")->query(digraphs=>"..lexegezacebisousesarmaindirea.eratenberalavetiedorquanteisrion") => begin %>Check it out<%= end %>.</p>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
%= stylesheet '/names.css'
%= stylesheet begin
body {
  width: 80ex;
  padding: 1em;
  font-family: "Palatino Linotype", "Book Antiqua", Palatino, serif;
}
.mono {
  width: 100%;
  font-family: "Andale Mono", Monaco, "Courier New", Courier, monospace, "Symbola";
}
% end
<meta name="viewport" content="width=device-width">
</head>
<body>
<%= content %>
<hr>
<p>
<a href="https://campaignwiki.org/names">Name Generator</a>&#x2003;
<%= link_to 'Help' => 'help' %>&#x2003;
<%= link_to 'Source' => 'source' %>&#x2003;
<a href="https://github.com/kensanata/hex-mapping/">GitHub</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

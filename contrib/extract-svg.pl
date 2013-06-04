#!/usr/bin/perl -w

# This tool takes an SVG file and an id on the command line.
# It extracts the id from the input and scales it appropriately for text-mapper:
# <svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">...</svg>

# In Inkscape, you should select the icon you want, ungroup it
# entirely, group it once, look at the object properties and note the
# id. Then call it as follows, for example:
# perl extract-svg.pl ~/Downloads/Gnomeylandicons/Gnomeylandicons.svg g5496
# The SVG at the end is what you are looking for.

use strict;
use SVG::Parser;
use List::Util qw(min max);
use lib '.';
use Image::SVG::Path qw(extract_path_info create_path_string);
use Storable qw(dclone);

sub smallest {
  my ($default, @rest) = @_;
  return defined($default) ? min($default, @rest) : min(@rest);
}

sub biggest {
  my ($default, @rest) = @_;
  return defined($default) ? max($default, @rest) : max(@rest);
}

sub add_point_to_bounding_box {
  my ($point, $left, $top, $right, $bottom) = @_;
  $left = smallest($left, $point->[0]);
  $top = biggest($top, $point->[1]);
  $right = biggest($right, $point->[0]);
  $bottom = smallest($bottom, $point->[1]);
  return ($left, $top, $right, $bottom);
}

sub push_bounding_box {
  my ($obj, $left, $top, $right, $bottom) = @_;
  if ($obj->getElementName() eq "path") {
    warn "<path id='" . $obj->getAttribute("id") . "'"
      .  " d='" . $obj->getAttribute("d") . "'>\n";
    foreach my $elem (extract_path_info ($obj->getAttribute("d"),
					 {absolute => 1})) {
      if ($elem->{type} eq 'moveto' or $elem->{type} eq 'lineto') {
	($left, $top, $right, $bottom) =
	  add_point_to_bounding_box($elem->{point},
				    $left, $top, $right, $bottom);
      } elsif ($elem->{type} eq 'cubic-bezier') {
	# ignore control points, just use the end point
	($left, $top, $right, $bottom) =
	  add_point_to_bounding_box($elem->{end},
				    $left, $top, $right, $bottom);
      } elsif ($elem->{type} eq 'closepath') {
	# do nothing
      } else {
	warn "ERROR: unsupported path instruction '" . $elem->{type} . "'\n";
      }
    }
  } elsif  ($obj->getElementName() eq "line") {
    warn "<line id='" . $obj->getAttribute("id") . "'"
      .  " x1='" . $obj->getAttribute("x1") . "'"
      .  " y1='" . $obj->getAttribute("y1") . "'"
      .  " x2='" . $obj->getAttribute("x2") . "'"
      .  " y2='" . $obj->getAttribute("y2") . "'>\n";
    $left = smallest($left, $obj->getAttribute("x1"), $obj->getAttribute("x2"));
    $right = biggest($right, $obj->getAttribute("x1"), $obj->getAttribute("x2"));
    $bottom = smallest($bottom, $obj->getAttribute("y1"), $obj->getAttribute("y2"));
    $top = biggest($bottom, $obj->getAttribute("y1"), $obj->getAttribute("y2"));
  } elsif  ($obj->getElementName() eq "rect") {
    warn "<rect id='" . $obj->getAttribute("id") . "'"
      .  " x='" . $obj->getAttribute("x") . "'"
      .  " y='" . $obj->getAttribute("y") . "'"
      .  " width='" . $obj->getAttribute("width") . "'"
      .  " height='" . $obj->getAttribute("height") . "'>\n";
    $left = smallest($left, $obj->getAttribute("x"));
    $right = biggest ($right, $obj->getAttribute("x") + $obj->getAttribute("width"));
    $bottom = smallest($bottom, $obj->getAttribute("y"));
    $top = biggest($top, $obj->getAttribute("y") + $obj->getAttribute("height"));
  } elsif ($obj->getElementName() eq "polyline") {
    warn "<polyline id='" . $obj->getAttribute("id") . "'"
      .  " points='" . $obj->getAttribute("points") . "'>\n";
    my @numbers = split(/(?:,|(?=-)|\s+)/, $obj->getAttribute("points"));
    for (my $i = 0; $i < @numbers / 2; $i++) {
      my $offset = $i * 2;
      # warn "  (" . $numbers[$offset] . ", " . $numbers[$offset + 1] . ")\n";
      ($left, $top, $right, $bottom) =
	add_point_to_bounding_box([@numbers[$offset, $offset + 1]],
				  $left, $top, $right, $bottom);
    }
  } elsif  ($obj->getElementName() eq "g") {
    # do nothing
  } else {
    warn "ERROR: unsupported element " . $obj->getElementName() . "\n";
  }

  warn "Bounding box: ("
    . join(", ", map { defined($_) ? $_ : "?"} $left, $top, $right, $bottom) . ")\n";

  foreach my $child ($obj->getChildren()) {
    ($left, $top, $right, $bottom) =
      push_bounding_box($child, $left, $top, $right, $bottom);
  }

  return ($left, $top, $right, $bottom);
}

sub scale_object {
  my ($obj, $dx1, $dy1, $scale, $dx2, $dy2) = @_;
  if ($obj->getElementName() eq "path") {
    # $point remains unscaled
    my $point = [0, 0];
    my @points = extract_path_info ($obj->getAttribute("d"), {absolute => 1});
    foreach my $elem (@points) {
      if ($elem->{type} eq 'moveto') {
	$point->[0] = $elem->{point}->[0];
	$point->[1] = $elem->{point}->[1];
	$elem->{point}->[0] = ($point->[0] + $dx1) * $scale + $dx2;
	$elem->{point}->[1] = ($point->[1] + $dy1) * $scale + $dy2 + $dy2;
      } elsif ($elem->{type} eq 'cubic-bezier') {
	# $c1 and $c2 remain unscaled
	my $c1 = dclone($point);
	my $c2 = dclone($point);
	$point->[0] = $elem->{end}->[0];
	$point->[1] = $elem->{end}->[1];
	$c1->[0] = $elem->{control1}->[0];
	$c1->[1] = $elem->{control1}->[1];
	$c2->[0] = $elem->{control2}->[0];
	$c2->[1] = $elem->{control2}->[1];
	$elem->{end}->[0] = ($point->[0] + $dx1) * $scale + $dx2;
	$elem->{end}->[1] = ($point->[1] + $dy1) * $scale + $dy2;
	$elem->{control1}->[0] = ($c1->[0] + $dx1) * $scale + $dx2;
	$elem->{control1}->[1] = ($c1->[1] + $dy1) * $scale + $dy2;
	$elem->{control2}->[0] = ($c2->[0] + $dx1) * $scale + $dx2;
	$elem->{control2}->[1] = ($c2->[1] + $dy1) * $scale + $dy2;
      }
    }
    $obj->setAttribute("d", create_path_string(\@points));
    warn "scaled: <path id='" . $obj->getAttribute("id") . "'"
      .  " d='" . $obj->getAttribute("d") . "'>\n";
  } elsif  ($obj->getElementName() eq "line") {
    $obj->setAttribute("x1", ($obj->getAttribute("x1") + $dx1) * $scale + $dx2);
    $obj->setAttribute("y1", ($obj->getAttribute("y1") + $dy1) * $scale + $dy2);
    $obj->setAttribute("x2", ($obj->getAttribute("x2") + $dx1) * $scale + $dx2);
    $obj->setAttribute("y2", ($obj->getAttribute("y2") + $dy1) * $scale + $dy2);
    warn "scaled: <line id='" . $obj->getAttribute("id") . "'"
      .  " x1='" . $obj->getAttribute("x1") . "'"
      .  " y1='" . $obj->getAttribute("y1") . "'"
      .  " x2='" . $obj->getAttribute("x2") . "'"
      .  " y2='" . $obj->getAttribute("y2") . "'>\n";
  } elsif  ($obj->getElementName() eq "rect") {
    $obj->setAttribute("x", ($obj->getAttribute("x") + $dx1) * $scale + $dx2);
    $obj->setAttribute("y", ($obj->getAttribute("y") + $dy1) * $scale + $dy2);
    $obj->setAttribute("width", $obj->getAttribute("width") * $scale);
    $obj->setAttribute("height", $obj->getAttribute("height") * $scale);
    warn "scaled: <rect id='" . $obj->getAttribute("id") . "'"
      .  " x='" . $obj->getAttribute("x") . "'"
      .  " y='" . $obj->getAttribute("y") . "'"
      .  " width='" . $obj->getAttribute("width") . "'"
      .  " height='" . $obj->getAttribute("height") . "'>\n";
  } elsif  ($obj->getElementName() eq "polyline") {
    my @points = ();
    my @numbers = split(/(?:,|(?=-)|\s+)/, $obj->getAttribute("points"));
    for (my $i = 0; $i < @numbers / 2; $i++) {
      my $offset = $i * 2;
      push(@points, (($numbers[$offset] + $dx1) * $scale + $dx2)
	   . "," . (($numbers[$offset + 1] + $dy1) * $scale + $dy2));
    }
    $obj->setAttribute("points", join(" ", @points));
    warn "scaled <polyline id='" . $obj->getAttribute("id") . "'"
      .  " points='" . $obj->getAttribute("points") . "'>\n";
  } else {
    warn "not scaled: " . $obj->getElementName() . "\n";
  }

  # fix stroke-width
  my $style = $obj->getAttribute("style");
  if ($style->{"stroke-width"}) {
    $style->{"stroke-width"} *= $scale;
    warn " setting stroke-width: " . $style->{"stroke-width"} . "\n";
    $obj->setAttribute("style", $style);
  }
  if ($obj->getAttribute("stroke-width")) {
    $obj->setAttribute("stroke-width", $obj->getAttribute("stroke-width") * $scale);
  }
  return $obj;
}

sub transform {
  my ($left, $top, $right, $bottom) = @_;
  my $dx1 = -$left;
  my $dy1 = -$bottom;
  my $scale = min(512/abs($top-$bottom), 512/abs($right-$left));
  my $dx2 = (512 - ($right - $left) * $scale) / 2;
  my $dy2 = (512 - ($top - $bottom) * $scale) / 2;
  warn "dx1: $dx1; dy1: $dy1; scale: $scale; dx2: $dx2; dy2: $dy2\n";
  return ($dx1, $dy1, $scale, $dx2, $dy2);
}

sub fit_into_bounding_box {
  my ($obj, $dx1, $dy1, $scale, $dx2, $dy2) = @_;
  warn "fitting " . $obj->getElementName() . "\n";
  my $clone = scale_object($obj->cloneNode(), $dx1, $dy1, $scale, $dx2, $dy2);
  foreach my $child ($obj->getChildren()) {
    $clone->appendChild(fit_into_bounding_box($child, $dx1, $dy1, $scale, $dx2, $dy2));
  }
  return $clone;
}

sub clean {
  my $obj = shift;
  foreach my $attr ($obj->getAttributes()) {
    if ($attr =~ /^(inkscape:|transform|id)/) {
      $obj->setAttribute($attr, undef);
    }
  }
  foreach my $child ($obj->getChildren()) {
    clean($child);
  }
}

sub main {
  die "Usage: $0 <file> <id>\n" unless 2 == @ARGV;
  my ($file, $id) = @ARGV;
  my $parser = new SVG::Parser();
  my $svg = SVG::Parser->new()->parsefile($file);
  my $ref = $svg->getElementByID($id);
  my @bounding_box = push_bounding_box($ref, undef, undef, undef, undef);
  my $clone = fit_into_bounding_box($ref, transform(@bounding_box));
  clean($clone);
  my $xml = $clone->xmlify();
  warn "$xml\n";
  $xml =~ s/(^|>)\n\s*</$1</g;
  warn "removing whitespace...\n";
  print qq{<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">$xml</svg>\n};
  # <rect x="0" y="0" width="512" height="512" />
}

main();

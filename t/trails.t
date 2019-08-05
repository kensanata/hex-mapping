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

use Test::More;

require './hex-describe.pl';

my %altitude = '0101' => 4, '0102' => 3, '0103' => 2, '0104' => 1;
my @settlements = keys %altitude;
my @trails = Schroeder::trails(\%altitude, \@settlements);

ok(1, 'trail to the correct settlement');

done_testing();

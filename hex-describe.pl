#!/usr/bin/env perl
# Copyright (C) 2018  Alex Schroeder <alex@gnu.org>
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
use Mojolicious::Lite;
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::Log;
use Array::Utils qw(intersect);

my $log = Mojo::Log->new;

my $default_map = q{0101 dark-green trees village
0102 light-green bushes
0103 light-green bushes
0104 light-green bushes
0105 light-green bushes
0106 light-green forest-hill
0107 light-grey mountain
0108 white mountains cliff1
0109 white mountain
0110 light-grey mountain
0201 dark-grey swamp
0202 light-green bushes
0203 light-green bushes
0204 green forest
0205 light-green fir-forest
0206 light-green firs thorp
0207 white mountain cliff1
0208 white mountain
0209 light-grey mountain
0210 grey swamp
0301 light-green bushes
0302 dark-green trees town
0303 green forest
0304 dark-grey swamp
0305 light-green firs thorp cliff1
0306 light-green forest-hill
0307 light-grey mountain
0308 light-grey mountain
0309 light-grey mountain
0310 light-green fir-forest
0401 green forest
0402 green forest
0403 light-green bushes
0404 green trees village
0405 light-green fir-forest
0406 light-green forest-hill
0407 light-green firs thorp
0408 light-green fir-forest
0409 light-green forest-hill
0410 light-green firs thorp
0501 green forest
0502 light-green bushes
0503 green forest
0504 light-green bushes
0505 light-green firs thorp
0506 grey swamp
0507 grey swamp
0508 light-green fir-forest
0509 light-green fir-forest
0510 light-green bushes
0601 light-green fir-forest
0602 light-green fir-forest
0603 light-green fir-forest
0604 light-green forest-hill
0605 light-green forest-hill
0606 light-green forest-hill
0607 light-green bushes
0608 dark-grey swamp
0609 dark-grey swamp
0610 green trees village
0701 light-green forest-hill
0702 light-green forest-hill
0703 light-green fir-forest
0704 light-green firs thorp
0705 light-grey mountain
0706 light-grey mountain cliff4
0707 grey swamp
0708 light-green fir-forest
0709 light-green firs thorp
0710 dark-grey swamp
0801 light-grey mountain
0802 grey swamp
0803 light-grey mountain
0804 white mountains cliff0 cliff1 cliff5
0805 white mountain cliff4
0806 light-green fir-forest
0807 grey swamp
0808 light-green forest-hill
0809 light-green fir-forest
0810 light-green firs thorp
0901 white mountain
0902 light-grey mountain
0903 light-grey mountain
0904 white mountain
0905 white mountain
0906 light-grey mountain
0907 light-green firs thorp
0908 light-grey mountain cliff0
0909 light-green firs thorp
0910 light-green forest-hill
1001 white mountains cliff3 cliff5
1002 white mountain cliff3
1003 light-grey mountain
1004 white mountain cliff2
1005 light-grey mountain
1006 light-grey mountain
1007 light-grey mountain
1008 white mountain cliff5
1009 light-grey mountain
1010 light-green forest-hill
1101 white mountain
1102 light-grey mountain
1103 grey swamp
1104 water
1105 white mountains cliff1 cliff3 cliff5
1106 white mountain
1107 light-grey mountain
1108 white mountains cliff0 cliff1 cliff2
1109 white mountain
1110 light-grey mountain
1201 light-grey mountain
1202 grey swamp
1203 light-grey mountain
1204 white mountain cliff0 cliff3
1205 light-grey mountain
1206 light-grey mountain
1207 light-grey mountain
1208 white mountain
1209 light-grey mountain
1210 light-green firs thorp
1301 light-green forest-hill
1302 light-green forest-hill
1303 light-green fir-forest
1304 light-grey mountain
1305 grey swamp
1306 water
1307 light-grey mountain
1308 white mountains cliff0 cliff1
1309 white mountain
1310 light-grey mountain
1401 grey swamp
1402 grey swamp
1403 light-green firs thorp
1404 grey swamp
1405 light-grey mountain
1406 light-grey mountain
1407 white mountain
1408 white mountain
1409 light-grey mountain
1410 light-green firs thorp
1501 light-green fir-forest
1502 light-green forest-hill
1503 light-green fir-forest
1504 light-grey mountain
1505 grey swamp
1506 white mountain cliff1
1507 white mountains cliff0
1508 white mountains
1509 white mountain
1510 light-grey mountain
1601 light-green firs thorp
1602 light-grey mountain
1603 white mountain cliff0 cliff3
1604 light-grey mountain
1605 light-grey mountain
1606 white mountain
1607 white mountain
1608 white mountain
1609 light-grey mountain
1610 light-green firs thorp
1701 light-grey mountain
1702 white mountain cliff0
1703 white mountains cliff0 cliff3 cliff4
1704 grey swamp
1705 water
1706 light-grey mountain
1707 light-grey mountain
1708 light-grey mountain
1709 light-grey mountain
1710 light-green fir-forest
1801 light-grey mountain
1802 white mountain
1803 light-grey mountain
1804 light-grey mountain
1805 light-grey mountain
1806 grey swamp
1807 light-green fir-forest
1808 light-green firs thorp
1809 light-green forest-hill
1810 light-green fir-forest
1901 light-green firs thorp
1902 light-grey mountain
1903 light-grey mountain
1904 white mountain cliff2
1905 white mountain
1906 light-grey mountain
1907 light-green firs thorp
1908 grey swamp
1909 light-green fir-forest
1910 light-green bushes
2001 grey swamp
2002 light-green firs thorp
2003 light-green fir-forest
2004 white mountains cliff1
2005 white mountain
2006 light-grey mountain
2007 light-green forest-hill
2008 light-green firs thorp
2009 green trees village
2010 light-green bushes
1704-1604-1505 canyon
1510-1610-1711 river
1609-1710-1810-1711 river
1310-1410-1511 river
1102-1202-1303-1402-1401-1400 river
1110-1210-1111 river
0110-0210-0310-0410-0311 river
1409-1410-1511 river
0209-0210-0310-0410-0311 river
1602-1503-1402-1401-1400 river
2006-1907-1908-1909-2009-2110 river
0309-0408-0508-0608-0609-0610-0611 river
1206-1306-1305-1404-1403-1402-1401-1400 river
1405-1305-1404-1403-1402-1401-1400 river
1504-1404-1403-1402-1401-1400 river
1902-2002-2102 river
1906-1907-1908-1909-2009-2110 river
1203-1104-1103-1202-1303-1402-1401-1400 river
0107-0206-0205-0204-0304-0303-0302-0201-0101-0100 river
1801-1901-1900 river
1701-1601-1501-1500 river
1201-1202-1303-1402-1401-1400 river
1009-0909-0809-0710-0609-0610-0611 river
0908-0807-0707-0708-0608-0609-0610-0611 river
1708-1807-1908-1909-2009-2110 river
1304-1305-1404-1403-1402-1401-1400 river
1007-0907-0807-0707-0708-0608-0609-0610-0611 river
1903-2003-2103 river
0906-0806-0807-0707-0708-0608-0609-0610-0611 river
1709-1808-1909-2009-2110 river
0308-0407-0507-0508-0608-0609-0610-0611 river
1406-1306-1305-1404-1403-1402-1401-1400 river
1003-1103-1202-1303-1402-1401-1400 river
1006-0907-0807-0707-0708-0608-0609-0610-0611 river
1707-1807-1908-1909-2009-2110 river
1805-1806-1807-1908-1909-2009-2110 river
1307-1306-1305-1404-1403-1402-1401-1400 river
0706-0707-0708-0608-0609-0610-0611 river
1605-1505-1404-1403-1402-1401-1400 river
1804-1704-1604-1505-1404-1403-1402-1401-1400 river
1604-1505-1404-1403-1402-1401-1400 river
0902-0802-0703-0602-0503-0402-0302-0201-0101-0100 river
1209-1210-1111 river
1205-1306-1305-1404-1403-1402-1401-1400 river
0801-0802-0703-0602-0503-0402-0302-0201-0101-0100 river
1803-1704-1604-1505-1404-1403-1402-1401-1400 river
0307-0407-0507-0508-0608-0609-0610-0611 river
1005-0906-0806-0807-0707-0708-0608-0609-0610-0611 river
0705-0704-0603-0503-0402-0302-0201-0101-0100 river
1207-1107-1206-1306-1305-1404-1403-1402-1401-1400 river
1706-1806-1807-1908-1909-2009-2110 river
0803-0704-0603-0503-0402-0302-0201-0101-0100 river
0903-0802-0703-0602-0503-0402-0302-0201-0101-0100 river
1301-1401-1400 river
1809-1810-1711 river
1302-1401-1400 river
2001-2002-2102 river
1010-0911 river
2007-2008-2009-2110 river
0409-0509-0609-0610-0611 river
1502-1501-1500 river
0605-0505-0404-0304-0303-0302-0201-0101-0100 river
0910-0810-0710-0609-0610-0611 river
0701-0601-0501-0401-0302-0201-0101-0100 river
1705-1704-1604-1505-1404-1403-1402-1401-1400 river
0406-0405-0404-0304-0303-0302-0201-0101-0100 river
0306-0305-0304-0303-0302-0201-0101-0100 river
0808-0709-0608-0609-0610-0611 river
0702-0602-0503-0402-0302-0201-0101-0100 river
0106-0205-0204-0304-0303-0302-0201-0101-0100 river
0606-0506-0505-0404-0304-0303-0302-0201-0101-0100 river
0604-0505-0404-0304-0303-0302-0201-0101-0100 river
0404-0302 trail
0709-0610 trail
0305-0302 trail
0810-0610 trail
0302-0101 trail
1808-2009 trail
1210-0909 trail
1601-1403 trail
1901-1601 trail
0907-0709 trail
0206-0404 trail
0410-0610 trail
0407-0404 trail
2002-1901 trail
1410-1210 trail
1610-1808 trail
0909-0610 trail
0704-0404 trail
2008-2009 trail
0505-0404 trail
1907-2009 trail
include https://campaignwiki.org/contrib/gnomeyland.txt
# Seed: 1520694313
};

my $default_table = q{;light-grey mountain
1,The green valley up here has some sheep and a *kid* called [human kid] guarding them.
1,There is a cold pond up in this valley [cold lake].
1,The upper valley is rocky [maybe a hill giant].
1,Steep cliffs make progress practically impossible without climbing gear.
1,Nothing but gray rocks.

;human kid
1,Al
1,Bert
1,Cus
1,Dirk
1,Ed
1,Fal
1,Gil
1,Hela
1,Ila
1,Jo
1,Keg

;cold lake
4,but it's cold and nothing lives here
1,and in it lives a *water spirit* called [undine]
1,with [2d4] *turtle people* led by one they call [turtle]

;undine
1,[undine 1] [undine 2]

;undine 1
1,Mountain
1,Tears of
1,Eyes of
1,Sweet
1,Eternal

;undine 2
1,Joy
1,Sorrow
1,Ice
1,Sleep
1,Dew
1,Rain

;turtle
1,Patience
1,Calm
1,Quiet
1,Slow
1,Peace
1,Submit
1,Wait

;maybe a hill giant
5,and empty
1,and some of these boulders have been assembled into a crude stone tower with [2d4] *hill giants* led by one they call [hill giant]

;hill giant
1,Flat Nose
1,Thunder Voice
1,Smash Fist
1,Sheep Finder
1,Ogon of the Valley, former soldier of Ugra the Great

;white mountain
1,The air up here is cold. You can see the [name for white big mountains] from here.
1,Snow fields make it impossible to cross without skis.
1,There is a hidden meadow up here, protected by the [name for white big mountains].
1,The glaciers need a local guide and ropes to cross.
1,The glacier ends at a small lake [maybe an ice cave].
1,A *white dragon* lives in a ruined mountain fortress on the highest peak around here.

;maybe an ice cave
1,bright blue and ice cold
1,and there is an ice cave leading beneath the glacier
1,and there is an ice cave inhabited by a *cryohydra*

;mountains
1,These mountains are called the [name for white big mountains]. [more mountains]

;name for white big mountains
1,[dreadful] [peaks]

;dreadful
1,Dire
1,Desert
1,Dead
1,Mourning
1,Giant
1,Sharp
1,Hungry

;peaks
1,Peaks
1,Domes
1,Teeth
1,Giants
1,Domes
1,Mounts
1,Graves

;more mountains
1,They are impossible to climb.
1,These passes need a local guide to cross. [mountain people].
1,A glacier fills the gap between these mountains.

;mountain people
1,[1d4 frost giants]
1,[2d4] *winter wolves* live up here
1,There is a dwarven forge called [dwarf forge] up here. [dwarves]

;1d4 frost giants
1,The *frost giant* [frost giant] lives here in a [frost giant lair] with [frost giant companions]
3,[1d3+1] *frost giants* led by one they call [frost giant] live here with [frost giant companions] in a [frost giant lair]

;frost giant
1,Winter's Bone
1,Snow
1,Ice
1,Cold
1,Glacier
1,Storm
1,Darkness
1,Tooth

;frost giant lair
1,a glorious ice blue cave
1,an old castle built of gray stones
1,a castle built of ice and snow
1,a gargantuan palace of ice and darkness
1,a fortress guarding one of the passages to the realm of eternal ice

;frost giant companions
3,[1d4] *white bears*
2,[2d4] *winter wolves*
1,a *cryohydra*
1,a *white dragon*
1,a *spectre* of their ancient ice king

;dwarf forge
1,[dwarf forge 0] [dwarf forge 1]
1,[dwarf forge 1]
1,[dwarf forge 1][dwarf forge 2]

;dwarf forge 0
1,Great
1,Old
1,High

;dwarf forge 1
1,Anvil
1,Hammer
1,Grimm
1,Grind
1,Sky
1,Thunder
1,Star
1,Moon

;dwarf forge 2
1,light
1,eater
1,father

;dwarves
3,This is a small forge. [5d8] dwarves live and work here led by one they call [dwarf]
1,This is a legendary forge stronghold. [5d8x10] dwarves live and work here led by one they call [dwarf] (level [1d4+8]). [3d6] families live here, each led by a clan elder (level [1d6+2])

;dwarf
1,[dwarf 1] [dwarf 2a][dwarf 2b]<img src="[[redirect https://campaignwiki.org/face/redirect/alex/dwarf]]" />

;dwarf 1
1,Lóa
1,Marjun
1,Ragna
1,Sigrun
1,Tordís
1,Várdís
1,Yngva
1,Albin
1,Ani
1,Baldur
1,Bofi
1,Egi
1,Frosti
1,Gylvi

;dwarf 2a
1,Shield
1,Hammer
1,Plate
1,Sword
1,Axe
1,Stone
1,Iron
1,Steel
1,Earth

;dwarf 2b
1,bearer
1,smasher
1,master
1,friend
1,maker
1,eater

;water
1,A lake covering the ruins of an ancient town
1,A lake inhabited by [2d20] charming *nixies* and the same number of *giant fish* guarding their sea weed garden
1,A big lake [cold lake]
1,A tribe of [5d8] *froglings* in a mud village guarded by [frogling companions]

;frogling companions
1,spear traps
5,[1d5] *giant toads*

;forest-hill
1,One of the hills has an old lookout from which you can see most of the [name for forest/forest-hill/trees/fir-forest/firs].
1,Small creeks have dug deep channels into this forest. The going is tough.
1,One one these forested hills is inhabited by [1d6 ogres].
1,These hills belong to the [orctribe], [1d6x10] *orcs* led by one they call [orc leader]. Their fort is [orc fort].
1,On one of the hills here stands an old tower overlooking the forest below. This is the home of a *manticore* called [manticore].
1,The hill overlooking [name for forest/forest-hill/trees/fir-forest/firs] is the home of [1d8 treants].
1,There is a hill with a nice cave which offers shelter from the rain but is home to [1d4 bears].
1,[5d8] dwarves have set up a small logging community, here. They are led by one they call [dwarf]. The camp is defended by [dwarven companions]

;dwarven companions
1,a palisade and wooden spikes
1,a *war bear*
4,[1d5+1] *war bears*

;1d4 bears
1,an angry, male *bear*
1,a small family of [1d3+1] *bears*

;orctribe
1,[orctribe 1] [orctribe 2] tribe

;orctribe 1
1,White
1,Red
1,Black
1,Broken
1,Smashed
1,Crushed
1,Ground

;orctribe 2
1,Hand
1,Fist
1,Eye
1,Face
1,Skull
1,Sword
1,Hammer
1,Shield

;orc leader
1,[orc]<img src="[[redirect https://campaignwiki.org/face/redirect/alex/orc]]" />

;orc
1,Mushroom Friend (HD [1d6+1])
1,Pie Eater (HD [1d6+1])
1,Pig Face (HD [1d6+1])
1,Strong Arm (HD [1d6+1])
1,Spear Thrower (HD [1d6+1])
1,Long Fang (HD [1d6+1])

;orc fort
1,surrounded by spiked pit traps
1,guarded by a *boar*
4,guarded by [1d4+1] *boars*

;1d6 ogres
1,[ogre leader]
5,[ogre leader] leading [ogres]

;ogre
1,Pain
1,Smash
1,Club
1,Hammer
1,Rock
1,Flesh Eater

;ogre leader
1,an *ogre mage* called [ogre]
5,an *ogre* called [ogre]

;ogres
1,[1d5] more *ogres*
1,[1d5] more *ogres* and [1d6x10] *orcs*

;bushes
1,Badlands full of shrubs and wild hedges.
1,Dry lands full of tumbleweed and thorn bushes.
1,A well hidden hamlet of [5d8] *halflings* led by one they call [halfling leader].
1,An ancient stone fort overlooking the woods has been taken over by a war party of [4d6] *hobgoblins*. The fort is defended by [hobgoblin companions].
1,Beneath these badlands is a cavesystem including an underground river.
1,The dry lands up here are the hunting grounds of a *manticore* called [manticore] living in the ruins of an old tower.
1,A *green dragon* lives at [hill name], one of the hills overlooking these shrublands.

;hobgoblin companions
1,a small watchtower with an archer
1,a *giant ape*
1,[1d5+1] *giant apes*

;manticore
1,Old Man [manticore name]
1,Old [manticore name]
1,Lord [manticore name]
1,Grandfather [manticore name]
1,[manticore name]
1,Bastard of [manticore name]
1,Ancient [manticore name]

;manticore name
1,Pain
1,Greed
1,Spite
1,Envy
1,Hate
1,Avarice
1,Ambition

;halfling leader
1,[halfling name] (level [1d6+1])

;halfling name
1,Asphodel
1,Bell
1,Berylla
1,Celandine
1,Dodinas
1,Gorbadoc
1,Hamfast
1,Isumbras
1,Lalia
1,Lobelia
1,Mentha
1,Mosco
1,Myrtle
1,Otho
1,Rufus
1,Seredic
1,Tobald
1,Tolman

;hill name
1,[hill 1] [hill 2]

;hill 1
1,Green
1,Red
1,Big
1,Rocky
1,Gold
1,Iron
1,Dead Man's

;hill 2
1,Cliff
1,Crag
1,Hill
1,Ridge
1,Rock

;swamp
1,The river widens here and forms a large swamp. You need a guide and boats in order to pass through it.
1,This bog is a labyrinth. You need a guide to find your way through it.
1,This reed is home to a lot of birds.
1,These wet land have been settled by a tribe of [6d6] *lizard people* led by one they call [lizard leader] (HD [1d4+1]). The little village of mud huts is guarded by [lizard companions].
1,This swamp is home to [5d8] *froglings* in a mud village guarded by [frogling companions].
1,A ruined tower standing on a small island in this swamp is home to the *ettin* called [ettin].
1,In the old days, this bog was used to drown evil necromancers. [bog wights]
1,On one of the islands of this swamp there is a huge mud mound. [goblins]

;lizard leader
1,Son of Set
1,Egg Mother
1,Forked Tongue
1,Nest Builder
1,Poet Heart
1,Silent Hunter
1,Quiet Night
1,Golden Eyes
1,Daughter of Drake
1,Dragon Spirit

;lizard companions
2,spiked barriers
5,[1d5] *giant wasps*
5,[1d5] *giant lizards*

;trees
1,Tall trees cover this valley.
1,There are traces of logging activity in this light forest.
1,[2d4] *harpies* sing in the tree tops, luring men into the depths of the forest and to their death.
1,There is a cave in this forest housing the *ettin* called [ettin].

;ettin
1,Bert and Bob
1,Smasher and Gnawer
1,Death and Pain
1,Club and Nail
1,Bone and Marrow
1,Punch and Break

;bog wights
1,At night, [wight crawls]

;wight crawls
1,the *wight* [wight leader] crawls out of a wet grave and roams the land in search of followers.
1,[1d7+1] *wights* led by [wight leader] crawl out of their wet graves and roam the land in search of more followers.

;wight leader
1,Old [wight name] of [wight realm]
1,[wight name] the Terrible of [wight realm]
1,[wight name] the Cruel of [wight realm]
1,King [king wight] of [wight realm]
1,Queen [queen wight] of [wight realm]

;wight name
1,[king wight]
1,[queen wight]

;king wight
1,Eilif
1,Kyran
1,Tariq

;queen wight
1,Kali
1,Maura
1,Thyia

;wight realm
1,Abilard
1,Erlechai
1,Merlen
1,Ouria
1,Yzarria

;goblins
1,[6d10] *goblins* live here, led by one they call [goblin].
5,[6d10] *goblins* live here, led by one they call [goblin]. The goblins have tamed [2d6] [goblin companions]. Goblins love to ride these into battle.

;goblin companions
2,*giant wolves*
1,*giant weasels*
1,*giant spiders*
1,*giant beetles*

;goblin
1,[goblin 1] [goblin 2]

;goblin 1
1,Death
1,Man
1,Eye
1,Wolf
1,Beetle
1,The

;goblin 2
1,Rider
1,Killer
1,Poker
1,King
1,Basher
1,Impaler

;forest
1,This is the [name for forest/forest-hill/trees/fir-forest/firs] and there are no trails, here. Without a guide, you will get lost.
1,Tall trees and dense canopy keep the sunlight away. There are big mushrooms everywhere. [mushrooms]
1,This forest is under the protection of [1d8 treants].
1,The trees here are full of spider webs. Anybody climbing the trees will get attacked by [2d4] *giant spiders*.
1,[2d12] *elves* led by one they call [elf leader] (level [1d6+1]) have built their [elf dwelling] in this forest. [elf companions]
1,A system of big tunnels under these trees is home to [1d6 weasels].
1,At dusk and dawn, you can sometimes see [boars].

;mushrooms
1,The mushrooms are guarded by [mykonids]
1,If eaten, [do something interesting]
1,These mushrooms are actually the antennaes and horns for the big sleeping supermushroom [name for forest/forest-hill/trees/fir-forest/firs] living beneath the forest. Around here, your sleep will be filled with mushroom dreams.

;mykonids
1,[3d6] *mykonids*.
1,[3d6] *mykonids* guarding a mushroom circle. On nights of the full moon, or on a 1 in 6, the portal to the fey realms opens. If so, [2d12] *elves* led by one they call [elf leader] (level [1d6+1]) will be visiting.

;do something interesting
1,save vs. poison or die. The locals use this to kill criminals.
1,save vs. poison or loose your voice for a week. The locals avoid doing this.
1,save vs. poison or be cursed to turn into a mykonid over the coming week.
1,save vs. poison or be paralysed for 1d4 hours. Local Set cultists will trade in these mushrooms.
1,gain telepathic powers for a week. The locals use them to spy on the thoughts of any foreigners.
1,enjoy wild and colorful visions for 1d20 hours. If you roll higher than your wisdom, see something relevant for the current campaign. The locals lead village idiots here to warn them of impeding danger.
1,heal 1d6+1. The locals assemble here after a fight to recuperate.

;name for forest/forest-hill/trees/fir-forest/firs
1,[forest 1] [forest 2]

;forest 1
1,Dark
1,Deep
1,Murky
1,Black
1,Shadow
1,Moon
1,Green

;forest 2
1,Forest
1,Wood

;boars
1,the guardian spirit of this forest, a *demon boar*
25,a male *boar* seaching for food
5, a group of [5d6] female *boars* and their young

;1d6 weasels
1,a *giant weasel*
5,[1d5+1] *giant weasels*

;1d8 treants
1,the *treant* called [treant]
7,[1d7+1] *treants* led by the one they call [treant]

;treant
1,Oldfather
1,Birchwhip
1,Rootstrong
1,Mossman
1,Coldwater

;elf dwelling
1,wooden tree palace
1,network of hanging bridges and little tree houses

;elf companions
1,The settlement is nearly impossible to spot from the ground level.
1,At night, the settlement is illuminated by magic light.
1,During the day, sweet music can be haird from the tree tops.
1,The settlement is protected by a *giant weasel*.
2,The settlement is protected by [1d2+1] *giant weasels*.

;elf leader
1,[elf]<img src="[[redirect https://campaignwiki.org/face/redirect/alex/elf]]" />

;elf
1,Longevity
1,Sleepyflower
1,Forestflute
1,Waspheart
1,Lushvalley
1,Starlight
1,Treefriend
1,Moonlove
1,Sunshine

;fir-forest
1,A fir forest.
1,A fir forest. Sometimes you can see an *elk*.
1,This fir forest is home to a pack of [3d6] *wolves*.
1,At dusk and dawn, you can sometimes see [boars].
1,There is a cave in this fir forest housing the *ettin* called [ettin].
1,At the foot of [crag name], there is cave inhabited by [1d8 trolls].
1,In this fir forest is a little campsite with [1d8 bugbears].

;1d8 bugbears
1,a *bugbear* called [bugbear]
7,[1d7+1] *bugbears* led by one they call [bugbear]

;bugbear
1,Silentfoot
1,Silverpaws
1,Deathlicker
1,Piercingeyes

;crag name
1,[crag 1] [crag 2]

;crag 1
1,Stone
1,Steep
1,Witching
1,Old
1,Wind

;crag 2
1,Crag
1,Break
1,Cliff
1,Hill

;1d8 trolls
1,a *troll* called [troll]
7,[1d7+1] *trolls* led by one they call [troll]

;troll
1,Stone
1,Rock
1,Boulder
1,Strong
1,Fist
1,Grey

;firs
1,A few stunted firs grow in these highlands.
1,The dry lands up here are the hunting grounds of a *manticore* called [manticore] living in the ruins of an old tower.
1,At dusk and dawn a pack of [3d6] *wolves* through these highlands.

;thorp
1,There is a thorp of [1d4x10] *humans* led by one they call [human]. The [human houses] are protected by [human companions].

;village
1,There is a village of [5d6x10] *humans* led by a [human class] (level 9) called [human] who lives in a small tower with their subordinate [human class] (level 7) called [human] and their two aides, the [human class] [human] and the [human class] [human] (both level 5). The [human houses] are protected by [human companions] and a [human defense].

;town
1,There is a town of [1d6x100] *humans* led by a [human class] (level 9) called [human] who lives in a keep with their subordinate [human class] (level 7) called [human] and their two aides, the [human class] [human] and [human class] [human] (both level 5). The [human houses] are protected by a town wall and the river. There is [town feature].

;town feature
1,a market
1,a ferry
1,a toll bridge
1,a huge gallows
1,a fight pit
1,a chained *troll*
1,a temple of [power]

;human houses
1,thatched huts
1,wooden houses
1,grass covered longhouses
1,log cabins
1,small stone huts
1,mud huts

;human defense
1,ditch
1,palisade
1,the river flowing around it

;human companions
1,some sharpened stakes
1,a *war dog*
6,[1d6+1] *war dogs*

;human class
1,sorceror
1,magic user
1,necromancer
1,fighter
1,warlord
1,knight

;human
1,[man]<img src="[[redirect https://campaignwiki.org/face/redirect/alex/man]]" />
1,[woman]<img src="[[redirect https://campaignwiki.org/face/redirect/alex/woman]]" />

;man
1,Aaron
1,Claudius
1,Ferdinand
1,Hannibal
1,Justinian
1,Konrad
1,Mondrian
1,Orland
1,Rudolf
1,Thorman
1,Voron
1,Xaver
1,Zoran

;woman
1,Berta
1,Dagmar
1,Elena
1,Gertrude
1,Isolde
1,Lamia
1,Nauma
1,Petra
1,Quen
1,Sereina
1,Ulma
1,Wilma
1,Ysolde

;power
1,Set
1,Orcus
1,Nergal
1,Pazuzu
1,Freya
1,Odin
1,Thor
1,Mithra
1,Hel
};

sub get_data {
  my $url = shift;
  $log->debug("get_data: $url");
  my $ua = Mojo::UserAgent->new;
  my $res = $ua->get($url)->result;
  return $res->body if $res->is_success;
  $log->error("get_data: " . $res->code . " " . $res->message);
}

sub get_post_data {
  my $url = shift;
  my %data = @_;
  $log->debug("get_post_data: $url");
  my $ua = Mojo::UserAgent->new;
  my $tx = $ua->post($url => form => \%data);
  my $error;
  if ($tx->success) {
    my $res = $ua->post($url => form => \%data)->result;
    return $res->body if $res->is_success;
    $error = $res->code . " " . $res->message;
  } else {
    my $err = $tx->error;
    if ($err->{code}) {
      $error = $err->{code} . " " . $err->{message};
    } else {
      $error = $err->{message};
    }
  }
  $log->error("get_post_data: $error");
  return "<p>There was an error when attempting to load the map ($error).</p>";
}

# based on text-mapper.pl Mapper process
my $hex_re = qr/^(\d\d)(\d\d)(?:\s+([^"\r\n]+)?\s*(?:"(.+)"(?:\s+(\d+))?)?|$)/;

sub parse_map {
  my $map = shift;
  my $map_data;
  for my $hex (split(/\r?\n/, $map)) {
    if ($hex =~ /$hex_re/) {
      my ($x, $y, $types) = ($1, $2, $3);
      my @types = split(/ /, $types);
      my @words;
      for my $w1 (@types) {
	for my $w2 (@types) {
	  if ($w1 eq $w2) {
	    push(@words, $w1);
	  } else {
	    push(@words, "$w1 $w2");
	  }
	}
      }
      $map_data->{"$x$y"} = \@words;
    }
  }
  return $map_data;
}

my $dice_re = qr/^(\d+)d(\d+)(?:x(\d+))?(?:\+(\d+))?$/;

sub parse_table {
  my $text = shift;
  $log->debug("parse_table: parsing " . length($text) . " characters");
  my $data = {};
  my $key;
  for my $line (split(/\r?\n/, $text)) {
    if ($line =~ /^;([^#\r\n]+)/) {
      $key = $1;
    } elsif ($key and $line =~ /^(\d+),(.+)/) {
      $data->{$key}->{total} += $1;
      my %h = (count => $1, text => $2);
      $h{text} =~ s/\*(.*?)\*/<strong>$1<\/strong>/g;
      push(@{$data->{$key}->{lines}}, \%h);
    }
  }
  # check tables
  for my $table (keys %$data) {
    for my $line (@{$data->{$table}->{lines}}) {
      for my $subtable ($line->{text} =~
			/
			\[\[redirect (http\[\]\n*?)\]\]
			\[([^\[\]\n]*?)\]
			/gx) {
	next if $subtable =~ /$dice_re/;
	next if $subtable =~ /^https?:/;
	$log->error("Error in table $table: subtable $subtable is missing")
	    unless $data->{$subtable};
      }
    }
  }
  return $data;
}

sub pick_description {
  my $total = shift;
  my $lines = shift;
  my $roll = int(rand($total)) + 1;
  my $i = 0;
  for my $line (@$lines) {
    $i += $line->{count};
    if ($i >= $roll) {
      return $line->{text};
    }
  }
  return '';
}

sub resolve_redirect {
  # If you install this tool on a server using HTTPS, then some browsers will
  # make sure that including resources from other servers will not work.
  my $url = shift;
  my $ua = Mojo::UserAgent->new;
  my $res = $ua->get($url)->result;
  if ($res->code == 301 or $res->code == 302) {
    return Mojo::URL->new($res->headers->location)
	->base(Mojo::URL->new($url))
	->to_abs;
  }
  $log->info("resolving redirect for $url did not result in a redirection");
  return $url;
}

sub pick {
  my $map_data = shift;
  my $table_data = shift;
  my $level = shift;
  my $coordinates = shift;
  my $word = shift;
  my $text;
  # $log->debug("looking for a $word table");
  if ($table_data->{$word}) {
    my $total = $table_data->{$word}->{total};
    my $lines = $table_data->{$word}->{lines};
    $text = pick_description($total, $lines);
    $text =~ s/\[\[redirect (https:.*?)\]\]/resolve_redirect($1)/ge;
    $text =~ s/\[(.*?)\]/describe($map_data,$table_data,$level+1,$coordinates,[$1])/ge;
    # $log->debug("picked $text from $total entries");
  }
  return $text;
}

my %names;

sub describe {
  my $map_data = shift;
  my $table_data = shift;
  my $level = shift;
  my $coordinates = shift;
  my $words = shift;
  return '' if $level > 10;
  my @descriptions;
  for my $word (@$words) {
    # valid dice rolls: 1d6, 1d6+1, 1d6x10, 1d6x10+1
    if (my ($n, $d, $m, $p) = $word =~ /$dice_re/) {
      my $r = 0;
      for(my $i = 0; $i < $n; $i++) {
	$r += int(rand($d)) + 1;
      }
      $r *= $m||1;
      $r += $p||0;
      # $log->debug("rolling dice: $word = $r");
      push(@descriptions, $r);
    } elsif ($word =~ /^name for (\S+)/) { # "name for white big mountain"
      my $key = $1; # "white"
      my $name = $names{"$word: $coordinates"}; # "name for white big mountain: 0101"
      return $name if $name;
      $name = pick($map_data, $table_data, $level, $coordinates, $word);
      next unless $name;
      push(@descriptions, $name);
      spread_name($map_data, $coordinates, $word, $key, $name);
    } else {
      my $text = pick($map_data, $table_data, $level, $coordinates, $word);
      next unless $text;
      push(@descriptions, $text);
    }
  }
  return join(' ', @descriptions);
}

sub process {
  my $text = shift;
  my @terms = split(/(<img.*?>)/, $text);
  return $text unless @terms > 1;
  my @output; # $output[0] is texts, $output[1] is images
  my $i = 0;
  while (@terms) {
    push(@{$output[$i]}, shift(@terms));
    $i = 1 - $i;
  }
  return '<span class="images">' . join('', @{$output[1]}) . '</span>'
    . join('', @{$output[0]});
}

sub describe_map {
  my $map_data = shift;
  my $table_data = shift;
  my %descriptions;
  for my $coord (keys %$map_data) {
    $descriptions{$coord} = process(describe($map_data, $table_data, 1,
					     $coord, $map_data->{$coord}));
  }
  return \%descriptions;
}

my $delta = [[[-1,  0], [ 0, -1], [+1,  0], [+1, +1], [ 0, +1], [-1, +1]],  # x is even
	     [[-1, -1], [ 0, -1], [+1, -1], [+1,  0], [ 0, +1], [-1,  0]]]; # x is odd

sub xy {
  my $coordinates = shift;
  return (substr($coordinates, 0, 2), substr($coordinates, 2));
}

sub coordinates {
  my ($x, $y) = @_;
  return sprintf("%02d%02d", $x, $y);
}

sub neighbour {
  # $hex is [x,y] or "0101" and $i is a number 0 .. 5
  my ($hex, $i) = @_;
  $hex = [xy($hex)] unless ref $hex;
  # return is a string like "0102"
  return coordinates(
    $hex->[0] + $delta->[$hex->[0] % 2]->[$i]->[0],
    $hex->[1] + $delta->[$hex->[0] % 2]->[$i]->[1]);
}

sub spread_name {
  my $map_data = shift;
  my $coordinates = shift;
  my $word = shift; # "name for white big mountain"
  my $key = shift; # "white"
  my @keys = split(/\//, $key); # ("white")
  my $name = shift; # "Vesuv"
  my %seen = ($coordinates => 1);
  # $log->debug("$word: $coordinates = $name");
  my @queue = map { neighbour($coordinates, $_) } 0..5;
  while (@queue) {
    # $log->debug("Working on the first item of @queue");
    my $coord = shift(@queue);
    next if $seen{$coord} or not $map_data->{$coord};
    $seen{$coord} = 1;
    if (intersect(@keys, @{$map_data->{$coord}})) {
      $log->error("$word for $coord is already something else")
	  if $names{"$word for $coord"};
      $names{"$word: $coord"} = $name; # "name for white big mountain: 0102"
      # $log->debug("$word: $coord = $name");
      push(@queue, map { neighbour($coord, $_) } 0..5);
    }
  }
}

sub describe_text {
  my $input = shift;
  my $table_data = shift;
  my @descriptions;
  for my $text (split(/\r?\n/, $input)) {
    $log->debug("replacing lookups in $text");
    $text =~ s/\[(.*?)\]/describe({},$table_data,1,"",[$1])/ge;
    push(@descriptions, $text);
  }
  return \@descriptions;
}

get '/' => sub {
  my $c = shift;
  my $map = $c->param('map') || $default_map;
  my $url = $c->param('url');
  my $table = $c->param('table');
  $c->render(template => 'edit', map => $map, url => $url, table => $table);
};

get '/load/random/smale' => sub {
  my $c = shift;
  my $map = get_data('https://campaignwiki.org/text-mapper/smale/random/text');
  $c->render(template => 'edit', map => $map, url=>'', table => '');
};

get '/load/random/alpine' => sub {
  my $c = shift;
  my $map = get_data('https://campaignwiki.org/text-mapper/alpine/random/text');
  $c->render(template => 'edit', map => $map, url=>'', table => '');
};

any '/describe' => sub {
  my $c = shift;
  my $map = $c->param('map');
  my $svg = get_post_data('https://campaignwiki.org/text-mapper/render', map => $map);
  my $url = $c->param('url');
  my $table;
  $table = get_data($url) if $url;
  $table ||= $c->param('table');
  $table ||= $default_table;
  $c->render(template => 'description',
	     svg => $svg,
	     descriptions => describe_map(
	       parse_map($map),
	       parse_table($table)));
};

get '/nomap' => sub {
  my $c = shift;
  my $input = $c->param('input') || '';
  my $url = $c->param('url');
  my $table = $c->param('table');
  $c->render(template => 'nomap', input => $input, url => $url, table => $table);
};

any '/describe/text' => sub {
  my $c = shift;
  my $input = $c->param('input');
  my $url = $c->param('url');
  my $table;
  $table = get_data($url) if $url;
  $table ||= $c->param('table');
  $table ||= $default_table;
  $c->render(template => 'text',
	     descriptions => describe_text($input, parse_table($table)));
};

get '/default/map' => sub {
  my $c = shift;
  $c->render(text => $default_map, format => 'txt');
};

get '/default/table' => sub {
  my $c = shift;
  $c->render(text => $default_table, format => 'txt');
};

get '/source' => sub {
  my $c = shift;
  seek(DATA,0,0);
  local $/ = undef;
  $c->render(text => <DATA>, format => 'txt');
};

get '/authors' => sub {
  my $c = shift;
  $c->render(template => 'authors');
};

get '/help' => sub {
  my $c = shift;
  $c->render(template => 'help');
};

app->start;

__DATA__
@@ edit.html.ep
% layout 'default';
% title 'Hex Describe';
<h1>Hex Describe</h1>
<p>
Describe a hex map using some random data.
</p>
<p>
Load <%= link_to 'random Smale data' => 'loadrandomsmale' %>.
Load <%= link_to 'random Alpine data' => 'loadrandomalpine' %>.
Or use <%= link_to 'no map' => 'nomap' %>.
</p>
%= form_for describe => (method => 'POST') => begin
%= text_area map => (cols => 60, rows => 15) => begin
<%= $map =%>
% end

<p>
If you need the <%= link_to 'default map' => 'defaultmap' %>
for anything, feel free to use it. It was generated using
the <a href="https://campaignwiki.org/text-mapper/alpine">Alpine</a>
generator.
</p>

<p>
%= submit_button 'Submit', name => 'submit'
</p>

<p>
The description of the map is generated using the
<%= link_to 'default table' => 'defaulttable' %>.
If you have your own tables somewhere public (a pastebin, a public file at a
file hosting service), you can provide the URL to your tables. Alternatively,
you can just paste your tables into the text area below.
</p>

<p>
Table URL:
%= text_field url => $url

<p>
Alternatively, just paste your tables here:
%= text_area table => (cols => 60, rows => 15) => begin
<%= $table =%>
% end
%= end


@@ description.html.ep
% layout 'default';
% title 'Hex Describe';
<h1>Hex Descriptions</h1>
<div class="description">
%== $svg
% for my $hex (sort keys %$descriptions) {
<p><strong><%= $hex =%></strong>: <%== $descriptions->{$hex} %></p>
% }
</div>

@@ nomap.html.ep
% layout 'default';
% title 'Hex Describe (without a map)';
<h1>Hex Describe (no map)</h1>
<p>
Write a text using [square brackets] to replace with data from a random table.
Provide a random table using the URL below.
</p>
%= form_for describetext => (method => 'POST') => begin
%= text_area input => (cols => 60, rows => 15) => begin
<%= $input =%>
% end

<p>
Table URL:
%= text_field url => $url

<p>
Alternatively, just paste your tables here:
%= text_area table => (cols => 60, rows => 15) => begin
<%= $table =%>
% end

<p>
%= submit_button 'Submit', name => 'submit'
</p>
%= end


@@ text.html.ep
% layout 'default';
% title 'Hex Describe (without a map)';
<h1>Hex Descriptions (no map)</h1>
<div class="description">
% for my $text (@$descriptions) {
<p><%== $text %></p>
% }
</div>


@@ help.html.ep
% layout 'default';
% title 'Hex Describe';
<h1>Hex Describe Help</h1>

<p>
How do you get started writing a table for <em>Hex Describe</em>? This page is
my attempt at writing a tutorial.
</p>

<p>
First, let’s talk about random tables to generate text. <a class="url http
outside" href="http://random-generator.com/">Abufalia</a> uses the following
format:</p><ol><li>each table starts with a semicolon and the name of the
table</li><li>each entry starts with a number, a comma and the
text</li></ol><p>Let’s write a table for some hills.
</p>

<pre>
;hills
1,The hills are covered in trees.
1,An orc tribe is camping in a ruined watch tower.
</pre>

<p>
If we use this table to generate random text, then half the hills will be
covered in trees and the other half will be covered in orc infested watch tower
ruins. What we want is for orcs to be rare. We can simply make the harmless
entry more likely:
</p>

<pre>
;hills
5,The hills are covered in trees.
1,An orc tribe is camping in a ruined watch tower.
</pre>

<p>
Now five in six hills will be harmless.
</p>

<p>
We could have chosen a different approach, though. We could have written more
entries instead.
</p>

<pre>
1,The hills are covered in trees.
1,Many small creeks separated by long ridges make for bad going in these badlands.
1,An orc tribe is camping in a ruined watch tower.
</pre>

<p>
Now every line has a one in three chance of being picked. I like almost all the
hexes to have lairs in them. In my game, people can still travel through these
regions with just a one in six chance of an encounter. That’s why I’m more
likely to just write a table like this:
</p>

<pre>
;hills
1,Many small creeks separated by long ridges make for bad going in these badlands.
1,An *ettin* is known to live in the area.
1,A *manticore* has taken over a ruined tower.
1,A bunch of *ogres* live in these hills.
1,An *orc tribe* is camping in a ruined watch tower.
</pre>

<p>
Now only one in five hexes has nothing to offer.
</p>

<p>
We can be more specific because we can include dice rolls in square brackets. So
let’s specify how many ogres you will encounter:
</p>

<pre>
;hills
1,Many small creeks separated by long ridges make for bad going in these badlands.
1,An *ettin* is known to live in the area.
1,A *manticore* has taken over a ruined tower.
1,[1d6] *ogres* live in these hills.
1,An *orc tribe* is camping in a ruined watch tower.
</pre>

<p>
Then again, it makes me sad when the generated text then says “1 ogres”. It
should say “1 ogre!” We can do that by creating a separate table for ogres.
Separate tables come in square brackets, like dice rolls.
</p>

<pre>
;hills
1,Many small creeks separated by long ridges make for bad going in these badlands.
1,An *ettin* is known to live in the area.
1,A *manticore* has taken over a ruined tower.
1,[1d6 ogres live] in these hills.
1,An *orc tribe* is camping in a ruined watch tower.

;1d6 ogres live
1,An *ogre* lives
5,[1d5+1] *ogres* live
</pre>

<p>
Now if there are ogres in these hills, there is a one in six chance for an
“ogre” living in these hills and a five in six chance for two to six “ogres”
living in these hills.
</p>

<p>
How about we name the most important ogre such that players have an ogre to talk
to?
</p>

<pre>
;hills
1,Many small creeks separated by long ridges make for bad going in these badlands.
1,An *ettin* is known to live in the area.
1,A *manticore* has taken over a ruined tower.
1,[1d6 ogres live] in these hills.
1,An *orc tribe* is camping in a ruined watch tower.

;1d6 ogres live
1,An *ogre* named [ogre] lives
5,[1d5+1] *ogres* led by one named [ogre] live

;ogre
1,Mad Eye
1,Big Tooth
1,Much Pain
1,Bone Crusher
</pre>

<p>
As you can see, these three tables can already generate a lot of different
descriptions. For example:
</p>

<ol>
<li>An <em>ettin</em> is known to live in the area.</li>
<li>An <em>ogre</em> named Mad Eye lives in these hills.</li>
<li>4 <em>ogres</em> led by one named Big Tooth live in these hills.</li>
</ol>

<p>
Notice how the ogre names are all just two words. How about splitting them into
tables?
</p>

<pre>
;hills
1,Many small creeks separated by long ridges make for bad going in these badlands.
1,An *ettin* is known to live in the area.
1,A *manticore* has taken over a ruined tower.
1,[1d6 ogres live] in these hills.
1,An *orc tribe* is camping in a ruined watch tower.

;1d6 ogres live
1,An *ogre* named [ogre] lives
5,[1d5+1] *ogres* led by one named [ogre] live

;ogre
1,[ogre 1] [ogre 2]

;ogre 1
1,Mad
1,Big
1,Much
1,Bone

;ogre 2
1,Eye
1,Tooth
1,Pain
1,Crusher
</pre>

<p>
Now we will see such fantastic names as Big Pain, Bone Eye and Mad Tooth.
</p>

<p>
And now you just keep adding. Take a look at the <a class="url http outside"
href="https://campaignwiki.org/hex-describe/default/table">default table</a> if
you want to see more examples.
</p>

<p>
But now you might be wondering: how does <em>Hex Describe</em> know which table
to use for a map entry like the following?
</p>

<pre>
0101 dark-green trees village
</pre>

<p>
The answer is simple: <em>Hex Describe</em> will simply try every word and every
two word combo. If a table for any of these exists, it will be used.
</p>

<p>
Thus, the following tables will be used, if they exist:
</p>

<pre>
;dark-green
;dark-green trees
;dark-green village
;trees dark-green
;trees
;trees village
;village dark-green
;village trees
;village
</pre>

<p>
Not all of them make sense. I usually try to stick to single words. I needed
this feature, however, because I wanted to provide different tables for “white
mountain” and “light grey mountain”. Just look at the example:
</p>

<p>
<img alt="A screenshot of the map" style="width: 100%"
src="https://alexschroeder.ch/wiki/download/Image_1_for_2018-03-12_Describing_Hexes" />
</p>

<p>
The mountains in the bottom left corner at (01.09) and (01.10) just feel
different. I guess you could say that the two swamps in (05.07) and (06.08) also
feel different. In that case you might opt to provide different tables for “grey
swamp” and “dark-grey swamp”. Up to you!
</p>

<p>
As far as I am concerned, however, I recommend to start with the following
tables:
</p>

<pre>
;water
;mountains
;white mountain
;light-grey mountain
;forest-hill
;bushes
;swamp
;trees
;forest
;fir-forest
;firs
;thorp
;village
;town
</pre>

<p>
This will have you covered for all these hexes:
</p>

<p>
<img alt="A list of hexes illustrating the list of terrains covered" style="width: 100%"
src="https://alexschroeder.ch/wiki/download/Image_1_for_2018-03-15_How_to_Describe_Hexes" />
</p>

<p>
You’re good to go! Write those tables and share them. <img alt=":)" class="smiley" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQBAMAAADt3eJSAAAABGdBTUEAALGPC/xhBQAAAAFzUkdCAK7OHOkAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAACFQTFRFAAAAAAAAHRkAiHUA07YA+tgAZFYA/90AWU0Aj3sA////jG0orwAAAAF0Uk5TAEDm2GYAAAABYktHRApo0PRWAAAAbUlEQVQI12NgYGAUFBRgAAJGZdcQIxBLLLy8vDQRKJBeUV7eXibAwBReWF4uXqrAIFwOYpQbMohAGI4MouVgEMggWgiixQMZRErEy8sL3R2BiieWl0sCFTOFVwoKTgdqZ0wHqQEaCLcCYSnUGQB7ciGbohFtcwAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAxNC0wNy0wM1QxNDo0Nzo0NiswMjowMAcO4yYAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMTQtMDctMDNUMTQ6NDc6NDYrMDI6MDB2U1uaAAAAAElFTkSuQmC" />
</p>

<p>
If you’re more interested in the <em>Smale</em> maps, I recommend you start with
the following tables:
</p>

<pre>
;water
;swamp
;marsh
;desert
;grass
;trees
;forest
;fir-forest
;forest-mountain
;forest-mountains
;forest-hill
;mountain
;hill
;bush
;bushes
;thorp
;village
;town
;large-town
;city
;keep
;tower
;castle
;shrine
;law
;chaos
;fields
</pre>

<p>
And if you want to split them up: instead of “desert” use “sand desert” and
“dust desert”; instead of “fir-forest” use “green fir-forest” and “dark-green
fir-forest”; instead of “hill” use “light-grey hill” and “dust hill”; instead of
“forest-hill” use “light-grey forest-hill” and “green forest-hill”; instead of
“forest-mountains” use “green forest-mountains” and “grey forest-mountains”.
</p>

@@ authors.html.ep
% layout 'default';
% title 'Hex Describe Authors';
<h1>Hex Describe Authors</h1>

<p>
The default table contains material by the following people:
</p>

<ul>
<li><a href="https://alexschroeder.ch">Alex Schroeder</a></li>
<li><a href="https://ropeblogi.wordpress.com/">Tommi Brander</a></li>
</ul>

<p>
The icons are based on the
<a href="https://github.com/kensanata/hex-mapping/tree/master/gnomeyland">Gnomeyland</a>
icons by Gregory B. MacKenzie.
</p>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
%= stylesheet '/hex-describe.css'
%= stylesheet begin
body {
  padding: 1em;
  font-family: "Palatino Linotype", "Book Antiqua", Palatino, serif;
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
.description {
  max-width: 80ex;
}
p {
}
.images img {
  max-width: 80px;
}
.images {
  clear: both;
  float: right;
}
hr {
  clear: both;
}
% end
<meta name="viewport" content="width=device-width">
</head>
<body>
<%= content %>
<hr>
<p>
<a href="https://campaignwiki.org/hex-describe">Hex Describe</a>&#x2003;
<%= link_to 'Authors' => 'authors' %>&#x2003;
<%= link_to 'Help' => 'help' %>&#x2003;
<%= link_to 'Source' => 'source' %>&#x2003;
<a href="https://github.com/kensanata/hex-mapping/blob/master/hex-describe.pl">GitHub</a>&#x2003;
<a href="https://alexschroeder.ch/wiki/Contact">Alex Schroeder</a>
</body>
</html>

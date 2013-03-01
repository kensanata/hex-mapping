Hex Mapping
===========

Many role-playing games use hex maps. Traditionally, D&D used hex maps
for the wilderness and Traveller used a hex map for sectors and
subsectors. They are everywhere.

This project collects the various tools I have used to work with hex
maps. All of them are web applications (CGI scripts) written in Perl 5
and the maps are always SVG documents.

old-school-hex
--------------

This application takes an ASCII art representation of a map and turns
it into a black-and-white hex map.

Example input:

     n " " .
    n-n O-. .
     n-"-" .

text-mapper
-----------

This application takes a textual representation of a map and produces
SVG output.

Example input:

    0101 empty
    0102 mountain
    0103 hill "bone hills"
    0104 forest

uwp-generator
-------------

This application generates a random UWP list suitable for
Traveller-style Science Fiction games.

It generates output like the following:

    Tavomazupa       0103  D85D000-0           Ba Wa
    Xeqqtite         0107  C858651-6       S   Ag Ga NI
    Baziezoti        0108  C467100-7           Lo A
    Zuzinba          0109  D350697-3       S   De Lt NI Po
    Titutelu         0202  C75B988-6           Hi Wa

svg-map
-------

This application takes the UWP of a subsector and generates a map for
you. If possible, it also adds communication and trade routes based on
some heuristics. You should install the `uwp-generator` in the same
directory such that the "Random Map" button works as advertized.

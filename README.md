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
    0103 hill
    0104 forest

You need to define what these labels stand for. You can use the
example provided. Here's how to define SVG attributes:

    empty attributes fill="#ffffff" stroke="#b3b3ff"
    mountain attributes fill="#708090"
    hill attributes fill="#daa520"
    forest attributes fill="#228b22"

If you want to get even more fancy, you can define a path inside a
particular terrain:

    hill path M -42.887901,11.051062 C -38.8,5.5935948 -34.0,0.5 -28.174309,-3.0 C -20.987476,-6.5505102 -11.857161,-5.1811592 -5.7871072,-0.050580244 C -2.0,2.6706698 1.1683798,6.1 3.8585628,9.8783938 C 4.1,12.295981 2.5,13.9 0.57117882,14.454662 C -3.0696782,9.3 -7.8,5.1646538 -13.4,2.1 C -21.686794,-1.7 -30.0,0.79168476 -36.5,6.6730178 C -38.8,9.0 -40.9,11.5 -43.086547,14.0 C -43.088939,15.072012 -44.8,14.756431 -44.053241,13.8 C -43.7,12.8 -43.0,12.057 -42.887901,11.051062 z M -5.0,-0.75883624 C 0.9,-6.9553992 7.6,-12.7 15.5,-16.171056 C 21.5,-18.6 28.5,-17.6 33.9,-14.2 C 39.15207,-11.0 41.67227,-5.5846132 43.7,-0.072156244 C 42.456295,2.4 41.252332,5.7995568 39.0,2.9 C 37.295351,-2.9527612 33.1,-8.2775842 27.4,-10.7 C 20.5,-13.551561 12.2,-12.061567 6.4,-7.4 C 2.4597998,-4.7 -1.0845122,-1.4893282 -4.5,1.8 C -7.2715222,4.0 -6.0866092,0.89928976 -5.0,-0.75883624 z

You can provide attributes for this path as well:

    hill path attributes fill="#b8860b"

And finally, you can add attributes to the text element used for the
coordinates:

    text font-size="20pt" dy="15px"

uwp-generator
-------------

This application generates a random UWP list suitable for
Traveller-style Science Fiction games.

svg-map
-------

This application takes the UWP of a subsector and generates a map for
you. If possible, it also adds communication and trade routes based on
some heuristics. You should install the `uwp-generator` in the same
directory such that the "Random Map" button works as advertized.

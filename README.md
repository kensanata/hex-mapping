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

# Hex Mapping

Many role-playing games use hex maps. Traditionally, D&D used hex maps
for the wilderness and Traveller used a hex map for sectors and
subsectors. They are everywhere.

This project collects the various tools I have used to work with hex
maps. All of them are web applications (CGI scripts) written in Perl 5
and the maps are always SVG documents.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-generate-toc again -->
**Table of Contents**

- [Hex Mapping](#hex-mapping)
- [Text Mapper](#text-mapper)
    - [Text Maps from the Command Line](#text-maps-from-the-command-line)
- [Traveller Subsector Generator](#traveller-subsector-generator)
    - [Subsectors from the Command Line](#subsectors-from-the-command-line)
- [Old School Hex](#old-school-hex)
- [Monones](#monones)

<!-- markdown-toc end -->

# Text Mapper

This application takes a textual representation of a map and produces
SVG output.

Example input:

    0101 empty
    0102 mountain
    0103 hill "bone hills"
    0104 forest

Try it: https://campaignwiki.org/text-mapper

## Text Maps from the Command Line

`xmllint` allows us to extract text from XML and HTML documents. On a
Debian system, it's part of `libxml2-utils`.

Generate a text file with a 20x20 alpine wilderness map:

`perl text-mapper.pl get /alpine 2>/dev/null | xmllint --html --xpath '//textarea/text()' - > random-alpine-map.txt`

You'll note that at the very end it contains the seed value.

You can regenerate the same map using this seed:

`perl text-mapper.pl get "/alpine?seed=1499413794" 2>/dev/null | xmllint --html --xpath '//textarea/text()' - > 1499413794.txt`

You can also modify the width and breadth of the map:

`perl text-mapper.pl get "/alpine?width=10&height=5" 2>/dev/null | xmllint --html --xpath '//textarea/text()' - > random-alpine-map.txt`

Let's define an alias to handle the encoding of the map for us:

`alias encodeURIComponent='perl -pe '\''s/([^a-zA-Z0-9_.!~*()'\''\'\'''\''-])/sprintf("%%%02X",ord($1))/ge'\'`

Make some changes to the text file generated above using a text editor
and generate the updated map:

`perl text-mapper.pl get --header 'Content-Type:application/x-www-form-urlencoded' --method POST --content map=$(cat 1499413794.txt|encodeURIComponent) /render 2>/dev/null > 1499413794.svg`

You
can
[use svgexport](https://mijingo.com/blog/exporting-svg-from-the-command-line-with-svgexport) to
generate a PNG image, if you want.

First, install it:

`npm install svgexport -g`

You need to tell it what quality to use when exporting. I use 100% for
PNG files; I'd use less for JPG files.

`svgexport 1499413794.svg 1499413794.png 100%`

# Traveller Subsector Generator

This application generates a random UWP list suitable for
Traveller-style Science Fiction games.

It generates output like the following:

    Tavomazupa       0103  D85D000-0           Ba Wa
    Xeqqtite         0107  C858651-6       S   Ag Ga NI
    Baziezoti        0108  C467100-7           Lo A
    Zuzinba          0109  D350697-3       S   De Lt NI Po
    Titutelu         0202  C75B988-6           Hi Wa

It also takes the UWP of a sector or subsector and generates a map for
you. If possible, it also adds communication and trade routes based on
some heuristics.

Try it: https://campaignwiki.org/traveller

## Subsectors from the Command Line

`xmllint` allows us to extract text from XML and HTML documents. On a
Debian system, it's part of `libxml2-utils`.

How to get a random UWP from the command line:

`perl traveller.pl get /uwp/874568503 2>/dev/null | xmllint --html --xpath '//pre/text()' -  | perl -MHTML::Entities -pe 'decode_entities($_);'`

How to generate a SVG file from the command line:

`perl traveller.pl get /map/874568503 2>/dev/null > 874568503.svg`

Generating a simple SVG file from a map on the command line (URL-escaped):

`perl traveller.pl get --header 'Content-Type:application/x-www-form-urlencoded' --method POST --content "map=Rezufa%200101%20E310000-0%20Ba" /map 2>/dev/null`

Generating an SVG map from UWP in a text file:

`perl traveller.pl get --header 'Content-Type:application/x-www-form-urlencoded' --method POST --content map=$(cat 874568503.txt|encodeURIComponent) /map`

This assumes you defined the following alias:

`alias encodeURIComponent='perl -pe '\''s/([^a-zA-Z0-9_.!~*()'\''\'\'''\''-])/sprintf("%%%02X",ord($1))/ge'\'`

# Old School Hex

This application takes an ASCII art representation of a map and turns
it into a black-and-white hex map.

Example input:

     n " " .
    n-n O-. .
     n-"-" .

Try it: https://alexschroeder.ch/old-school-hex

# Monones

This application generates an island using a
[Voronoi diagram](https://en.wikipedia.org/wiki/Voronoi_diagram). It's
based on Amit Patel's post
[Polygonal Map Generation for Games](http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/)
(2010).

https://campaignwiki.org/monones

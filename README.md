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
    - [old-school-hex](#old-school-hex)
    - [text-mapper](#text-mapper)
    - [uwp-generator](#uwp-generator)
    - [svg-map](#svg-map)
    - [monones](#monones)

<!-- markdown-toc end -->

# old-school-hex

This application takes an ASCII art representation of a map and turns
it into a black-and-white hex map.

Example input:

     n " " .
    n-n O-. .
     n-"-" .

# Text Mapper

This application takes a textual representation of a map and produces
SVG output.

Example input:

    0101 empty
    0102 mountain
    0103 hill "bone hills"
    0104 forest

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

# Monones

This application generates an island using a
[Voronoi diagram](https://en.wikipedia.org/wiki/Voronoi_diagram). It's
based on Amit Patel's post
[Polygonal Map Generation for Games](http://www-cs-students.stanford.edu/~amitp/game-programming/polygon-map-generation/)
(2010).

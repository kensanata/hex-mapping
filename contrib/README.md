Converting Images
=================

Convert SVG to PDF using Inkscape:

```
inkscape --file=traveller.svg --export-area-drawing --without-gui \
    --export-png=traveller.png
```

Add white background:

```
convert traveller.png -alpha remove -background white traveller.png
```

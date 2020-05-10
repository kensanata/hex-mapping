mx =: 30
my =: 20

NB. display map for visuals
decimal =:16"_#.'0123456789abcdef'"_ i.]

NB. colors for viewmat
rgb=: _2 (+/ .*&16 1)\ '0123456789abcdef'&i. @ }.
ocean      =: rgb '#1c86ee'
water      =: rgb '#6ebae7'
sand       =: rgb '#e3bea3'
darksoil   =: rgb '#c97457'
soil       =: rgb '#b0b446'
lightgreen =: rgb '#b7c18c'
green      =: rgb '#77904c'
darkgreen  =: rgb '#2d501a'
lightgrey  =: rgb '#dcddbe'
colors =: (ocean, water, lightgreen, green, darkgreen,: lightgrey)
load 'viewmat'
show =: colors & viewmat

NB. a table of complex numbers
c =: (i. my) j./ i. mx

NB. starting position of the hotspot
hr =: 5
hy =: >. hr % 2
hx =: <. 0.5 + (my % 3) + ? <. 0.5 + my % 3
hc =: hx j. hy

NB. a function to compute altitude changes based on where the hotspot is
change =: 3 : 0
  h =. hr > {. & *. c - y     NB. hotspot = 1
  u =. 0.8 < ? (my, mx) $ 0  NB. regions atop the hotspot might move up
  d =. 0.9 < ? (my, mx) $ 0  NB. regions off the hotspot might move down
  (u * h) - d * -. h
)

NB. a table of altitudes
a =: (my, mx) $ 0

NB. compute the meandering path of the hotspot across the map
NB. compute the change for each step and add it to the altitude
NB. no negative values (always go east)
3 : 0''
for. i. mx - 2  * hr do.
  r =. ? my
  if. r < {. +. hc do. d =. _1j1 else. d =. 1j1 end.
  smoutput r, d, hc
  hc =: hc + d
  a =: 0 & >. a + change hc
end.
)

NB. visualize the last state
show a

NB. print map for text-mapper
colors =: 'ocean', 'water', 'light-green', 'green', 'dark-green',: 'light-grey'
3 : 0''
for_i. i. my do.
  for_j. i. mx do.
    color =. (j { i { a) { colors
    NB. smoutput (>'r<0>2.d' 8!:0 j) , (>'r<0>2.d' 8!:0 i) , ' ', color
  end.
end.
)
smoutput 'include https://campaignwiki.org/contrib/gnomeyland.txt'

NB. exit 0

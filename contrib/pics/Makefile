SRC=$(HOME)/src/halberds-and-helmets/graphics-src
JPGS=Ape.jpg Basilisk.jpg Bear.jpg Bee.jpg Beetle.jpg Boar.jpg \
Bugbear.jpg Cat.jpg Centaur.jpg Centipede.jpg Chimera.jpg Crab.jpg \
Creeper.jpg Crocodile.jpg Doppelganger.jpg Dragon.jpg Elephant.jpg \
Ettin.jpg Fish.jpg Gargoyle.jpg Ghoul.jpg Giant.jpg Gnoll.jpg \
Gnome.jpg Goblin.jpg Golem.jpg Gorgon.jpg Gryphon.jpg Harpy.jpg \
Hellhound.jpg Hobgoblin.jpg Horse.jpg Hydra.jpg Ifrit.jpg \
Invisible-Stalker.jpg Jinni.jpg Kappa.jpg Lizard-People.jpg Lizard.jpg \
Lycanthrope.jpg Manticore.jpg Marid.jpg Medusa.jpg Minotaur.jpg \
Mummy.jpg Myconid.jpg Naga.jpg Nixie.jpg Ogre.jpg Orc.jpg Pegasus.jpg \
Pixie.jpg Rakshasa.jpg Salamander.jpg Scorpion.jpg Sea-Serpent.jpg \
Shadow.jpg Shark.jpg Skeleton.jpg Snake.jpg Spectre.jpg Squid.jpg \
Swamp-Crane.jpg Tengu.jpg Toad.jpg Treant.jpg Troll.jpg Unicorn.jpg \
Vampire.jpg Weasel.jpg Wight.jpg Wolf.jpg Worm.jpg Wraith.jpg Zombie.jpg

all: $(JPGS)

%.jpg: $(SRC)/%.jpg
	convert -resize 600 "$<" "$@"

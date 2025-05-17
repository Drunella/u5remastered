#!/bin/bash

# needed:
# existing britannia.data, underworld.data
# python with pillow

python -m pip list | grep -i pillow >/dev/null
result=$?
if [ $result != 0 ] ; then
    echo "need python with module pillow"
    exit 1
fi

python -m pip list | grep -i pyyaml >/dev/null
result=$?
if [ $result != 0 ] ; then
    echo "need python with module pyyaml"
    exit 1
fi

mkdir -p build/png

# get tiles and colors
SDL_VIDEODRIVER=dummy c1541 disks/osi.d64 -read s0 ./build/png/s0.prg
dd status=none bs=1 if=build/png/s0.prg skip=2 of=build/png/s0.bin >/dev/null
rm build/png/s0.prg

SDL_VIDEODRIVER=dummy c1541 disks/osi.d64 -read s1 ./build/png/s1.prg
dd status=none bs=1 if=build/png/s1.prg skip=2 of=build/png/s1.bin >/dev/null
rm build/png/s1.prg

SDL_VIDEODRIVER=dummy c1541 disks/osi.d64 -read s2 ./build/png/s2.prg
dd status=none bs=1 if=build/png/s2.prg skip=2 of=build/png/s2.bin >/dev/null
rm build/png/s2.prg

SDL_VIDEODRIVER=dummy c1541 disks/osi.d64 -read s3 ./build/png/s3.prg
dd status=none bs=1 if=build/png/s3.prg skip=2 of=build/png/s3.bin >/dev/null
rm build/png/s3.prg

SDL_VIDEODRIVER=dummy c1541 disks/osi.d64 -read colors ./build/png/colors.prg
dd status=none bs=1 if=build/png/colors.prg skip=2 of=build/png/colors.bin
rm build/png/colors.prg

tools/tilesbuilder.py

# get fonts
SDL_VIDEODRIVER=dummy c1541 disks/osi.d64 -read htxt ./build/png/htxt.prg
dd status=none bs=1 if=build/png/htxt.prg skip=2 of=build/png/htxt.bin >/dev/null
tools/font2png.py -o ./build/png/font.png ./build/png/htxt.bin

# build world maps
maps=('britannia' 'underworld' 'towne' 'castle' 'keep' 'dwelling')
skips=(16 16 128 128 128 128)
folds=(0 0 1 1 1 1)

for i in "${!maps[@]}"; do
  echo "${maps[i]}:"
  dd status=none bs=256 if=build/source/${maps[i]}.data skip=${skips[i]} of=build/png/${maps[i]}.map
  if [ ${folds[i]} = 0 ]; then
      tools/mapbuilder.py build/png/${maps[i]}.map build/png/tiles.png build/${maps[i]}_map.png 16
      tools/gembuilder.py --transform src/png/transform.yaml --layout normal build/png/${maps[i]}.map src/png/tileset.yaml -o build/${maps[i]}_gem.png
  else
      tools/mapbuilder.py build/png/${maps[i]}.map build/png/tiles.png build/${maps[i]}_map.png 16 --fold4
      tools/gembuilder.py --transform src/png/transform.yaml --layout 2x2 build/png/${maps[i]}.map src/png/tileset.yaml -o build/${maps[i]}_gem.png
  fi
done

# build dungeon maps
dungeon=('deceit' 'despise' 'destard' 'wrong' 'covetous' 'shame' 'hythloth' 'doom')
skips=(160 162 164 166 168 170 172 174)

for i in "${!dungeon[@]}"; do
  echo "${dungeon[i]}:"
  dd status=none bs=256 if=build/source/dungeon.data skip=${skips[i]} count=2 of=build/png/${dungeon[i]}.map
  tools/dungeonbuilder.py build/png/${dungeon[i]}.map ./build/png/font.png ./src/png/dungeon.yaml build/${dungeon[i]}.png
done

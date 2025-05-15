#!/bin/bash

# needed:
# existing britannia.data, underworld.data
# python with pillow

python -m pip list | grep pillow >/dev/null
result=$?

if [ $result != 0 ] ; then
    echo "need python with module pillow "
    exit 1
fi

mkdir -p build/png

c1541 disks/osi.d64 -read s0 ./build/png/s0.prg
dd status=none bs=1 if=build/png/s0.prg skip=2 of=build/png/s0.bin >/dev/null
rm build/png/s0.prg

c1541 disks/osi.d64 -read s1 ./build/png/s1.prg
dd status=none bs=1 if=build/png/s1.prg skip=2 of=build/png/s1.bin >/dev/null
rm build/png/s1.prg

c1541 disks/osi.d64 -read s2 ./build/png/s2.prg
dd status=none bs=1 if=build/png/s2.prg skip=2 of=build/png/s2.bin >/dev/null
rm build/png/s2.prg

c1541 disks/osi.d64 -read s3 ./build/png/s3.prg
dd status=none bs=1 if=build/png/s3.prg skip=2 of=build/png/s3.bin >/dev/null
rm build/png/s3.prg

c1541 disks/osi.d64 -read colors ./build/png/colors.prg
dd status=none bs=1 if=build/png/colors.prg skip=2 of=build/png/colors.bin
rm build/png/colors.prg

tools/tilesbuilder.py

maps=('britannia' 'underworld' 'towne' 'castle' 'keep' 'dwelling')
skips=(16 16 128 128 128 128)
folds=(0 0 1 1 1 1)

for i in "${!maps[@]}"; do
  echo "${maps[i]}:"
  dd status=none bs=256 if=build/source/${maps[i]}.data skip=${skips[i]} of=build/png/${maps[i]}.map
  if [ ${folds[i]} = 0 ]; then
      tools/mapbuilder.py build/png/${maps[i]}.map build/png/tiles.png build/${maps[i]}.png 16
  else
      tools/mapbuilder.py build/png/${maps[i]}.map build/png/tiles.png build/${maps[i]}.png 16 --fold4
  fi
  
done

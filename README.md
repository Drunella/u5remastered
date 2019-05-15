# Ultima V Remastered
This is the source to build an EasyFlash version from original C64 Ultima V
disks.

## Features
* Import and export save games
* Ultima V music

## Required Tools
To build you need the following:
* cc65
* c1541 from VICE
* cartconv from VICE
* exomizer v2.0.11
* Python 3.5 or greater
* GNU Make

## Building
To build Ultima V Remastered create the folder `disks/` and place the
original disks in it. Name the disks `osi.d64`(Program disk), `dungeon.d64`, `britannia.d64`, 
`underworld.d64`, `towne.d64`, `dwelling.d64`, `castle.d64`, `keep.d64`.

Then build with

```
make
```

Find the crt image in the build sub-directory: `build/u5remastered.crt`.

# Bugs

I wanted to have a working version with music as fast as possible. I did not
test it thoroughly. Please report bugs or suggestions to .... I'm willing to
implement more features in te future.

# Ultima V Remastered
This is the source to build an EasyFlash and 1581 version from original C64 
Ultima V disks.

## Features
* Import and export save games
* Ultima V music

## Required Tools
To build you need the following:
* cc65
* c1541 from VICE
* cartconv from VICE
* exomizer v3.0.2
* Python 3.5 or greater
* GNU Make

## Building
To build Ultima V Remastered create the folder `disks/` and place the
original disks in it. Name the disks `osi.d64`(Program disk), `dungeon.d64`, 
`britannia.d64`, `underworld.d64`, `towne.d64`, `dwelling.d64`, `castle.d64`, 
`keep.d64`.

Then build with

```
make
```

Find the crt and d81 image in the build sub-directory:
`build/u5remastered.crt`.
`build/u5remastered.d81`.

# Bugs

I wanted to have a working version with music as fast as possible. I did not
test it thoroughly. I'm planning to implement more features sometimes in the future.

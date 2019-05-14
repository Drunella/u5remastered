#!/bin/bash

function findaddress() {
    # $1: symbol
    # $2: filename
    egrep -i "$1 = .[0-9a-f]+" $2 | sed "s/$1 = .\([0-9a-f]\+\)/\1/"
}

# $1 destdirectory
# $2 inc file
# $3 inc file
mkdir -p $1

# note_data_insert_low ###
#address=$( findaddress "note_data_insert_low" $2 )
#target=$( findaddress "note_data" $2 )
#value=$(( target % target  ))
destname="$1/music.1.patch"
echo "binhex" > $destname
echo "# note_data_insert_low" >> $destname
echo "filename = music_rom.bin" >> $destname
echo "address = 0x02f8" >> $destname
echo "original = 69b8" >> $destname
echo "new      = 6926" >> $destname

# note_data_insert_high ###
#address=$( findaddress "note_data_insert_low" $2 )
#target=$( findaddress "note_data" $2 )
#value=$(( target % target  ))
destname="$1/music.2.patch"
echo "binhex" > $destname
echo "# note_data_insert_high" >> $destname
echo "filename = music_rom.bin" >> $destname
echo "address = 0x02fe" >> $destname
echo "original = 6979" >> $destname
echo "new      = 6986" >> $destname

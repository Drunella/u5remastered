#!/bin/bash

function findaddress() {
    # $1: symbol
    # $2: filename
    egrep -i "$1 = .[0-9a-f]+" $2 | sed "s/$1 = .\([0-9a-f]\+\)/\1/"
}

# $1 destdirectory
# $2 inc file
mkdir -p $1

target=$( findaddress "_disk_check_type" $2 )
destname="$1/transfer.5.patch"
echo "jumptable" > $destname
echo "# 0x80e7" >> $destname
echo "# _disk_check_type" >> $destname
echo "filename = \"0x41/transfer\"" >> $destname
echo "address = 0x00e7" >> $destname
echo "oldtarget = 0x6c2a" >> $destname
echo "newtarget = 0x$target" >> $destname

target=$( findaddress "_disk_load_block" $2 )
destname="$1/transfer.6.patch"
echo "jumptable" > $destname
echo "# 0x81fa" >> $destname
echo "# _disk_check_type" >> $destname
echo "filename = \"0x41/transfer\"" >> $destname
echo "address = 0x01fa" >> $destname
echo "oldtarget = 0x6c00" >> $destname
echo "newtarget = 0x$target" >> $destname

target=$( findaddress "_disk_load_block" $2 )
destname="$1/transfer.7.patch"
echo "jumptable" > $destname
echo "# 0x8203" >> $destname
echo "# _disk_check_type" >> $destname
echo "filename = \"0x41/transfer\"" >> $destname
echo "address = 0x0203" >> $destname
echo "oldtarget = 0x6c00" >> $destname
echo "newtarget = 0x$target" >> $destname


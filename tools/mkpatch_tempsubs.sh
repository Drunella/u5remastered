#!/bin/bash

function findaddress() {
    # $1: symbol
    # $2: filename
    egrep -i "$1 = .[0-9a-f]+" $2 | sed "s/$1 = .\([0-9a-f]\+\)/\1/"
}

# $1 destdirectory
# $2 inc file
mkdir -p $1

# 0x6c00 IO_read_block_entry
target=$( findaddress "IO_read_block_entry" $2 )
destname="$1/temp.subs.1.patch"
echo "jumptable" > $destname
echo "# 0x6c00" >> $destname
echo "# IO_read_block_entry" >> $destname
echo "address = 0x0002" >> $destname
echo "newtarget = 0x$target" >> $destname

# 0x6c09 IO_request_disk_char_entry
target=$( findaddress "IO_request_disk_id_entry" $2 )
destname="$1/temp.subs.2.patch"
echo "jumptable" > $destname
echo "# 0x6c09" >> $destname
echo "# IO_request_disk_id_entry" >> $destname
echo "address = 0x000b" >> $destname
echo "newtarget = 0x$target" >> $destname

# 0x6c24 IO_load_file_entry
target=$( findaddress "IO_load_file_entry" $2 )
destname="$1/temp.subs.3.patch"
echo "jumptable" > $destname
echo "# 0x6c24" >> $destname
echo "# IO_load_file_entry" >> $destname
echo "address = 0x0026" >> $destname
echo "newtarget = 0x$target" >> $destname

# 0x6c2a IO_request_disk_id_entry
target=$( findaddress "IO_request_disk_char_entry" $2 )
destname="$1/temp.subs.4.patch"
echo "jumptable" > $destname
echo "# 0x6c2a" >> $destname
echo "# IO_request_disk_char_entry" >> $destname
echo "address = 0x002c" >> $destname
echo "newtarget = 0x$target" >> $destname

# 0x6c2d IO_save_file_entry
target=$( findaddress "IO_save_file_entry" $2 )
destname="$1/temp.subs.5.patch"
echo "jumptable" > $destname
echo "# 0x6c2d" >> $destname
echo "# IO_save_file_entry" >> $destname
echo "address = 0x002f" >> $destname
echo "newtarget = 0x$target" >> $destname

# 0x6c30 IO_read_block_alt_entry
target=$( findaddress "IO_read_block_alt_entry" $2 )
destname="$1/temp.subs.6.patch"
echo "jumptable" > $destname
echo "# 0x6c30" >> $destname
echo "# IO_read_block_alt_entry" >> $destname
echo "address = 0x0032" >> $destname
echo "newtarget = 0x$target" >> $destname

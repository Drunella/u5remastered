#!/usr/bin/env python3

import os
import sys
import glob
import subprocess
import argparse
import hashlib
import traceback
import pprint


def load_map(filename):
    m = []
    with open(filename) as f:
        for l in f:
            if l[0] == '#' or l[0] == ';':
                continue
            if len(l.strip()) == 0:
                continue
            m.append(l.split())
    return m


def load_file(filename):
    with open(filename, "rb") as f:
        return bytearray(f.read())


def remove_prg(data):
    low = data[0]
    high = data[1]
    del data[0:2]
    return high*256 + low


def bin_initialize():
    global binary_file
    binary_file = bytearray([0xff] * 64 * 16384) # all 64 banks


def bin_placedata(data, bank, address):
    global binary_file
    if address < 0x8000 or address >= 0xC000:
        raise Exception("address outside allowed range: 0x{0:04x}".format(address))
    address -= 0x8000
    address += bank * 16384
    binary_file[address:address+len(data)] = data


def bin_write(filename):
    global binary_file
    with open(filename, "wb") as f:
        f.write(binary_file)


# format map file
# bank f filename [addr] [value]
# bank a address addr value
#
# f: writes filename at prg address (if *.prg) or given address
# a: writes addreass at given address in lo/hi format
#
# addr: destination address in bin file (prg is ignored) (required for non prg)
#       all start addresses must be in range of 0x8000 to 0xbfff (lo-hi area)
#       or must be changed with addr
# example
# 0 f eapi-am29f040.prg addr 0xb800
# 0 f directory.data.prg addr 0xa000
# 0 a 0x6ca8 addr 0x9601
#

def main(argv):
    global binary_file
    p = argparse.ArgumentParser()
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-s", dest="source", action="store", required=True, help="source directory.")
    p.add_argument("-b", dest="build", action="store", required=True, help="build directory.")
    args = p.parse_args()
    source_path = args.source
    temp_path = os.path.join(args.build, "temp")
    os.makedirs(temp_path, exist_ok=True)
    files_path = os.path.join(args.build, "files")
    os.makedirs(files_path, exist_ok=True)
    obj_path = os.path.join(args.build, "obj")
    os.makedirs(obj_path, exist_ok=True)

    map = load_map(os.path.join(obj_path, "crt.map"))
    bin_initialize()

    # add prg files
    for e in map:
        #pprint.pprint(e)
        type = e[1]
        bank = int(e[0], 0)
        file = e[2]
        if len(e) > 3:
            flag = e[3]
            value = int(e[4], 0)
            if flag != "addr":
                raise Exception("unknown flag " + flag)
        else:
            flag = ""
            value = 0

        if type == "f":
            # load file
            filename = os.path.join(obj_path, file)
            data = load_file(filename)
            if file.endswith(".prg"):
                address = remove_prg(data)
                if flag == "addr":
                    address = value
            else:
                if flag != "addr":
                    raise Exception("must give address for non prg file")
                address = value
            bin_placedata(data, bank, address)
        elif type == "a":
            address = value
            value = int(file, 0)
            if flag != "addr":
                raise Exception("must give address for non prg file")
            data = bytearray(2);
            data[0] = value % 256
            data[1] = value // 256
            bin_placedata(data, bank, address)
        else:
            raise Exception("unknown type " + type)

    final_path = os.path.join(obj_path, "u5remastered.bin")
    bin_write(final_path)
    
    return 0

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

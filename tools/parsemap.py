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
    with open(filename, "rt") as f:
        lines = f.read().split()
    return lines


def find_entry_in_map(map, entry):
    if not entry in map:
        return None
    index = map.index(entry) + 1
    return map[index]


def main(argv):
    global binary_file
    p = argparse.ArgumentParser()
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-s", dest="source", action="store", required=True, help="source map file.")
    #p.add_argument("-b", dest="build", action="store", required=True, help="destination build directory.")
    p.add_argument("-e", dest="symbols", action="append", required=True, help="symbol.")
    p.add_argument("-d", dest="destfilename", action="store", required=True, help="destination file name.")
    args = p.parse_args()
    source_filename = args.source
    destination_filename = args.destfilename
    #temp_path = os.path.join(args.build, "temp")
    #os.makedirs(temp_path, exist_ok=True)
    #files_path = os.path.join(args.build, "files")
    #os.makedirs(files_path, exist_ok=True)
    #obj_path = os.path.join(args.build, "obj")
    #os.makedirs(obj_path, exist_ok=True)

    map = load_map(source_filename)
    result = dict()

    for s in args.symbols:
        address = find_entry_in_map(map, s)
        if address is None:
            raise Exception("symbol " + s + " not found in " + source_filename)
        result[s] = int(address, 16)

    with open(destination_filename, "wt") as f:
        for e in result:
            f.write("{0} = ${1:04x}\n".format(e, result[e]))

    return 0

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

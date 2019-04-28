#!/usr/bin/env python3

import os
import sys
import glob
import subprocess
import argparse
import hashlib
import traceback
import pprint


def load_file(filename):
    global binary_file
    with open(filename, "rb") as f:
        binary_file = bytearray(f.read())


def save_file(filename):
    global binary_file
    with open(filename, "wb") as f:
        f.write(binary_file)


def load_patch(filename):
    # format of u5 patch files
    # [patchtype]
    # variable = value
    # ...
    # ; or #
    p = dict()
    with open(filename, "rt") as f:
        type = f.readline();
        p["type"] = type.strip()
        for line in f:
            line.strip()
            if len(line) == 0:
                continue
            if line[0] == '#' or line[0] == ';':
                continue
            content = line.split()
            p[content[0]] = content[2]
    return p
    

def apply_patch_jumptable(data): 
    # jumptable patch
    # address = [the local address in the file of the jmp opcode] ; don't forget the load address
    # newtarget = [the hex/dec value of the new target]
    global binary_file
    a = int(data["address"], 0)
    n = int(data["newtarget"], 0)
    binary_file[a + 1] = n % 256
    binary_file[a + 2] = n // 256


def main(argv):
    global binary_file
    p = argparse.ArgumentParser()
    p.add_argument("patches", nargs='+', help="patch to apply.")
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-s", dest="sourcefile", action="store", required=True, help="source file to patch.")
    p.add_argument("-d", dest="destfilename", action="store", required=False, help="destination file name.")
    args = p.parse_args()
    source_filename = args.sourcefile
    destination_filename = source_filename
    if hasattr(args, "destfilename"):
        destination_filename = args.destfilename

    load_file(source_filename)
    counter = 0
    for p in args.patches:
        patch = load_patch(p)
        # apply patch
        if patch["type"] == "jumptable":
            apply_patch_jumptable(patch)
        else:
            raise Exception("unknown patch " +  patch["type"])
        counter += 1
        if args.verbose:
            print("patch " + p + " applied.")
        
    save_file(args.destfilename)
    if args.verbose:
        print("file " + args.destfilename + " " + str(counter) + " patches applied")
    return 0

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

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
            p[content[0]] = content[2].strip('"')
    return p


def compare_bytes(a, b):
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
        else:
            pass
    return True


def address_get(data):
    low = data[0]
    high = data[1]
    return high*256 + low


def load_files_directory(filename):
    directory = dict()
    with open(filename) as f:
        result = [line.split() for line in f]
        for l in result:
          directory[l[0]] = l[1]
    return directory
 

def apply_patch_jumptable(data): 
    # jumptable patch
    # jumptable
    # address = [the local address in the file of the jmp opcode] ; don't forget the load address
    # newtarget = [the hex/dec value of the new target]
    global binary_file
    a = int(data["address"], 0) + 2
    n = int(data["newtarget"], 0)
    o = int(data["oldtarget"], 0)
    old = binary_file[a+1] + binary_file[a+2]*256
    if old != o:
        raise Exception("patch {0} old target (0x{1:04x}) does not match".format(data["destfile"], old))
    binary_file[a + 1] = n % 256
    binary_file[a + 2] = n // 256


def apply_patch_prghex(data): 
    # patch a prg file with hexadecimal, respects the load address
    # prghex
    # address = [the local address in the filee] ; load address is automaticall applied
    # original = [the hex data of the old value]
    # new = [the hex data of te new value]
    global binary_file
    a = int(data["address"], 0) + 2
    o = bytes.fromhex(data["original"])
    n = bytes.fromhex(data["new"])
    
    if len(o) != len(n):
        raise Exception("patch " + data["destfile"] + " failed")
    check = binary_file[a:a+len(o)]
    if compare_bytes(o, check) == False:
        raise Exception("patch " + data["destfile"] + " failed: original content not found");
    binary_file[a:a+len(o)] = n


def apply_patch_prgbin(data): 
    # patch file with content of other prgfile. The data of the patch file must be inside the 
    # original file
    # prgbin
    # prg = [the filename of the prg file]
    global binary_file
    address = address_get(binary_file)
    patch_filename = data["prg"]
    with open(patch_filename, "rb") as f:
        patch_data = bytearray(f.read())
    patch_address = address_get(patch_data)
    patch_position = patch_address - address + 2
    patch_length = len(patch_data) - 2
    length = len(binary_file)
    if patch_position < 0:
        raise Exception("prg patch of " + data["destfile"] + " does not start within file")
    if patch_length <= 0:
        raise Exception("prg patch of " + data["destfile"] + " is too short")
    if patch_position+len(patch_data) > length:
        # resize
        t = bytearray(patch_position+len(patch_data))
        t[0:length] = binary_file[0:length]
        binary_file = t

    binary_file[patch_position:patch_position+patch_length] = patch_data[2:2+patch_length]


def main(argv):
    global binary_file
    p = argparse.ArgumentParser()
    p.add_argument("patches", nargs='+', help="patch to apply.")
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-q", dest="dryrun", action="store_true", required=False, help="don't patch, just dryrun.")
    p.add_argument("-a", dest="autopatch", action="store_true", required=False, help="auto patch files from patches.")
    p.add_argument("-f", dest="filedir", action="store", required=True, help="directory to search files.")
    args = p.parse_args()
    files_path = args.filedir

    fileslist = load_files_directory(os.path.join(files_path, "files.list"))
    counter = 0
    for p in args.patches:
        try:
            patch = load_patch(p)

            # find file
            filename = fileslist[patch["filename"]] + ".prg"
            patch["destfile"] = filename
            load_file(os.path.join(files_path, filename))
        
            # apply patch
            if patch["type"] == "jumptable":
                apply_patch_jumptable(patch)
            elif patch["type"] == "prghex":
                apply_patch_prghex(patch)
            elif patch["type"] == "prgbin":
                apply_patch_prgbin(patch)
            else:
                raise Exception("unknown patch " +  patch["type"])
            counter += 1
            if args.verbose:
                print("patch " + p + " applied to " + filename + ".")
            if not args.dryrun:
                save_file(os.path.join(files_path, filename))
        except Exception as e:
            print(e)
            #traceback.print_exc()
    return 0

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

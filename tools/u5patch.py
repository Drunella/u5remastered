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
    a = int(data["address"], 0)
    n = int(data["newtarget"], 0)
    binary_file[a + 1] = n % 256
    binary_file[a + 2] = n // 256


def apply_patch_hex(data): 
    # patch file with hexadecimal
    # hexdata
    # address = [the local address in the file of the jmp opcode] ; don't forget the load address
    # original = [the hex data of the old value]
    # new = [te hex data of te new value]
    global binary_file
    a = int(data["address"], 0)
    o = bytes.fromhex(data["original"])
    n = bytes.fromhex(data["new"])
    
    if len(o) != len(n):
        raise Exception("patch " + data["filename"] + " failed")
    check = binary_file[a:a+len(o)]
    if compare_bytes(o, check) == False:
        raise Exception("patch " + data["filename"] + " failed: original content not found");
    binary_file[a:a+len(o)] = n


def apply_patch_prg(data): 
    # patch file with content of other prgfile. The data of the patch file must be inside the 
    # original file
    # prg
    # filename = [the filename of the prg file]
    global binary_file
    base = address_get(binary_file)
    fn = data["prg"]
    with open(fn, "rb") as f:
        pdata = bytearray(f.read())
    dest = address_get(pdata)
    pos = dest - base + 2
    length = len(pdata) - 2
    if pos < 0:
        raise Exception("prg patch " + fn + " is not within file")
    if length <= 0:
        raise Exception("prg patch " + fn + " is too short")
    binary_file[pos:pos+length] = pdata[2:2+length]


def main(argv):
    global binary_file
    p = argparse.ArgumentParser()
    p.add_argument("patches", nargs='+', help="patch to apply.")
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
#    p.add_argument("-s", dest="sourcefile", action="store", required=False, help="source file to patch.")
#    p.add_argument("-d", dest="destfilename", action="store", required=False, help="destination file name.")
    p.add_argument("-a", dest="autopatch", action="store_true", required=False, help="auto patch files from patches.")
    p.add_argument("-f", dest="filedir", action="store", required=True, help="directory to search files.")
    args = p.parse_args()
    files_path = args.filedir
#    source_filename = args.sourcefile
#    destination_filename = source_filename
#    if hasattr(args, "destfilename") and args.destfilename != None:
#        destination_filename = args.destfilename

    fileslist = load_files_directory(os.path.join(files_path, "files.list"))
#    load_file(source_filename)
    counter = 0
    for p in args.patches:
        try:
            patch = load_patch(p)

            # find file
            filename = fileslist[patch["filename"]] + ".prg"
            load_file(os.path.join(files_path, filename))
        
            # apply patch
            if patch["type"] == "jumptable":
                apply_patch_jumptable(patch)
            elif patch["type"] == "hexdata":
                apply_patch_hex(patch)
            elif patch["type"] == "prg":
                apply_patch_prg(patch)
            else:
                raise Exception("unknown patch " +  patch["type"])
            counter += 1
            if args.verbose:
                print("patch " + p + " applied.")       
            save_file(os.path.join(files_path, filename))
        except Exception as e:
            print(e)
            #traceback.print_exc()
#    if args.verbose:
#        print("file " + args.destfilename + " " + str(counter) + " patches applied")
    return 0

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

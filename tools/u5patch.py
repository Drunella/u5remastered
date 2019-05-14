#!/usr/bin/env python3

import os
import sys
import glob
import subprocess
import argparse
import hashlib
import traceback
import pprint


class AlreadyAppliedException(Exception):
    pass
    
    
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
    # type = [patchtype]
    # variable = value
    # ...
    # ; or #
    p = dict()
    with open(filename, "rt") as f:
        #type = f.readline();
        #p["type"] = type.strip()
        for line in f:
            line.strip()
            if len(line) == 0:
                continue
            if line[0] == '#' or line[0] == ';':
                continue            
            content = line.split()
            if len(content) < 3:
                continue
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
 

def load_map_file(filename):
    off_switch = "Exports list by value:"
    on_switch = "Exports list by name:"
    parser = False
    symbs = dict()
    with open(filename, "rt") as f:
        for l in f:
            line = l.strip()
            if line == on_switch:
                parser = True
                continue
            if line == off_switch:
                parser = False
                continue
            if parser == False:
                continue
            if len(line) == 0:
                continue
            # parse
            s = line.split()
            if len(s) < 3:
                continue
            k = s[0]
            symbs[k] = int(s[1], 16)
            if len(s) > 3:            
                k = s[3]
                symbs[k] = int(s[4], 16)
    return symbs


def resolve_symbol(value):
    global symbols
    #print("value " + value)
    if value[0:6] == "symbol":
        # remove 'symbol(' and ')' and recurse
        s = value[7:-1].strip('"')
        if s not in symbols:
            raise Exception("patch failed: symbol " + s + " not found")
        return symbols[s]
    elif value[0:4] == "high":
        # remove 'high(' and ')'
        s = value[5:-1].strip('"')
        v = resolve_symbol(s)
        return v // 256
    elif value[0:3] == "low":
        # remove 'low(' and ')'
        s = value[4:-1].strip('"')
        v = resolve_symbol(s)
        return v % 256
    else:
        return int(value, 0)


def apply_patch_symaddr(data): 
    # replace address with symbol patch
    # symaddr
    # filename = "..."
    # offset = 2 [offset 2 for prgs, offset 0 for bin, or other value to align with jump table]
    # address = [the local address in the file of the jmp opcode]
    # oldtarget = [the hex/dec value of the new target]
    # symbol = [the symbol name]
    global binary_file
    global symbols
    offset = int(data["offset"], 0)
    address = resolve_symbol(data["address"]) + offset
    oldtarget = resolve_symbol(data["oldtarget"])
    newtarget = resolve_symbol(data["newtarget"])
    old = binary_file[address] + binary_file[address + 1] * 256
    # check if already applied
    if old == newtarget:
        raise AlreadyAppliedException("patch " + data["patchfile"] + " already applied")    
    if old != oldtarget:
        raise Exception("patch {0} old target (0x{1:04x}) does not match".format(data["patchfile"], old))
    binary_file[address] = newtarget % 256
    binary_file[address + 1] = newtarget // 256


def apply_patch_symvalue(data): 
    # replace single byte value
    # symvalue
    # filename = "..."
    # offset = 2 [offset 2 for prgs, offset 0 for bin, or other value to align with target]
    # address = [the local address in the file of the jmp opcode]
    # oldvalue = [the hex/dec value of the old target]
    # newvalue = [the hex/dec value of the new target]
    # symbol = [the symbol name]
    global binary_file
    offset = int(data["offset"], 0)
    address = resolve_symbol(data["address"]) + offset
    oldvalue = resolve_symbol(data["oldvalue"])
    newvalue = resolve_symbol(data["newvalue"])
    old = binary_file[address]
    # check if already applied
    if old == newvalue:
        raise AlreadyAppliedException("patch " + data["patchfile"] + " already applied")    
    if old != oldvalue:
        raise Exception("patch {0} old value (0x{1:02x}) does not match".format(data["patchfile"], old))
    binary_file[address] = newvalue


#def apply_patch_jumptable(data): 
#    # jumptable patch
#    # jumptable
#    # offset
#    # address = [the local address in the file of the jmp opcode] ; don't forget the load address
#    # newtarget = [the hex/dec value of the new target]
#    global binary_file
#    a = int(data["address"], 0) + 2
#    n = int(data["newtarget"], 0)
#    o = int(data["oldtarget"], 0)
#    old = binary_file[a+1] + binary_file[a+2]*256
#    # check for new ###
#    if old == n:
#        raise AlreadyAppliedException("patch " + data["patchfile"] + " already applied")    
#    if old != o:
#        raise Exception("patch {0} old target (0x{1:04x}) does not match".format(data["patchfile"], old))
#    binary_file[a + 1] = n % 256
#    binary_file[a + 2] = n // 256


#def apply_patch_prghex(data): 
#    # patch a prg file with hexadecimal, respects the load address
#    # prghex
#    # address = [the local address in the filee] ; load address is automaticall applied
#    # original = [the hex data of the old value]
#    # new = [the hex data of te new value]
#    global binary_file
#    a = int(data["address"], 0) + 2
#    o = bytes.fromhex(data["original"])
#    n = bytes.fromhex(data["new"])
#    
#    if len(o) != len(n):
#        raise Exception("patch " + data["patchfile"] + " failed")
#    check = binary_file[a:a+len(o)]
#    if compare_bytes(n, check) == True:
#        raise AlreadyAppliedException("patch " + data["patchfile"] + " already applied")
#    if compare_bytes(o, check) == False:
#        raise Exception("patch " + data["patchfile"] + " failed: original content not found");
#    binary_file[a:a+len(o)] = n


def apply_patch_hex(data): 
    # patch a file with hexadecimal, no load address
    # type = hex
    # offset = [offset in file, for prg]
    # address = [the local address in the filee] ; load address is automaticall applied
    # original = [the hex data of the old value]
    # new = [the hex data of te new value]
    global binary_file
    offset = int(data["offset"], 0)
    a = int(data["address"], 0) + offset
    o = bytes.fromhex(data["original"])
    n = bytes.fromhex(data["new"])
    
    if len(o) != len(n):
        raise Exception("patch " + data["patchfile"] + " failed")
    check = binary_file[a:a+len(o)]
    if compare_bytes(n, check) == True:
        raise AlreadyAppliedException("patch " + data["patchfile"] + " already applied")
    if compare_bytes(o, check) == False:
        raise Exception("patch " + data["patchfile"] + " failed: original content not found");
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
        raise Exception("prg patch of " + data["patchfile"] + " does not start within file")
    if patch_length <= 0:
        raise Exception("prg patch of " + data["patchfile"] + " is too short")
    # check
    o = binary_file[patch_position:patch_position+patch_length]
    n = patch_data[2:2+patch_length]
    if compare_bytes(o, n) == True:
        raise AlreadyAppliedException("patch " + data["patchfile"] + " already applied")   
    # patch
    if patch_position+len(patch_data) > length:
        # resize
        t = bytearray(patch_position+len(patch_data))
        t[0:length] = binary_file[0:length]
        binary_file = t
    binary_file[patch_position:patch_position+patch_length] = patch_data[2:2+patch_length]



def main(argv):
    global binary_file
    global symbols
    p = argparse.ArgumentParser()
    p.add_argument("patches", nargs='+', help="patch to apply.")
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-m", dest="mapfiles", action="append", required=False, help="map file with exported symbols.")
    p.add_argument("-q", dest="dryrun", action="store_true", required=False, help="don't patch, just dryrun.")
    p.add_argument("-l", dest="fileslist", action="store", required=True, help="files with the list of u5 files.")
    p.add_argument("-f", dest="filedir", action="store", required=True, help="directory to search files.")
    args = p.parse_args()

    files_path = args.filedir
    fileslist = load_files_directory(args.fileslist)
    
    symbols = dict()
    if args.mapfiles is not None:
        for s in args.mapfiles:
            n = load_map_file(s)
            symbols = {**symbols, **n}

    counter = 0
    for p in args.patches:
        try:
            patch = load_patch(p)

            # added parameters: patch filename
            patch["patchfile"] = p

            # find file and add filename of file to patch
            if patch["filename"] in fileslist:
                patch["origfile"] = patch["filename"]
                filename = fileslist[patch["filename"]] + ".prg"
            elif os.path.isfile(os.path.join(files_path,  patch["filename"])):
                patch["origfile"] = patch["filename"]
                filename = patch["filename"]
            else:
                raise Exception("cannot find file " + patch["filename"])

            load_file(os.path.join(files_path, filename))
        
            # apply patch
#            if patch["type"] == "jumptable":
#                apply_patch_jumptable(patch)
            if patch["type"] == "hex":
                apply_patch_hex(patch)
#            elif patch["type"] == "binhex":
#                apply_patch_binhex(patch)
            elif patch["type"] == "prgbin":
                apply_patch_prgbin(patch)
            elif patch["type"] == "symaddr":
                apply_patch_symaddr(patch)
            elif patch["type"] == "symvalue":
                apply_patch_symvalue(patch)
            else:
                raise Exception("unknown patch " +  patch["type"])
            counter += 1
            if args.verbose:
                print("patch " + p + " applied to " + patch["origfile"] + ".")
            if not args.dryrun:
                save_file(os.path.join(files_path, filename))
        except AlreadyAppliedException as aae:
            if args.verbose:
                print(aae)
        except Exception as e:
            print(e)
            traceback.print_exc()
            return 1
    return 0

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

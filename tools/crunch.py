#!/usr/bin/env python3

# ----------------------------------------------------------------------------
# Copyright 2019 Drunella
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------

import os
import sys
import glob
import subprocess
import argparse
import traceback
import re
import pprint


def file_readaddress(filename):
    with open(filename, "rb") as f:
        low = f.read(1)[0]
        high = f.read(1)[0]
        return high*256 + low


#def file_prependaddress(filename, address):
#    low = address % 256
#    high = address // 256
#    with open(filename, "rb") as f:
#        data = f.read()    
#    with open(filename, "wb") as f:
#        f.seek(0)
#        b = bytearray(1)
#        b[0] = low
#        f.write(b)
#        b[0] = high
#        f.write(b)
#        f.write(data)


def file_crunch(infilename, outfilename, crunchtype, startaddress=0):
    if crunchtype == "level":
        # for easyflash
        arguments = ["exomizer", "level", \
                                 "-m", "256", \
                                 "-M", "256", \
                                 "-o", outfilename, \
                                 infilename \
                     ]
    elif crunchtype == "mem":
        # for d81
        arguments = ["exomizer", "mem", \
                                 "-l", "0x{0:04x}".format(startaddress), \
                                 "-m", "256", \
                                 "-M", "256", \
                                 "-o", outfilename, \
                                 infilename \
                     ]
    else:
        raise Exception("unknown type " + crunchtype)
    result = subprocess.run(arguments, stdout=subprocess.PIPE, universal_newlines=True)
    if result.returncode != 0:
        raise Exception("error crunching file " + infilename)
    m = re.search("Crunched data reduced ([0-9-]*) bytes .([0-9-]*).", result.stdout)
    if not m:
        print("warning: no compression info on " + outfilename)
        return
    size = int(m.group(1), 0)
    ratio = int(m.group(2), 0)
    if ratio < 0:
        print("warning: negative ratio (" + str(ratio) + "%) for " + outfilename)


def main(argv):
    global source_path
    p = argparse.ArgumentParser()
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-b", dest="build", action="store", required=True, help="build directory.")
    p.add_argument("-t", dest="type", action="store", required=True, help="exomizer type.")
    args = p.parse_args()
#    temp_path = os.path.join(args.build, "temp")
#    os.makedirs(temp_path, exist_ok=True)
    files_path = args.build #os.path.join(args.build, "files")
    os.makedirs(files_path, exist_ok=True)

    if args.type == "mem":
        crunchtype = "mem"
    elif args.type == "level":
        crunchtype = "level"
    else:
       raise Exception("unknown type " + args.type)

    amount = 0
    for filename in os.listdir(files_path):
        if not filename.endswith(".prg"):
            continue
        amount += 1
    
    count = 0
    for f in os.listdir(files_path):
        if not f.endswith(".prg"):
            continue
        count += 1
        if args.verbose:
            print("processing file {0:d} of {1:d}     \r".format(count, amount), end='\r')
        basename = f[0:-4]
        infilename = os.path.join(files_path, f)
        outfilename = os.path.join(files_path, basename + ".crunch")
        address = file_readaddress(infilename)
        file_crunch(infilename, outfilename, crunchtype, address)
        #file_prependaddress(outfilename, address)
    if args.verbose:
        print("")
    # make a file to let make know we are ready
    ready_path = os.path.join(files_path, "crunched.done")
    open(ready_path, 'a').close()


if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

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
import subprocess
import argparse
import hashlib
import traceback
#import pprint
import re


def readdisks_info(filename):
    disks = []
    with open(filename) as f:
        result = [line.split() for line in f]
    return result


def readdisk_getdiskfile(directory, diskname):
    directory = os.path.dirname(os.path.join(directory, diskname))
    #print("directory: " + directory)
    #print("filepattern: " + filepattern)
    for f in os.listdir(directory):
        filename = os.path.basename(f)
        if not filename.startswith(diskname):
            continue
        if filename.endswith(".d64"):
            return f
    raise Exception("no disk file found for " + filepattern)


def readdisk_directory(filename):
    global my_env
    result = subprocess.run(["c1541", filename, "-list"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True, env=my_env)
    lines = result.stdout.splitlines()
    pattern = re.compile(r'^\s*(\d+)\s+"([^"]+)"')
    retval = []
    for l in lines:
        match = pattern.match(l)
        if match:
            num, text = match.groups()
            if (int(num) == 0):
                continue
            retval.append(text)
    return retval

def readdisk_checktype(filename, typeid, typename):
    global my_env
    result = subprocess.run(["c1541", filename, "-block", "18", "0", "162"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True, env=my_env)
    content = result.stdout.splitlines()
    value = content[1].split()[2]
    if int(value, 16) != typeid:
        raise Exception("disk type mismatch")
    return typeid
    
    
def readdisk_extractfile(diskfile, filename, destfile):
    global my_env
    arguments = ["c1541", diskfile, "-read", filename, destfile]
    result = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True, env=my_env)
    if result.returncode != 0:
        raise Exception("error extracting file " + filename + " from disk " + diskfile)


def readdisk_extractblock(diskfile, destfile, track, sector):
    global my_env
    arguments = ["c1541", diskfile, "-bread", destfile, str(track), str(sector)]
    result = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True, env=my_env)
    if result.returncode != 0:
        raise Exception("error extracting block " + track + ", " + sector + " from disk " + diskfile)


def file_md5(filename):
    m = hashlib.md5()
    with open(filename, "rb") as f:
        data = open(filename, "rb").read()
        m.update(f.read())
    return m.hexdigest()


def main(argv):
    global my_env
    
    p = argparse.ArgumentParser()
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-b", dest="build", action="store", required=True, help="build directory.")
    p.add_argument("-s", dest="source", action="store", required=True, help="source directory.")
    p.add_argument("-d", dest="disks", action="store", required=True, help="disks file.")
    args = p.parse_args()
    source_path = args.source
    #temp_path = os.path.join(args.build, "temp")
    #os.makedirs(temp_path, exist_ok=True)
    files_path = args.build #os.path.join(args.build, "files")
    os.makedirs(files_path, exist_ok=True)

    my_env = os.environ
    my_env["SDL_VIDEODRIVER"] = "dummy"

    files_directory = dict()
    disks = readdisks_info(args.disks)
    try:
        for d in disks:
            diskid = int(d[1], 0)
            diskname = d[0]
            if (args.verbose):
                print("extracting files from " + diskname + " ...")
            result = readdisk_getdiskfile(args.source, diskname)
            diskfile = os.path.join(source_path, result)
            #pprint.pprint(diskfile)
            typeid = readdisk_checktype(diskfile, diskid, d[0])
            directory = readdisk_directory(diskfile)
            for f in directory:
                if f == "dconfig":
                    continue
                entry = "0x{0:x}/{1}".format(diskid, f)
                tempfile = os.path.join(files_path, "uncompressed.tmp")
                readdisk_extractfile(diskfile, f, tempfile)
                hex = file_md5(tempfile)
                processfile = os.path.join(files_path, hex + ".prg")
                if os.path.isfile(processfile):
                    # file already processed
                    files_directory[entry] = hex
                else:
                    # create file
                    os.rename(tempfile, processfile)
                    files_directory[entry] = hex
            if len(d) == 2:
                continue

            if (args.verbose):
                print("extracting blocks from " + diskname + " ...")
            blockfile = os.path.join(files_path, "block.tmp")
            datafile = os.path.join(files_path, diskname + ".data")
            with open(datafile, "wb") as df:
                # d[2]:starttrack d[3]:startsector d[4]:endtrack d[5]:endsector
                for track in range(int(d[2]), int(d[4])+1):
                    for sector in range(int(d[3]), int(d[5])+1):
                        readdisk_extractblock(diskfile, blockfile, track, sector)
                        with open(blockfile, "rb") as sf:
                            df.write(sf.read())

        # boot sector
        if (args.verbose):
            print("extracting boot sector ...")
        blockfile = os.path.join(files_path, "block.tmp")
        datafile = os.path.join(files_path, "boot.data")
        result = readdisk_getdiskfile(args.source, "osi")
        diskfile = os.path.join(source_path, result)
        with open(datafile, "wb") as df:
            readdisk_extractblock(diskfile, blockfile, 1, 0)
            with open(blockfile, "rb") as sf:
                df.write(sf.read())

            
    except Exception as e:
        print(e)
        print("error processing disk " + diskname)
        raise e
        return 2

    files_directory_name = os.path.join(files_path, "files.list")
    with open(files_directory_name, "wt") as f:
        for k in sorted(files_directory):
            f.write("{0:s} {1:s}\n".format(k, files_directory[k]))

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

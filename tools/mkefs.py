#!/usr/bin/env python3

import os
import sys
import glob
import subprocess
import argparse
import hashlib
import traceback
import pprint


def load_files_directory(filename):
    directory = dict()
    with open(filename) as f:
        result = [line.split() for line in f]
        for l in result:
          data = l.split()
          directory[data[0]] = data[1]
    return directory


def readdisk_directory(filename):
    result = subprocess.run(["c1541", filename, "-list"], stdout=subprocess.PIPE, universal_newlines=True)
    lines = result.stdout.splitlines()[1:-1]
    retval = []
    for l in lines:
        content = l.split()[1][1:-1]
        retval.append(content)
    return retval


def readdisk_checktype(filename, typeid, typename):
    result = subprocess.run(["c1541", filename, "-block", "18", "0", "162"], stdout=subprocess.PIPE, universal_newlines=True)
    content = result.stdout.splitlines()
    value = content[1].split()[2]
    if int(value, 16) != typeid:
        raise Exception("disk type mismatch")
    return typeid
    
    
def readdisk_extractfile(diskfile, filename, destfile):
    arguments = ["c1541", diskfile, "-read", filename, destfile]
    result = subprocess.run(arguments, stdout=subprocess.PIPE, universal_newlines=True)
    if result.returncode != 0:
        raise Exception("error extracting file " + filename + " from disk " + diskname)


def readdisk_extractblock(diskfile, destfile, track, sector):
    arguments = ["c1541", diskfile, "-bread", destfile, str(track), str(sector)]
    result = subprocess.run(arguments, stdout=subprocess.PIPE, universal_newlines=True)
    if result.returncode != 0:
        raise Exception("error extracting block " + track + ", " + sector + " from disk " + diskname)


def file_md5(filename):
    m = hashlib.md5()
    with open(filename, "rb") as f:
        data = open(filename, "rb").read()
        m.update(f.read())
    return m.hexdigest()


def main(argv):
    global source_path
    p = argparse.ArgumentParser()
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    p.add_argument("-b", dest="build", action="store", required=True, help="build directory.")
    p.add_argument("-f", dest="output", action="store", required=True, help="output file.")
    args = p.parse_args()
    temp_path = os.path.join(args.build, "temp")
    os.makedirs(temp_path, exist_ok=True)
    files_path = os.path.join(args.build, "files")
    os.makedirs(files_path, exist_ok=True)

    f = os.path.join(files_path, "files.list")
    load_files_directory()
    
    
    
    return 0
    files_directory = dict()
    disks = readdisks_info(args.source + "/disks/disks.txt")
    for d in disks:
        try:
            diskid = int(d[1], 0)
            diskname = d[0]
            if (args.verbose):
                print("extracting from " + diskname + " ...")
            diskfile = glob.glob(os.path.join(args.source, "disks", diskname + ".*"))
            typeid = readdisk_checktype(diskfile[0], diskid, d[0])
            directory = readdisk_directory(diskfile[0])
            for f in directory:
                entry = "0x{0:x}/{1}".format(diskid, f)
                tempfile = os.path.join(temp_path, "uncompressed")
                readdisk_extractfile(diskfile[0], f, tempfile)
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
            blockfile = os.path.join(temp_path, "block")
            datafile = os.path.join(files_path, diskname + ".data")
            with open(datafile, "wb") as df:
                # d[2]:starttrack d[3]:startsector d[4]:endtrack d[5]:endsector
                for track in range(int(d[2]), int(d[4])+1):
                    for sector in range(int(d[3]), int(d[5])+1):
                        readdisk_extractblock(diskfile[0], blockfile, track, sector)
                        with open(blockfile, "rb") as sf:
                            df.write(sf.read())
            
        except Exception as e:
            print(e)
            print("error processing disk " + diskname)
            raise e
            return 2

    files_directory_name = os.path.join(files_path, "files.list")
    files_directory.sort()
    with open(files_directory_name, "wt") as f:
        for k in files_directory:
            f.write("{0:s} {1:s}\n".format(k, files_directory[k]))

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

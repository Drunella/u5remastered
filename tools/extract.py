#!/usr/bin/env python3

import os
import sys
import glob
import subprocess
import argparse
import hashlib



def readdisks_info(filename):
    disks = []
    with open(filename) as f:
        result = [line.split() for line in f]
    return result


def readdisk_directory(filename):
    result = subprocess.run(["c1541", filename, "-list"], stdout=subprocess.PIPE, universal_newlines=True)
    print(result.stdout)


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
    p.add_argument("-s", dest="source", action="store", required=True, help="source directory.")
    args = p.parse_args()
    source_path = args.source
    temp_path = os.path.join(args.build, "temp")
    os.makedirs(temp_path, exist_ok=True)
    files_path = os.path.join(args.build, "files")
    os.makedirs(files_path, exist_ok=True)

    files_directory = dict()
    disks = readdisks_info(args.source + "/disks/disks.txt")
    for d in disks:
        try:
            diskid = int(d[1], 0)
            diskname = d[0]
            print("extracting from " + diskname + " ...")
            diskfile = glob.glob(os.path.join(args.source, "disks", diskname + ".*"))
            typeid = readdisk_checktype(diskfile[0], diskid, d[0])
            directory = readdisk_directory(diskfile[0])
            for f in directory:
                entry = "0x{0:x}/{1}".format(diskid, f)
                tempfile = os.path.join(temp_path, "uncompressed")
                readdisk_extractfile(diskfile[0], f, tempfile)
                hex = file_md5(tempfile)
                processfile = os.path.join(files_path, hex)
                if os.path.isfile(processfile):
                    # file already processed
                    files_directory[entry] = hex
                else:
                    # create file
                    os.rename(tempfile, processfile)
                    files_directory[entry] = hex
        except Exception as e:
            print(e)
            print("error processing disk " + diskname)
            return 1

    files_directory_name = os.path.join(files_path, "files.list")
    with open(files_directory_name, "wt") as f:
        for k in files_directory:
            f.write("{0:s} {1:s}\n".format(k, files_directory[k]))

        
if __name__ == '__main__':
    sys.exit(main(sys.argv))

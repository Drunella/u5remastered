#!/usr/bin/env python3

import os
import sys
import subprocess
import argparse
import hashlib
import traceback
#import pprint


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
    p.add_argument("-s", dest="source", action="store", required=True, help="source directory.")
    args = p.parse_args()
    source_path = args.source
    temp_path = os.path.join(args.build, "temp")
    os.makedirs(temp_path, exist_ok=True)
    files_path = os.path.join(args.build, "files")
    os.makedirs(files_path, exist_ok=True)

    files_directory = dict()
    disks = readdisks_info(os.path.join(args.source, "../src/disks.cfg"))
    for d in disks:
        try:
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
                entry = "0x{0:x}/{1}".format(diskid, f)
                tempfile = os.path.join(temp_path, "uncompressed")
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
            blockfile = os.path.join(temp_path, "block")
            datafile = os.path.join(files_path, diskname + ".data")
            with open(datafile, "wb") as df:
                # d[2]:starttrack d[3]:startsector d[4]:endtrack d[5]:endsector
                for track in range(int(d[2]), int(d[4])+1):
                    for sector in range(int(d[3]), int(d[5])+1):
                        readdisk_extractblock(diskfile, blockfile, track, sector)
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

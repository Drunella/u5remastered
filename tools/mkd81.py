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
import hashlib
import traceback
import pprint




def create_disk(filename):
    #if os.path.isfile(filename):
    #    raise Exception("disk image " + filename  + "already exists")
    arguments = ["c1541",
                "-format",
                "ultima v,65",
                "d81",
                filename]
    result = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True)
    print (result.stdout)
    return


def copyfile_disk(diskname, sourcefilename, destfilename, verbose=False):
    if not os.path.isfile(diskname):
        raise Exception("disk image " + diskname  + "not found")
    destfilename = destfilename.lower()
    arguments = ["c1541",
                 diskname,
                 "-write",
                 sourcefilename,
                 destfilename]
    result = subprocess.run(arguments, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
    if result.returncode != 0:
        print(result.stderr)
        raise Exception("copying of " + destfilename + " failed")
    print("copied " + destfilename + " on " + diskname)
    return


def readdisks_info(filename):
    disks = dict()
    with open(filename) as f:
        result = [line.split() for line in f]
    for d in result:
        disks[d[0]] = d
    return disks


def load_files_directory(filename):
    directory = dict()
    with open(filename) as f:
        result = [line.split() for line in f]
        for l in result:
          directory[l[0]] = l[1]
    return directory


def readexcludes_info(filename):
    disks = []
    with open(filename) as f:
        result = [line.split() for line in f]
    return result


def join_ws(iterator, seperator):
    it = map(str, iterator)
    seperator = str(seperator)
    string = next(it, '')
    for s in it:
        string += seperator + s
    return string


def load_file(filename):
    with open(filename, "rb") as f:
        return bytearray(f.read())


def save_diskimage(filename):
    global disk_image
    with open(filename, "wb") as f:
        f.write(disk_image)


def load_include(filename):
    content = dict()
    with open(filename, "rt") as f:
        for l in f:
            l = l.strip()
            if len(l) == 0:
                continue
            if l[0] == '#' or l[0] == ';':
                continue
            tokens = l.split()
            if len(tokens) < 3:
                continue
            if tokens[1] != '=':
                continue
            if tokens[2][0] == '$':
                value = int(tokens[2][1:], 16)
            else:
                value = int(tokens[2], 0)
            content[tokens[0]] = value
    return content


def get_sector(track, sector):
    global disk_image
    if track < 1 or track > 80:
        raise Exception("invalid track " + track)
    if sector < 0 or sector > 39:
        raise Exception("invalid sector " + sector)
    offset = ((track - 1) * 40 + sector) * 256
    return disk_image[offset:offset+256]

    
def set_sector(track, sector, data):
    global disk_image
    if track < 1 or track > 80:
        raise Exception("invalid track " + track)
    if sector < 0 or sector > 39:
        raise Exception("invalid sector " + sector)
    if len(data) != 256:
        raise Exception("data must be 256 bytes long (is " + str(len(data)) + ")")
    offset = ((track - 1) * 40 + sector) * 256
    disk_image[offset:offset+256] = data


def bam_marksectorused(realtrack, sector):
    if realtrack < 1 or realtrack > 80:
        raise Exception("invalid track " + track)
    if sector < 0 or sector > 39:
        raise Exception("invalid sector " + sector)
    if realtrack > 40:
        data = get_sector(40, 2)
        track = realtrack - 40
    else:
        data = get_sector(40, 1)
        track = realtrack
    offset = (track - 1) * 6 + 16
    track_data = data[offset:offset+6]
    # sector 0: bit 0 of byte 1; sector 1: bit 1 of byte 1; ... sector 9: bit 0 of byte 2
    if (track_data[1 + sector // 8] & (1 << (sector % 8))) == 0:
        # bit is 0, sector used
        raise Exception("track {0}, sector {1} already in use".format(track, sector))
    track_data[1 + sector // 8] &= ~(1 << (sector % 8))
    track_data[0] = track_data[0] - 1
    #print("t:{0} {1} {2:08b} {3:08b} {4:08b} {5:08b} {6:08b}".format(track, track_data[0], track_data[1], track_data[2], track_data[3], track_data[4], track_data[5]))
    data[offset:offset+6] = track_data
    if realtrack > 40:
        set_sector(40, 2, data)
    else:
        set_sector(40, 1, data)


def disk_fillwithblocks(diskname, filesdir):
    global disk_map
    global includes
    
    if diskname not in disk_map:
        raise Exception("disk " + diskname + " not found")
    info = disk_map[diskname]
    data_file = os.path.join(filesdir, diskname + ".data")
    data = load_file(data_file)
    
    offset = includes[diskname + "_track_correction"]
    if offset > 127:
        offset = offset - 256
    starttrack = includes[diskname + "_track_original"] + offset
    startsector = includes[diskname + "_sector_correction"]
    height = includes[diskname + "_track_height"]
    for t in range(0, height):
        for s in range(0, 16):
            dest_track = t + starttrack
            dest_sector = s + startsector
            offset = (t * 16 + s) * 256
            set_sector(dest_track, dest_sector, data[offset:offset+256])
            bam_marksectorused(dest_track, dest_sector)


def disk_finddirentry(data, filename):
    offset = (39 * 40 + 3) * 256   # track 40 sector 3
    last = (39 * 40 + 40) * 256    # track 40 sector 15 + 1 byte
    size = 32  # size od one entry

    while offset < last:
        entry = data[offset:offset+size]
        if entry[2] == 0:
            offset += size
            continue
        name = entry[5:21].replace(b"\xa0", b"\x20").strip().decode('ascii').lower()
        if (name == filename):
            return entry
        offset += size
    return None


def disk_findemptyentry(data):
    offset = (39 * 40 + 3) * 256   # track 40 sector 3
    last = (39 * 40 + 40) * 256    # track 40 sector 15 + 1 byte
    size = 32  # size of one entry
    position = 0

    while offset < last:
        entry = data[offset:offset+size]
        if entry[2] == 0:
            # (sector, direntry in sector, offset in disk)
            return (position // 8 + 3, position % 8, offset)
        offset += size
        position += 1
    return None


def disk_makeentry(filename, original):
    # reset entry
    data = bytearray(32)
    data[0x00] = 0  # track / sector, must be set later eventually
    data[0x01] = 0
    data[0x02] = 0x82  # prg file
    # 3 and 4 will not be changed, track and sector of first data
    data[0x03] = original[0x03]
    data[0x04] = original[0x04]
    data[0x05:0x05 + 16] = bytearray([0xa0] * 16)  # a0 padded name
    data[0x05:0x05 + len(filename)] = filename.upper().encode('ascii')
    data[0x17:0x17 + 7] = bytearray([0x00] * 7)  # unused
    # 0x1e and 0x1f will not be changed, number of used sectors
    data[0x1e] = original[0x1e]
    data[0x1f] = original[0x1f]
    return data

    
def disk_makeadditionaldirentry(originalfile, newfile, verbose=False):
    global disk_image
    
    # find original entry
    original = disk_finddirentry(disk_image, originalfile)
    if original is None:
        raise Exception("could not find file " + originalfile + " on disk")
    newentry = disk_makeentry(newfile, original)
    position = disk_findemptyentry(disk_image)
    if position is None:
        raise Exception("could not find empty directory entry on disk")
    disk_image[position[2]:position[2]+32] = newentry

    # first entry in sector
    if position[1] == 0:
        # set track=0 and sector=255, and track sector od previous direntry sector
        offset = (39 * 40 + position[0]) * 256
        disk_image[offset] = 0
        disk_image[offset + 1] = 0xff    
        disk_image[offset - 256] = 40
        disk_image[offset - 256 + 1] = position[0]
        bam_marksectorused(40, position[0])

    if verbose:
        print("additional directory entry: " + newfile + " on disk")
    return



def main(argv):
    global disk_image
    global disk_map
    global includes
    global output_file
    p = argparse.ArgumentParser()
    p.add_argument("-v", dest="verbose", action="store_true", help="Verbose output.")
    #p.add_argument("-q", dest="dryrun", action="store_true", required=False, default=False, help="do dry run, don't change files.")
    p.add_argument("-d", dest="diskinfo", action="store", required=True, help="disk info file.")
    p.add_argument("-f", dest="filespath", action="store", required=True, help="path of files.")
    p.add_argument("-i", dest="includefiles", action="append", required=False, help="include files with values.")
    p.add_argument("-o", dest="outputfile", action="store", required=True, help="d81 output file.")
    p.add_argument("-x", dest="excludes", action="store", required=False, default=None, help="files to exclude.")

    args = p.parse_args()
    output_file = args.outputfile
    diskinfo_file = args.diskinfo
    files_path = args.filespath
    files_list_name = os.path.join(files_path, "files.list")

    # load diskinfo
    disk_map = readdisks_info(diskinfo_file)
    files_list = load_files_directory(files_list_name)

    # excludes
    excludes_list = []
    if args.excludes is not None:
        excludes = readexcludes_info(args.excludes)
        for ex in excludes:
            d = disk_map[ex[0]]
            n = chr(int(d[1], 0)) + join_ws(ex[1:], " ")
            excludes_list.append(n.lower())
    #pprint.pprint(excludes_list)
       
    # create disk
    create_disk(output_file)
    disk_image = load_file(output_file)

    # add includes
    includes = dict()
    for files in args.includefiles:
        content = load_include(files)
        includes = {**content, **includes}
    
    # use blocked sectors and boot sectors
    bam_marksectorused(1,0)  # boot sector
    disk_fillwithblocks("dungeon", files_path)
    disk_fillwithblocks("britannia", files_path)
    disk_fillwithblocks("underworld", files_path)
    disk_fillwithblocks("towne", files_path)
    disk_fillwithblocks("dwelling", files_path)
    disk_fillwithblocks("castle", files_path)
    disk_fillwithblocks("keep", files_path)

    # write disk
    save_diskimage(output_file)    

    # copy startup file (as first file) and other non crunched files
    sourcefilename = files_list["0x41/meow"] + ".prg"
    copyfile_disk(output_file, os.path.join(files_path, sourcefilename), "ultima v", verbose=args.verbose)

    sourcefilename = "loader.prg"
    copyfile_disk(output_file, os.path.join(files_path, sourcefilename), "xyzzy", verbose=args.verbose)

    sourcefilename = files_list["0x41/m"] + ".prg"
    copyfile_disk(output_file, os.path.join(files_path, sourcefilename), "m", verbose=args.verbose)
    
    sourcefilename = files_list["0x41/subs.128"] + ".prg"
    copyfile_disk(output_file, os.path.join(files_path, sourcefilename), "subs.128", verbose=args.verbose)

    sourcefilename = files_list["0x41/temp.subs"] + ".prg"
    copyfile_disk(output_file, os.path.join(files_path, sourcefilename), "temp.subs", verbose=args.verbose)
    
    sourcefilename = "exodecrunch.prg"
    copyfile_disk(output_file, os.path.join(files_path, sourcefilename), "exo", verbose=args.verbose)

    # transfer files to disk and create duplicates
    uncrunched = ["0x41/create1.txt", "0x41/m9", "0x41/blank.prty", "0x48/blank.party", 
                 "0x44/story1.txt", "0x44/story2.txt", "0x44/story3.txt", "0x44/story4.txt"]
    already_copied = dict()
    additional_entry = dict()
    for e in files_list:
        # build name
        key = files_list[e]
        destparts = e.split('/')
        destfilename = chr(int(destparts[0], 0)) + destparts[1]
        destfilename = destfilename.lower()
        # exclude list
        if destfilename in excludes_list:
            continue
        if e in uncrunched:
            sourcefilename = os.path.join(files_path, key + ".prg")
        else:
            sourcefilename = os.path.join(files_path, key + ".crunch")
        if key in already_copied:
            # append entry
            additional_entry[destfilename] = already_copied[key]
            #disk_makeadditionaldirentry(output_file, already_copied[key], destfilename, verbose=args.verbose)
        else:
            # copy file
            copyfile_disk(output_file, sourcefilename, destfilename, verbose=args.verbose)
            already_copied[key] = destfilename

    # make additional entries
    disk_image = load_file(output_file)
    for e in additional_entry:
        disk_makeadditionaldirentry(additional_entry[e], e, verbose=args.verbose)
        
    # create boot sector
    # ###

    # write disk
    save_diskimage(output_file)    

        
if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        os.remove(output_file)
        sys.exit(1)

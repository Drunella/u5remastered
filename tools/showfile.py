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
import pprint


def file_readdata(filename):
    address = -1
    size = -1
    with open(filename, "rb") as f:
        data = f.read()
    address = data[0] + data[1]*256
    size = len(data)
    return (address, size)


def load_files_directory(filename):
    directory = dict()
    with open(filename) as f:
        result = [line.split() for line in f]
        for l in result:
          #pprint.pprint(l)
          directory[l[0]] = l[1]
    return directory


def main(argv):
    global source_path
    p = argparse.ArgumentParser()
    p.add_argument("filesdir", nargs=1, help="files directory.")
    args = p.parse_args()
    files_path = args.filesdir[0]

    files = load_files_directory(os.path.join(files_path, "files.list"))

    for f in files:
        filename = os.path.join(files_path, files[f] + ".prg")
        info = file_readdata(filename)
        print("{0:20s}: addr=0x{1:04x} size=0x{2:x}".format(f, info[0], info[1]))


if __name__ == '__main__':
    try:
        retval = main(sys.argv)
        sys.exit(retval)
    except Exception as e:
        print(e)
        traceback.print_exc()
        sys.exit(1)

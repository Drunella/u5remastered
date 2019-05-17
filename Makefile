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

# Settings
TARGET=c64
LD65=cl65
CA65=ca65
CC65=cc65
DA65=da65
#LD65=ld65
LD65FLAGS=-t $(TARGET)
CA65FLAGS=-t $(TARGET) -I . --debug-info
CC65FLAGS=-t $(TARGET) -O
#LD65FLAGS=
export LD65_LIB=/opt/cc65/share/cc65/lib

.SUFFIXES: .prg .s .c
.PHONY: clean subdirs all easyflash mrproper

LOADER_FILES=build/ef/menu.o build/ef/loader.o build/ef/io-data.o build/ef/io-rw.o build/ef/io-code.o build/exo/exodecrunch.o build/ef/menu_savegame.o build/ef/menu_util.o build/ef/menu_backup.o build/ef/music-base.o build/ef/music-disassemble.o

MUSIC_FILES=build/ef/music-base.o build/ef/music-disassemble.o


# all
all: easyflash

# easyflash
easyflash: subdirs build/ef/directory.data.prg build/ef/files.data.prg build/u5remastered.crt

# d81


# assemble
build/%.o: src/%.s
	$(CA65) $(CA65FLAGS) -o $@ $<

# compile
build/%.s: src/%.c
	$(CC65) $(CC65FLAGS) -o $@ $<

# assemble2
build/%.o: build/%.s
	$(CA65) $(CA65FLAGS) -o $@ $<


# exomizer for ef
build/ef/exodecrunch.prg: build/exo/exodecrunch.o build/ef/io-rw.o build/ef/io-data.o
	$(LD65) $(LD65FLAGS) -o $@ -C src/ef/exodecrunch.cfg $^

# easyflash init.prg
build/ef/init.prg: build/ef/init.o
	$(LD65) $(LD65FLAGS) -o $@ -C src/ef/init.cfg $^

# easyflash loader.prg
build/ef/loader.prg: $(LOADER_FILES)
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/loader.map -o $@ -C src/ef/loader.cfg c64.lib $(LOADER_FILES)

# music
build/ef/music.prg build/ef.f/music_rom.bin build/ef/music.map: $(MUSIC_FILES)
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/music.map -o build/ef/music.prg -C src/ef/music.cfg $(MUSIC_FILES)

# music map
#build/ef/music.inc: build/ef/music.map
#	tools/parsemap.py -v -s ./build/ef/music.map -d build/ef/music.inc -e _play_song

# io-replacement
build/ef/io-replacement.prg build/ef/io-replacement.map: build/ef/io-code.o build/ef/io-data.o build/ef/io-rw.o build/exo/exodecrunch.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/io-replacement.map -o build/ef/io-replacement.prg -C ./src/ef/io-replacement.cfg $^

# io-addendum
build/ef/io-addendum.prg: build/ef/io-code.o build/ef/io-data.o build/ef/io-rw.o build/exo/exodecrunch.o
	$(LD65) $(LD65FLAGS) -o $@ -C ./src/ef/io-addendum.cfg $^

# io map
#build/ef/io-replacement.inc: build/ef/io-replacement.map
#	tools/parsemap.py -v -s ./build/ef/io-replacement.map -d build/ef/io-replacement.inc -e _IO_load_file_entry -e _IO_read_block_entry -e _IO_request_disk_id_entry -e _IO_request_disk_char_entry -e _IO_save_file_entry -e _IO_read_block_alt_entry  -e get_crunched_byte -e decrunch_table

# transfer-load
build/ef/transfer-load.prg build/ef/transfer-load.map: build/ef/transfer-load.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/transfer-load.map -o $@ -C ./src/ef/transfer-load.cfg $^

# transfer-load map
#build/ef/transfer-load.inc: build/ef/transfer-load.map
#	tools/parsemap.py -v -s ./build/ef/transfer-load.map -d build/ef/transfer-load.inc -e _disk_load_block -e _disk_check_type


# disassemble m.prg 
build/ef/music-disassemble.o: build/source/m.prg src/ef/music-disassemble.info ./src/ef/music-export.i
	$(DA65) -i ./src/ef/music-disassemble.info -o ./build/temp/music-disassemble.s
	cat ./src/ef/music-export.i >> ./build/temp/music-disassemble.s
	$(CA65) $(CA65FLAGS) -o ./build/ef/music-disassemble.o ./build/temp/music-disassemble.s

# files with additional items
build/ef.f/files.list: build/source/files.list build/ef/io-addendum.prg build/ef/music.prg
	cp ./build/source/* ./build/ef.f/
	cp build/ef/io-addendum.prg build/ef.f/io.add.prg
	cp build/ef/music.prg build/ef.f/music.prg
	echo "0x41/io.add io.add" >> build/ef.f/files.list
	echo "0x41/music music" >> build/ef.f/files.list
	
# patch
build/ef.f/patched.done: build/ef.f/files.list build/ef/io-replacement.map build/ef/transfer-load.map build/ef/music.map build/ef/transfer-load.prg build/ef.f/music_rom.bin
	tools/u5patch.py -v -l ./build/ef.f/files.list -f ./build/ef.f -m build/ef/io-replacement.map -m build/ef/transfer-load.map -m build/ef/music.map ./patches/ef/*.patch
	cp build/ef.f/music_rom.bin build/ef/music_rom.aprg
	touch ./build/ef.f/patched.done
	 
# crunch
build/ef.f/crunched.done: build/ef.f/patched.done
	tools/crunch.py -v -b ./build/ef.f
	touch build/ef.f/crunched.done

# build efs
build/ef/directory.data.prg build/ef/files.data.prg: build/ef.f/crunched.done
	tools/mkefs.py -v -o ./src/disks.cfg  -x ./src/ef/exclude.cfg -f ./build/ef.f -e crunch -d ./build/ef

# build blocks
build/ef/crt.blocks.map: build/ef.f/files.list
	tools/mkblocks.py -v -o ./src/disks.cfg -b ./src/ef/block.map -f ./build/ef.f -m ./build/ef/crt.blocks.map -d ./build/ef

# cartridge binary
build/ef/u5remastered.bin: build/ef/directory.data.prg build/ef/files.data.prg build/ef/exodecrunch.prg build/ef/init.prg build/ef/loader.prg src/ef/eapi-am29f040.prg build/ef/crt.blocks.map build/ef/music_rom.aprg
	cp ./src/ef/crt.map ./build/ef/crt.map
	cp ./src/ef/eapi-am29f040.prg ./build/ef/eapi-am29f040.prg
	tools/mkbin.py -v -b ./build/ef -m ./build/ef/crt.map -m ./build/ef/crt.blocks.map -o ./build/ef/u5remastered.bin

# cartdridge crt
build/u5remastered.crt: build/ef/u5remastered.bin
	cartconv -b -t easy -o build/u5remastered.crt -i build/ef/u5remastered.bin -n "Ultima 5 Remastered" -p


# d81
# io-replacement d81
build/d81/io-replacement.prg build/d81/io-replacement.map: build/d81/io-code.o build/exo/exodecrunch.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/d81/io-replacement.map -o build/d81/io-replacement.prg -C ./src/d81/io-replacement.cfg $^


subdirs:
	@mkdir -p ./build/temp 
	@mkdir -p ./build/exo
	@mkdir -p ./build/d81.f
	@mkdir -p ./build/d81
	@mkdir -p ./build/source
	@mkdir -p ./build/ef.f
	@mkdir -p ./build/ef

clean:
	rm -rf build/ef
	rm -rf build/d81
	rm -rf build/ef.f 
	rm -rf build/d81.f
	rm -rf build/temp
	rm -rf build/exo
	rm -f build/u5remastered.crt
	rm -f build/u5remastered.d81

mrproper:
	rm -rf build


# source files
build/source/files.list:
	tools/extract.py -v -d ./src/disks.cfg -s ./disks -b ./build/source

# get m.prg	
build/source/m.prg:
	c1541 ./disks/osi.d64 -read m ./build/source/m.prg

# get xyzzy.prg	
build/source/xyzzy.prg:
	c1541 ./disks/osi.d64 -read xyzzy ./build/source/xyzzy.prg

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
.PHONY: clean subdirs all easyflash mrproper pngs

# karma patches
KARMA_PATCHES=build/common/karma_britannia.map build/common/karma_britannia.prg build/common/karma_underworld.map build/common/karma_underworld.prg build/common/karma_twn.map build/common/karma_twn.prg
KARMA_MAPS=-m build/common/karma_britannia.map -m build/common/karma_underworld.map -m build/common/karma_twn.map

# all
all: easyflash d81 backbit

# easyflash
easyflash: subdirs build/ef/directory.data.prg build/ef/files.data.prg build/u5remastered.crt

# d81
d81: subdirs build/u5remastered.d81

# backbit
backbit: subdirs build/u5remastered-BackBit.d81

# assemble
build/%.o: src/%.s
	$(CA65) $(CA65FLAGS) -o $@ $<

# compile
build/%.s: src/%.c
	$(CC65) $(CC65FLAGS) -o $@ $<

# assemble2
build/%.o: build/%.s
	$(CA65) $(CA65FLAGS) -o $@ $<


# ------------------------------------------------------------------------
# easyflash

EF_MENU_FILES=build/ef/menu.o build/ef/startup.o build/ef/io-code.o build/ef/menu_savegame.o build/ef/menu_util.o build/ef/menu_backup.o build/ef/music-base.o build/ef/music-disassemble.o build/ef/editor.o build/common/utils.o build/ef/music-playsound.o
EF_MUSIC_FILES=build/ef/music-base.o build/ef/music-disassemble.o build/ef/music-playsound.o

# easyflash config.prg
build/ef/efs-config.prg: build/ef/efs-config.o src/ef/efs-config.cfg
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/efs-config.map -Ln ./build/ef/efs-config.lst -o $@ -C src/ef/efs-config.cfg c64.lib build/ef/efs-config.o

# easyflash init.prg -> directly to cart
build/ef/init.prg: build/ef/init.o
	$(LD65) $(LD65FLAGS) -o $@ -C src/ef/init.cfg $^

# easyflash loader.bin -> directly to cart
build/ef/loader.prg: build/ef/loader.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/loader.map -o $@ -Ln ./build/ef/loader.lst -C src/ef/loader.cfg c64.lib build/ef/loader.o

# easyflash menu.prg -> to efs
build/ef/menu.prg: $(EF_MENU_FILES)
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/menu.map -o $@ -C src/ef/menu.cfg c64.lib $(EF_MENU_FILES)

# music -> to efs, directly to cart
build/ef/music.prg build/ef.f/music_rom.bin build/ef/music.map: $(EF_MUSIC_FILES)
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/music.map -o build/ef/music.prg -C src/ef/music.cfg $(EF_MUSIC_FILES)

# editor.o
build/ef/editor.o:
	$(CC65) $(CC65FLAGS) -DEASYFLASH -o build/ef/editor.s src/common/editor.c
	$(CA65) $(CA65FLAGS) -o $@ build/ef/editor.s

# io-replacement -> replacement code
build/ef/io-replacement.prg build/ef/io-replacement.map: build/ef/io-code.o build/ef/subs128-disassemble.o build/ef/music-disassemble.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/io-replacement.map -o build/ef/io-replacement.prg -C ./src/ef/io-replacement.cfg $^

# transfer-load
build/ef/transfer-load.prg build/ef/transfer-load.map: build/ef/transfer-load.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/ef/transfer-load.map -o $@ -C ./src/ef/transfer-load.cfg $^

# disassemble m.prg 
build/ef/music-disassemble.o: build/source/m.prg src/ef/music-disassemble.info ./src/ef/music-export.i
	$(DA65) -i ./src/ef/music-disassemble.info -o ./build/temp/music-disassemble.s
	cat ./src/ef/music-export.i >> ./build/temp/music-disassemble.s
	$(CA65) $(CA65FLAGS) -o ./build/ef/music-disassemble.o ./build/temp/music-disassemble.s

# playsound
build/ef/music-playsound.o: build/ef/io-replacement.map
	tools/getsymbol.py -m build/ef/io-replacement.map -s playsound > build/temp/music-playsound.s
	cat ./src/ef/music-playsound-template.s >> build/temp/music-playsound.s
	$(CA65) $(CA65FLAGS) -o ./build/ef/music-playsound.o ./build/temp/music-playsound.s
	
# disassemble subs.128.prg
build/ef/subs128-disassemble.o: build/source/subs.128.prg src/ef/subs128-disassemble.info
	$(DA65) -i ./src/ef/subs128-disassemble.info -o ./build/temp/subs128-disassemble.s
	$(CA65) $(CA65FLAGS) -o ./build/ef/subs128-disassemble.o ./build/temp/subs128-disassemble.s

# files with additional items
build/ef.f/files.list: build/source/files.list build/ef/music.prg build/ef/menu.prg
	cp ./build/source/* ./build/ef.f/
	cp build/ef/menu.prg build/ef.f/menu.prg
	cp build/ef/music.prg build/ef.f/music.prg
	echo "0x41/menu menu" >> build/ef.f/files.list
	echo "0x41/music music" >> build/ef.f/files.list
	
# patch
build/ef.f/patched.done: build/ef.f/files.list build/ef/io-replacement.map build/ef/transfer-load.map build/ef/music.map build/ef/transfer-load.prg build/ef.f/music_rom.bin $(KARMA_PATCHES)
	tools/u5patch.py -v -l ./build/ef.f/files.list -f ./build/ef.f -m build/ef/io-replacement.map -m build/ef/transfer-load.map -m build/ef/music.map $(KARMA_MAPS) ./patches/ef/*.patch ./patches/*.patch
	cp build/ef.f/music_rom.bin build/ef/music_rom.aprg
	touch ./build/ef.f/patched.done

# crunch
#build/ef.f/crunched.done: build/ef.f/patched.done
#	tools/crunch.py -v -t level -b ./build/ef.f
#	touch build/ef.f/crunched.done
	 
# build efs
build/ef/directory.data.prg build/ef/files.data.prg: build/ef.f/patched.done
	tools/mkefs.py -v -o ./src/disks.cfg  -x ./src/ef/exclude.cfg -f ./build/ef.f -e prg -d ./build/ef

# build blocks
build/ef/crt.blocks.map: build/ef.f/files.list
	tools/mkblocks.py -v -o ./src/disks.cfg -b ./src/ef/block.map -f ./build/ef.f -m ./build/ef/crt.blocks.map -d ./build/ef

# cartridge binary
build/ef/u5remastered.bin: build/ef/directory.data.prg build/ef/files.data.prg build/ef/init.prg build/ef/loader.prg src/ef/eapi-am29f040.prg build/ef/crt.blocks.map build/ef/music_rom.aprg build/ef/efs-config.prg src/ef/lib-efs.prg
	cp ./src/ef/crt.map ./build/ef/crt.map
	cp ./src/ef/eapi-am29f040.prg ./build/ef/eapi-am29f040.prg
	cp ./src/ef/lib-efs.prg ./build/ef/lib-efs.prg
	tools/mkbin.py -v -b ./build/ef -m ./build/ef/crt.map -m ./build/ef/crt.blocks.map -o ./build/ef/u5remastered.bin

# cartdridge crt
build/u5remastered.crt: build/ef/u5remastered.bin
	cartconv -b -t easy -o build/u5remastered.crt -i build/ef/u5remastered.bin -n "Ultima 5 Remastered" -p


# ------------------------------------------------------------------------
# d81

# io-replacement d81
build/d81/io-replacement.prg build/d81/io-replacement.map: build/d81/io-code.o build/common/exodecrunch.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/d81/io-replacement.map -o build/d81/io-replacement.prg -C ./src/d81/io-replacement.cfg $^

# loader
build/d81/loader.prg: build/d81/loader.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/d81/loader.map -o build/d81/loader.prg -C ./src/d81/loader.cfg $^

build/d81.f/loader.prg: build/d81/loader.prg
	cp ./build/d81/loader.prg build/d81.f/loader.prg

# exomizer for d81
build/d81/exodecrunch.prg: build/common/exodecrunch.o build/d81/io-code.o
	$(LD65) $(LD65FLAGS) -o $@ -C ./src/d81/exodecrunch.cfg $^

build/d81.f/exodecrunch.prg: build/d81/exodecrunch.prg
	cp ./build/d81/exodecrunch.prg ./build/d81.f/exodecrunch.prg

# transfer-load
build/d81/transfer-load.prg build/d81/transfer-load.map: build/d81/transfer-load.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/d81/transfer-load.map -o $@ -C ./src/d81/transfer-load.cfg $^

# editor.prg
build/d81.f/editor.prg: build/d81/save_util.o
	$(CC65) $(CC65FLAGS) -DD81 -o build/d81/editor.s src/common/editor.c
	$(CA65) $(CA65FLAGS) -o build/d81/editor.o build/d81/editor.s
	$(LD65) $(LD65FLAGS) -vm -m ./build/d81/editor.map -o $@ -C src/d81/editor.cfg c64.lib build/d81/editor.o build/d81/save_util.o

# editor128.prg
build/d81.f/editor128.prg:
	$(CC65) -t c128 -DD81 -o build/d81/save_util128.s src/d81/save_util.c
	$(CC65) -t c128 -DD81 -o build/d81/editor128.s src/common/editor.c
	$(CA65) -t c128 -I . --debug-info -o build/d81/save_util128.o build/d81/save_util128.s
	$(CA65) -t c128 -o build/d81/editor128.o build/d81/editor128.s
	$(LD65) -t c128 -vm -m ./build/d81/editor128.map -o $@ -C src/d81/editor128.cfg c128.lib build/d81/editor128.o build/d81/save_util128.o

# savegame.prg
build/d81.f/savegame.prg: build/d81/savegame.o build/d81/save_util.o build/common/utils.o 
	$(LD65) $(LD65FLAGS) -vm -m ./build/d81/savegame.map -o $@ -C src/d81/savegame.cfg c64.lib $^

# savegame128.prg
build/d81.f/savegame128.prg:
	$(CC65) -t c128 -DD81 -o build/d81/save_util128.s src/d81/save_util.c
	$(CC65) -t c128 -DD81 -o build/d81/savegame128.s src/d81/savegame.c
	$(CA65) -t c128 -I . --debug-info -o build/common/utils128.o src/common/utils.s
	$(CA65) -t c128 -I . --debug-info -o build/d81/save_util128.o build/d81/save_util128.s
	$(CA65) -t c128 -I . --debug-info -o build/d81/savegame128.o build/d81/savegame128.s
	$(LD65) -t c128 -vm -m ./build/d81/savegame128.map -o $@ -C src/d81/savegame128.cfg c128.lib  build/d81/save_util128.o build/d81/savegame128.o build/common/utils128.o

# files with additional items
build/d81.f/files.list: build/source/files.list
	cp ./build/source/* ./build/d81.f/

# crunch
build/d81.f/crunched.done: build/d81.f/patched.done
	tools/crunch.py -v -t mem -b ./build/d81.f
	touch build/d81.f/crunched.done

# patch
build/d81.f/patched.done: build/d81.f/files.list build/d81/io-replacement.map build/d81/io-replacement.prg build/d81/transfer-load.map build/d81/transfer-load.prg $(KARMA_PATCHES)
	tools/u5patch.py -v -l ./build/d81.f/files.list -f ./build/d81.f -m build/d81/io-replacement.map -m build/d81/transfer-load.map $(KARMA_MAPS) ./patches/d81/*.patch ./patches/*.patch
	touch ./build/d81.f/patched.done

# build disk
build/u5remastered.d81: build/d81.f/crunched.done build/d81.f/loader.prg build/d81.f/exodecrunch.prg build/d81.f/editor.prg build/d81.f/savegame.prg build/d81.f/savegame128.prg build/d81.f/editor128.prg
	tools/mkd81.py -v -o ./build/u5remastered.d81 -x ./src/d81/exclude.cfg -i ./src/d81/io.i -d ./src/disks.cfg -f ./build/d81.f


# ------------------------------------------------------------------------
# backbit

# io-replacement d81
build/backbit/io-replacement.prg build/backbit/io-replacement.map: build/backbit/io-code.o build/common/exodecrunch.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/backbit/io-replacement.map -o build/backbit/io-replacement.prg -C ./src/backbit/io-replacement.cfg $^

# loader
build/backbit/loader.prg: build/backbit/loader.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/backbit/loader.map -o build/backbit/loader.prg -C ./src/backbit/loader.cfg $^

build/backbit.f/loader.prg: build/backbit/loader.prg
	cp ./build/backbit/loader.prg build/backbit.f/loader.prg

build/backbit/exodecrunch.prg: build/common/exodecrunch.o build/backbit/io-code.o
	$(LD65) $(LD65FLAGS) -o $@ -C ./src/backbit/exodecrunch.cfg $^

build/backbit.f/exodecrunch.prg: build/backbit/exodecrunch.prg
	cp ./build/backbit/exodecrunch.prg ./build/backbit.f/exodecrunch.prg

# transfer-load
build/backbit/transfer-load.prg build/backbit/transfer-load.map: build/d81/transfer-load.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/backbit/transfer-load.map -o $@ -C ./src/d81/transfer-load.cfg $^

# savegame.prg
#build/backbit.f/savegame.prg: build/d81/savegame.o build/d81/save_util.o build/common/utils.o
#	$(LD65) $(LD65FLAGS) -u __EXEHDR__ -vm -m ./build/backbit/savegame.map -o $@ -C src/d81/savegame.cfg c64.lib $^

# editor.prg
#build/backbit.f/editor.prg: build/d81/save_util.o
#	$(CC65) $(CC65FLAGS) -DD81 -o build/backbit/editor.s src/common/editor.c
#	$(CA65) $(CA65FLAGS) -o build/backbit/editor.o build/backbit/editor.s
#	$(LD65) $(LD65FLAGS) -u __EXEHDR__ -vm -m ./build/backbit/editor.map -o $@ -C src/d81/editor.cfg c64.lib build/backbit/editor.o build/d81/save_util.o

# files with additional items
build/backbit.f/files.list: build/source/files.list
	cp ./build/source/* ./build/backbit.f/

# crunch
build/backbit.f/crunched.done: build/backbit.f/patched.done
	tools/crunch.py -v -t mem -b ./build/backbit.f
	touch build/backbit.f/crunched.done

# patch
build/backbit.f/patched.done: build/backbit.f/files.list build/backbit/io-replacement.map build/backbit/io-replacement.prg build/backbit/transfer-load.map build/backbit/transfer-load.prg $(KARMA_PATCHES)
	tools/u5patch.py -v -l ./build/backbit.f/files.list -f ./build/backbit.f -m build/backbit/io-replacement.map -m build/backbit/transfer-load.map $(KARMA_MAPS) ./patches/backbit/*.patch ./patches/d81/*.patch ./patches/*.patch
	touch ./build/backbit.f/patched.done

# build disk
build/u5remastered-BackBit.d81: build/backbit.f/crunched.done build/backbit.f/loader.prg build/backbit.f/exodecrunch.prg build/d81.f/editor.prg build/d81.f/savegame.prg build/d81.f/savegame128.prg build/d81.f/editor128.prg
	tools/mkd81.py -v -o ./build/u5remastered-BackBit.d81 -x ./src/backbit/exclude.cfg -i ./src/backbit/io.i -d ./src/disks.cfg -f ./build/backbit.f -f ./build/d81.f


# ------------------------------------------------------------------------
# common

# karma out britannia
build/common/karma_britannia.prg build/common/karma_britannia.map: build/common/karma_britannia.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/common/karma_britannia.map -o build/common/karma_britannia.prg -C ./src/common/karma_britannia.cfg $^

# karma out underworld
build/common/karma_underworld.prg build/common/karma_underworld.map: build/common/karma_underworld.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/common/karma_underworld.map -o build/common/karma_underworld.prg -C ./src/common/karma_underworld.cfg $^

# karma out twn
build/common/karma_twn.prg build/common/karma_twn.map: build/common/karma_twn.o
	$(LD65) $(LD65FLAGS) -vm -m ./build/common/karma_twn.map -o build/common/karma_twn.prg -C ./src/common/karma_twn.cfg $^


# ------------------------------------------------------------------------
# map pngs

pngs: build/source/files.list
	tools/create_maps.sh


# ------------------------------------------------------------------------

subdirs:
	@mkdir -p ./build/temp 
	@mkdir -p ./build/common
	@mkdir -p ./build/d81.f
	@mkdir -p ./build/d81
	@mkdir -p ./build/backbit.f
	@mkdir -p ./build/backbit
	@mkdir -p ./build/source
	@mkdir -p ./build/ef.f
	@mkdir -p ./build/ef

clean:
	rm -rf build/ef
	rm -rf build/d81
	rm -rf build/backbit
	rm -rf build/ef.f 
	rm -rf build/d81.f
	rm -rf build/backbit.f
	rm -rf build/temp
	rm -rf build/common
	rm -rf build/source
	rm -rf build/png
	rm -f build/u5remastered.crt
	rm -f build/u5remastered.d81
	rm -f build/u5remastered-BackBit.d81
	rm -rf build/*.png

mrproper:
	rm -rf build


# source files
build/source/files.list:
	tools/extract.py -v -d ./src/disks.cfg -s ./disks -b ./build/source

# get m.prg	
build/source/m.prg:
	SDL_VIDEODRIVER=dummy c1541 ./disks/osi.d64 -read m ./build/source/m.prg

# get subs.128.prg	
build/source/subs.128.prg:
	SDL_VIDEODRIVER=dummy c1541 ./disks/osi.d64 -read subs.128 ./build/source/subs.128.prg


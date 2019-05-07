# Settings
TARGET=c64
CL65=cl65
CA65=ca65
#LD65=ld65
CL65FLAGS=-t $(TARGET) -I ./src/include
CA65FLAGS=-t $(TARGET) -I . -I ./src/include --debug-info
#LD65FLAGS=

.SUFFIXES: .prg .s
.PHONY: clean mrproper subdirs all easyflash


# all
all: easyflash

# easyflash
easyflash: subdirs build/ef/directory.data.prg build/ef/files.data.prg build/u5remastered.crt

# d81


# compile
build/%.o: src/%.s
	$(CA65) $(CA65FLAGS) -o $@ $<


# exomizer for ef
build/ef/exodecrunch.prg: build/exo/exodecrunch.o build/ef/io-rw.o build/ef/io-data.o
	$(CL65) $(CL65FLAGS) -o $@ -C src/ef/exodecrunch.cfg $^

# easyflash init.prg
build/ef/init.prg: build/ef/init.o
	$(CL65) $(CL65FLAGS) -o $@ -C src/ef/init.cfg $^

# easyflash loader.prg
build/ef/loader.prg: build/ef/loader.o build/ef/io-data.o build/ef/io-rw.o build/ef/io-code.o build/exo/exodecrunch.o
	$(CL65) $(CL65FLAGS) -o $@ -C src/ef/loader.cfg $^

# io-replacement
build/ef/io-replacement.prg build/ef/io-replacement.map: build/ef/io-code.o build/ef/io-data.o build/ef/io-rw.o build/exo/exodecrunch.o
	$(CL65) $(CL65FLAGS) -vm -m ./build/ef/io-replacement.map -o build/ef/io-replacement.prg -C ./src/ef/io-replacement.cfg $^

# io-addendum
build/ef/io-addendum.prg: build/ef/io-code.o build/ef/io-data.o build/ef/io-rw.o build/exo/exodecrunch.o
	$(CL65) $(CL65FLAGS) -o $@ -C ./src/ef/io-addendum.cfg $^

# io map
build/ef/io-replacement.inc: build/ef/io-replacement.map
	tools/parsemap.py -v -s ./build/ef/io-replacement.map -d build/ef/io-replacement.inc -e IO_load_file_entry -e IO_read_block_entry -e IO_request_disk_id_entry -e IO_request_disk_char_entry -e IO_save_file_entry -e IO_read_block_alt_entry  -e get_crunched_byte -e decrunch_table


# raw files
build/files/files.list: build/ef/io-addendum.prg
	tools/extract.py -v -s ./disks -b ./build/files
	cp build/ef/io-addendum.prg build/files/io.add.prg
	echo "0x41/io.add io.add" >> build/files/files.list
	
# patch
build/files/patched.done: build/files/files.list build/ef/io-replacement.inc
	tools/mkpatch_tempsubs.sh ./build/patches ./build/ef/io-replacement.inc
	tools/u5patch.py -v -f ./build/files -a ./patches/*.patch ./build/patches/*.patch
	touch ./build/files/patched.done
	 
# crunch
build/files/crunched.done: build/files/patched.done
	tools/crunch.py -v -b ./build/files
	touch build/files/crunched.done

# build efs
build/ef/directory.data.prg build/ef/files.data.prg: build/files/crunched.done
	tools/mkefs.py -v -o ./src/disks.cfg  -x ./src/ef/exclude.cfg -f ./build/files -e crunch -d ./build/ef

# build blocks
build/ef/crt.blocks.map: build/files/files.list
	tools/mkblocks.py -v -o ./src/disks.cfg -b ./src/ef/block.map -f ./build/files -m ./build/ef/crt.blocks.map -d ./build/ef

# cartridge binary
build/ef/u5remastered.bin: build/ef/directory.data.prg build/ef/files.data.prg build/ef/exodecrunch.prg build/ef/init.prg build/ef/loader.prg src/ef/eapi-am29f040.prg build/ef/crt.blocks.map
	cp ./src/ef/crt.map ./build/ef/crt.map
	cp ./src/ef/eapi-am29f040.prg ./build/ef/eapi-am29f040.prg
	tools/mkbin.py -v -b ./build/ef -m ./build/ef/crt.map -m ./build/ef/crt.blocks.map -o ./build/ef/u5remastered.bin

# cartdridge crt
build/u5remastered.crt: build/ef/u5remastered.bin
	cartconv -t easy -o build/u5remastered.crt -i build/ef/u5remastered.bin -n "Ultima 5 Remastered" -p


subdirs:
	@mkdir -p ./build/temp ./build/exo
	@mkdir -p ./build/files
	@mkdir -p ./build/patches
	@mkdir -p ./build/ef

clean:
	rm -rf build/ef
	rm -rf build/d81

mrproper:
	rm -rf build


#
#build/ef/src/io/data_loader.exported.inc: src/io/data_loader.map
#	tools/parsemap.py -v -s ./src/io/data_loader.map -d ./src/io/data_loader.exported.inc -e get_crunched_byte -e load_prg -e save_prg_byte -e save_source_high -e save_source_low -e load_block -e load_destination_high -e load_destination_low -e save_source_low -e save_source_high

## data loader
#build/obj/data_loader.prg src/io/data_loader.map: src/io/data_loader.s
#	$(CL65) $(CL65FLAGS) -vm -m ./src/io/data_loader.map -o build/obj/data_loader.prg -C src/io/data_loader.cfg $^
## data loader map
#src/io/data_loader.exported.inc: src/io/data_loader.map
#	tools/parsemap.py -v -s ./src/io/data_loader.map -d ./src/io/data_loader.exported.inc -e get_crunched_byte -e load_prg -e save_prg_byte -e save_source_high -e save_source_low -e load_block -e load_destination_high -e load_destination_low -e save_source_low -e save_source_high

# io
#build/obj/io.prg src/io/io.map: src/io/io.s src/io/data_loader.exported.inc
#	$(CL65) $(CL65FLAGS) -vm -m ./src/io/io.map -o ./build/obj/io.prg -C ./src/io/io.cfg ./src/io/io.s
# io.map
#src/io/io.exported.inc: src/io/io.map
#	tools/parsemap.py -v -s ./src/io/io.map -d ./src/io/io.exported.inc -e IO_load_file_entry -e IO_read_block_entry -e IO_request_disk_id_entry -e IO_request_disk_char_entry -e IO_save_file_entry -e IO_read_block_alt_entry -e read_block_filename -e requested_disk -e save_files_flags
 
# io jump table replacements
#build/ef/temp.subs.patched.prg: build/ef/io-replacement.inc
#	c1541 disks/osi.d64 -read temp.subs build/ef/temp.subs.prg
#	tools/mkpatch_tempsubs.sh ./build/patches ./build/ef/io-replacement.inc
#	# replace
#	tools/u5patch.py -v -s ./build/ef/temp.subs.prg -d ./build/ef/temp.subs.patched.prg ./build/patches/temp.subs.*


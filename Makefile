# Settings
TARGET=c64
CL65=cl65
#CA65=ca65
#LD65=ld65
CL65FLAGS=-t $(TARGET) -I ./src/include
#CA65FLAGS=-t $(TARGET) -I . -I ./src/include --debug-info
#LD65FLAGS=

.SUFFIXES: .prg .s

# ultima 5
ultima5: build/u5remastered.crt

# all
all: build/obj/directory.data.prg build/obj/files.data.prg build/u5remastered.crt

# code
#code: build/obj/exodecrunch.prg build/obj/loader.prg build/obj/initialize.prg build/obj/io.prg

# compile
%.o: %.s
	$(CA65) $(CA65FLAGS) -o $@ $<

# loader.prg
build/obj/loader.prg: src/ef/loader.s
	$(CL65) $(CL65FLAGS) -o $@ -C $(<D)/$(*F).cfg $^

# initialize
build/obj/initialize.prg: src/ef/initialize.s
	$(CL65) $(CL65FLAGS) -o $@ -C $(<D)/$(*F).cfg $^

# io
build/obj/io.prg src/io/io.map: src/io/io.s src/io/data_loader.s
	$(CL65) $(CL65FLAGS) -vm -m $(<D)/io.map -o build/obj/io.prg -C src/io/io.cfg $^

# io.map
src/io/io.created.inc: src/io/io.map
	tools/parsemap.py -v -s ./src/io/io.map -d ./src/io/io.created.inc -e IO_load_file_entry -e IO_read_block_entry -e IO_request_disk_id_entry -e IO_request_disk_char_entry -e IO_save_file_entry -e IO_read_block_alt_entry -e get_crunched_byte -e load_block_highdestination
 
# exomizer
build/obj/exodecrunch.prg: src/exo/exodecrunch.s src/io/io.created.inc
	$(CL65) $(CL65FLAGS) -vm -m $(<D)/exodecrunch.map -o $@ -C $(<D)/$(*F).cfg $<

# io jump table replacements
build/obj/temp.subs.patched.prg: src/io/io.created.inc
	mkdir -p ./build/patches
	c1541 disks/osi.d64 -read temp.subs build/obj/temp.subs.prg
	tools/mkpatch_tempsubs.sh ./build/patches ./src/io/io.created.inc
	tools/u5patch.py -v -s ./build/obj/temp.subs.prg -d ./build/obj/temp.subs.patched.prg ./build/patches/temp.subs.*

# raw files
build/files/files.list:
	mkdir -p ./build/files ./build/obj
	tools/extract.py -v -s ./disks -b ./build

# crunched
build/files/crunched.done: build/files/files.list
	tools/crunch.py -v -b ./build

# build efs
build/obj/directory.data.prg build/obj/files.data.prg: build/files/crunched.done
	tools/mkefs.py -v -s ./src -b ./build -e crunch

# cartridge binary
build/obj/u5remastered.bin: build/obj/directory.data.prg build/obj/files.data.prg build/obj/exodecrunch.prg build/obj/initialize.prg build/obj/loader.prg src/ef/eapi-am29f040.prg build/obj/io.prg build/obj/exodecrunch.prg build/obj/temp.subs.patched.prg
	cp ./src/crt.map ./build/obj/crt.map
	tools/mkbin.py -v -s ./src/ -b ./build/

# cartdridge crt
build/u5remastered.crt: build/obj/u5remastered.bin
	cartconv -t easy -o build/u5remastered.crt -i build/obj/u5remastered.bin -n "Ultima 5 Remastered Demo" -p


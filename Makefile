# Settings
TARGET=c64
CL65=cl65
#CA65=ca65
#LD65=ld65
CL65FLAGS=-t $(TARGET) -I ./src/include
#CA65FLAGS=-t $(TARGET) -I . -I ./src/include --debug-info
#LD65FLAGS=

.SUFFIXES: .prg .s

# all
all: build/obj/directory.data.prg build/obj/files.data.prg code

# code
code: build/obj/exodecrunch.prg build/obj/loader.prg build/obj/initialize.prg build/obj/io.prg

# compile
%.o: %.s
	$(CA65) $(CA65FLAGS) -o $@ $<

# builddir
#builddirs:
#	mkdir -p build/obj build/files build/temp
	
# loader
#src/ef/loader.o:  src/ef/loader.s

# initialize
#src/ef/initialize.o:  src/ef/initialize.s

# loader.prg
build/obj/loader.prg: src/ef/loader.s
	$(CL65) $(CL65FLAGS) -o $@ -C $(<D)/$(*F).cfg $^

# initialize
build/obj/initialize.prg: src/ef/initialize.s
	$(CL65) $(CL65FLAGS) -o $@ -C $(<D)/$(*F).cfg $^

# io
build/obj/io.prg: src/io/io.s
	$(CL65) $(CL65FLAGS) -vm -m $(<D)/io.map -D decrunch=0x7B1D -o $@ -C $(<D)/$(*F).cfg $^

# exomizer
build/obj/exodecrunch.prg: src/exo/exodecrunch.s src/exo/get_crunched_byte.s
	$(CL65) $(CL65FLAGS) -vm -m $(<D)/exodecrunch.map -o $@ -C $(<D)/$(*F).cfg $^

# io jump table replacements
# ### todo ###

# raw files
build/files/files.list:
	tools/extract.py -v -s ./disks -b ./build

# crunched
build/files/crunched.done: build/files/files.list
	tools/crunch.py -v -b ./build

# build efs
build/obj/directory.data.prg build/obj/files.data.prg: build/files/crunched.done
	tools/mkefs.py -v -s ./src -b ./build


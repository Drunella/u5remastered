# Settings
TARGET=c64
CL65=cl65
CA65=ca65
#LD65=ld65
CL65FLAGS=-t $(TARGET)
CA65FLAGS=-t $(TARGET) -I . -I src/include --debug-info
#LD65FLAGS=

.SUFFIXES: .prg .s

# all
all: builddirs build/obj/loader.prg build/obj/initialize.prg build/obj/directory.data.prg build/obj/files.data.prg


# compile
%.o: %.s builddirs
	$(CA65) $(CA65FLAGS) -o build/obj/$(@F) $<

# builddir
builddirs:
	mkdir -p build/obj build/files build/temp
	
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

# raw files
build/files/files.list:
	tools/extract.py -v -s ./disks -b ./build

# crunched
build/files/crunched.done: build/files/files.list
	tools/crunch.py -v -b ./build

# build efs
build/obj/directory.data.prg build/obj/files.data.prg: build/files/crunched.done
	tools/mkefs.py -v -s ./src -b ./build


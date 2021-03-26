D_SRCS := $(shell find source/kernel -type f)
D_MODULES := $(shell echo $(D_SRCS) | sed 's/\//./g' | sed 's/source\.//g' | sed 's/\.d / /g' | sed 's/\.d$$//')
D_OBJS := $(patsubst %,build/%.o,$(D_MODULES))
D_DEPFILES := $(patsubst build/%.o,build/%.dep,$(D_OBJS))
run: build/kernel.hdd
	qemu-system-x86_64 -hda build/kernel.hdd \
		-s -debugcon stdio -global \
		isa-debugcon.iobase=0xe9 -cpu max
runf: build/kernel.hdd
	qemu-system-x86_64 -hda build/kernel.hdd \
		-no-shutdown -no-reboot -s -debugcon stdio -global \
		isa-debugcon.iobase=0xe9 -cpu max
bochs: build/kernel.hdd
	bochs
al:
	echo $(D_OBJS)
	/opt/homebrew/Cellar/binutils/2.36.1/bin/addr2line --exe build/kernel.elf | sponge

build/%.o build/%.dep:
	$(eval DEP := $(patsubst build/%.o,build/%.dep,$@))
	$(eval OBJ := $(patsubst build/%.dep,build/%.o,$@))
	$(eval DSRC := $(shell echo $(patsubst build/%.dep,source/%,$(DEP)) | sed 's/\./\//g').d)
	$(eval CSRC := $(patsubst build/%.o,source/%.c,$(OBJ)))
	$(eval ASSRC := $(patsubst build/%.o,source/%.s,$(OBJ)))
	@([ -e $(DSRC) ] && [ -e $(OBJ) ] && [ $(DSRC) -ot $(OBJ) ]) || \
		([ -e $(CSRC) ] && [ -e $(OBJ) ] && [ $(CSRC) -ot $(OBJ) ]) || \
		([ -e $(ASSRC) ] && [ -e $(OBJ) ] && [ $(ASSRC) -ot $(OBJ) ]) || ( \
		if ([ -e $(DSRC) ]); then \
			echo DD $(OBJ) && \
			ldc2 --makedeps=$(DEP) \
			--float-abi=soft -code-model=kernel --disable-red-zone \
			-mtriple x86_64-linux -O0 --frame-pointer=all -betterC \
			-c $(DSRC) --oq -od=build -g --d-debug -I source \
			-mattr=-sse,-sse2,-sse3,-ssse3 --disable-red-zone; \
			exit $$?; \
		fi; \
		if ([ -e $(CSRC) ]); then \
			echo CC $(OBJ) && \
			clang -MD -MF $(DEP) \
			-target x86_64-elf -ffreestanding $(CSRC) -o $@ -c -ggdb \
			-fno-omit-frame-pointer -mno-red-zone; \
			exit $$?;\
		fi; \
		( \
			echo AS $(OBJ) && \
			yasm -o $(OBJ) $(ASSRC) -felf64 -g dwarf2 && \
			echo "$(OBJ): $(ASSRC)" >$(DEP) \
		) \
	) || ( \
		echo "Error..."; \
		echo "  Attempted to produce: $(OBJ)"; \
		echo "  Output depfile: $(DEP)"; \
		echo "  Source (C/D/ASM): $(CSRC) $(DSRC) $(ASSRC)" \
	)
	@[ -e $(DEP) ] || (echo "The compiler failed to produce a depfile, aborting!!!";false)
	@[ -e $(OBJ) ] || (echo "The compiler failed to produce an object for $(OBJ), aborting!!!";false)
	@(printf "$(DEP) ";cat $(DEP)) | sponge $(DEP)

include $(D_DEPFILES)

build/kernel.elf: build/task.o build/boot.o $(D_OBJS) source/kernel.ld source/task.c
	@rm -f build/kernel.elf
	@echo LD $@
	@ld.lld -m elf_x86_64 -nostdlib -T source/kernel.ld \
		-o build/kernel.elf /opt/libgcc-cross-x86_64-elf.a \
		build/boot.o build/task.o $(D_OBJS) | ddemangle
	@[ -e build/kernel.elf ]

build/kernel.hdd: build/env/ready
	@echo FORMAT $@
	@if [ -e build/kernel.hdd ]; then true; else truncate build/kernel.hdd -s 64M; duogpt build/kernel.hdd; fi
	@echfs-utils -g -p0 build/kernel.hdd quick-format 512
	@sh import.sh
	@limine-install build/kernel.hdd
	

build/initrd.bin: $(shell find data)
	@cd data && find . | cpio -o >../build/initrd.bin && cd ..

build/env/ready: build/kernel.elf cfg/limine.cfg build/initrd.bin
	@mkdir -vp build/env/boot
	@cp cfg/limine.cfg build/env
	@cp build/kernel.elf build/env/boot/kernel.elf
	@cp build/initrd.bin build/env/boot/initrd.bin
	@touch build/env/ready
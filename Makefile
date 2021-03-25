D_SRCS = $(shell find source -type f | grep -v '\.[sc]$$')
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
	/opt/homebrew/Cellar/binutils/2.36.1/bin/addr2line --exe build/kernel.elf | sponge
build/kernel.elf: build/boot.o $(D_SRCS) linker.ld source/task.c
	find build | grep '\.o$$' | grep -v \/boot\.o | xargs rm -f
	clang -target x86_64-elf -ffreestanding source/task.c -o build/cctask.o -c -ggdb -fno-omit-frame-pointer
	ldc2 --makedeps -v --float-abi=soft -code-model=kernel -mtriple x86_64-linux -O0 --frame-pointer=all -betterC -c $(D_SRCS) -od=build -g --d-debug -mattr=-sse,-sse2,-sse3,-ssse3 --disable-red-zone
	@rm -f build/kernel.elf
	ld.lld -m elf_x86_64 -nostdlib -T linker.ld -o build/kernel.elf build/boot.o /opt/libgcc-cross-x86_64-elf.a `find build | grep '\.o$$' | grep -v \/boot\.o` --color-diagnostics 2>&1
	@[ -e build/kernel.elf ]

build/%.o: source/%.s
	yasm -o $@ $< -felf64 -g dwarf2

build/kernel.hdd: build/env/ready
	@rm -f build/kernel.hdd
	@truncate build/kernel.hdd -s 64M
	@duogpt build/kernel.hdd
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
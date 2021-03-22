D_SRCS = $(shell find source -type f | grep -v '\.s$$')
run: build/kernel.hdd
	qemu-system-x86_64 -hda build/kernel.hdd -accel kvm \
		-no-reboot -no-shutdown -s -debugcon stdio -global \
		isa-debugcon.iobase=0x400 -vnc :1 -cpu host
al:
	addr2line --exe build/kernel.elf | sponge
build/kernel.elf: build/boot.o $(D_SRCS) linker.ld
	find build | grep '\.o$$' | grep -v \/boot\.o | xargs rm -f
	dmd -O -betterC -m64 -c $(D_SRCS) -od=build -g -gs -gf -vtls -debug
	@rm -f build/kernel.elf
	ld.lld -nostdlib -T linker.ld -o build/kernel.elf build/boot.o /opt/cross/lib/gcc/x86_64-elf/10.2.0/libgcc.a `find build | grep '\.o$$' | grep -v \/boot\.o` --color-diagnostics 2>&1 | ddemangle
	@[ -e build/kernel.elf ]

build/%.o: source/%.s
	yasm -o $@ $< -felf64 -g dwarf2

build/kernel.hdd: build/env/ready
	@rm -f build/kernel.hdd
	@fallocate build/kernel.hdd -l 64M
	@parted -s build/kernel.hdd mklabel gpt
	@parted -s build/kernel.hdd mkpart primary 2048s 100%
	@echfs-utils -g -p0 build/kernel.hdd quick-format 512
	@sh import.sh
	@limine-install build/kernel.hdd
	

build/initrd.bin: $(shell find data)
	@cd data && find | afio -o ../build/initrd.bin && cd ..

build/env/ready: build/kernel.elf cfg/limine.cfg build/initrd.bin
	@mkdir -vp build/env/boot
	@cp cfg/limine.cfg build/env
	@cp build/kernel.elf build/env/boot/kernel.elf
	@cp build/initrd.bin build/env/boot/initrd.bin
	@touch build/env/ready
set disassembly-flavor intel
file build/kernel.elf
target remote :1234
maintenance packet qqemu.sstep=1
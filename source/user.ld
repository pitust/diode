SECTIONS
{


    . = 0x000008000000000;

    __elf_begin = .;
    .text : ALIGN(4096) {
        *(.text*)
    }
	. = ALIGN(4096);

    .rodata : ALIGN(4096) {
        *(.rodata*)
    }

    .data : ALIGN(4096) {
        *(.data*)
        __init_begin = .;
        *(.init_array)
        *(.init_array*)
        __init_end = .;
    }

    .tdata : ALIGN(4096) {
        *(.tdata)
    }

    .tbss : ALIGN(4096) {
        *(.tbss)
    }

    .bss : ALIGN(4096) {
        *(COMMON)
        *(.bss*)
    }
    __elf_end = .;
}

SECTIONS
{

    . = 0x000001100000000;
    .text : ALIGN(4096) {
        *(.text*)
    }
	. = ALIGN(4096);

    .rodata : ALIGN(4096) {
        *(.rodata*)
    }

    .data : ALIGN(4096) {
        *(.data*)
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
}

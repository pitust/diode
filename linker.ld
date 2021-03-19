SECTIONS
{

    . = 0xffffffff80200000;
	_text_begin = .;
    .text : ALIGN(16777216) {
        *(.text*)
    }
	. = ALIGN(16777216);
	_text_end = .;

    .rodata : ALIGN(4096) {
        *(.rodata*)
    }

    .data : ALIGN(4096) {
        *(.data*)
    }

    .tdata : ALIGN(4096) {
        put_tls_here = .;
        *(.tdata)
        zero_tls_begin = .;
        *(.tbss)
        zero_tls_end = .;
    }

    .bss : ALIGN(4096) {
        *(COMMON)
        *(.bss*)
    }
	
    .stivale2hdr : {
        KEEP(*(.stivale2hdr))
    }
	_exec_end = .;
}

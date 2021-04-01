global _start
extern _main

section .text


_start:
    mov rdi, 0xC000 ; SYS_BOOTSTRAP_SETUPSTACK
    syscall ; this causes #UD. this is normal. easier to handle. ignore that
    mov rsp, rax ; they have to return in rax

    call _main

    db 0xeb, 0xfe
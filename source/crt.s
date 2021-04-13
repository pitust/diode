global _start
global __psys_fork
extern _main
extern __init_begin
extern __init_end
extern __elf_begin
extern __elf_end

section .text

stack: dq 0

__psys_fork:
    push rbx
    push rcx
    push rdx
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    mov [rel stack], rsp
    lea rsi, [rel __psys_resume]
    syscall

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdx
    pop rcx
    pop rbx
    ret

__psys_resume:
    mov rsp, [rel stack]
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdx
    pop rcx
    pop rbx
    xor rax, rax
    ret

_start:
    mov rdi, 0xC000 ; SYS_BOOTSTRAP_SETUPSTACK
    syscall ; this causes #UD. this is normal. easier to handle. ignore that
    mov rsp, rax ; they have to return in rax

    lea rdi, [rel __init_begin]
    lea rsi, [rel __init_end]

    mov rax, QWORD __elf_begin
    mov rdx, rax
    mov rax, QWORD __elf_end
    mov rcx, rax

    call _main

    db 0xeb, 0xfe
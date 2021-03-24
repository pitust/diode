extern isrhandle_ec
extern isrhandle_noec
bits 64

%define HEADER_TAG_FRAMEBUFFER_ID 0x3ecc1bc43d0f7971
%define HEADER_TAG_FB_MTRR_ID 0x4c7bb07731282e00
%define HEADER_TAG_SMP_ID 0x1ab015085f3273df
%define HEADER_TAG_5LV_PAGING_ID 0x932f477032007e8f
%define STRUCT_TAG_CMDLINE_ID 0xe5e76a1b4597a781
%define STRUCT_TAG_MEMMAP_ID 0x2187f79e8612de07
%define STRUCT_TAG_FRAMEBUFFER_ID 0x506461d2950408fa
%define STRUCT_TAG_FB_MTRR_ID 0x6bc1a78ebe871172
%define STRUCT_TAG_MODULES_ID 0x4b6fe466aade04ce
%define STRUCT_TAG_RSDP_ID 0x9e1786930a375e78
%define STRUCT_TAG_EPOCH_ID 0x566a7bed888e1407
%define STRUCT_TAG_FIRMWARE_ID 0x359d837855e3858c
%define STRUCT_TAG_SMP_ID 0x34d1d96339647025
%define STRUCT_TAG_PXE_SERVER_INFO 0x29d1e96239247032

TASK_FLD_STATE equ 0
TASK_FLD_PREV equ 8
TASK_FLD_NEXT equ 16
TASK_FLD_DATA equ 24

section .stivale2hdr
global stivale_hdr
global task_call

stivale_hdr:
	dq 0
	dq stack_top
	dq 0
	dq STIVALE_TAG_0

section .text

STIVALE_TAG_0:
    dq STRUCT_TAG_FRAMEBUFFER_ID
    dq 0
    dw 0
    dw 0
    dw 0

rdrandom:
    rdrand rax
    ret

global asm_switch
global setjmp
global longjmp
global _D4core5bitop4outpFNbNikkZh
global _rdrand

extern sched_switch

setjmp:
    mov [rdi +  0], rbx
    mov [rdi +  8], rbp
    mov [rdi + 16], r12
    mov [rdi + 24], r13
    mov [rdi + 32], r14
    mov [rdi + 40], r15
    lea rax, [rsp + 8]
    mov [rdi + 48], rax
    mov rax, [rsp]
    mov [rdi + 56], rax
    mov rax, 0
    ret

longjmp:
    mov    rax, rsi
    mov    rbp, [rdi + 8]
    mov    [rdi + 48], rsp
    push   QWORD [rdi + 56]
    mov    rbx, [rdi +  0]
    mov    r12, [rdi + 16]
    mov    r13, [rdi + 24]
    mov    r14, [rdi + 32]
    mov    r15, [rdi + 40]
    ret

_rdrand:
    rdrand rax
    jnc _rdrand
    ret

fgdt:
    lgdt [rel GDT64.Pointer]
    mov ax, GDT64.Data
    mov ss, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    pop rax
    push GDT64.Code
    push rax
    retf

section .data


%macro idtend 1
    dq isr%1
%endmacro

%macro isrgen 1

isr%1:
    push rbp
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    mov rdi, %1
    lea rsi, [rsp]
%if (%1 >= 0x8 && %1 <= 0xE) || %1 == 0x11 || %1 == 0x1E
    call isrhandle_ec
%else
    call isrhandle_noec
%endif
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rbp
    pop rax
%if (%1 >= 0x8 && %1 <= 0xE) || %1 == 0x11 || %1 == 0x1E
    add rsp, 8 ; error code
%endif
    iretq

%endmacro

global get_idt_targets
get_idt_targets:
    lea rax, [rel idt_targets]
    ret

global idt_targets
idt_targets:
%assign i 0
%rep 256
    idtend i
%assign i i+1
%endrep

%assign i 0
%rep 256
isrgen i
%assign i i+1
%endrep

section .data
global fgdt

GDT64:                           ; Global Descriptor Table (64-bit).
.Null: equ $ - GDT64         ; The null descriptor.
    dw 0xFFFF                    ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 0                         ; Access.
    db 1                         ; Granularity.
    db 0                         ; Base (high).
.Code: equ $ - GDT64         ; The code descriptor.
    dw 0                         ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 10011010b                 ; Access (exec/read).
    db 10101111b                 ; Granularity, 64 bits flag, limit19:16.
    db 0                         ; Base (high).
.Data: equ $ - GDT64         ; The data descriptor.
    dw 0                         ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 10010010b                 ; Access (read/write).
    db 00000000b                 ; Granularity.
    db 0                         ; Base (high).
.Pointer:                    ; The GDT-pointer.
    dw $ - GDT64 - 1             ; Limit.
    dq GDT64                     ; Base.
section .bss
stack_bottom:
	resb 0x20000
stack_top:
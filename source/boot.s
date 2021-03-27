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
    pop rax
    pop rbp
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

global setrsp0
global setist1
global getrsp0
global gettss
global gettssgdt
global gettssgdtid
global load_tss
global platform_sc
global user_branch
global _stac
global _clac
is_smap: dq 0
is_smap_i: dq 0

smap_i:
    mov rax, 1
    cmp [rel is_smap_i], rax
    je .retr
    mov eax, 7
    mov ecx, 0
    cpuid
    shr ebx, 20
    and ebx, 1
    mov [rel is_smap], rbx
    mov rax, 1
    mov [rel is_smap_i], rax
.retr:
    ret

_stac:
    call smap_i
    mov rax, 1
    cmp [rel is_smap], rax
    jne .retr
    stac
.retr:
    ret
_clac:
    call smap_i
    mov rax, 1
    cmp [rel is_smap], rax
    jne .retr
    clac
.retr:
    ret

user_branch:
    mov rdx, 0x18 | 3
    mov ax, 0x23 | 3
    mov ds,ax
    mov es,ax 
    mov fs,ax 
    mov gs,ax

    xor rbx, rbx
    xor rcx, rcx
    push rax
    xor rax, rax
    push rsi
    xor rsi, rsi
    push 0x200
    push rdx
    xor rdx, rdx
    push rdi
    xor rdi, rdi
    iretq

platform_sc:
    db 0xeb, 0xfe

load_tss:
    mov ax, 0x28
    ltr ax
    ret
setrsp0:
    mov [rel TSS.tss_rsp0], rdi
    ret
setist1:
    mov [rel TSS.ist1], rdi
    ret
getrsp0:
    mov rax, [rel TSS.tss_rsp0]
    ret

gettss:
    lea rax, [rel TSS]
    ret

gettssgdt:
    lea rax, [rel GDT64.TSSE]
    ret
gettssgdtid:
    mov rax, GDT64.TSS
    ret


section .data
global fgdt
align 16

GDT64:                           ; Global Descriptor Table (64-bit).
.Null: equ $ - GDT64         ; The null descriptor.
    dw 0xFFFF                    ; Limit (low).
    dw 0                         ; Base (low).
    db 0                         ; Base (middle)
    db 0                         ; Access.
    db 1                         ; Granularity.
    db 0                         ; Base (high).
.Code: equ $ - GDT64         ; The code descriptor.
    dq 0x00af9b000000ffff
.Data: equ $ - GDT64         ; The data descriptor.
    dq 0x00af93000000ffff ; probably wrong tho
.UserCode: equ $ - GDT64         ; The code descriptor.
    dq 0x00affb000000ffff
.UserData: equ $ - GDT64         ; The data descriptor.
    dq 0x00aff3000000ffff
.TSS: equ $ - GDT64
.TSSE:
    times 16 db 0


.Pointer:                    ; The GDT-pointer.
    dw $ - GDT64 - 1             ; Limit.
    dq GDT64                     ; Base.

align 16
times 4 db 0
TSS: 
    dd 0 ; 0x00 reserved
.tss_rsp0:
    dd 0 ; 0x04 RSP0 (low)
    dd 0 ; 0x08 RSP0 (high)
    dd 0 ; 0x0C RSP1 (low)
    dd 0 ; 0x10 RSP1 (high)
    dd 0 ; 0x14 RSP2 (low)
    dd 0 ; 0x18 RSP2 (high)
    dd 0 ; 0x1C reserved
    dd 0 ; 0x20 reserved
.ist1:
    dq death_stack_top ; 0x24 IST1
    dq 0 ; 0x2C IST2
    dq 0 ; 0x34 IST3
    dq 0 ; 0x3C IST4
    dq 0 ; 0x44 IST5
    dq 0 ; 0x4C IST6
    dq 0 ; 0x54 IST7
    dd 0 ; 0x5C reserved
    dd 0 ; 0x60 reserved
    dw 0 ; 0x64 reserved
    dw 13 ; 0x66 IOPB offset

    times 16-13 db 0 ; pad

section .bss

stack_bottom:
	resb 0x40000
stack_top:
death_stack_bottom:
	resb 0x40000
death_stack_top:
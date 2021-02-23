; multiboot definitions
%define MULTIBOOT_HEADER_MAGIC	0x1BADB002
%define MULTIBOOT_HEADER_FLAGS	0x00000003
 
; where is the kernel?
%define KERNEL_VMA_BASE			0xFFFF800000000000
%define KERNEL_LMA_BASE			0x100000
 
; the gdt entry to use for the kernel
%define CS_KERNEL				0x10
%define CS_KERNEL32				0x08
 
; other definitions
 
%define STACK_SIZE				0x4000

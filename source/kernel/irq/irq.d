module kernel.irq;

import kernel.io;
import kernel.mm;
import kernel.platform;

private extern(C) struct ISRFrameNOEC {
    ulong r15;
    ulong r14;
    ulong r13;
    ulong r12;
    ulong r11;
    ulong r10;
    ulong r9;
    ulong r8;
    ulong rdi;
    ulong rsi;
    ulong rdx;
    ulong rcx;
    ulong rbx;
    ulong rax;
    ulong rbp;
    // ulong error;

    ulong ip;
    ulong cs;
    ulong flags;
    ulong sp;
    ulong ss;
}
private extern(C) struct ISRFrame {
    ulong r15;
    ulong r14;
    ulong r13;
    ulong r12;
    ulong r11;
    ulong r10;
    ulong r9;
    ulong r8;
    ulong rdi;
    ulong rsi;
    ulong rdx;
    ulong rcx;
    ulong rbx;
    ulong rax;
    ulong rbp;

    ulong error;
    ulong ip;
    ulong cs;
    ulong flags;
    ulong sp;
    ulong ss;

}

/// Handle an ISR
extern(C) void isrhandle_ec(ulong isr, ISRFrame* frame) {
    printk("ISR: {hex} code={hex}", isr, frame.error);
    printk("Frame: {hex}", frame);
    if (isr == 3) {
        return;
    }
    assert(false);
}

/// Handle an ISR
extern(C) void isrhandle_noec(ulong isr, ISRFrameNOEC* frame) {
    ISRFrame frame2;
    frame2.ip = frame.ip;
    frame2.cs = frame.cs;
    frame2.flags = frame.flags;
    frame2.sp = frame.sp;
    frame2.ss = frame.ss;
    frame2.error = 0;
    frame2.r15 = frame.r15;
    frame2.r14 = frame.r14;
    frame2.r13 = frame.r13;
    frame2.r12 = frame.r12;
    frame2.r11 = frame.r11;
    frame2.r10 = frame.r10;
    frame2.r9 = frame.r9;
    frame2.r8 = frame.r8;
    frame2.rdi = frame.rdi;
    frame2.rsi = frame.rsi;
    frame2.rdx = frame.rdx;
    frame2.rcx = frame.rcx;
    frame2.rbx = frame.rbx;
    frame2.rax = frame.rax;
    isrhandle_ec(isr, &frame2);
}

/// An IDTR
extern(C) struct IDTR {
    /// The size of the IDT
    align(1) ushort size;
    /// The address of the IDT
    align(1) ulong addr;
    
    /// O-Meta
    OMeta _ometa_size() {
        return hex_ometa();
    }
    /// O-Meta
    OMeta _ometa_addr() {
        return hex_ometa();
    }

    /// Load this IDTR
    void load() {
        ulong idtr = cast(ulong)&this;
        asm {
            mov RAX, idtr;
            lidt [RAX];
        }
    }
}

extern(C) private ulong* get_idt_targets();

extern(C) private struct IDTEntry {
    align(1) ushort pointer_low;
    align(1) ushort gdt_selector = 8;
    align(1) ubyte ist = 0;
    align(1) ubyte type = 0x8e;
    align(1) ushort pointer_middle;
    align(1) uint pointer_high;
    align(1) uint reserved;

    void addr(ulong addr) {
        pointer_low = cast(ushort)addr;
        pointer_middle = cast(ushort)(addr >> 16);
        pointer_high = addr >> 32;
    }
}
static assert(IDTEntry.sizeof == 16);
extern(C) private struct IDTRStruct {
    align(1) ushort length;
    align(1) ulong base;
}
private __gshared IDTEntry[256] idt;

/// Allocate an IDT and return its corresponding IDTR
IDTR new_idtr() {
    IDTR idtr;
    const ulong* targets = get_idt_targets();
    foreach (i; 0..256) {
        idt[i].addr = targets[i];
    }
    idtr.addr = cast(ulong)idt.ptr;
    idtr.size = 4096;
    return idtr;
}
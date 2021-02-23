module kernel.irq;

import kernel.io;
import kernel.mm;
import kernel.platform;


/// Handle an ISR
extern(C) void isrhandle(ulong isr, ulong error_code) {
    printk("ISR: {hex} code={hex}", isr, error_code);
    assert(false);
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

private extern(C) ulong* get_idt_targets();

/// Allocate an IDT and return its corresponding IDTR
IDTR new_idtr() {
    IDTR idtr;
    ulong* idt = cast(ulong*)page();
    foreach (i; 0..256) {
        const ulong target = get_idt_targets()[i];
        idt[i * 2 + 0] = 0x0000_8e00_0033_0000 | (target & 0xffff) | ((target & 0xffff_0000) >> 16);
        idt[i * 2 + 1] = target >> 32;
    }
    idtr.addr = cast(ulong)idt;
    idtr.size = 4096;
    return idtr;
}
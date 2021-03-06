module kernel.irq;

import kernel.io;
import kernel.mm;
import kernel.pmap;
import kernel.task;
import kernel.util;
import kernel.guards;
import kernel.platform;
import kernel.syscall.dispatch;
import kernel.task : sched_yield;

enum PageFaultError {
    PRESENT = 1,
    WRITE = 2,
    USER = 4,
    RESERVED = 8,
    INSTRUCTION_FETCH = 16
}

private extern (C) struct ISRFrameNOEC {
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

    ulong rip;
    ulong cs;
    ulong flags;
    ulong rsp;
    ulong ss;
}

///
extern (C) struct ISRFrame {
    /// The value of the register `r15`
    ulong r15;
    /// The value of the register `r14`
    ulong r14;
    /// The value of the register `r13`
    ulong r13;
    /// The value of the register `r12`
    ulong r12;
    /// The value of the register `r11`
    ulong r11;
    /// The value of the register `r10`
    ulong r10;
    /// The value of the register `r9`
    ulong r9;
    /// The value of the register `r8`
    ulong r8;
    /// The value of the register `rdi`
    ulong rdi;
    /// The value of the register `rsi`
    ulong rsi;
    /// The value of the register `rdx`
    ulong rdx;
    /// The value of the register `rcx`
    ulong rcx;
    /// The value of the register `rbx`
    ulong rbx;
    /// The value of the register `rax`
    ulong rax;
    /// The value of the register `rbp`
    ulong rbp;
    /// The value of the register `error`
    ulong error;
    /// The value of the register `rip`
    ulong rip;
    /// The value of the register `cs`
    ulong cs;
    /// The value of the register `flags`
    ulong flags;
    /// The value of the register `rsp`
    ulong rsp;
    /// The value of the register `ss`
    ulong ss;

}

/// Acknowledge end of interrupt on the legacy PIC.
void pic_eoi() {
    outp(0x20, 0x20);
}

/// Handle an ISR
extern (C) void isrhandle_ec(ulong isr, ISRFrame* frame) {
    if (isr == 0xe) {
        ulong pfaddr;
        asm {
            mov RAX, CR2;
            mov pfaddr, RAX;
        }         
        printk(ERROR, "Page fault addr: {hex}", pfaddr);
        if (frame.error & 4) {
            if (cur_t.user_stack_bottom && pfaddr + 0x1000 > cur_t.user_stack_bottom && pfaddr < cur_t.user_stack_top) {
                printk("Demand paging stack at {hex} (for {ptr})", cur_t.user_stack_bottom - 0x1000, frame.rip);
                cur_t.user_stack_bottom -= 0x1000;
                user_map(cast(void*)cur_t.user_stack_bottom);
                return;
            }
        }
    }
    import kernel.syscall.util : is_safe_function;
    if (is_safe_function) printk(ERROR, " (in safe fn)");
    printk(ERROR, "ISR: {hex} code={hex}", isr, frame.error);
    printk(ERROR, "Frame: {hex}", frame);
    foreach (ref pg; cur_t.pages_that_we_own.data) {
        if (pg.isthere) {
            printk(" Page @ {ptr}", pg.addr);
        }
    }
    printk(ERROR, "in PID {}", cur_t.tid);
    if (isr == /* page fault */ 0x0e) printk(ERROR, "PF error: {}", cast(PageFaultError)frame.error);
    assert(false);
}

/// Handle an ISR
extern (C) void isrhandle_noec(ulong isr, ISRFrameNOEC* frame) {
    // isrhandle_ec(isr, &frame2);
    if (isr ==  /* timer */ 0x20) {
        pic_eoi();
        sched_yield();
        return;
    }
    if (isr == /* weird bochs thing */ 0x27) {
        return;
    }
    if (isr == /* invalid opcode */ 0x6) {
        // if the CPU has no SCE, we just trap #UDs from syscall.
        auto smoff = no_smap();
        ubyte[2] insn = [/* syscall */ 0x0f, 0x05];
        if (memcmp(cast(byte*)frame.rip, cast(byte*)insn.ptr, 2) == 0)  {
            smoff.die();
            frame.rip += 2;
            frame.rax = cast(ulong) syscall(frame.rdi, cast(void*)frame.rsi);
            return;
        }
    }
    printk(ERROR, "ISR: {hex}", isr);
    printk(ERROR, "Frame: {hex}", frame);
    assert(0);
    
}

/// An IDTR
extern (C) struct IDTR {
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

extern (C) private ulong* get_idt_targets();

extern (C) private struct IDTEntry {
    align(1) ushort pointer_low;
    align(1) ushort gdt_selector = 8;
    align(1) ubyte ist = 0;
    align(1) ubyte type = 0x8e;
    align(1) ushort pointer_middle;
    align(1) uint pointer_high;
    align(1) uint reserved;

    void addr(ulong addr) {
        pointer_low = cast(ushort) addr;
        pointer_middle = cast(ushort)(addr >> 16);
        pointer_high = addr >> 32;
    }
}

static assert(IDTEntry.sizeof == 16);
extern (C) private struct IDTRStruct {
    align(1) ushort length;
    align(1) ulong base;
}

private __gshared IDTEntry[256] idt;

/// Allocate an IDT and return its corresponding IDTR
IDTR new_idtr() {
    IDTR idtr;
    const ulong* targets = get_idt_targets();
    foreach (i; 0 .. 256) {
        idt[i].addr = targets[i];
        idt[i].ist = 0;
    }
    // idt[8].ist = 1;
    idtr.addr = cast(ulong) idt.ptr;
    idtr.size = 4096;
    return idtr;
}

private const ubyte PIC1 = 0x20;
private const ubyte PIC2 = 0xA0;
private const ubyte PIC1_COMMAND = PIC1;
private const ubyte PIC1_DATA = (PIC1 + 1);
private const ubyte PIC2_COMMAND = PIC2;
private const ubyte PIC2_DATA = (PIC2 + 1);

/// ICW4 (not) needed
private const ubyte ICW1_ICW4 = 0x01;
/// Single (cascade) mode
private const ubyte ICW1_SINGLE = 0x02;
/// Call address interval 4 (8)
private const ubyte ICW1_INTERVAL4 = 0x04;
/// Level triggered (edge) mode
private const ubyte ICW1_LEVEL = 0x08;
/// Initialization - required!
private const ubyte ICW1_INIT = 0x10;
/// 8086/88 (MCS-80/85) mode
private const ubyte ICW4_8086 = 0x01;
/// Auto (normal) EOI
private const ubyte ICW4_AUTO = 0x02;
/// Buffered mode/slave
private const ubyte ICW4_BUF_SLAVE = 0x08;
/// Buffered mode/master
private const ubyte ICW4_BUF_MASTER = 0x0C;
/// Special fully nested (not)
private const ubyte ICW4_SFNM = 0x10;

///
void remap(ubyte offset1, ubyte offset2) {

    outp(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4); // starts the initialization sequence (in cascade mode)
    outp(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    outp(PIC1_DATA, offset1); // ICW2: Master PIC vector offset
    outp(PIC2_DATA, offset2); // ICW2: Slave PIC vector offset
    outp(PIC1_DATA, 4); // ICW3: tell Master PIC that there is a slave PIC at IRQ2 (0000 0100)
    outp(PIC2_DATA, 2); // ICW3: tell Slave PIC its cascade identity (0000 0010)

    outp(PIC1_DATA, ICW4_8086);
    outp(PIC2_DATA, ICW4_8086);

    outp(PIC1_DATA, cast(ubyte)~0b0000_0001);
    outp(PIC2_DATA, cast(ubyte)~0b0000_0000);

    outp(0x43, 0x34);
    outp(0x40, cast(ubyte)(300 & 0xff));
    outp(0x40, cast(ubyte)(300 >> 16));

}

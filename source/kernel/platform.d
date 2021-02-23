module kernel.platform;

/// halt the CPU until an interrupt arrives
void hlt() {
    asm {
        hlt;
    }
}

/// are interrupts on?
bool intr() {
    ulong flags;
    asm {
        pushfq;
        pop RBX;
        mov flags, RBX;
    }
    return !!(flags & 0x200);
}


/// The I/O port mapped to QEMU's stdout
public const DEBUG_IO_PORT = 0x400;


private extern(C) struct Stackframe {
  Stackframe* rbp;
  ulong rip;
}
/// Do stack unwinding
void backtrace()
{
    Stackframe *stk;
    asm {
        mov stk, RBP;
    }
    import kernel.io : printk;
    printk("Stack trace:\n");
    for(;;)
    {
        // Unwind to previous stack frame
        printk("  {ptr}", stk.rip);
        if (stk.rbp == cast(Stackframe*)0) break;
        stk = stk.rbp;
    }
}
/// Reload CS
extern(C) void reload_cs();
extern(C) private __gshared int kend;
// Get kernel end
ulong get_kend() {
    return cast(ulong)&kend - 0xffffffff80000000;
}
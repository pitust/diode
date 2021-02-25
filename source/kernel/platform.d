module kernel.platform;

import kernel.optional;

/// A nothing
struct nothing {}

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

private extern (C) struct Stackframe {
    Stackframe* rbp;
    ulong rip;
}
/// Do stack unwinding
void backtrace() {
    Stackframe* stk;
    asm {
        mov stk, RBP;
    }
    import kernel.io : printk;

    printk("Stack trace:\n");
    for (;;) {
        // Unwind to previous stack frame
        printk("  {ptr}", stk.rip);
        if (stk.rbp == cast(Stackframe*) 0)
            break;
        stk = stk.rbp;
    }
}
/// Reload CS
extern (C) void reload_cs();
/// Get a random number
extern (C) ulong rdrandom();
extern (C) private __gshared int kend;
/// Get kernel end
ulong get_kend() {
    return cast(ulong)&kend - 0xffffffff80000000;
}

/// Atomically add
void atomic_add(ulong* target, ulong val) {
    asm {
        mov RAX, target;
        mov RBX, val;
        lock;
        add [RAX], RBX;
    }
}

/// Atomically sub
void atomic_sub(ulong* target, ulong val) {
    asm {
        mov RAX, target;
        mov RBX, val;
        lock;
        sub [RAX], RBX;
    }
}

/// Atomically xchg
ulong atomic_xchg(ulong* target, ulong val) {
    asm {
        mov RAX, target;
        mov RBX, val;
        lock;
        xchg [RAX], RBX;
        mov val, RBX;
    }
    return val;
}

/// A lock!
struct Lock {
    private ulong l = 0;
    /// Grab a lock
    void lock() {
        while (atomic_xchg(&this.l, 1)) {}
    }
    /// Unlock
    void unlock() {
        assert(atomic_xchg(&this.l, 0));
    }
}

/// A jump buffer
struct jmpbuf {
    private ulong rbx;
    private ulong rbp;
    private ulong r12;
    private ulong r13;
    private ulong r14;
    private ulong r15;
    private ulong rsp;
    private ulong rip;
    private ulong rsi;
}

/// Set Jump
extern(C) ulong setjmp(jmpbuf* buf);

/// Long Jump
extern(C) void longjmp(jmpbuf* buf, ulong value);
private __gshared Option!(jmpbuf*) _catch_assert = Option!(jmpbuf*).none();

/// Catch assertions from `fn`
Option!T catch_assert(T)(T function() fn) {
    assert(_catch_assert.is_none());
    jmpbuf j;
    if (setjmp(&j)) {
        _catch_assert = Option!(jmpbuf*).none();
        return Option!(T).none();
    }
    _catch_assert = Option!(jmpbuf*)(&j);
    T v = fn();
    _catch_assert = Option!(jmpbuf*).none();
    return Option!(T)(v);
}

/// Catch assertions from `fn`
Option!nothing catch_assert(void function() fn) {
    assert(_catch_assert.is_none());
    jmpbuf j;
    if (setjmp(&j)) {
        _catch_assert = Option!(jmpbuf*).none();
        return Option!(nothing).none();
    }
    _catch_assert = Option!(jmpbuf*)(&j);
    fn();
    nothing n;
    _catch_assert = Option!(jmpbuf*).none();
    return Option!(nothing)(n);
}

/// Internal assetion code
extern (C) void __assert(char* assertion, char* file, int line) {

    import kernel.io : putsk;
    import core.bitop : outp;
    import kernel.util : intToString;
    putsk("Kernel assertion failed: ");
    for (int i = 0; assertion[i] != 0; i++) {
        outp(DEBUG_IO_PORT, assertion[i]);
    }
    putsk(" at ");
    for (int i = 0; file[i] != 0; i++) {
        outp(DEBUG_IO_PORT, file[i]);
    }
    outp(DEBUG_IO_PORT, ':');
    char[70] buf;
    char* ptr = intToString(line, buf.ptr, 10);
    for (int i = 0; ptr[i] != 0; i++) {
        outp(DEBUG_IO_PORT, ptr[i]);
    }
    outp(DEBUG_IO_PORT, '\n');
    backtrace();
    if (_catch_assert.is_some()) {
        longjmp(*_catch_assert.unwrap(), 1);
    }
    for (;;) {
        hlt();
    }
}
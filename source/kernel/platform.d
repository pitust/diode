module kernel.platform;

import kernel.optional;

/// A nothing
struct nothing {
}

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
        if (stk.rbp == cast(Stackframe*) 0 || stk.rip == 0)
            break;
        if (stk.rip < 0xffffffff80000000) break;
        stk = stk.rbp;
    }
}
/// Reload CS
extern (C) void reload_cs();
private extern(C) ulong _rdrand();
private ulong _rdrand2() {
    ulong raw = 0;
    while (!raw) raw = _rdrand();
    return raw;
}
/// Get a random number
ulong rdrandom() {
    const ulong lo = _rdrand2();
    const ulong hi = _rdrand2();
    return (lo >> 32) | (hi & 0xffff_ffff_0000_0000);
}
private __gshared ulong seed = 0;
private __gshared ulong bk2 = 0;
private __gshared ulong step = 63;
/// Get a (cryptographicaly weak) random number
uint rdshortweakrandom() {
    step += 1;
    if (step == 64) {
        step = 0;
        seed ^= bk2 = rdrandom();
    }
    seed ^= bk2 << 1;
    const ulong bk2lsb = bk2 >> 63;
    bk2 <<= 1;
    bk2 |= bk2lsb;
    return seed & 0xffff_ffff;
}
/// Get a (cryptographicaly shit) random number
ulong rdweakrandom() {
    return (cast(ulong)rdshortweakrandom()) | ((cast(ulong)rdshortweakrandom()) << 32);
}

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
        while (atomic_xchg(&this.l, 1)) {
        }
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
extern (C) ulong setjmp(jmpbuf* buf);

/// Long Jump
extern (C) void longjmp(jmpbuf* buf, ulong value);
private __gshared Option!(jmpbuf*) _catch_assert = Option!(jmpbuf*)();

/// Catch assertions from `fn`
Option!T catch_assert(T, Args...)(T function(Args) fn, Args args) {
    Option!(jmpbuf*) _catch_assert_bak = _catch_assert;
    jmpbuf j;
    if (setjmp(&j)) {
        _catch_assert = Option!(jmpbuf*)();
        return Option!(T)();
    }
    _catch_assert = Option!(jmpbuf*)(&j);
    T v = fn(args);
    _catch_assert = *&_catch_assert_bak;
    return Option!(T)(v);
}

/// Internal assetion code
extern (C) void __assert(char* assertion, char* file, int line) {

    import kernel.io : putsk;
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
        longjmp(_catch_assert.unwrap(), 1);
    }
    for (;;) {
        hlt();
    }
}

/// Get the contents of the `rflags` register
ulong flags() {
    ulong f;
    asm {
        pushf;
        pop RAX;
        mov f, RAX;
    }
    return f;
}

/// Update the contents of the `rflags` register
void setflags(ulong flags) {
    asm {
        mov RAX, flags;
        push RAX;
        popf;
    }
}

/// Clear the interrupts
void cli() {
    asm {
        cli;
    }
}

/// Output a byte
void outp(ushort port, ubyte b) {
    asm {
        mov DX, port;
        mov AL, b;
        out DX, AL;
    }
}
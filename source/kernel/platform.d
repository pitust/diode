module kernel.platform;

import kernel.optional;
import ldc.attributes;

/// Call a system call
extern (C) void platform_sc(ulong sysno, void* data);
/// Branch to userland
extern (C) @safe void user_branch(ulong tgd, void* stack);
/// Set Jump
extern (C) @(llvmAttr("returns-twice"))
ulong setjmp(jmpbuf* buf);
/// Long Jump
extern (C) @(llvmAttr("noreturn"))
void longjmp(jmpbuf* buf, ulong value);
private __gshared Option!(jmpbuf*) _catch_assert = Option!(jmpbuf*)();
/// manipulate SMAP enable
pragma(mangle, "_stac") extern (C) void stac();
/// manipulate SMAP enable
pragma(mangle, "_clac") extern (C) void clac();

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
public const DEBUG_IO_PORT_NUM = 0xe9;

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
    import kernel.io : printk, FATAL;

    printk(FATAL, "Stack trace:");
    for (;;) {
        // Unwind to previous stack frame
        printk(FATAL, "  {ptr}", stk.rip);
        if (stk.rbp == cast(Stackframe*) 0 || stk.rip == 0)
            break;
        if (stk.rip < 0xffffffff80000000)
            break;
        if ((cast(ulong) stk.rbp) < 0xffffffff80000000)
            break;
        stk = stk.rbp;
    }
}

/// IA32_EFER
public const uint IA32_EFER = 0xC0000080;

/// IA32_EFER System Call Extensions
public const uint IA32_EFER_SCE = 1 << 0;
/// IA32_EFER Long Mode Enable
public const uint IA32_EFER_LME = 1 << 8;
/// IA32_EFER Long Mode Active
public const uint IA32_EFER_LMA = 1 << 10;
/// IA32_EFER No Execute Enable
public const uint IA32_EFER_NXE = 1 << 11;

///
public const uint IA32_STAR = 0xC0000081;
///
public const uint IA32_LSTAR = 0xC0000082;
///
public const uint IA32_SFMASK = 0xC0000084;

extern (C) long d_syscall(ulong a, ulong b) {
    import kernel.syscall.dispatch;

    return syscall(a, b);
}

/// Read an MSR
ulong rdmsr(uint msr) {
    ulong outp;
    asm {
        mov ECX, msr;
        rdmsr;
        shr RDX, 32;
        or RDX, RAX;
        mov outp, RDX;
    }
    return outp;
}

/// Write an MSR
void wrmsr(uint msr, ulong value) {
    uint lo = cast(uint) value;
    uint hi = cast(uint)(value >> 32);
    asm {
        mov ECX, msr;
        mov EAX, lo;
        mov EDX, hi;
        wrmsr;
    }
}

/// Reload CS
extern (C) void reload_cs();
private extern (C) ulong _rdrand();
private ulong _rdrand2() {
    ulong raw = 0;
    while (!raw)
        raw = _rdrand();
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
    return (cast(ulong) rdshortweakrandom()) | ((cast(ulong) rdshortweakrandom()) << 32);
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
struct lock {
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

    import kernel.io : FATAL, printk;
    import kernel.util : intToString;

    const ulong f = flags;
    cli();

    printk(FATAL, "Kernel assertion failed: {} at {}:{}", assertion, file + 3, line);
    backtrace();
    if (_catch_assert.is_some()) {
        flags = f;
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
void flags(ulong flags) {
    asm {
        mov RAX, flags;
        push RAX;
        popf;
    }
}

private extern (C) void* getrsp0();
private extern (C) void setrsp0(void* v);
private extern (C) void setist1(void* v);

/// Get the contents of `rsp0`
void* rsp0() {
    return getrsp0();
}
/// Update the contents of `ist1`
void ist1(void* v) {
    setist1(v);
}

/// Update the contents of `rsp0`
void rsp0(void* rsp0nv) {
    setrsp0(rsp0nv);
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

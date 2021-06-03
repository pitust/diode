module libsys.entry;

import libsys.io;
import libsys.mem;
import std.traits;
import libsys.util;
import libsys.syscall;
import vshared.share;

extern (C) int ___emain();

pragma(mangle, "_main") private extern (C) void usermain(ulong bgn, ulong end, void** elfbgn, void** elfend) {
    foreach (i; 0 .. ((end - bgn) / 8)) {
        alias initfn = extern(C) void function();
        (*cast(initfn*)((i * 8) + bgn))();
    }
    elfbase = elfbgn;
    elftop = elfend;

    commit_bigblk();
    ulong ec = cast(ulong) ___emain();
    sweep();
    syscall(Syscall.EXIT, &ec);
    assert(0);
}

mixin template entry(alias f) {
    static if (is(typeof(&f) == int function())) {
        private extern (C) int ___emain() {
            return f();
        }
    } else {
        private extern (C) int ___emain() {
            printf("t={}", f.stringof);
            f();
            return 0;
        }
    }
}

private void write(ref char* buf, char* s) {
    while (*s)
        write(buf, *(s++));
}

private void write(ref char* buf, immutable(char)* s) {
    while (*s)
        write(buf, *(s++));
}

private void write(ref char* buf, char c) {
    *(buf++) = c;
}

/// memset - fill memory with a constant byte
///
/// The memset() function fills the first len bytes of the memory 
/// area pointed to by mem with the constant byte data.
///
/// The memset() function returns a pointer to the memory area mem.
extern (C) byte* memset(byte* mem, int data, size_t len) {
    for (size_t i = 0; i < len; i++)
        mem[i] = cast(byte) data;
    return mem;
}

/// Do stack unwinding
private void do_backtrace() {
    import kernel.platform : Stackframe;
    Stackframe* stk;
    asm {
        mov stk, RBP;
    }
    import libsys.io : printf, FATAL;

    printf(FATAL, "Stack trace:");
    for (;;) {
        // Unwind to previous stack frame
        printf(FATAL, "  {hex}", stk.rip);
        if (stk.rbp == cast(Stackframe*) 0 || stk.rip == 0)
            break;
        if (stk.rip > 0xffffffff80000000)
            break;
        if ((cast(ulong) stk.rbp) > 0xfff8_0000_0000_0000)
            break;
        stk = stk.rbp;
    }
}

pragma(mangle, "__assert") extern (C) void cause_assert(immutable(char)* assertion, immutable(char)* file, int line) {
    char[512] buf;
    char[512] buf2;
    char* b = buf.ptr;
    write(b, ("[\x1b[31;1mFATAL\x1b[0m] " ~ __FILE__[3 .. __FILE__.length] ~ ":"
            ~ __LINE__.stringof ~ " User assertion failed: \0")
            .ptr);
    write(b, assertion);
    write(b, " at \0".ptr);
    write(b, file + 3);
    write(b, ":\0".ptr);
    write(b, intToString(line, buf2.ptr, 10));
    write(b, "\n\0".ptr);
    int le = cast(int)(b - buf.ptr);
    KPrintBuffer kbuf;
    kbuf.len = le;
    kbuf.ptr = buf.ptr;
    ulong exitcode = 127;
    syscall(Syscall.KPRINT, cast(void*)&kbuf);
    do_backtrace();
    syscall(Syscall.EXIT, &exitcode);
    while (1) {
    }
}


/// memcpy - copy memory area
///
/// The  memcpy() function copies n bytes from memory area src to memory area dest.
/// The memory areas must not overlap. Use memmove(3) if the memory
/// areas do overlap.
///
/// The memcpy() function returns a pointer to dest.
extern (C) byte* memcpy(byte* dst, const byte* src, size_t n) {
    size_t i = 0;
    while (i + 8 <= n) {
        *(cast(ulong*)(&dst[i])) = *(cast(ulong*)(&src[i]));
        i += 8;
    }
    while (i + 4 <= n) {
        *(cast(uint*)(&dst[i])) = *(cast(uint*)(&src[i]));
        i += 4;
    }
    while (i + 2 <= n) {
        *(cast(ushort*)(&dst[i])) = *(cast(ushort*)(&src[i]));
        i += 2;
    }
    while (i + 1 <= n) {
        *(cast(byte*)(&dst[i])) = *(cast(byte*)(&src[i]));
        i += 1;
    }
    return dst;
}
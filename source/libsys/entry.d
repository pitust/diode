module libsys.entry;

import libsys.io;
import std.traits;
import libsys.util;
import libsys.syscall;
import vshared.share;

extern (C) int ___emain();

pragma(mangle, "_main") private extern (C) void usermain() {
    // syscall(Syscall.SEND, 
    ulong ec = cast(ulong) ___emain();
    syscall(Syscall.EXIT, &ec);
    assert(0);
}

mixin template entry(alias f) {
    static if (is(ReturnType!(f) == int)) {
        private extern (C) int ___emain() {
            return f();
        }
    } else {
        private extern (C) int ___emain() {
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
extern (C) byte* memset(byte* mem, byte data, size_t len) {
    for (size_t i = 0; i < len; i++)
        mem[i] = data;
    return mem;
}

private extern (C) void __assert(char* assertion, char* file, int line) {
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
    kbuf.len = le - 1;
    kbuf.ptr = buf.ptr;
    ulong exitcode = 127;
    syscall(Syscall.KPRINT, cast(void*)&kbuf);
    syscall(Syscall.EXIT, &exitcode);
    while (1) {
    }
}

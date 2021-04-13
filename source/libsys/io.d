module libsys.io;

import core.vararg;
import core.volatile;
import std.traits;
import std.algorithm;
import libsys.syscall;
import vshared.share;
import libsys.util;

/// puts_const_str is like puts but for const(string)
void puts_const_str(const(string) s) {
    foreach (chr; s) {
        if (chr == 0)
            break;
        putc(chr);
    }
}

/// puts_const_str is like puts but for const(string)
void puts_const_str(string s) {
    foreach (chr; s) {
        if (chr == 0)
            break;
        putc(chr);
    }
}

/// puts is a dumb version of printf (with no newline!)
void puts(char* s) {
    for (int i = 0; s[i] != 0; i++) {
        putc(s[i]);
    }
}

/// puts is a dumb version of printf (with no newline!)
void puts(immutable(char)[] s) {
    foreach (chr; s) {
        putc(chr);
    }
}

/// puts is a dumb version of printf (with no newline!)
private void puts_string(T)(T s) {
    foreach (chr; s) {
        putc(chr);
    }
}

private __gshared char[128] buf;
private __gshared int buf_idx = 0;

/// Flush the I/O buffer
void flush() {
    KPrintBuffer kbuf;
    kbuf.len = buf_idx;
    kbuf.ptr = buf.ptr;
    syscall(Syscall.KPRINT, cast(void*)&kbuf);
    buf_idx = 0;
}

/// putc prints a char (buffered)
extern(C) void putc(char c) {
    if (c != 0) {
        if (buf_idx >= 128) flush();
        buf[buf_idx++] = c;
        if (c == '\n') flush();
    }
}

/// puts is a dumb version of printf (with no newline!)
void puts(T)(T s) {
    static assert(is(Unqual!(T) : ArrayMarker!char));
    foreach (char chr; s) {
        putc(chr);
    }
}

/// puts is a dumb version of printf (with no newline!)
void puts(char s) {
    putc(s);
}

private struct EnumMarker {

}

private struct ArrayMarker(T) {
}

private struct IOIterMarker(T) {
}

/// A hex printer for `T`
extern (C) struct Hex(T) {
    /// The value of the `hex`
    align(T.alignof) T inner;
    /// Create a new Hex
    this(T inner) {
        this.inner = inner;
    }
}

private template isEnum(alias symb) {
    static if (is(symb == enum))
        enum bool isEnum = true;
    else
        enum bool isEnum = false;
}

private template Unqual(T) {
    static if (is(T U == shared(const U)))
        alias Unqual = U;
    else static if (is(T U == const U))
        alias Unqual = U;
    else static if (is(T U == immutable U))
        alias Unqual = U;
    else static if (is(T U == shared U))
        alias Unqual = U;
    else static if (is(T == string))
        alias Unqual = ArrayMarker!char;
    else static if (__traits(hasMember, T, "ioiter"))
        alias Unqual = IOIterMarker!(ReturnType!(__traits(getMember, T, "ioiter")));
    else static if (isArray!(T)) {
        alias Unqual = ArrayMarker!(typeof(T.init[0]));
    } else static if (isEnum!(T))
        alias Unqual = EnumMarker;
    else
        alias Unqual = T;
}

private template UnPtr(T) {
    static if (is(T U == U*))
        alias UnPtr = void*;
    else
        alias UnPtr = T;
}

private template Deref(T) {
    static if (is(T U == U*))
        alias Deref = Deref(U);
    else
        alias Deref = T;
}

private void _printf_outint(string subarray, ulong arg, bool bare = false) {
    int pad = 0;
    int base = 10;
    switch (subarray) {
    case "_chr_oob":
        base = 16;
        pad = 2;
        break;
    case "hex":
        if (!bare)
            puts("0x");
        base = 16;
        break;
    case "ptr":
        if (!bare)
            puts("0x");
        base = 16;
        pad = 16;
        break;
    case "":
        break;
    case "oct":
        if (!bare)
            puts("0o");
        base = 8;
        break;
    case "bin":
        if (!bare)
            puts("0b");
        base = 2;
        break;
    default:
        assert(false);
    }
    char[70] arr;
    char* arr_offset_correctly = intToString(arg, arr.ptr, base);
    const long arr_offset_correctly_len = strlen(arr_offset_correctly);
    const long pad_needed = max(0, pad - arr_offset_correctly_len);
    for (int i = 0; i < pad_needed; i++)
        puts('0');
    puts(arr_offset_correctly);
}

private void _printf_outint(string subarray, long arg) {
    int pad = 0;
    int base = 10;
    switch (subarray) {
    case "hex":
        puts("0x");
        base = 16;
        break;
    case "ptr":
        puts("0x");
        base = 16;
        pad = 8;
        break;
    case "":
        break;
    case "oct":
        puts("0o");
        base = 8;
        break;
    case "bin":
        base = 2;
        puts("0b");
        break;
    default:
        assert(false);
    }
    char[70] arr;
    char* arr_offset_correctly = intToString(arg, arr.ptr, base);
    const long arr_offset_correctly_len = strlen(arr_offset_correctly);
    const long pad_needed = max(0, pad - arr_offset_correctly_len);
    for (int i = 0; i < pad_needed; i++)
        puts('0');
    puts(arr_offset_correctly);
}

private template GetOMeta(string Target) {
    const char[] GetOMeta = "OMeta meta = arg._ometa_" ~ Target ~ ";";
}

private template HasOMeta(string Target) {
    const char[] HasOMeta = "__traits(compiles, arg._ometa_" ~ Target ~ ")";
}
/// An O-Meta
struct OMeta {
    /// Should we ignore the value? If yes, print `fmt`
    bool ignore = false;
    /// Should we _fully_ ignore the value?
    bool nuke = false;
    /// The format string for this O-Meta
    string fmt = "";
    /// Should we print it raw?
    bool print_raw = false;
    /// Internal print skipper
    byte _oskip = 0;
}
/// Get a hex printer O-Meta
OMeta hex_ometa() {
    OMeta m;
    m.fmt = "hex";
    m.print_raw = false;
    return m;
}
/// Get a hex printer O-Meta
OMeta disabler_ometa() {
    OMeta m;
    m.nuke = true;
    return m;
}
/// Get a pointer printer O-Meta
OMeta ptr_ometa() {
    OMeta m;
    m.fmt = "ptr";
    m.print_raw = false;
    return m;
}

unittest {
    printf("Test printf [short]: {}", cast(short) 3);
    printf("Test printf [ushort]: {}", cast(ushort) 3);
    printf("Test printf [int]: {}", cast(int) 3);
    printf("Test printf [uint]: {}", cast(uint) 3);
    printf("Test printf [long]: {}", cast(long) 3);
    printf("Test printf [ulong]: {}", cast(ulong) 3);
    printf("Test printf [string]: {}", "asdf");
    printf("Test printf [char*]: {}", "asdf".ptr);
}

/// Print an object!
void putdyn(ObjTy)(string subarray, ObjTy arg, int prenest = 0, bool is_field = false) {
    ObjTy arg2 = arg;
    putdyn(subarray, arg2, prenest, is_field);
}

/// Print an object!
void putdyn(ObjTy)(string subarray, ref ObjTy arg, int prenest = 0, bool is_field = false) {
    if (subarray == ":?") {
        subarray = "";
        is_field = true;
    }
    alias T = Unqual!(typeof(arg));
    static if (is(T : const char[])) {
        assert(subarray == "");
        if (is_field) {
            puts('"');
            foreach (chr; arg) {
                if (chr == '\n') {
                    puts("\\n");
                } else if (chr > 0x7e || chr < 0x20) {
                    puts("\\x");
                    _printf_outint("_chr_oob", cast(ulong) chr);
                } else {
                    puts(chr);
                }
            }
            puts('"');
        } else {
            puts_string(arg);
        }
    }
    static if (is(T == EnumMarker)) {
        static foreach (k; __traits(allMembers, ObjTy)) {
            {
                if (__traits(getMember, ObjTy, k) == arg) {
                    puts_string(k);
                    return;
                }
            }
        }
        // it's a bitfield
        putc('[');
        bool do_space = true;
        static foreach (k; __traits(allMembers, ObjTy)) {
            {
                if (__traits(getMember, ObjTy, k) & arg) {
                    if (do_space) {
                        do_space = false;
                        putc(' ');
                    }
                    puts_string(k);
                    putc(' ');
                }
            }
        }
        putc(']');
    } else static if (is(T : const char*)) {
        assert(subarray == "");
        if (is_field) {
            puts('"');
            for (int i = 0; arg[i]; i++) {
                if (arg[i] == '\n') {
                    puts("\\n");
                } else if (arg[i] > 0x7e || arg[i] < 0x20) {
                    puts("\\x");
                    _printf_outint("_chr_oob", cast(ulong) arg[i]);
                } else {
                    puts(arg[i]);
                }
            }
            puts('"');
        } else {
            for (int i = 0; arg[i]; i++) {
                putc(arg[i]);
            }
        }
    } else static if (is(T : ArrayMarker!char)) {
        if (is_field) {
            puts('"');
            foreach (chr; arg) {
                if (chr == '\n') {
                    puts("\\n");
                } else if (chr > 0x7e || chr < 0x20) {
                    puts("\\x");
                    _printf_outint("_chr_oob", cast(ulong) chr);
                } else {
                    puts(chr);
                }
            }
            puts('"');
        } else {
            puts_string(arg);
        }
    } else static if (is(T == char)) {
        puts("'");
        if (arg == '\n') {
            puts("\\n");
        } else if (arg > 0x7e || arg < 0x20) {
            puts("\\x");
            _printf_outint("_chr_oob", cast(ulong) arg);
        } else {
            puts(arg);
        }
        puts("'");
    } else static if (is(T U == Hex!U)) {
        assert(subarray == "");
        putdyn("hex", arg.inner, prenest, is_field);
    } else static if (is(T == byte)) {
        _printf_outint(subarray, cast(long) arg);
    } else static if (is(T == ubyte)) {
        _printf_outint(subarray, cast(ulong) arg);
    } else static if (is(T == int)) {
        _printf_outint(subarray, cast(long) arg);
    } else static if (is(T == uint)) {
        _printf_outint(subarray, cast(ulong) arg);
    } else static if (is(T == short)) {
        _printf_outint(subarray, cast(long) arg);
    } else static if (is(T == ushort)) {
        _printf_outint(subarray, cast(ulong) arg);
    } else static if (is(T == long)) {
        _printf_outint(subarray, arg);
    } else static if (is(T == ulong)) {
        _printf_outint(subarray, arg);
    } else static if (is(T == bool)) {
        puts(arg ? "true" : "false");
    } else static if (is(T == void)) {
        puts("void");
    } else static if (is(T == void*)) {
        assert(subarray == "");
        _printf_outint("ptr", cast(ulong) arg);
    } else static if (is(T U == ArrayMarker!U)) {
        puts('[');
        bool is_first = true;
        foreach (member; arg) {
            if (is_first) {
                puts('\n');
                for (int i = 0; i < prenest; i++) {
                    puts(" ");
                }
                is_first = false;
            }
            puts("    ");
            {
                putdyn(subarray, member, prenest + 4, true);
            }
            puts('\n');
            for (int i = 0; i < prenest; i++) {
                puts(" ");
            }
        }
        puts(']');
    } else static if (is(T U == IOIterMarker!U)) {
        puts('[');
        bool is_first = true;
        int max_counter = 0;
        foreach (member; arg.ioiter()) {
            max_counter++;
            if (max_counter > 15) {
                puts("   ... snip");
                puts('\n');
                for (int i = 0; i < prenest; i++) {
                    puts(" ");
                }
                break;
            }
            if (is_first) {
                puts('\n');
                for (int i = 0; i < prenest; i++) {
                    puts(" ");
                }
                is_first = false;
            }
            puts("    ");
            {
                putdyn(subarray, member, prenest + 4, true);
            }
            puts('\n');
            for (int i = 0; i < prenest; i++) {
                puts(" ");
            }
        }
        puts(']');
    } else static if (is(T U == Option!U)) {
        if (arg.is_some()) {
            puts("Some(");
            putdyn(subarray, arg.unwrap(), prenest, true);
            puts(")");
        } else {
            assert(arg.is_none());
            puts("None");
        }
    } else {
        alias U = UnPtr!(T);
        static if (is(U == void*) && __traits(hasMember, T, "__hide_deref")) {
            if (cast(ulong) arg != 0) {
                putdyn(subarray, *arg, prenest);
            } else {
                puts("(null)");
            }
        } else static if (is(U == void*)) {
            string asdf = T.stringof;
            puts_const_str(asdf);
            puts(" @ ");
            _printf_outint("ptr", cast(ulong) arg);
            if (cast(ulong) arg != 0) {
                puts(" ");
                putdyn(subarray, *arg, prenest);
            }
        } else {
            static if (__traits(hasMember, T, "opFormat")) {
                putdyn(subarray, T.opFormat(), prenest);
            } else static if (__traits(hasMember, T, "opFormatter")) {
                arg.opFormatter(subarray, prenest);
            } else {
                puts('{');
                bool is_first = true;
                static foreach (member; [__traits(allMembers, T)]) {
                    static if (member.length > 6 && member[0 .. 6] == "_prnt_") {
                        if (is_first) {
                            puts('\n');
                            for (int i = 0; i < prenest; i++) {
                                puts(" ");
                            }
                            is_first = false;
                        }
                        puts("    ");
                        puts(member[6 .. member.length]);
                        puts(": ");
                        __traits(getMember, arg, member)(subarray, prenest + 4);
                        puts('\n');
                        for (int i = 0; i < prenest; i++) {
                            puts(" ");
                        }
                    } else static if (!isCallable!(__traits(getMember, arg, member)) && __traits(compiles, putdyn(
                            subarray, __traits(getMember, arg,
                            member), prenest + 4, true))) {
                        static if (!__traits(compiles, __traits(getMember, arg, member)
                                ._oskip) && !__traits(hasMember, arg, "__noshow_" ~ member)) {
                            if (is_first) {
                                puts('\n');
                                for (int i = 0; i < prenest; i++) {
                                    puts(" ");
                                }
                                is_first = false;
                            }
                            puts("    ");
                            puts(member);
                            puts(": ");
                            static if (mixin(HasOMeta!(member))) {
                                {
                                    mixin(GetOMeta!(member));
                                    putdyn(meta.fmt, __traits(getMember, arg,
                                            member), prenest + 4, meta.print_raw);
                                }
                            } else {
                                putdyn(subarray, __traits(getMember, arg,
                                        member), prenest + 4, true);
                            }
                            puts('\n');
                            for (int i = 0; i < prenest; i++) {
                                puts(" ");
                            }
                        }
                    }
                }
                puts('}');
            }
        }
    }
}

/// Log level
enum Log {
    DEBUG,
    INFO,
    WARN,
    ERROR,
    FATAL,
}

/// Debug
public const Log DEBUG = Log.DEBUG;
/// Info
public const Log INFO = Log.INFO;
/// Warn
public const Log WARN = Log.WARN;
/// Error
public const Log ERROR = Log.ERROR;
/// Fatal
public const Log FATAL = Log.FATAL;

private template Digit(uint n) {
    public __gshared enum char[] Digit = [("0123456789"[n .. n + 1])[0]];
}

private template Itoa(uint n) {
    static if (n < 0)
        public __gshared const char[] Itoa = "-" ~ Itoa!(-n);
    else static if (n < 10)
        public __gshared const char[] Itoa = Digit!(n);
    else
        public __gshared const char[] Itoa = Itoa!(n / 10) ~ Digit!(n % 10);
}

private __gshared ulong lineno_max = 3;

/// Print a string
void printf(string A = __FILE__, int L = __LINE__, Args...)(Log l, string s, Args args) {
    printf(L, A, l, s, args);
}
/// Print a string
void printf(Args...)(int L, string A, Log l, string s, Args args) {
    version(DiodeNoDebug) {
        if (l == Log.DEBUG) return;
    }
    ulong maxl = 4;
    putc('[');
    switch (l) {
    case DEBUG:
        puts("\x1b[30;1mDEBUG");
        maxl = 5;
        break;
    case INFO:
        puts("\x1b[32;1mINFO");
        break;
    case WARN:
        puts("\x1b[33;1mWARN");
        break;
    case ERROR:
        puts("\x1b[31;1mERROR");
        maxl = 5;
        break;
    case FATAL:
        puts("\x1b[31;1mFATAL");
        maxl = 5;
        break;
    default:
        printf(FATAL, "Invalid level: {}", cast(int) l);
        assert(0);
    }
    puts("\x1b[0m] ");
    puts_string(A[3 .. A.length]);
    puts(":");
    char[32] buffer;
    char* asds = intToString(L, buffer.ptr, 10);
    puts(asds);
    putc(' ');
    ulong asdslength = strlen(asds);
    if (lineno_max < asdslength)
        lineno_max = asdslength;
    for (ulong i = asdslength; i < lineno_max; i++)
        putc(' ');

    int offinit = cast(int)(lineno_max + A.length - 5 + maxl);

    int idx_into_s = 0;
    foreach (arg; args) {

        // advance s
        while (s[idx_into_s] != '{')
            putc(s[idx_into_s++]);
        const int og_idx = idx_into_s + 1;
        while (s[idx_into_s++] != '}') {
        }
        const string subarray = s[og_idx .. idx_into_s - 1];

        putdyn(subarray, arg, offinit);
    }
    while (idx_into_s < s.length)
        putc(s[idx_into_s++]);
    putc('\n');
}

/// Print a string
void printf(string A = __FILE__, int L = __LINE__, Args...)(string s, Args args) {
    printf!(A, L, Args)(INFO, s, args);
}

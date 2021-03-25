module kernel.io;

import core.vararg;
import core.volatile;
import std.traits;
import std.algorithm;

import kernel.optional;
import kernel.platform;
import kernel.util;

/// putsk_const_str is like putsk but for const(string)
void putsk_const_str(const(string) s) {
    foreach (chr; s) {
        if (chr == 0)
            break;
        putck(chr);
    }
}

/// putsk_const_str is like putsk but for const(string)
void putsk_const_str(string s) {
    foreach (chr; s) {
        if (chr == 0)
            break;
        putck(chr);
    }
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(char* s) {
    for (int i = 0; s[i] != 0; i++) {
        putck(s[i]);
    }
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(immutable(char)[] s) {
    foreach (chr; s) {
        putck(chr);
    }
}

/// putsk is a dumb version of printk (with no newline!)
private void putsk_string(T)(T s) {
    foreach (chr; s) {
        putck(chr);
    }
}

/// putck prints a char (cough cough outp(DEBUG_IO_PORT, chr) cough)
void putck(char c) {
    if (c != 0) {
        outp(DEBUG_IO_PORT_NUM, c);
    }
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(T)(T s) {
    static assert(is(Unqual!(T) : ArrayMarker!char));
    foreach (char chr; s) {
        putck(chr);
    }
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(char s) {
    putck(s);
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
    } else
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

private void _printk_outint(string subarray, ulong arg, bool bare = false) {
    int pad = 0;
    int base = 10;
    switch (subarray) {
    case "_chr_oob":
        base = 16;
        break;
    case "hex":
        if (!bare)
            putsk("0x");
        base = 16;
        break;
    case "ptr":
        if (!bare)
            putsk("0x");
        base = 16;
        pad = 16;
        break;
    case "":
        break;
    case "oct":
        if (!bare)
            putsk("0o");
        base = 8;
        break;
    case "bin":
        if (!bare)
            putsk("0b");
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
        putsk('0');
    putsk(arr_offset_correctly);
}

private void _printk_outint(string subarray, long arg) {
    int pad = 0;
    int base = 10;
    switch (subarray) {
    case "hex":
        putsk("0x");
        base = 16;
        break;
    case "ptr":
        putsk("0x");
        base = 16;
        pad = 8;
        break;
    case "":
        break;
    case "oct":
        putsk("0o");
        base = 8;
        break;
    case "bin":
        base = 2;
        putsk("0b");
        break;
    default:
        assert(false);
    }
    char[70] arr;
    char* arr_offset_correctly = intToString(arg, arr.ptr, base);
    const long arr_offset_correctly_len = strlen(arr_offset_correctly);
    const long pad_needed = max(0, pad - arr_offset_correctly_len);
    for (int i = 0; i < pad_needed; i++)
        putsk('0');
    putsk(arr_offset_correctly);
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
    printk("Test printk [short]: {}", cast(short) 3);
    printk("Test printk [ushort]: {}", cast(ushort) 3);
    printk("Test printk [int]: {}", cast(int) 3);
    printk("Test printk [uint]: {}", cast(uint) 3);
    printk("Test printk [long]: {}", cast(long) 3);
    printk("Test printk [ulong]: {}", cast(ulong) 3);
    printk("Test printk [string]: {}", "asdf");
    printk("Test printk [char*]: {}", "asdf".ptr);
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
            putsk('"');
            foreach (chr; arg) {
                if (chr == '\n') {
                    putsk("\\n");
                } else if (chr > 0x7f || chr < 0x20) {
                    putsk("\\x");
                    _printk_outint("_chr_oob", cast(ulong) chr);
                } else {
                    putsk(chr);
                }
            }
            putsk('"');
        } else {
            putsk_string(arg);
        }
    } else static if (is(T : const char*)) {
        assert(subarray == "");
        if (is_field) {
            putsk('"');
            for (int i = 0; arg[i]; i++) {
                if (arg[i] == '\n') {
                    putsk("\\n");
                } else if (arg[i] > 0x7f || arg[i] < 0x20) {
                    putsk("\\x");
                    _printk_outint("_chr_oob", cast(ulong) arg[i]);
                } else {
                    putsk(arg[i]);
                }
            }
            putsk('"');
        } else {
            for (int i = 0; arg[i]; i++) {
                putck(arg[i]);
            }
        }
    } else static if (is(T : ArrayMarker!char)) {
        assert(subarray == "");
        if (is_field) {
            putsk('"');
            foreach (chr; arg) {
                if (chr == '\n') {
                    putsk("\\n");
                } else if (chr > 0x7f || chr < 0x20) {
                    putsk("\\x");
                    _printk_outint("_chr_oob", cast(ulong) chr);
                } else {
                    putsk(chr);
                }
            }
            putsk('"');
        } else {
            putsk_string(arg);
        }
    } else static if (is(T == char)) {
        putsk("'");
        if (arg == '\n') {
            putsk("\\n");
        } else if (arg > 0x7f || arg < 0x20) {
            putsk("\\x");
            _printk_outint("_chr_oob", cast(ulong) arg);
        } else {
            putsk(arg);
        }
        putsk("'");
    } else static if (is(T U == Hex!U)) {
        assert(subarray == "");
        putdyn("hex", arg.inner, prenest, is_field);
    } else static if (is(T == byte)) {
        _printk_outint(subarray, cast(long) arg);
    } else static if (is(T == ubyte)) {
        _printk_outint(subarray, cast(ulong) arg);
    } else static if (is(T == int)) {
        _printk_outint(subarray, cast(long) arg);
    } else static if (is(T == uint)) {
        _printk_outint(subarray, cast(ulong) arg);
    } else static if (is(T == short)) {
        _printk_outint(subarray, cast(long) arg);
    } else static if (is(T == ushort)) {
        _printk_outint(subarray, cast(ulong) arg);
    } else static if (is(T == long)) {
        _printk_outint(subarray, arg);
    } else static if (is(T == ulong)) {
        _printk_outint(subarray, arg);
    } else static if (is(T == bool)) {
        putsk(arg ? "true" : "false");
    } else static if (is(T == void)) {
        putsk("void");
    } else static if (is(T == void*)) {
        assert(subarray == "");
        _printk_outint("ptr", cast(ulong) arg);
    } else static if (is(T U == ArrayMarker!U)) {
        putsk('[');
        bool is_first = true;
        foreach (member; arg) {
            if (is_first) {
                putsk('\n');
                for (int i = 0; i < prenest; i++) {
                    putsk(" ");
                }
                is_first = false;
            }
            putsk("    ");
            {
                putdyn("", member, prenest + 4, true);
            }
            putsk('\n');
            for (int i = 0; i < prenest; i++) {
                putsk(" ");
            }
        }
        putsk(']');
    } else static if (is(T U == IOIterMarker!U)) {
        putsk('[');
        bool is_first = true;
        int max_counter = 0;
        foreach (member; arg.ioiter()) {
            max_counter++;
            if (max_counter > 15) {
                putsk("   ... snip");
                putsk('\n');
                for (int i = 0; i < prenest; i++) {
                    putsk(" ");
                }
                break;
            }
            if (is_first) {
                putsk('\n');
                for (int i = 0; i < prenest; i++) {
                    putsk(" ");
                }
                is_first = false;
            }
            putsk("    ");
            {
                putdyn(subarray, member, prenest + 4, true);
            }
            putsk('\n');
            for (int i = 0; i < prenest; i++) {
                putsk(" ");
            }
        }
        putsk(']');
    } else static if (is(T U == Option!U)) {
        if (arg.is_some()) {
            putsk("Some(");
            putdyn(subarray, arg.unwrap(), prenest, true);
            putsk(")");
        } else {
            assert(arg.is_none());
            putsk("None");
        }
    } else {
        alias U = UnPtr!(T);
        static if (is(U == void*) && __traits(hasMember, T, "__hide_deref")) {
            if (cast(ulong) arg != 0) {
                putdyn(subarray, *arg, prenest);
            } else {
                putsk("(null)");
            }
        } else static if (is(U == void*)) {
            string asdf = T.stringof;
            putsk_const_str(asdf);
            putsk(" @ ");
            _printk_outint("ptr", cast(ulong) arg);
            if (cast(ulong) arg != 0) {
                putsk(" ");
                putdyn(subarray, *arg, prenest);
            }
        } else {
            static if (__traits(hasMember, T, "opFormat")) {
                putdyn(subarray, T.opFormat(), prenest);
            } else static if (__traits(hasMember, T, "opFormatter")) {
                arg.opFormatter(subarray, prenest);
            } else {
                putsk('{');
                bool is_first = true;
                static foreach (member; [__traits(allMembers, T)]) {
                    static if (member.length > 6 && member[0 .. 6] == "_prnt_") {
                        if (is_first) {
                            putsk('\n');
                            for (int i = 0; i < prenest; i++) {
                                putsk(">");
                            }
                            is_first = false;
                        }
                        putsk("    ");
                        putsk(member[6 .. member.length]);
                        putsk(": ");
                        __traits(getMember, arg, member)(subarray, prenest + 4);
                        putsk('\n');
                        for (int i = 0; i < prenest; i++) {
                            putsk(" ");
                        }
                    } else static if (!isCallable!(__traits(getMember, arg, member))) {
                        static if (!__traits(compiles, __traits(getMember, arg, member)
                                ._oskip) && !__traits(hasMember, arg, "__noshow_" ~ member)) {
                            if (is_first) {
                                putsk('\n');
                                for (int i = 0; i < prenest; i++) {
                                    putsk(" ");
                                }
                                is_first = false;
                            }
                            putsk("    ");
                            putsk(member);
                            putsk(": ");
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
                            putsk('\n');
                            for (int i = 0; i < prenest; i++) {
                                putsk(" ");
                            }
                        }
                    }
                }
                putsk('}');
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
void printk(string A = __FILE__, int L = __LINE__, Args...)(Log l, string s, Args args) {
    const ulong f = flags;
    cli();
    ulong maxl = 4;
    putck('[');
    switch (l) {
    case DEBUG:
        putsk("\x1b[30;1mDEBUG");
        break;
    case INFO:
        putsk("\x1b[32;1mINFO");
        break;
    case WARN:
        putsk("\x1b[33;1mWARN");
        break;
    case ERROR:
        putsk("\x1b[31;1mERROR");
        maxl = 5;
        break;
    case FATAL:
        putsk("\x1b[31;1mFATAL");
        maxl = 5;
        break;
    default:
        printk(FATAL, "Invalid level: {}", cast(int)l);
        assert(0);
    }
    putsk("\x1b[0m] ");
    putsk_string(A[7 .. A.length]);
    putsk(":");
    const(char[]) asds = Itoa!L;
    foreach (c; asds) {
        putck(c);
    }
    putck(' ');
    if (lineno_max < asds.length)
        lineno_max = asds.length;
    for (ulong i = asds.length; i < lineno_max; i++)
        putck(' ');

    int offinit = cast(int)(lineno_max + A.length - 2 + maxl);

    int idx_into_s = 0;
    foreach (arg; args) {

        // advance s
        while (s[idx_into_s] != '{')
            putck(s[idx_into_s++]);
        const int og_idx = idx_into_s + 1;
        while (s[idx_into_s++] != '}') {
        }
        const string subarray = s[og_idx .. idx_into_s - 1];

        putdyn(subarray, arg, offinit);
    }
    while (idx_into_s < s.length)
        putck(s[idx_into_s++]);
    putck('\n');
    flags = f;
}

/// Print a string
void printk(string A = __FILE__, int L = __LINE__, Args...)(string s, Args args) {
    printk!(A, L, Args)(INFO, s, args);
}

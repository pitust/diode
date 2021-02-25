module kernel.io;

import core.bitop;
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
        outp(DEBUG_IO_PORT, chr);
    }
}

/// putsk_const_str is like putsk but for const(string)
void putsk_const_str(string s) {
    foreach (chr; s) {
        if (chr == 0)
            break;
        outp(DEBUG_IO_PORT, chr);
    }
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(char* s) {
    for (int i = 0; s[i] != 0; i++) {
        outp(DEBUG_IO_PORT, s[i]);
    }
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(T)(T s) {
    static assert(is(Unqual!(T) : ArrayMarker!char));
    foreach (char chr; s) {
        outp(DEBUG_IO_PORT, chr);
    }
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(char s) {
    outp(DEBUG_IO_PORT, s);
}

/// putsk is a dumb version of printk (with no newline!)
void putsk(immutable(char)* s) {
    for (int i = 0; s[i] != 0; i++) {
        outp(DEBUG_IO_PORT, s[i]);
    }
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
    else static if (__traits(hasMember, T, "ioiter"))
        alias Unqual = IOIterMarker!(ReturnType!(__traits(getMember, T, "ioiter")));
    else static if (__traits(isStaticArray, T)) {
        static if (is(T U == U[0])) {
            alias Unqual = ArrayMarker!U;
        } else {
            alias Unqual = ArrayMarker!(typeof(T[0]));
        }
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

private void putdyn(ObjTy)(string subarray, ObjTy arg, int prenest = 0, bool is_field = false) {
    if (subarray == ":?") {
        subarray = "";
        is_field = true;
    }
    pragma(msg, "=> putdyn: ", typeof(arg));
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
            putsk_const_str(arg);
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
            putsk(arg);
        }
    } else static if (is(T : ArrayMarker!char)) {
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
            putsk(arg);
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
                    putsk("   ");
                }
                is_first = false;
            }
            putsk("   ");
            {
                putdyn("", member, prenest + 1, true);
            }
            putsk('\n');
            for (int i = 0; i < prenest; i++) {
                putsk("   ");
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
                    putsk("   ");
                }
                break;
            }
            if (is_first) {
                putsk('\n');
                for (int i = 0; i < prenest; i++) {
                    putsk("   ");
                }
                is_first = false;
            }
            putsk("   ");
            {
                putdyn("", member, prenest + 1, true);
            }
            putsk('\n');
            for (int i = 0; i < prenest; i++) {
                putsk("   ");
            }
        }
        putsk(']');
    } else static if (is(T U == Option!U)) {
        if (arg.is_some()) {
            putsk("Some(");
            putdyn(subarray, *arg.unwrap(), prenest, true);
            putsk(")");
        } else {
            assert(arg.is_none());
            putsk("None");
        }
    } else {
        alias U = UnPtr!(T);
        static if (is(U == void*)) {
            string asdf = T.stringof;
            putsk_const_str(asdf);
            putsk(" @ ");
            _printk_outint("ptr", cast(ulong) arg);
            if (cast(ulong) arg != 0) {
                putsk(" ");
                putdyn("", *arg, prenest);
            }
        } else {
            static if (__traits(hasMember, T, "opFormat")) {
                putdyn(subarray, T.opFormat(), prenest);
            } else {
                putsk('{');
                bool is_first = true;
                static foreach (member; [__traits(allMembers, T)]) {
                    static if (__traits(compiles, putdyn("",
                            __traits(getMember, arg, member), prenest + 1, true))) {
                        static if (!__traits(compiles, __traits(getMember, arg, member)._oskip)) {
                            if (is_first) {
                                putsk('\n');
                                for (int i = 0; i < prenest; i++) {
                                    putsk("   ");
                                }
                                is_first = false;
                            }
                            putsk("   ");
                            putsk(member);
                            putsk(": ");
                            static if (mixin(HasOMeta!(member))) {
                                {
                                    mixin(GetOMeta!(member));
                                    putdyn(meta.fmt, __traits(getMember, arg,
                                            member), prenest + 1, meta.print_raw);
                                }
                            } else {
                                putdyn("", __traits(getMember, arg, member), prenest + 1, true);
                            }
                            putsk('\n');
                            for (int i = 0; i < prenest; i++) {
                                putsk("   ");
                            }
                        }
                    }
                }
                putsk('}');
            }
        }
    }
    pragma(msg, "<= putdyn: ", typeof(arg));
}

/// Print a string
void printk(Args...)(string s, Args args) {
    int idx_into_s = 0;
    foreach (arg; args) {

        // advance s
        while (s[idx_into_s] != '{')
            outp(DEBUG_IO_PORT, s[idx_into_s++]);
        const int og_idx = idx_into_s + 1;
        while (s[idx_into_s++] != '}') {
        }
        const string subarray = s[og_idx .. idx_into_s - 1];

        putdyn(subarray, arg);
    }
    while (idx_into_s < s.length)
        outp(DEBUG_IO_PORT, s[idx_into_s++]);
    outp(DEBUG_IO_PORT, '\n');
}

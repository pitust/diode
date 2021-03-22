module kernel.optional;

import kernel.util : memcpy;
import std.conv : emplace;

unittest {
    import kernel.io : printk;

    printk("[optional] Create, uninited");
    Option!int uninited = Option!(int).none();
    printk("[optional] is_{some,none} on `none`");
    assert(uninited.is_none());
    assert(!uninited.is_some());

    printk("[optional] Create, inited");
    Option!int inited = Option!int(3);
    printk("[optional] is_{some,none} on `Some(3)`");
    assert(!inited.is_none());
    assert(inited.is_some());
    printk("[optional] unwrap is 3 on `Some(3)");
    assert(3 == *inited.unwrap());
    printk("[optional]: Some(3): {} | None: {}", inited, uninited);
}

/// Is it something? Is it nothing? It's unclear.
struct Option(T) {
    align(T.alignof) private char[T.sizeof] buf;
    private bool is_something = false;
    private bool __invariant = false;
    /// Is it something?
    bool is_some() {
        assert(__invariant);
        return is_something;
    }
    /// Is it nothing?
    bool is_none() {
        assert(__invariant);
        return !is_something;
    }
    /// Unwrap it
    T unwrap() {
        assert(__invariant);
        assert(is_some());
        return *cast(T*) buf.ptr;
    }
    /// Something
    static Option!T opCall(ref T t) {
        Option!(T) e;
        e.is_something = true;
        memcpy(cast(byte*) e.buf.ptr, cast(byte*)&t, t.sizeof);
        emplace(cast(T*) e.buf.ptr, t);
        e.__invariant = true;
        return e;
    }
    /// Something
    static Option!T opCall(T t) {
        Option!(T) e;
        e.is_something = true;
        memcpy(cast(byte*) e.buf.ptr, cast(byte*)&t, t.sizeof);
        emplace(cast(T*) e.buf.ptr, t);
        e.__invariant = true;
        return e;
    }
    /// Nothing
    static Option!T opCall() {
        Option!(T) e;
        e.__invariant = true;
        e.is_something = false;
        return e;
    }

    /// Map a value (if it's `some`)
    Option!U map(U)(U function(T t) f) {
        if (is_something) {
            return Option!U(f(unwrap()));
        }
        return Option!U();
    }

    /// Map a value (if it's `some`, allowing it to return an option)
    Option!U and_then(U)(Option!U function(T t) f) {
        if (is_something) {
            return f(unwrap());
        }
        return Option!U();
    }

    invariant() {
        assert(__invariant);
    }

    ~this() {
        assert(__invariant);
        if (is_something) {
            destroy(*cast(T*) buf.ptr);
        }
    }
}

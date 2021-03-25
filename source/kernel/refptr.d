module kernel.refptr;

import kernel.io;
import kernel.mm;


private struct Marker {}

/// A smart pointer
struct Ref(T) {
    private ulong* rc;
    private T* v;

    @disable this();

    /// Construct
    this(Args...)(Args args) {
        rc = alloc!(ulong)(1);
        v = alloc!(T, Args)(args);
    }

    /// Construct
    this(ref Ref!(T) rhs) {
        rc = rhs.rc;
        v = rhs.v;
        (*rc)++;
    }

    private this(Marker m) {}

    /// Construct
    static Ref!T mk() {
        Marker m;
        auto a = Ref!(T)(m);
        a.rc = alloc!(ulong)(1);
        a.v = alloc!(T)();
        return a;
    }

    ~this() {
        (*rc)--;
        if (!*rc) {
            printk(DEBUG, "Freeing an rc");
        }
    }

    invariant() {
        assert(*rc, "Argh!");
    }

    /// Data
    @property ref T data() {
        return *v;
    }
    
    ///
    void __noshow_rc() {}
    ///
    void __noshow_v() {}
    ///
    void _prnt_refcount(string subarray, int prenest) {
        // We make 3 copies inside of printk.
        // TODO: pass-by-value???
        putdyn(subarray, *rc - 3, prenest);
    }
    ///
    void _prnt_value(string subarray, int prenest) {
        putdyn(subarray, *v, prenest);
    }
}
module kernel.autoinit;

import kernel.io;

alias MakeFunction(T) = T function();


unittest {
    AutoInitable!int i = AutoInitable!int((() {
        return 3;
    }));
    printk("[autoinit] assert uninitialized");
    assert(!i.is_init());
    i.ensure_init();
    printk("[autoinit] assert initialized...");
    assert(i.is_init());
    printk("[autoinit] assert initialized correctly...");
    assert(*i.val() == 3);

    AutoInitable!int j = AutoInitable!int(3);
    printk("[autoinit] assert initialized correctly...");
    assert(*j.val() == 3);

    AutoInitable!int k = AutoInitable!int((() {
        return 3;
    }));
    printk("[autoinit] assert uninitialized...");
    assert(!k.is_init());
    printk("[autoinit] assert autoinitialized correctly...");
    assert(*k.val() == 3);
}

/// Auto-initable struct
struct AutoInitable(T) {
    align(T.alignof) private byte[T.sizeof] data;
    private bool _is_init = false;
    private MakeFunction!(T) makefcn;

    /// Create AutoInitable
    public this(MakeFunction!(T) val) {
        this._is_init = false;
        this.makefcn = val;
    }
    /// Create initatied AutoInitable
    public this(T val) {
        this._is_init = true;
        *(cast(T*)this.data.ptr) = val;
        this.makefcn = () {
            assert(false);
        };
    }
    /// Gets the value inside
    T* val() {
        this.ensure_init();
        return (cast(T*)this.data.ptr);
    }
    /// Initializes the value inside
    void ensure_init() {
        if (!is_init) {
            import std.conv : emplace;
            this._is_init = true;
            *(cast(T*)this.data.ptr) = this.makefcn();
        }
    }
    /// Is it inited?
    bool is_init() {
        return this._is_init;
    }
}
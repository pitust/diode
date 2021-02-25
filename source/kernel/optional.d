module kernel.optional;

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



/// A value that might or might not be there
struct Option(T) {
    align(T.alignof) private byte[T.sizeof] data;
    private bool _is_some = false;
    @disable this();
    /// Copy ctor
    public this(ref Option!T rhs) {
        if (rhs._is_some) {
            this._is_some = true;
            *(cast(T*) this.data.ptr) = *rhs.unwrap();
        } else {
            this._is_some = false;
        }
    }
    private this(bool s1, bool s2) {
        this._is_some = false;
    }
    /// Create AutoInit
    static Option!T none() {
        Option!T o = Option!T(false, false);
        o._is_some = false;
        return o;
    }

    /// Create an Option with the given value, calling its postblit/copy ctors
    public this(T val) {
        this._is_some = true;
        *(cast(T*) this.data.ptr) = val;
    }
    /// Gets the value inside, asserting it exists
    T* unwrap() {
        assert(this._is_some);
        return (cast(T*) this.data.ptr);
    }
    /// Do we even have a value?
    bool is_some() {
        return this._is_some;
    }
    /// Do we _not_ have a value?
    bool is_none() {
        return !this._is_some;
    }
}

module kernel.mm;


import kernel.autoinit;
import std.conv : emplace;



private extern(C) struct MPageHeader {
    align(4) MPageHeader* next;
    ulong pagecount;
}

private __gshared MPageHeader* first = cast(MPageHeader*)0;

/// Allocate a page
void* page() {
    assert(first != cast(MPageHeader*)0);
    if (first.pagecount == 1) {
        void* result = cast(void*)first;
        first = first.next;
        return result;
    }
    first.pagecount -= 1;
    void* data = cast(void*)(first + first.pagecount * 4096);
    (cast(long*)data)[0] = 0;
    (cast(long*)data)[1] = 0;
    return data;
}

/// Add a bunch of pages to the memory manager
void addpage(ulong addr, ulong pagecount) {
    MPageHeader* next = first;
    first = cast(MPageHeader*)addr;
    import kernel.io : printk;
    first.next = next;
    first.pagecount = pagecount;
}

private struct MMRefValue(T) {
    T value;
    ulong refcount = 1;
}

// Our allocator!
// The algorithm is called RFAlloc, by me
// It's essencialy an RNG that ensures resources get used nicely.
// Each page committed lets us use 256K-64 of RAM.
private struct RFAllocPageState {
    RFAllocPageState* next;
    byte bitmap[4096 - 8];
    bool get_bitmap_offset_at()
}
private __gshared AutoInit!int val = AutoInit((() {
    return 3;
}));
/// Allocate some RAM
T* alloc(T)() {

}



/// A refernce value
struct RefValue(T) {
    private MMRefValue!(T)* val;
    
    /// The refcounted value itself!
    T* data() {
        return &val.value;
    }

    /// Regular ctor
    this(T value) {
        this.val = alloc();
        this.val.value = value;
    }

    /// Copy ctor
    this(ref RefValue!(T)* rhs) {
        import kernel.platform : atomic_sub;
        atomic_add(&this.val.refcount, 1);
    }

    ~this() {
        import kernel.platform : atomic_sub;
        atomic_sub(&this.val.refcount, 1);
        if (this.val.refcount == 0) {
            free(this.val);
        }
    }
}
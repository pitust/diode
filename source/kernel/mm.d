module kernel.mm;

import kernel.autoinit;
import kernel.platform : rdrandom;
import std.conv : emplace;

private extern (C) struct MPageHeader {
    align(4) MPageHeader* next;
    ulong pagecount;
}

private __gshared MPageHeader* first = cast(MPageHeader*) 0;

/// Allocate a page
void* page() {
    assert(first != cast(MPageHeader*) 0);
    if (first.pagecount == 1) {
        void* result = cast(void*) first;
        first = first.next;
        return result;
    }
    first.pagecount -= 1;
    void* data = cast(void*)(first + first.pagecount * 4096);
    (cast(long*) data)[0] = 0;
    (cast(long*) data)[1] = 0;
    return data;
}

/// Add a bunch of pages to the memory manager
void addpage(ulong addr, ulong pagecount) {
    MPageHeader* next = first;
    first = cast(MPageHeader*) addr;
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
// Each page committed lets us use a bit of RAM.
private struct RFAllocPageState {
    byte[2048] bitmap;
    RFAllocPageState*[2] childs;

    bool get_bitmap_offset_at(ulong offset, ulong bitmap_final_offset, ulong depth) {
        if (depth == 0) {
            return !!(bitmap[bitmap_final_offset >> 3] & (1 << (bitmap_final_offset & 0x7)));
        }
        RFAllocPageState* target = childs[offset & 1];
        if (target == cast(RFAllocPageState*) 0) {
            // This is a used-map
            // if it doesn't even own an RFAllocPageState
            // (literally the first step in getting a malloc from a region),
            // it's unused!
            return false;
        }
        return target.get_bitmap_offset_at(offset >> 1, bitmap_final_offset, depth - 1);
    }

    void set_bitmap_offset_at(ulong offset, ulong bitmap_final_offset, ulong depth, bool value) {
        if (depth == 0) {
            bitmap[bitmap_final_offset >> 3] &= ~(1 << (bitmap_final_offset & 0x7));
            bitmap[bitmap_final_offset >> 3] |= ((cast(ulong) value) << (bitmap_final_offset & 0x7));
            return;
        }
        RFAllocPageState* target = childs[offset & 1];
        if (target == cast(RFAllocPageState*) 0) {
            target = childs[offset & 1] = create();
        }
        target.set_bitmap_offset_at(offset >> 1, bitmap_final_offset, depth - 1, value);
    }

    static RFAllocPageState* create() {
        import kernel.util : memset;

        RFAllocPageState* el = cast(RFAllocPageState*) page();
        memset(el.bitmap.ptr, 0, 2048);
        el.childs[0] = cast(RFAllocPageState*) 0;
        el.childs[1] = cast(RFAllocPageState*) 0;

        return el;
    }
}
private __gshared AutoInit!(RFAllocPageState*) aps = AutoInit!(RFAllocPageState*)((() {
        return RFAllocPageState.create();
    }));

private __gshared ulong apsdims = 0;

private __gshared ulong poolsize = 0;
private const ulong poolbase = 0xffff_8000_f000_0000;
private const ulong MM_ATTEMPTS_RFALLOC = 10;

private void increase_apsdims() {
    apsdims += 1;
    RFAllocPageState** apsref = aps.val();
    RFAllocPageState* apsold = *apsref;
    *apsref = RFAllocPageState.create();
    // this reborrow is awkward but makes dscanner shut up so :shrug:
    (*apsref).childs[0] = &*apsold;
}
private void commit_to_pool() {
    if ((1 << apsdims) == poolsize) {
        increase_apsdims();
    }
    // import kernel.pmap : krwmap, Phys;
    // krwmap(Phys(poolbase + poolsize), page());
    assert(false);
    poolsize += 4096;
}

/// Allocate some stuff
T* alloc(T)() {
    const ulong size = (T.sizeof + 15) & 0xffff_ffff_ffff_fff0;
    if (poolsize == 0) {
        commit_to_pool();
    }
    const ulong ss = size >> 4;
    while (true) {
        attempt: for (int i = 0;i < MM_ATTEMPTS_RFALLOC;i++) {
            const ulong rand = rdrandom() % poolsize;
            for (ulong j = 0;j < ss;j++) {
                const ulong v = j + rand;
                const bool hit = aps.val().get_bitmap_offset_at(v >> 14, v & 0x3fff, apsdims);
                if (hit) continue attempt;
            }
            for (ulong j = 0;j < ss;j++) {
                const ulong v = j + rand;
                aps.val().set_bitmap_offset_at(v >> 14, v & 0x3fff, apsdims, true);
            }
            return cast(T*)(rand + poolbase);
        }
        commit_to_pool();
    }
}

/// Free memory
void free(T)(T* value) {
    assert(false, "TODO: free");
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

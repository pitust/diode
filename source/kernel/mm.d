module kernel.mm;

import kernel.io;
import kernel.task;
import kernel.rtti;
import kernel.autoinit;
import kernel.optional;
import std.conv : emplace;
import kernel.util : memset;
import kernel.pmap : Phys, get_pte_ptr;
import kernel.platform : rdweakrandom, rdrandom;

private extern (C) struct MPageHeader {
    align(4) MPageHeader* next;
    ulong pagecount;
}

private __gshared MPageHeader* first = cast(MPageHeader*) 0;

T[] array(T)(T* ptr, ulong len) {
    ulong[2] data;
    data[0] = len;
    data[1] = cast(ulong)ptr;
    return transmute!(ulong[2], T[])(data);
}

/// Allocate a phys
Phys phys() {
    return Phys(cast(ulong) page());
}

private __gshared ulong used = 0;
private __gshared ulong total = 0;

/// Out of memory!
void oom_cond() {
    printk(FATAL, "OOM condition!");
    printk(FATAL, " Kernel heap: {hex}/{hex} bytes used", heap_usage, heap_max);
    printk(FATAL, " Page frame allocator: {hex}/{hex} pages used", used, total);
    assert(false, "OOM");
}

/// Allocate a page
void* page() {
    if (first == cast(MPageHeader*) 0)
        oom_cond();
    if (first.pagecount == 1) {
        void* result = cast(void*) first;
        first = first.next;
        return result;
    }
    first.pagecount -= 1;
    const ulong pc = first.pagecount;
    MPageHeader* n = first.next;
    void* data = cast(void*)(first);
    first = cast(MPageHeader*)(4096 + cast(ulong) first);
    first.next = &*n;
    first.pagecount = pc;
    used += 1;
    memset(cast(byte*) data, 0, 4096);
    return data;
}

/// Add a bunch of pages to the memory manager
void addpage(ulong addr, ulong pagecount, bool isinital = false) {
    MPageHeader* next = first;
    first = cast(MPageHeader*) addr;
    import kernel.io : printk;

    first.next = next;
    first.pagecount = pagecount;
    if (isinital) {
        total += pagecount;
    } else {
        import kernel.util;

        used -= pagecount;
        memset16(cast(ushort*)first, 0xfeeb, pagecount * 2048);
        // hmmm
        first.next = next;
        first.pagecount = pagecount;
    }
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
    private union {
        struct {
            byte[2048] bitmapA;
            byte[2048] bitmapB;
        }

        RFAllocPageState*[2] childs;
    }

    bool get_bitmap_offset_at(ulong offset, ulong bitmap_final_offset, ulong depth) {
        if (depth == 0) {
            return !!(bitmapA[bitmap_final_offset >> 3] & (1 << (bitmap_final_offset & 0x7)));
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

    bool get_bitmap_offset_at_slotb(ulong offset, ulong bitmap_final_offset, ulong depth) {
        if (depth == 0) {
            return !!(bitmapB[bitmap_final_offset >> 3] & (1 << (bitmap_final_offset & 0x7)));
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
            bitmapA[bitmap_final_offset >> 3] &= ~(1 << (bitmap_final_offset & 0x7));
            bitmapA[bitmap_final_offset >> 3] |= ((cast(ulong) value) << (bitmap_final_offset & 0x7));
            return;
        }
        RFAllocPageState* target = childs[offset & 1];
        if (target == cast(RFAllocPageState*) 0) {
            target = childs[offset & 1] = create();
        }
        target.set_bitmap_offset_at(offset >> 1, bitmap_final_offset, depth - 1, value);
    }

    void set_bitmap_offset_at_slotb(ulong offset, ulong bitmap_final_offset, ulong depth, bool value) {
        if (depth == 0) {
            bitmapB[bitmap_final_offset >> 3] &= ~(1 << (bitmap_final_offset & 0x7));
            bitmapB[bitmap_final_offset >> 3] |= ((cast(ulong) value) << (bitmap_final_offset & 0x7));
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
        heap_max += 4096;
        memset(el.bitmapA.ptr, 0, 2048);
        memset(el.bitmapB.ptr, 0, 2048);
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
private __gshared ulong stackbase = 0xffff_8100_0000_0000;
private const ulong poolbase = 0xffff_800f_f000_0000;
private const ulong MM_ATTEMPTS_RFALLOC = 3000;

/// Allocate a userland virtual address
void* alloc_user_virt() {
    return cast(void*)(rdrandom() & 0x000_0fff_ffff_0000);
}

/// Allocate a stack
void* alloc_stack(t* cur = cur_t) {
    stackbase += 0x2000;
    ulong base = stackbase;
    stackbase += 0x5000 + 0x4000;
    foreach (i; 0..8) {
        void* page = page();
        ulong* a = get_pte_ptr(cast(void*)(base + (i << 12))).unwrap();
        *a = 3 | cast(ulong)page;
    }
    return cast(void*)(base + 0x8000);
}

/// Free a stack
void free_stack(void* a) {

}

private void increase_apsdims() {
    apsdims += 1;
    RFAllocPageState** apsref = aps.val();
    RFAllocPageState* apsold = *apsref;
    *apsref = RFAllocPageState.create();
    // this reborrow is awkward but makes dscanner shut up so :shrug:
    (*apsref).childs[0] = &*apsold;
}

private void commit_to_pool() {
    ulong* a = get_pte_ptr(cast(void*) poolbase + poolsize).unwrap();
    *a = 3 | cast(ulong) page();
    poolsize += 4096;
    heap_max += 4096;
    if ((1 << (apsdims + 16)) == poolsize) {
        increase_apsdims();
    }
}

/// HeapBlock is a header of a heap-allocated object.
/// It is located 16 bytes _before_ the pointer returned by mmIsHeap.
extern (C) struct HeapBlock {
    /// The type of this object
    kernel.rtti.TypeInfo* typeinfo;
    /// The size of this object
    ulong size;

    /// Print it nicely
    void _prnt_value(string subarray, int prenest) {
        putsk("HeapBlock { ");
        typeinfo.print(cast(void*)((cast(ulong)&this) + 16), subarray, prenest, true);
        putsk(" }");
    }
}

static assert(HeapBlock.sizeof == 16);

/// How much bytes of the kernel heap are in use
__gshared ulong heap_usage = 0;
/// How much bytes of the kernel heap are committed
__gshared ulong heap_max = 0;
private __gshared ulong spillbits = 0;

/// is `arg` on the heap? If yes, tells you where it starts.
Option!(void*) mmIsHeap(void* a) {
    alias O = Option!(void*);
    ulong value = cast(ulong) a - poolbase;
    if (cast(ulong) a < poolbase) {
        return O();
    }
    if (value > poolsize) {
        return O();
    }
    ulong vs4 = (value >> 4) - 1;
    debug assert((*aps.val()).get_bitmap_offset_at(vs4 >> 14, vs4 & 0x3fff,
            apsdims), "Kernel: dangling pointer passed to `mmIsHeap`");
    ulong nego = 0;
    vs4 += 1;
    if (!(*aps.val()).get_bitmap_offset_at(vs4 >> 14, vs4 & 0x3fff,
            apsdims)) {
        return O(a);
    }
    while (true) {
        debug assert((*aps.val()).get_bitmap_offset_at((vs4 - nego) >> 14,
                (vs4 - nego) & 0x3fff, apsdims));
        if ((*aps.val()).get_bitmap_offset_at_slotb((vs4 - nego) >> 14,
                (vs4 - nego) & 0x3fff, apsdims))
            return O(poolbase + 16 + cast(void*)(value - (nego << 4)));
        nego++;
    }
}

/// is `arg` on the heap? If yes, tells you where its corresponding HeapBlock is placed.
Option!(HeapBlock*) mmGetHeapBlock(void* a) {
    return mmIsHeap(a).map!(HeapBlock*)((void* a) {
        return cast(HeapBlock*)(cast(ulong) a - 16);
    });
}

private void* kalloc(ulong size) {
    size = (size + 15) & 0xffff_ffff_ffff_fff0;
    if (poolsize == 0) {
        commit_to_pool();
    }
    if (size > 4096) {
        size = (size + 4095) / 4096;
        stackbase += 0x1000;
        ulong region = stackbase;
        foreach (i; 0..size) {
            stackbase += 0x1000;
            void* page = page();
            ulong* a = get_pte_ptr(cast(void*)(region + (i << 12))).unwrap();
            *a = 3 | cast(ulong)page;
        }
        return cast(void*)region;
        // stackbase
    }
    const ulong ss = size >> 4;
    while (true) {
        for (int i = 0; i < MM_ATTEMPTS_RFALLOC; i++) {
            const ulong rand = (rdweakrandom() % (poolsize - size)) & ~0xf;
            bool success = true;
            for (ulong j = 0; j < ss; j++) {
                const ulong v = j + (rand >> 4);
                const bool hit = (*aps.val()).get_bitmap_offset_at(v >> 14, v & 0x3fff, apsdims);
                if (hit) {
                    success = false;
                    break;
                }
            }
            if (!success)
                continue;
            for (ulong j = 0; j < ss; j++) {
                const ulong v = j + (rand >> 4);
                (*aps.val()).set_bitmap_offset_at(v >> 14, v & 0x3fff, apsdims, true);
            }
            (*aps.val()).set_bitmap_offset_at_slotb(rand >> 18, (rand >> 4) & 0x3fff, apsdims, true);
            heap_usage += size;
            heap_usage += ss / 8;
            spillbits += ss % 8;
            return cast(void*)(rand + poolbase);
        }
        commit_to_pool();
    }
    assert(false);
}

private void kfree(void* value, ulong size) {
    if (cast(ulong)value < poolbase) {
        return;
    }
    const ulong addr = cast(ulong) value - poolbase;
    size = (size + 15) & 0xffff_ffff_ffff_fff0;
    const ulong ss = size >> 4;
    for (ulong j = 0; j < ss; j++) {
        const ulong v = j + (addr >> 4);
        (*aps.val()).set_bitmap_offset_at(v >> 14, v & 0x3fff, apsdims, false);
    }
    (*aps.val()).set_bitmap_offset_at_slotb((addr >> 4) >> 14, (addr >> 4) & 0x3fff, apsdims, false);
    heap_usage -= ss / 8;
    heap_usage -= size;
    spillbits -= ss % 8;
    while (spillbits < 0) {
        spillbits += 8;
        heap_usage -= 1;
    }
}

/// Allocate some stuff
T* alloc(T, Args...)(Args arg) {
    const ulong size = (T.sizeof + 15) & 0xffff_ffff_ffff_fff0;
    HeapBlock* hblk = cast(HeapBlock*) kalloc(size + 16);
    hblk.typeinfo = typeinfo!T();
    hblk.size = size;
    T* a = cast(T*)(16 + cast(ulong) hblk);
    emplace!(T)(a, arg);
    return a;
}

/// Type structure 1337 hax. Wildly unsafe.
U transmute(T, U)(T a) {
    struct L {
        T v;
    }

    struct R {
        U v;
    }

    L l;
    l.v = a;
    return (cast(R*)&l).v;
}

private ulong storage_for_arr(T)(ulong n) {
    return ((T.sizeof * n) + 15) & 0xffff_ffff_ffff_fff0;
}

/// Unsafe alloca, needs a memcpy
T[] alloca_unsafe(T)(ulong n) {
    const ulong size = storage_for_arr!T(n);
    HeapBlock* hblk = cast(HeapBlock*) kalloc(size + 16);
    hblk.typeinfo = typeinfo!(T[])();
    hblk.size = size;
    memset(16 + cast(byte*) hblk, 0, size);
    T* hh = cast(T*)(16 + cast(ulong) hblk);
    struct fake_t {
        size_t length;
        T* ptr;
    }

    fake_t fake;
    fake.length = n;
    fake.ptr = hh;
    return transmute!(fake_t, T[])(fake);
}

/// Allocate a dynamically-sized array of 0 elements
T[] alloca(T)() {
    return alloca_unsafe!T(0);
}

/// Allocate a dynamically-sized array of `n` elements
T[] alloca(T, Args...)(ulong n, Args args) {
    T[] oa = alloca_unsafe!T(n);
    foreach (i; 0 .. n) {
        emplace(&oa[i], args);
    }
    return oa;
}

private T max(T)(T a, T b) {
    if (a < b)
        return b;
    return a;
}

/// Allocate a dynamically-sized array of `n` elements
void push(T)(ref T[] arr, T e) {
    T[] newa = arr;
    bool skipalloc = false;
    if (mmIsHeap(cast(void*) arr.ptr).is_some()) {
        HeapBlock* hb = mmGetHeapBlock(cast(void*) arr.ptr).unwrap();
        if (hb.size >= storage_for_arr!(T)(arr.length + 1)) {
            skipalloc = true;
        }
    }
    ulong oldlen = arr.length;
    if (!skipalloc) {
        newa = alloca_unsafe!T(max(arr.length * 2, arr.length + 1));
        foreach (i; 0 .. arr.length) {
            emplace(&newa[i], arr[i]);
        }
        free(arr);
    }
    // HACK: manipulating the internal repr of an array is questionable at best
    (cast(ulong*)&arr)[0] = oldlen + 1;
    (cast(ulong*)&arr)[1] = cast(ulong) newa.ptr;
    emplace(&arr[oldlen], e);
}

/// Allocate a dynamically-sized array of `n` elements
T[] realloca(T)(T[] old, ulong n) {
    // TODO: expand fast path

    T[] newa = alloca_unsafe!T(n);
    foreach (i; 0 .. n) {
        if (i < old.length) {
            emplace(&newa[i], old[i]);
        } else {
            emplace(&newa[i]);
        }
    }
    free(old);
    return newa;
}

/// Free memory
void free(T)(T* value) {
    HeapBlock* allocbase = cast(HeapBlock*)((cast(ulong) value) - 16);
    kfree(cast(void*) allocbase, allocbase.size + 16);
}

/// Free memory
void free(T)(T[] value) {
    if (mmGetHeapBlock(cast(void*) value.ptr).is_some()) {
        HeapBlock* allocbase = cast(HeapBlock*)((cast(ulong) value.ptr) - 16);
        kfree(cast(void*) allocbase, allocbase.size + 16);
    }
}

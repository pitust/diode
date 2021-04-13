module libsys.mem;

import libsys.syscall;
import vshared.share;
import libsys.errno;
import libsys.io;
import std.conv;

// My memory manager
// cool stuff
//
// the concept:
// we have three zones:
//    slab64's - 64-byte slabs for anything <= 64
//    bigblk's - a bitmap allocator
//    huge8k's - large >8k zones from mmap(). Aligned to 64 bytes (read: beginning_of_page+64)

// slab64 stuff
private struct Slab64 {
    Slab64* next;
    // amount of slabs
    ulong count;
}

__gshared ulong slab64_mem_low = 0;
__gshared ulong slab64_mem_size = 0;
__gshared Slab64* first_slab64 = cast(Slab64*) 0;
bool is_slab64(void* addr) {
    return is_slab64(cast(ulong) addr);
}

bool is_slab64(ulong addr) {
    if (!slab64_mem_low)
        return false;
    if (addr < slab64_mem_low)
        return false;
    if (addr > slab64_mem_size + slab64_mem_low)
        return false;
    return true;
}

void slab64_commit() {
    if (!slab64_mem_low) {
        slab64_mem_low = cast(ulong) must_succeed(mmap(cast(void*) 0, 4096, MMapFlags.MAP_PRIVATE));
    } else {
        must_succeed(mmap(cast(void*)(slab64_mem_low + slab64_mem_size), 4096, MMapFlags.MAP_FIXED | MMapFlags
                .MAP_PRIVATE));
    }
    Slab64* slab = cast(Slab64*)(slab64_mem_low + slab64_mem_size);
    slab.count = 64;
    slab.next = first_slab64;
    first_slab64 = slab;
    slab64_mem_size += 4096;
}

void* alloc_slab64(ulong size) {
    assert(size <= 64);
    size = 64;
    if (first_slab64 == cast(Slab64*) 0) {
        slab64_commit();
    }
    if (first_slab64.count > 1) {
        first_slab64.count -= 1;
        return cast(void*)(first_slab64.count * 64 + cast(ulong) first_slab64);
    }
    void* data = cast(void*) first_slab64;
    first_slab64 = first_slab64.next;
    return data;
}

void free_slab64(void* mem) {
    debug assert(is_slab64(cast(ulong) mem));
    Slab64* new_head = cast(Slab64*) mem;
    new_head.count = 1;
    new_head.next = first_slab64;
    first_slab64 = new_head;
}

// bigblk stuff
__gshared ulong bigblk_mem_low = 0;
__gshared ulong bigblk_bitmap_low = 0;
__gshared ulong bigblk_mem_size = 0;
__gshared ulong bigblk_bitmap_size = 0;
__gshared ulong bigblk_bitmap_off = 0;

bool is_bigblk(ulong addr) {
    if (!bigblk_mem_low)
        return false;
    if (addr < bigblk_mem_low)
        return false;
    if (addr > bigblk_mem_size + bigblk_mem_low)
        return false;
    return true;
}

bool testbits(ulong* mem, ulong offset, ulong count) {
    foreach (i; 0 .. count) {
        if ((mem[(offset + i) >> 6] >> ((offset + i) & 0x3f)) & 1)
            return false;
    }
    return true;
}

void setbits(ulong* mem, ulong offset, ulong count) {
    foreach (i; 0 .. count) {
        mem[(offset + i) >> 6] |= 1 << ((offset + i) & 0x3f);
    }
}

void clearbits(ulong* mem, ulong offset, ulong count) {
    foreach (i; 0 .. count) {
        mem[(offset + i) >> 6] &= ~(1 << ((offset + i) & 0x3f));
    }
}

void commit_bigblk() {
    if (!bigblk_bitmap_low) {
        bigblk_bitmap_low = cast(ulong) must_succeed(mmap(cast(void*) 0, 4096, MMapFlags
                .MAP_PRIVATE));
    } else if (bigblk_bitmap_size & 0x1000) {
        ulong tgd = bigblk_bitmap_low + bigblk_bitmap_size;
        must_succeed(mmap(cast(void*) tgd, 4096, MMapFlags.MAP_FIXED | MMapFlags.MAP_PRIVATE));
    }
    bigblk_bitmap_size += 0x20;
    if (!bigblk_mem_low) {
        bigblk_mem_low = cast(ulong) must_succeed(mmap(cast(void*) 0, 4096, MMapFlags.MAP_PRIVATE));
    } else {
        must_succeed(mmap(cast(void*)(bigblk_mem_low + bigblk_mem_size), 4096, MMapFlags.MAP_FIXED | MMapFlags
                .MAP_PRIVATE));
    }
    bigblk_mem_size += 4096;
}

void* alloc_bigblk(ulong size) {
    void* m = _alloc_bigblk(size + 8);
    *(cast(ulong*) m) = size;
    return m + 8;
}

void* _alloc_bigblk(ulong size) {
    import core.bitop;

    assert(size > 64);
    ulong sizex = size >> 4;
    ulong off_start = bigblk_bitmap_off;
    while (true) {
        ulong* ptr = cast(ulong*)(bigblk_bitmap_low + bigblk_bitmap_off);

        foreach (i; 0 .. 64)
            if (testbits(ptr, i, sizex)) {
                setbits(ptr, i, sizex);
                return cast(void*)(((i + (bigblk_bitmap_off << 3)) << 4) + bigblk_mem_low);
            }

        bigblk_bitmap_off += 8;
        if (off_start == bigblk_bitmap_off) {
            bigblk_bitmap_off = bigblk_bitmap_size;
            commit_bigblk();
        }
        bigblk_bitmap_off %= bigblk_bitmap_size;
    }
}

void dealloc_bigblk(void* mem) {
    ulong size = *(cast(ulong*) mem - 1);
    ulong m = cast(ulong)(mem - 1);
    ulong sizex = size >> 4;
    ulong off = ((m - bigblk_mem_low) >> 7);
    ulong i = ((m - bigblk_mem_low) >> 4) & 7;
    bigblk_bitmap_off = off;
    ulong* ptr = cast(ulong*)(bigblk_bitmap_low + off);
    clearbits(ptr, i, sizex);
}

// general malloc
extern (C) void* malloc(ulong size) {
    if (size <= 64)
        return alloc_slab64(size);
    return alloc_bigblk(size);
}

extern (C) void free(void* mem) {
    if (is_slab64(mem))
        dealloc_bigblk(mem);
    else {
        debug assert(is_bigblk(cast(ulong) mem));
        dealloc_bigblk(mem);
    }
}

// mark & sweep
private enum SweepColor {
    // note that scanned and not scanned are flipped around if `is_flipped` is set

    BLACK, // not scanned
    GRAY, // in process of being scanned
    WHITE, // scanned
}

private struct BlockHeader {
    ulong size;
    BlockHeader* next;
    BlockHeader* prev;
    SweepColor color;
}

private struct Block(T) {
    ulong magic;
    BlockHeader header;
    T data;
}

private __gshared BlockHeader* first = cast(BlockHeader*) 0;
private __gshared bool is_flipped = cast(BlockHeader*) 0;
__gshared ulong maysweep = 0;
__gshared void** elfbase;
__gshared void** elftop;

private SweepColor _swept() {
    return is_flipped ? SweepColor.BLACK : SweepColor.WHITE;
}

private SweepColor _not_swept() {
    return is_flipped ? SweepColor.WHITE : SweepColor.BLACK;
}

private T[] array(T)(T* ptr, ulong len) {
    union U {
        ulong[2] a;
        T[] b;
    }
    U data;
    data.a[0] = len;
    data.a[1] = cast(ulong)ptr;
    return data.b;
}

T[] alloc_array(T)(ulong n) {
    maysweep += 1;
    if (maysweep == 5) {
        sweep();
        maysweep = 0;
    }

    alias Blk = Block!(T);
    Blk* b = cast(Blk*) malloc(Blk.sizeof);
    b.magic = *cast(ulong*) "TRICOLOR".ptr;
    b.header.color = _swept;
    b.header.next = first;
    b.header.size = n * T.sizeof;
    b.header.prev = cast(BlockHeader*) 0;
    if (first) first.prev = &b.header;
    b.header.size = T.sizeof;
    first = &b.header;
    return array(&b.data, n);
}

T[] arr(T)(T[] args...) {
    return args;
}
T[] concat(T)(T[] arra, T[] args...) {
    T[] arr = alloc_array!(T)(arra.length + args.length);
    foreach (i; 0 .. arr.length) {
        if (arra.length > i) emplace(&arr.ptr[i], arra[i]);
        else emplace(&arr.ptr[i], args[i - arra.length]);
    }
    return arr;
}
T[] concat(T)(T[] arra, T[] args) {
    T[] arr = alloc_array!(T)(arra.length + args.length);
    foreach (i; 0 .. arr.length) {
        if (arra.length > i) emplace(&arr.ptr[i], arra[i]);
        else emplace(&arr.ptr[i], args[i - arra.length]);
    }
    return arr;
}



T* alloc(T)() {
    maysweep += 1;
    if (maysweep == 5) {
        sweep();
        maysweep = 0;
    }

    alias Blk = Block!(T);
    Blk* b = cast(Blk*) malloc(Blk.sizeof);
    b.magic = *cast(ulong*) "TRICOLOR".ptr;
    b.header.color = _swept;
    b.header.next = first;
    b.header.size = T.sizeof;
    b.header.prev = cast(BlockHeader*) 0;
    if (first) first.prev = &b.header;
    b.header.size = T.sizeof;
    first = &b.header;
    return &b.data;
}

private void do_dealloc(BlockHeader* v) {
    if (v.next)
        v.next.prev = v.prev;
    if (v.prev)
        v.prev.next = v.next;
    if (first == v)
        first = v.next;
//    printf(DEBUG, "Freeing {}", (cast(void*) v) - 8);
    free((cast(void*) v) - 8);
}

private void do_sweep_of(void* d) {
    void* ogptr = d;

    if (!is_bigblk(cast(ulong) d) && !is_slab64(d)) /* not a slab64 or a bigblk */ return;
    d = d - BlockHeader.sizeof - ulong.sizeof;
    if (!is_bigblk(cast(ulong) d) && !is_slab64(d)) /* also not a slab64 or a bigblk */ return;

    ulong magic = *cast(ulong*)(d);
    if (magic != *cast(ulong*) "TRICOLOR".ptr) /* wrong magic */ return; 

    // we are pretty sure this is a valid object. sweep it.
    BlockHeader* hdr = cast(BlockHeader*)(d + ulong.sizeof);

    if (hdr.color == SweepColor.GRAY) /* being sweeped */ return;

    hdr.color = SweepColor.GRAY;

    ulong size = hdr.size;
    ulong ptrcnt = size / 8;
    foreach (i; 0 .. ptrcnt) {
        do_sweep_of(cast(void*)*cast(ulong*)(i * 8 + ogptr));
    }

    hdr.color = _swept;
}

void sweep() {
    ulong[15] regs;
    ulong* rp = regs.ptr;
    asm {
        mov RAX, rp;

        mov [RAX + 0x0], RBX;
        mov [RAX + 0x8], RCX;
        mov [RAX + 0x10], RDX;
        mov [RAX + 0x18], RBP;
        mov [RAX + 0x20], RSI;
        mov [RAX + 0x28], RDI;
        mov [RAX + 0x30], R8;
        mov [RAX + 0x38], R9;
        mov [RAX + 0x40], R10;
        mov [RAX + 0x48], R11;
        mov [RAX + 0x50], R12;
        mov [RAX + 0x58], R13;
        mov [RAX + 0x60], R14;
        mov [RAX + 0x68], R15;
        mov [RAX + 0x70], RSP;
    }
    ulong stack_top;
    must_succeed(esyscall(Syscall.GET_STACK_BOUNDS, &stack_top));
    ulong stack_bottom = regs[14];
    is_flipped = !is_flipped;
    foreach (i; stack_bottom .. stack_top) {
        if (i & 7) continue;
        do_sweep_of(*(cast(void**) i));
    }
    foreach (ulong reg; regs) {
        do_sweep_of(cast(void*) reg);
    }
    foreach (void** ee; elfbase .. elftop) {
        do_sweep_of(*ee);
    }
    BlockHeader* h = first;
    while (h) {
        if (h.color == _not_swept) {
            BlockHeader* n = h.next;
            do_dealloc(h);
            h = n;
        } else
            h = h.next;
    }
}

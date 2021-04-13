module kernel.pmap;

import kernel.io;
import kernel.optional;

private ulong* read_cr3() {
    ulong* outval;
    asm {
        mov RAX, CR3;
        mov outval, RAX;
    }
    return outval;
}

/// A physical address
struct Phys {
    private ulong _addr;

    /// Access this phys, temporarily, mapping at least 4K of memory
    void quickmap(T, Args...)(void function(T*, Args) func, Args args) {
        void* addr = cast(void*) 0x0000_0800_8000_000;
        ulong* pte_addr = get_pte_ptr(addr).unwrap();
        assert(pte_addr[0] == 0);
        debug assert(pte_addr[1] == 0);
        pte_addr[0] = 0x3 | (cast(ulong) _addr & 0x000f_ffff_ffff_f000);
        pte_addr[1] = 0x3 | (cast(ulong)(_addr + 0x1000) & 0x000f_ffff_ffff_f000);
        flush_tlb();
        func(cast(T*)(addr + (_addr & 0x1ff)), args);
        pte_addr[0] = 0;
        pte_addr[1] = 0;
        flush_tlb();
    }

    /// Drop access to this phys, returning it to the memory manager
    void drop() {
        import kernel.mm : addpage;

        assert((this._addr & 0x1ff) == 0);
        addpage(this._addr, 1);
    }

    /// Create a new phys, 4096 bytex long, via the memory manager
    static Phys alloc() {
        import kernel.mm : phys;

        return phys();
    }

    /// Make it a long
    ulong addr() {
        return _addr;
    }

    /// O-Metas
    OMeta _ometa_addr() {
        return ptr_ometa();
    }
}

/// Flush the TLB
void flush_tlb() {
    asm {
        mov RAX, CR3;
        mov CR3, RAX;
    }
}

Option!Phys get_page_for(void* va) {
    ulong* page_table = read_cr3();
    ulong va_val = (cast(ulong) va) & 0x000f_ffff_ffff_f000;
    const ushort[4] offsets = [
        (va_val >> 12 >> 9 >> 9 >> 9) & 0x1ff, (va_val >> 12 >> 9 >> 9) & 0x1ff,
        (va_val >> 12 >> 9) & 0x1ff, (va_val >> 12) & 0x1ff
    ];
    foreach (ushort key; offsets) {
        if (page_table[key] & 0x80) {
            return Option!Phys(Phys(page_table[key] & 0x000f_ffff_ffff_f000));
        }
        if (!(page_table[key] & 1)) {
            return Option!(Phys)();
        }
        page_table = cast(ulong*)(page_table[key] & 0x000f_ffff_ffff_f000);
    }

    return Option!Phys(Phys(cast(ulong) page_table));
}

Option!(ulong*) get_user_pte_ptr(void* va) {
    ulong* page_table = read_cr3();
    ulong* control_pte = cast(ulong*) 0;
    ulong va_val = (cast(ulong) va) & 0x000f_ffff_ffff_f000;
    const ushort[4] offsets = [
        (va_val >> 12 >> 9 >> 9 >> 9) & 0x1ff, (va_val >> 12 >> 9 >> 9) & 0x1ff,
        (va_val >> 12 >> 9) & 0x1ff, (va_val >> 12) & 0x1ff
    ];
    int i = -1;
    foreach (ushort key; offsets) {
        i++;
        if (page_table[key] & 0x80) {
            return Option!(ulong*)();
        }
        if (!(page_table[key] & 1) && i != 3) {
            import kernel.mm : page, push;
            import kernel.task : cur_t;
            import kernel.util : memset;

            void* new_page_table = page();
            printk(DEBUG, "Paving a new (user) memory page, index {hex} into PTE at {}, paving {}",
                    key, &page_table[key], new_page_table);
            memset(cast(byte*) new_page_table, 0, 4096);
            push(cur_t.memoryowned, cast(ulong) new_page_table);
            page_table[key] = 0x7 | cast(ulong) new_page_table;
        }
        control_pte = &page_table[key];
        page_table = cast(ulong*)(page_table[key] & 0x000f_ffff_ffff_f000);
    }

    return Option!(ulong*)(control_pte);
}

Option!(ulong*) get_pte_ptr(void* va) {
    ulong* page_table = read_cr3();
    ulong* control_pte = cast(ulong*) 0;
    ulong va_val = (cast(ulong) va) & 0x000f_ffff_ffff_f000;
    const ushort[4] offsets = [
        (va_val >> 12 >> 9 >> 9 >> 9) & 0x1ff, (va_val >> 12 >> 9 >> 9) & 0x1ff,
        (va_val >> 12 >> 9) & 0x1ff, (va_val >> 12) & 0x1ff
    ];
    int i = -1;
    foreach (ushort key; offsets) {
        i++;
        if (page_table[key] & 0x80) {
            return Option!(ulong*)();
        }
        if (!(page_table[key] & 1) && i != 3) {
            import kernel.mm : page;
            import kernel.util : memset;

            void* new_page_table = page();
            debug printk(DEBUG, "Paving a new memory page, index {hex} into PTE at {}, paving {}",
                    key, &page_table[key], new_page_table);
            memset(cast(byte*) new_page_table, 0, 4096);
            debug printk(DEBUG, "paved");
            page_table[key] = 0x7 | cast(ulong) new_page_table;
        }
        control_pte = &page_table[key];
        page_table = cast(ulong*)(page_table[key] & 0x000f_ffff_ffff_f000);
    }

    return Option!(ulong*)(control_pte);
}
/// Initial paging fixups
void paging_fixups() {
    get_pte_ptr(cast(void*) 0x0000_0800_8000_000);
    get_pte_ptr(cast(void*) 0x0000_0800_8001_000);
}

unittest {
    import kernel.mm : page, addpage;

    printk("[pmap] get_pte_ptr so we can map stuff");
    void* addr = cast(void*) 0x0000_0800_8000_000;
    long* addrl = cast(long*) addr;
    long* target = cast(long*) page();
    ulong* pte_addr = get_pte_ptr(addr).unwrap();

    printk("[pmap] mapping {ptr} to {ptr}", cast(ulong) target, cast(ulong) addr);
    *pte_addr = 0x3 | cast(ulong) target;

    printk("[pmap] flushing TLB");
    flush_tlb();

    printk("[pmap] assert mapping worked");
    assert(*addrl == *target);
    *addrl = 0;
    assert(*addrl == 0);
    assert(*addrl == *target);
    *target = 3;
    assert(*addrl == 3);
    assert(*addrl == *target);

    printk("[pmap] get_page_for does work");
    assert(get_page_for(addr).unwrap().addr() == cast(ulong) target);

    printk("[pmap] freeing resources");
    *pte_addr = 0;
    addpage(cast(ulong) target, 1);

    printk("[pmap] flushing TLB");
    flush_tlb();

    printk("[pmap] allocating a phys");
    Phys p = Phys.alloc();
    Phys q = Phys.alloc();

    printk("[pmap] quickmapping a phys");
    p.quickmap((void* data, Phys q) {
        import kernel.platform : catch_assert;

        printk("[pmap] writing to quickmap");
        long* data_long = cast(long*) data;
        *data_long = 1235;
        assert(catch_assert((Phys q) {
                printk("[pmap] asserting quickmap re-mapping fails");
                q.quickmap((void*) {});
                return 0;
            }, q).is_none());
        printk("[pmap] unmapping a quickmap");
    }, q);

    printk("[pmap] dropping physes");
    p.drop();
    q.drop();

}

module kernel.pmap;

import kernel.io : Hex, printk;
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
    private ulong addr;
    /// format this!
    Hex!ulong opFormat() {
        return Hex!ulong(addr);
    }

    /// Make it a virtual address
    T* to_virt(T)() {
        cast(T*) addr;
    }
}

private void flush_page_tables() {
    asm {
        mov RAX, CR3;
        mov CR3, RAX;
    }
}



Option!Phys get_page_for(void* va) {
    ulong* pt = read_cr3();
    ulong va_val = (cast(ulong) va) & 0x000f_ffff_ffff_f000;
    const ushort[4] lvls = [
        (va_val >> 12 >> 9 >> 9 >> 9) & 0x1ff,
        (va_val >> 12 >> 9 >> 9) & 0x1ff,
        (va_val >> 12 >> 9) & 0x1ff,
        (va_val >> 12) & 0x1ff
    ];
    foreach (ushort key; lvls) {
        if (pt[key] & 0x80) {
            printk("Resolved: {ptr}", pt[key] & 0x000f_ffff_ffff_f000);
            return Option!Phys(Phys(pt[key] & 0x000f_ffff_ffff_f000));
            break;
        }
        if (!(pt[key] & 1)) {
            return Option!(Phys).none();
        }
        pt = cast(ulong*)(pt[key] & 0x000f_ffff_ffff_f000);
    }

    return Option!Phys(Phys(cast(ulong)pt));
    // printk(" VA: {ptr}", va_val);
    // printk("Page: {ptr} ->\n      {ptr}",
    //         (cast(ulong) va) & 0x000f_ffff_ffff_f000, *pt & 0x000f_ffff_ffff_f000);
}

module kernel.symbols;

import kernel.hashmap;
import kernel.io;

struct Symbol {
    immutable(char)* name;
    ulong off;
}

struct SymbolTable {
    BetterHashMap!(immutable(char)*) symtab;
}

__gshared SymbolTable symtab;

Symbol symbolify(ulong addr) {
    ulong the_addr = addr;
    while (!(addr in symtab.symtab)) {
        addr--;
        if (addr > 0xffffffff81000000 || addr < 0xffffffff80200000) return Symbol("<unknown>".ptr, 0);
    }
    return Symbol(*symtab.symtab[addr], the_addr - addr);
}

void load(byte* diode_kernel_map) {
    printk("Loading DKM @ {}", cast(void*)diode_kernel_map);
    ulong size = *cast(ulong*)diode_kernel_map;
    printk(" - size = {}", size);
    ulong idx = 8;
    ulong prev = 0;
    foreach (i; 0 .. size) {
        if (((i * 100) / size) > prev) { printk("Loading: {}%", i * 100 / size); prev = (i * 100) / size; }
        ulong tgd = *cast(ulong*)(diode_kernel_map + idx);
        idx += 8;
        ulong sz = *cast(ulong*)(diode_kernel_map + idx);
        idx += 8;
        char* name = cast(char*)(diode_kernel_map + idx);
        idx += sz + 1;
        symtab.symtab.insertElem(tgd, cast(immutable(char)*)name);
    }
    printk("Loaded!");
}
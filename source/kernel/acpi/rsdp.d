module kernel.acpi.rsdp;

import kernel.io;
import kernel.mm;
import kernel.optional;

uint load_u32(uint a) {
    return load_u32(cast(ulong)a);
}
uint load_u32(ulong a) {
    return *cast(uint*)a;
}

ulong value = 0;

struct RSDPEntry {
    char[] id;
    void* table;
}

private __gshared RSDPEntry[] tables;

Option!(void*) find_table(string id) {
    foreach (t; tables) {
        if (t.id == id) return Option!(void*)(t.table);
    }
    return Option!(void*)();
}

void load_rsdp(ulong u) {
    uint rsdt = load_u32(u + 16);
    uint entcount = (load_u32(rsdt + 4) - 36) / 4;
    tables = alloca_unsafe!(RSDPEntry)(0);
    printk("ACPI Tables:");
    foreach (i; 0..entcount) {
        uint tbl = load_u32(i * 4 + 36 + rsdt);
        char[] s = array(cast(char*)tbl, 4);
        RSDPEntry e;
        e.table = cast(void*)tbl;
        e.id = s;
        push(tables, e);
        printk(" - {}", s);
    }
}
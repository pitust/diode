module kernel.main;

import core.volatile;
import core.bitop;
import kernel.platform;
import kernel.io;
import kernel.util;
import kernel.irq;
import kernel.stivale;
import kernel.pmap;
import kernel.rtti;
import kernel.mm;
import kernel.task;
import kernel.optional;

unittest {

}

extern (C) private void fgdt();

private __gshared ulong test_global = 1;

private void test2() {
    __gshared ulong[4096] stack;

}

private void test1(void* a) {
    printk("test1: we got this pointer: {}", a);
    printk("test1: from RTTI i know it's of type {}", dynamic_typeinfo(a).name);

    Option!(uint*) maybe_uint = dynamic_cast!(uint)(a);
    Option!(ulong*) maybe_ulong = dynamic_cast!(ulong)(a);
    if (maybe_uint.is_some()) {
        printk("test1: as a uint, it's {}", *maybe_uint.unwrap());
    }
    if (maybe_ulong.is_some()) {
        printk("test1: as a ulong, it's {}", *maybe_ulong.unwrap());
    }
}

pragma(mangle, "_start") private extern (C) void kmain(StivaleHeader* info) {
    const uint COLUMNS = 80; //Screensize
    const uint LINES = 25;

    asm {
        mov RBX, 0;
        mov RAX, 0xdeadbeefdeadbeef;
        mov [RBX], RAX;
    }

    fgdt();

    ubyte* vidmem = cast(ubyte*) 0x000B_8000; //Video memory address

    for (int i = 0; i < COLUMNS * LINES * 2; i++) { //Loops through the screen and clears it
        volatileStore(vidmem + i, 0);
    }

    printk("Hello, {}!", "world");

    // make sure that if you try to use TLS you get a bunch of page faults
    // we really don't want you to use TLS
    // mark all globals __gshared
    ulong tls = 0x0000_7fff_ffff_ffff;
    asm {
        mov RAX, CR4;
        or RAX, 0x10000;
        mov CR4, RAX;
        mov RAX, [tls];
        wrfsbase RAX;
    }

    printk("Thank {} for blessing our ~flight~ operating system", info.brand);
    foreach (Tag* t; PtrTransformIter!Tag(info.tag0, function Tag* (Tag* e) {
            return e.next;
        })) {

        if (t.ident.inner == 0xe5e76a1b4597a781) {
            printk(" - Kernel Command Line: {:?}", (cast(TagCommandLine*) t).cmdline);
        }
        if (t.ident.inner == 0x2187f79e8612de07) {
            printk(" - Memory Map");
            TagMemoryMap* mmap = cast(TagMemoryMap*) t;
            for (int i = 0; i < mmap.size; i++) {
                const MemoryMapEntry ent = mmap.entries[i];
                if (ent.type != 1)
                    continue;
                ulong start = ent.base;
                const ulong end = ent.size + start;
                if (start == 0) {
                    start = 4096;
                }
                printk("  [{ptr}; {ptr}]", start, end);
                import kernel.mm : addpage;

                addpage(cast(ulong) start, cast(ulong)((end - start) / 4096), true);
            }
        }
        if (t.ident.inner == 0x506461d2950408fa)
            printk(" - Framebuffer");
        if (t.ident.inner == 0x6bc1a78ebe871172)
            printk(" - FB MTRR");
        if (t.ident.inner == 0x4b6fe466aade04ce)
            printk(" - Modules");
        if (t.ident.inner == 0x9e1786930a375e78)
            printk(" - RSDP");
        if (t.ident.inner == 0x566a7bed888e1407)
            printk(" - The Unix Epoch");
        if (t.ident.inner == 0x359d837855e3858c)
            printk(" - Firmware Info");
        if (t.ident.inner == 0x34d1d96339647025)
            printk(" - Symmetric Multiprocessing Information");
        if (t.ident.inner == 0x29d1e96239247032)
            printk(" - PXE Boot Server Information");
    }

    paging_fixups();

    IDTR idtr = new_idtr();
    asm {
        lea RAX, idtr;
        lidt [RAX];
    }
    printk("IDTR: {}", idtr);

    debug {
        printk("Unit tests...");
        static foreach (u; __traits(getUnitTests, __traits(parent, kmain)))
            u();
        printk("Done!");
    }

    asm {
        int 3;
        // sti;
    }
    remap(0x20, 0x28);
    
    ulong* a = alloc!ulong();
    *a = 1234;
    test1(cast(void*) a);
    free!ulong(a);

    uint* b = alloc!uint();
    *b = 5678;
    test1(cast(void*) b);
    free!uint(b);

    printk("{hex}/{hex} bytes used", heap_usage, heap_max);
    for (;;) {
        hlt();
    }
}

unittest {
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.autoinit))
            u();
        return 0;
    });
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.irq))
            u();
        return 0;
    });
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.io))
            u();
        return 0;
    });
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.mm))
            u();
        return 0;
    });
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.pmap))
            u();
        return 0;
    });
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.platform))
            u();
        return 0;
    });
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.optional))
            u();
        return 0;
    });
    catch_assert(() {
        static foreach (u; __traits(getUnitTests, kernel.util))
            u();
        return 0;
    });
}

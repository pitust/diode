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
    __gshared ulong[8192] stack1;
    __gshared ulong[8192] stack2;
    task_create((void* eh) {
        asm { sti; }
        while (true) {
            printk("T1 {hex}", flags);
            sched_yield();
        }
    }, cast(void*) 0, (cast(void*) stack1) + stack1
            .sizeof);
    task_create((void* eh) {
        asm { sti; }
        while (true) {
            printk("T2 {hex}", flags);
            sched_yield();
        }
    }, cast(void*) 0, (cast(void*) stack2) + stack2
            .sizeof);
    printk("HEY 1!");
}

private void test1(void* a) {
    printk("test1: we got this pointer: {}", a);
    printk("test1: from RTTI i know it's of type {}", dynamic_typeinfo(a).name);
    printk("test1: and it's HeapBlock is {}", mmGetHeapBlock(a));

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
    asm {
        mov RBX, 0;
        mov RAX, 0xdeadbeefdeadbeef;
        mov [RBX], RAX;
    }

    fgdt();

    printk("Hello, {}!", "world");

    printk("Thank {} for blessing our ~flight~ operating system", info.brand);
    foreach (Tag* t; PtrTransformIter!Tag(info.tag0, function Tag* (Tag* e) {
            return e.next;
        })) {
        if (t.ident.inner == 0x968609d7af96b845) {
            printk(" - Display EDID");
        }
        if (t.ident.inner == 0xe5e76a1b4597a781) {
            printk(" - Kernel Command Line: {:?}", (cast(TagCommandLine*) t).cmdline);
        }
        if (t.ident.inner == 0x2187f79e8612de07) {
            printk(" - Memory Map");
            TagMemoryMap* mmap = cast(TagMemoryMap*) t;
            int i = 0;
            foreach (MemoryMapEntry ent; mmap.entries) {
                if (i++ >= mmap.entcount)
                    break;
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
        if (t.ident.inner == 0x4b6fe466aade04ce) {
            printk(" - Modules");
            TagModules* m = cast(TagModules*) t;
            assert(m.modulecount <= 8);
            foreach (i; 0 .. m.modulecount) {
                Module mm = m.modules[i];
                printk("Module: {}", mm.name);
            }
        }
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

    ensure_task_init();
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

    asm {
        sti;
    }

    // printk("HEY 0!");
    test2();
    printk("HEY: {hex}", flags);
    sched_yield();
    for (;;) {
        printk("s: {hex}", flags);
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

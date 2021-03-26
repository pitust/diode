module kernel.main;

import core.bitop;
import core.volatile;
import kernel.io;
import kernel.mm;
import kernel.irq;
import kernel.pmap;
import kernel.port;
import kernel.task;
import kernel.rtti;
import kernel.util;
import kernel.refptr;
import kernel.guards;
import kernel.stivale;
import kernel.platform;
import kernel.optional;

unittest {

}

extern (C) private void fgdt();

private __gshared ulong test_global = 1;

private extern(C) void load_tss();
private extern(C) ulong gettss();
private extern(C) ulong* gettssgdt();
private extern(C) ulong gettssgdtid();

private void test2() {
    __gshared ulong[8192] stack1;
    __gshared ulong[8192] stack2;
    task_create((void* eh) {
        asm { sti; }
        while (true) {
            printk("T1 {hex}", flags);
        }
    }, cast(void*) 0, (cast(void*) stack1) + stack1
            .sizeof);
    task_create((void* eh) {
        asm { sti; }
        while (true) {
            printk("T2 {hex}", flags);
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

private ulong bits(ulong shiftup, ulong shiftdown, ulong mask, ulong val) {
    return ((val >> (shiftdown - mask)) & ((1 << mask) - 1)) << shiftup;
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
    TagModules* m;
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
            m = cast(TagModules*) t;
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

    if (m) {
        printk("Modules: ");
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

    const ulong ptr = gettss;

    gettssgdt[0] = bits(16, 24, 24, ptr) | bits(56, 32, 8, ptr) | (103 & 0xff) | (0b1001UL << 40) | (1UL << 47);
    gettssgdt[1] = ptr >> 32;
    assert(gettssgdtid == 0x28, "Unable to load it in");
    fgdt();
    load_tss();
    rsp0 = alloc_stack();
    ist1 = alloc_stack();
    printk("Fun RSP0/IST1 in!");
    wrmsr(IA32_EFER, rdmsr(IA32_EFER) | IA32_EFER_SCE);
    printk("{hex}", rdmsr(IA32_EFER));
    wrmsr(IA32_LSTAR, cast(ulong)&platform_sc);
    wrmsr(IA32_STAR, cast(ulong)(0x0000_1b10) << 32);
    wrmsr(IA32_SFMASK, /* IF */ 0x200);
    printk("SCE in!");
    uint outp;
    asm {
        mov EAX, 7;
        mov ECX, 0;
        cpuid;
        shr EBX, 20;
        and EBX, 1;
        mov outp, EBX;
    }
    printk(DEBUG, "cpuid leaf (7, 0)[20] = {hex}", outp);
    if (outp & 1) {
        asm {
            mov RAX, CR4;
            or RAX, 3 << 20;
            mov CR4, RAX;
        }
        printk("SMAP/SMEP is enabled!");
    } else {
        printk(WARN, "SMAP is not available on your machine");
    }
    cli();
    const void* arr = page();
    void* tgd = cast(void*)(0x0000_0004_f000_0000);
    

    *get_pte_ptr(tgd).unwrap() = 7 | cast(ulong)arr;
    flush_tlb();

    // Port* p = alloc!(Port)();
    // {
    //     PortRights r = PortRights(p, PortRightsKind.RECV);
    //     PortRights s = PortRights(p, PortRightsKind.SEND);
    //     byte[3] arra = [0, 1, 2];
    //     byte[] outpt;
    //     printk("result: {}", s.send(0, arra));
    //     printk("result: {}", r.recv(outpt));
    //     printk("out: {}", outpt);
    // }

    // jmp $
    auto g = no_smap();
    ubyte* mem = cast(ubyte*)tgd;
    // mov di, 1            66bf0100
    // mov rsi, 0x4f0000040 48be400000f004000000
    // syscall              0f 05
    // jmp $                eb fe
    
    mem[0] = 0x66;
    mem[1] = 0xbf;
    mem[2] = 0x01;
    mem[3] = 0x00;
    mem[4] = 0x48;
    mem[5] = 0xbe;
    mem[6] = 0x40;
    mem[7] = 0x00;
    mem[8] = 0x00;
    mem[9] = 0xf0;
    mem[10] = 0x04;
    mem[11] = 0x00;
    mem[12] = 0x00;
    mem[13] = 0x00;
    mem[14] = 0x0f;
    mem[15] = 0x05;
    mem[16] = 0xeb;
    mem[17] = 0xfe;

    mem[0x40] = 12;
    printk("Mappings are in! ({hex})", cast(ulong*)tgd);
    g.die();
    printk("Branching to {}", tgd);

    user_branch(cast(ulong)tgd, cast(void*)0);

    for (;;) {
        // the kernel idle task comes here
        sched_yield();
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

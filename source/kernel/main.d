module kernel.main;

import core.bitop;
import core.volatile;
import kernel.io;
import kernel.mm;
import kernel.elf;
import kernel.irq;
import kernel.cpio;
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
import kernel.ports.kbootstrap;

unittest {

}

extern (C) private void fgdt();

private __gshared ulong test_global = 1;

private extern (C) void load_tss();
private extern (C) ulong gettss();
private extern (C) ulong* gettssgdt();
private extern (C) ulong gettssgdtid();

private void test2() {
    __gshared ulong[8192] stack1;
    __gshared ulong[8192] stack2;
    task_create((void* eh) {
        asm {
            sti;
        }
        while (true) {
            printk("T1 {hex}", flags);
        }
    }, cast(void*) 0, (cast(void*) stack1) + stack1
            .sizeof);
    task_create((void* eh) {
        asm {
            sti;
        }
        while (true) {
            printk("T2 {hex}", flags);
        }
    }, cast(void*) 0, (cast(void*) stack2) + stack2
            .sizeof);
    printk("HEY 1!");
}

private void test1(void* a) {
    // version (DiodeNoDebug) {
    //     return;
    // }
    // printk("test1: we got this pointer: {}", a);
    // printk("test1: from RTTI i know it's of type {}", dynamic_typeinfo(a).name);
    // printk("test1: and it's HeapBlock is {}", mmGetHeapBlock(a));

    // Option!(uint*) maybe_uint = dynamic_cast!(uint)(a);
    // Option!(ulong*) maybe_ulong = dynamic_cast!(ulong)(a);
    // if (maybe_uint.is_some()) {
    //     printk("test1: as a uint, it's {}", *maybe_uint.unwrap());
    // }
    // if (maybe_ulong.is_some()) {
    //     printk("test1: as a ulong, it's {}", *maybe_ulong.unwrap());
    // }
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
    TagRSDP* rsdptag;
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
        if (t.ident.inner == 0x9e1786930a375e78) {
            printk(" - RSDP");
            rsdptag = cast(TagRSDP*)t;
        }
        if (t.ident.inner == 0x566a7bed888e1407)
            printk(" - The Unix Epoch");
        if (t.ident.inner == 0x359d837855e3858c)
            printk(" - Firmware Info");
        if (t.ident.inner == 0x34d1d96339647025)
            printk(" - Symmetric Multiprocessing Information");
        if (t.ident.inner == 0x29d1e96239247032)
            printk(" - PXE Boot Server Information");
    }

    assert(m);
    printk("Modules: ");
    CPIOFile banner, init;
    {
        Module mod = m.modules[0];
        ubyte[] moddata = array(mod.begin, cast(ulong)(mod.end - mod.begin));
        printk(" - {} ({hex} bytes)", mod.name, moddata.length);
        CPIOFile[] f = parse_cpio(moddata);
        if (try_find(banner, "./banner.txt", f)) {
            printk("MOTD: \n{}", transmute!(ubyte[], string)(banner.data));
        }
        find(init, "./init.elf", f);
    }

    paging_fixups();

    IDTR idtr = new_idtr();
    asm {
        lea RAX, idtr;
        lidt [RAX];
    }

    {
        import kernel.acpi.rsdp : load_rsdp;
        import kernel.pcie.mcfg : parse_mcfg, scan_pci;
        load_rsdp(rsdptag.rsdp);
        parse_mcfg();
        // scan_pci();
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

    const ulong ptr = gettss;

    gettssgdt[0] = bits(16, 24, 24, ptr) | bits(56, 32, 8, ptr) | (103 & 0xff) | (
            0b1001UL << 40) | (1UL << 47);
    gettssgdt[1] = ptr >> 32;
    assert(gettssgdtid == 0x28, "Unable to load it in");
    fgdt();
    load_tss();

    ist1 = alloc_stack();
    printk("Fun RSP0/IST1 in!");
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

    __gshared ulong[8192] stack1;
    task_create((CPIOFile* init) {
        asm {
            cli;
        }
        printk(DEBUG, "rsp0: {}", rsp0);
        ulong rip = 0;
        bool ok = load(rip, *init);
        assert(ok, "Init failed to load!");

        push(cur_t.fakeports, create_bootstrap());

        user_branch(cast(ulong) rip, cast(void*) 0);

    }, alloc!(CPIOFile)(init), (cast(void*) stack1) + stack1
            .sizeof);

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
    // mov di, 1            66bf0100
    // mov rsi, 0x4f0000040 48be400000f004000000
    // syscall              0f 05
    // jmp $                eb fe

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

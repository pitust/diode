module kernel.syscall.exec;

import kernel.mm;
import kernel.pmap;
import kernel.task;
import kernel.util;
import kernel.guards;
import kernel.hashmap;
import kernel.platform;

/// Exec
long sys_exec(void* data) {
    assert(0, "sys_exec");
}

/// Fork
long sys_fork(void* data) {
    struct ForkShmemPage {
        void* virt;
        byte* data;
    }
    struct ForkShmem {
        ulong spin;
        ulong tid;
        ulong stktop;
        ulong stkbtm;
        void* data;
        ForkShmemPage[] pgs;
    }
    ForkShmemPage[] pgs = [];
    foreach (e; cur_t.pages_that_we_own.data) {
        if (!e.isthere) continue;
        void* virt = cast(void*)e.addr;
        byte* datap = cast(byte*)(*get_user_pte_ptr(cast(void*)e.addr).unwrap() & 0x000f_ffff_ffff_f000);
        push(pgs, ForkShmemPage(virt, datap));
    }
    ForkShmem fosh = ForkShmem(0, 0, cur_t.user_stack_top, cur_t.user_stack_bottom, data, pgs);
    task_create(function (ForkShmem* fkshmem) {
        ulong* cr3;
        asm {
            mov RAX, CR3;
            mov cr3, RAX;
        }
        foreach (i; 1..256) {
            cr3[i] = 0;
        }
        auto g = no_smap();
        foreach (pg; fkshmem.pgs) {
            // pg.data
            user_map(pg.virt);
            import kernel.io;
            cur_t.user_stack_top = fkshmem.stktop;
            cur_t.user_stack_bottom = fkshmem.stkbtm;
            memcpy(cast(byte*)pg.virt, pg.data, 4096);
        }
        g.die();
        fkshmem.tid = cur_t.tid;
        ulong data = cast(ulong)fkshmem.data;
        fkshmem.spin = 1;
        asm { lfence; }

        user_branch(data, cast(void*)0);
    }, &fosh, alloc_stack());
    while (fosh.spin == 0) {
        sched_yield();
    }

    free(pgs);
    return fosh.tid;
}
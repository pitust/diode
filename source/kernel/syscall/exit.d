module kernel.syscall.exit;

import kernel.io;
import kernel.mm;
import kernel.pmap;
import kernel.task;
import kernel.syscall.util;

/// Exit
long sys_exit(void* data) {
    struct Exit {
        ulong code;
    }

    Exit e;
    e.code = 0;
    copy_from_user(data, cast(void*)&e, e.sizeof);
    printk(DEBUG, "Exiting with code: {}", e.code);
    ulong* pt;
    asm {
        mov RAX, CR3;
        mov pt, RAX;
    }
    // freet(pt);
    foreach (region; cur_t.memoryowned) {
        addpage(region, 1);
    }

    assert(0, "sys_exit");
}

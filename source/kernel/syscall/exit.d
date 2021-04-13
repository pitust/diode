module kernel.syscall.exit;

import kernel.io;
import kernel.mm;
import kernel.loafencode;
import kernel.pmap;
import kernel.task;
import kernel.syscall.util;
import kernel.ports.kbootstrap;

/// Exit
long sys_exit(void* data) {

    BootstrapCmdExit e;
    e.cmd = BootstrapCmd.NOTIFY_EXIT;
    e.code = 0;
    copy_from_user(data, cast(void*)&e.code, ulong.sizeof);
    printk(DEBUG, "pid({}) Exiting with code: {}", cur_t.tid, e.code);
    ulong* pt;
    asm {
        mov RAX, CR3;
        mov pt, RAX;
    }

    foreach (i; 1..256) {
        pt[i] = 0;
    }

    flush_tlb();

    // freet(pt);
    foreach (region; cur_t.memoryowned) {
        addpage(region, 1);
    }

    byte[] dat = alloca!(byte)(0);
    encode(e, dat);

    // If they have at least one port,
    if (cur_t.ports.length > 0) {
        printk(DEBUG, "Sending exit info to the BSP");
        // then signal on the bootstrap port
        cur_t.ports[0].send(/* ktid == pid */ cur_t.tid, dat);
    }


    task_exit();
}

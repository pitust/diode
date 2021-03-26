module kernel.syscall.dispatch;

import kernel.syscall.exec;
import kernel.syscall.exit;
import kernel.syscall.map;
import kernel.syscall.io;
import kernel.io;


/// Kinds of syscalls
enum Syscall {
    EXIT = 1,
    MAP,
    SBRK,
    SEND,
    RECV,
    CREATE_PORT,
    EXEC
}

/// Handle a syscall
long syscall(ulong sysno, void* data) {
    switch (sysno) {
    case Syscall.EXIT:
        return sys_exit(data);
    case Syscall.MAP:
        return sys_map(data);
    case Syscall.SBRK:
        return sys_sbrk(data);
    case Syscall.SEND:
        return sys_send(data);
    case Syscall.RECV:
        return sys_recv(data);
    case Syscall.CREATE_PORT:
        return sys_create_port(data);
    case Syscall.EXEC:
        return sys_exec(data);
    default:
        printk(WARN, "Invalid syscall performed: sys={hex} data={}", sysno, data);
        return -1;
    }
}
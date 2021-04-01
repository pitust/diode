module kernel.syscall.dispatch;


import kernel.syscall.kprint;
import kernel.syscall.exec;
import kernel.syscall.exit;
import kernel.syscall.map;
import kernel.syscall.io;
import vshared.share;
import kernel.io;

/// Handle a syscall
long syscall(ulong sysno, ulong data) {
    return syscall(sysno, cast(void*)data);
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
    case Syscall.KPRINT:
        return sys_kprint(data);
    case cast(Syscall)0xC000:
        return sys_make_user_stack(data);
    default:
        printk(WARN, "Invalid syscall performed: sys={hex} data={}", sysno, data);
        assert(0);
        return -1;
    }
}
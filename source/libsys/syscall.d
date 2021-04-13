module libsys.syscall;

import vshared.share;
import libsys.errno;

long syscall(Syscall sysno, void* arg) {
    long o;
    ulong sys = cast(ulong) sysno;
    asm {
        mov RDI, sys;
        mov RSI, arg;
        syscall;
        mov o, RAX;
    }
    return o;
}
long getpid() {
    long v;
    if (!esyscall(Syscall.GET_TID, &v)) return v;
    return -1;
}
extern(C) long __psys_fork(ulong sys);
extern(C) long fork() {
    return __psys_fork(cast(ulong) Syscall.FORK);
}

long esyscall(Syscall sysno, void* arg) {
    return error_out(syscall(sysno, arg));
}

void* mmap(void* addr, ulong len, MMapFlags flags) {
    import libsys.errno;

    MMap map;
    map.addr = addr;
    assert(len == 4096);
    map.flags = flags;
    map.addr = addr;
    long e = esyscall(Syscall.MAP, &map);
    if (e) return cast(void*)0;
    assert(map.addr != cast(void*)0);
    return map.addr;
}

long munmap(void* addr, ulong len) {
    import libsys.errno;

    MMap map;
    map.addr = addr;
    assert(len == 4096);
    map.flags = MMapFlags.MAP_UNMAP;
    map.addr = addr;
    long e = esyscall(Syscall.MAP, &map);
    return e;
}


void exit(long ec) {
    syscall(Syscall.EXIT, &ec);
    perror("exit");
    exit(0xffffffff);
}
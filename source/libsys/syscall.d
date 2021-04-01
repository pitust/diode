module libsys.syscall;

import vshared.share;

package long syscall(Syscall sysno, void* arg) {
    long o;
    ulong sys = cast(ulong)sysno;
    asm {
        mov RDI, sys;
        mov RSI, arg;
        syscall;
        mov o, RAX;
    }
    return o;
}
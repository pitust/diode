module libled.except;

import vshared.share;
import libsys.syscall;
import libsys.io;


///Deprecated: idk why
deprecated extern (C) __gshared void* _Dmodule_ref;

extern (C) Throwable _d_eh_enter_catch(void*) {
    assert(0, "_d_eh_enter_catch");
}

extern (C) void _d_arraybounds(string file, uint line) {
    printf(line, file, FATAL, "Out of bounds access to an array!");
    assert(0, "assertion failed");
}

extern (C) void _d_assert(string file, uint line) {
    printf(line, file, FATAL, "Assertion failed!");
    assert(0, "assertion failed");
}
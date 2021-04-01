module kernel.syscall.kprint;

import kernel.io;
import kernel.mm;
import vshared.share;
import kernel.syscall.util;


/// KPrint
long sys_kprint(void* data) {
    KPrintBuffer buf;
    copy_from_user(data, cast(void*)&buf, KPrintBuffer.sizeof);
    immutable(char)[] s = alloca!(immutable(char))(buf.len + 1, '\0');
    copy_from_user(cast(void*)buf.ptr, cast(void*)s.ptr, buf.len);
    putsk(s);
    free(s);
    return 0;
}
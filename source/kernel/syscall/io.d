module kernel.syscall.io;

import kernel.io;
import kernel.mm;
import kernel.task;
import vshared.share;
import kernel.syscall.util;

// struct 

/// Send
long sys_send(void* data) {
    KPortIOOp buf;
    copy_from_user(data, &buf, buf.sizeof);
    if (buf.kind == IOOpKind.KIND_RECV) /* Invalid operation */ return EINVAL;
    if (cur_t.ports.length > buf.port) {
        byte[] bufr = alloca_unsafe!(byte)(buf.len);
        copy_from_user(buf.data, bufr.ptr, buf.len);
        PortError e = cur_t.ports[buf.port].send(/* ktid == pid */ buf.kind == IOOpKind.KIND_SEND ? cur_t.tid : -1, bufr);
        free(bufr);
        if (e == PortError.EOK) return 0;
        if (e == PortError.EPERM) return /* Permission denied */ EPERM;
        if (e == PortError.EINVAL) return /* Invalid operation */ EINVAL;
        if (e == PortError.EEMPTY) return /* Empty */ EEMPTY;
    } else {
        return /* Bad file descriptor */ EBADF;
    }

    assert(0, "sys_send");
}
/// Recieve
long sys_recv(void* data) {
    assert(0, "sys_recv");
}
/// Create a port
long sys_create_port(void* data) {
    assert(0, "sys_create_port");
}
module kernel.syscall.io;

import kernel.io;
import kernel.mm;
import kernel.port;
import kernel.task;
import vshared.share;
import kernel.syscall.util;


__gshared ulong portassocbase = 0x1000;
// struct 

/// Send
long sys_send(void* data) {
    KPortIOOp buf;
    copy_from_user(data, &buf, buf.sizeof);
    if (buf.kind == IOOpKind.KIND_RECV) /* Invalid operation */ return EINVAL;
    if (buf.port in cur_t.ports) {
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
    KPortIOOp op;
    copy_from_user(data, &op, op.sizeof);
    if (op.kind != IOOpKind.KIND_RECV) return EINVAL;
    printk("port: {}", op.port);
    if (op.port !in cur_t.ports) return EBADF;
    assert(0, "sys_recv");
}
/// Create a port
long sys_create_port(void* data) {
    KPortCreate buf;
    // buf.outp
    // assert(0, "sys_create_port");
    ulong x = portassocbase++;
    Port* p = alloc!(Port)();
    cur_t.ports.insertElem(x, AnyPort(PortRights(p, PortRightsKind.ANON | PortRightsKind.SEND | PortRightsKind.RECV)));
    buf.outp = x;
    copy_to_user(data, &buf, buf.sizeof);
    return 0;
}
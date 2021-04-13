module libsys.port;

import libsys.mem;
import libsys.loaf;
import libsys.errno;
import vshared.share;
import libsys.syscall;

extern(C) struct port_t {
    ulong fd;
    long send(byte[] data) {
        return meh_port_send(this, data);
    }
    long send_fat(T)(T data) {
        byte[] buf = loaf_encode(data);
        return send(buf);
    }
    long send_anon(byte[] data) {
        return meh_port_send_anon(this, data.ptr, data.length);
    }
    long send_fat_anon(T)(T data) {
        byte[] buf = loaf_encode(data);
        return send_anon(buf);
    }
}

const PORT_RECV = cast(ulong)PortCloneFlags.RECV;
const PORT_SEND = cast(ulong)PortCloneFlags.SEND;
const PORT_SEND_ANON = cast(ulong)PortCloneFlags.SEND_ANON;

long meh_port_create(out port_t p) {
    KPortCreate buf;
    long e = esyscall(Syscall.CREATE_PORT, &buf);
    if (e) return e;
    p.fd = buf.outp;
    return 0;
}
long meh_port_delete(ref port_t p) {
    KPortDestroy buf;
    buf.inp = p.fd;
    long e = esyscall(Syscall.DESTROY_PORT, &buf);
    if (e) return e;
    p.fd = cast(ulong)/* sign extend */cast(long)-1;
    return 0;
}
long meh_port_send_anon(ref port_t p, void* data, ulong len) {
    return meh_port_send(p, data, len, true);
}
long meh_port_send(ref port_t p, byte[] data) {
    return meh_port_send(p, data.ptr, data.length, false);
}
long meh_port_send(ref port_t p, void* data, ulong len, bool hidepid = false) {
    KPortIOOp buf;
    buf.kind = hidepid ? IOOpKind.KIND_SEND_ANON : IOOpKind.KIND_SEND;
    buf.data = data;
    buf.len = len;
    buf.port = p.fd;
    long e = esyscall(Syscall.SEND, &buf);
    if (e) return e;
    return 0;
}
long meh_port_send(ref port_t p, byte[] data, bool hidepid = false) {
    return meh_port_send(p, data.ptr, data.length, hidepid);
}
long meh_port_recv(ref port_t p, out byte[] data) {
    void* dat;
    ulong le;
    long da = meh_port_recv(p, dat, le);
    if (da) return da;
    byte[] d = alloc_array!(byte)(le);
    data = d;
    free(dat);
    return 0;
}
long meh_port_recv(ref port_t p, out void* data, out ulong len) {
    import libsys.mem;
    import libsys.entry;

    KPortIOOp buf;
    buf.kind = IOOpKind.KIND_RECV;
    buf.port = p.fd;
    long e = esyscall(Syscall.RECV, &buf);
    if (e) return e;
    void* dat = malloc(buf.len);
    len = buf.len;
    memcpy(cast(byte*)dat, cast(byte*)buf.data, buf.len);
    buf.len = (buf.len + 4095) & ~0xfff;
    if (munmap(buf.data, buf.len)) {
        perror("meh_port_recv: munmap");
        exit(1);
    }
    return 0;
}
long meh_port_clone(ref port_t pin, ulong flags, out port_t pout) {
    KPortClone buf;
    buf.port_in = pin.fd;
    buf.flags = cast(PortCloneFlags)flags;
    long e = esyscall(Syscall.CLONE_PORT, &buf);
    if (e) return e;
    pout.fd = buf.port_out;
    return 0;
}
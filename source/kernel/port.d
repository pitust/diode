module kernel.port;

import kernel.io;
import kernel.mm;
import kernel.util;

/// Port message
struct PortMessage {
    /// The next port message
    PortMessage* next;
    /// The data, on the heap
    byte[] data;
    /// Source: 0 - kernel, -1 - anonymous, positive - that pid
    long sourcepid;
}

/// Port right kind
enum PortRightsKind {
    NONE = 0,
    RECV = 1,
    SEND = 2,
    ANON = 4,
    ANON_ONLY = 8
}

/// Port errors
enum PortError : byte {
    EOK = 0,
    EPERM = 1,
    EINVAL = 2,
    EEMPTY = -1,
}

/// Userland port rights
struct PortRights {
    /// What kind of rights this is?
    PortRightsKind kind = PortRightsKind.NONE;

    /// The port
    Port* port;

    /// Send data
    PortError send(long pid, byte[] data) {
        if (!(kind & PortRightsKind.SEND)) {
            printk(ERROR, "Attempted to send from a recieve port (kind = {hex})", kind);
            return PortError.EINVAL;
        }
        if (pid == -1) {
            if (!(kind & PortRightsKind.ANON)) {
                printk(WARN, "Permission denied to anonymously send from a regular port (kind = {hex})", kind);
                return PortError.EPERM;
            }
        } else {
            if (kind & PortRightsKind.ANON_ONLY) {
                printk(WARN, "Permission denied to non-anonymously send from an anon-only port (kind = {hex})", kind);
                return PortError.EPERM;
            }
        }
        byte[] heapdata = alloca_unsafe!(byte)(data.length);
        memcpy(heapdata.ptr, data.ptr, data.length);
        this.port.message = alloc!(PortMessage)(this.port.message, heapdata, pid);
        return PortError.EOK;
    }

    /// Recieve data
    PortError recv(ref byte[] data) {
        if (!(kind & PortRightsKind.RECV)) {
            printk(ERROR, "Attempted to recieve from a send port (kind = {hex})", kind);
            return PortError.EINVAL;
        }
        PortMessage* msg = this.port.message;
        if (msg == cast(PortMessage*) 0)
            return PortError.EEMPTY;
        this.port.message = msg.next;
        data = alloca!(byte)(msg.data.length);
        memcpy(data.ptr, msg.data.ptr, msg.data.length);
        free(msg.data);
        free(msg);
        return PortError.EOK;
    }

    @disable this();
    /// Make it from a port
    this(Port* port, PortRightsKind kind) {
        this.port = port;
        this.port.rc += 1;
        this.kind = kind;
    }
    /// Copy
    this(ref PortRights rhs) {
        this.port = rhs.port;
        this.port.rc += 1;
        this.kind = kind;
    }
    /// Dtor
    ~this() {
        this.port.rc -= 1;
        if (this.port.rc == 0) {
            printk(DEBUG, "Letting go of a port!");
            free(this.port);
        }
    }
}

/// A port
struct Port {
    /// Port's refcount
    ulong rc = 0;

    /// Port's message, if any
    PortMessage* message = cast(PortMessage*)0;
}

/// A fake (hax/kernel) port
struct FakePort {
    /// Recieve
    PortError function (FakePort*, ref byte[] data) _recv;
    /// Send
    PortError function (FakePort*, byte[] data) _send;
    /// Data
    void* data;
    
    /// Recieve
    PortError recv(ref byte[] data) {
        return this._recv(&this, data);
    }
    /// Send
    PortError send(byte[] data) {
        return this._send(&this, data);
    }
}
module vshared.share;

enum PortCloneFlags {
    RECV = 1,
    SEND = 2,
    SEND_ANON = 4
}

/// Port errors
enum PortError : byte {
    EOK = 0,
    EPERM = 1,
    EINVAL = 2,
    EEMPTY = -1,
}
enum Syscall {
    EXIT = 1,
    MAP = 2,
    MUNMAP = 3,
    SEND = 4,
    RECV = 5,
    CLOSE_PORT = 6,
    CLONE_PORT = 7,
    CREATE_PORT = 8,
    DESTROY_PORT = 9,
    EXEC = 10,
    FORK = 11,
    KPRINT = 12,
    GET_STACK_BOUNDS = 13,
    GET_TID = 14,
}
enum IOOpKind {
    KIND_SEND,
    KIND_SEND_ANON,
    KIND_RECV
}
alias KStackBounds = ulong;
struct KPortCreate {
    ulong outp;
}
struct KPortDestroy {
    ulong inp;
}
struct KPortIOOp {
    ulong port;
    void* data;
    ulong len;
    IOOpKind kind;
}
struct KPortClone {
    ulong port_in;
    ulong port_out;
    PortCloneFlags flags;
}
struct KPrintBuffer {
    ulong len;
    char* ptr;
}



const EPERM = 1;
const ENOENT = 2;
const ESRCH = 3;
const EINTR = 4;
const EIO = 5;
const ENXIO = 6;
const E2BIG = 7;
const ENOEXEC = 8;
const EBADF = 9;
const ECHILD = 10;
const EAGAIN = 11;
const ENOMEM = 12;
const EACCES = 13;
const EFAULT = 14;
const ENOTBLK = 15;
const EBUSY = 16;
const EEXIST = 17;
const EXDEV = 18;
const ENODEV = 19;
const ENOTDIR = 20;
const EISDIR = 21;
const EINVAL = 22;
const ENFILE = 23;
const EMFILE = 24;
const ENOTTY = 25;
const ETXTBSY = 26;
const EFBIG = 27;
const ENOSPC = 28;
const ESPIPE = 29;
const EROFS = 30;
const EMLINK = 31;
const EPIPE = 32;
const EDOM = 33;
const ERANGE = 34;
const EDEADLK = 35;
const ENAMETOOLONG = 36;
const ENOLCK = 37;
const ENOSYS = 38;
const ENOTEMPTY = 39;
const ELOOP = 40;
const EWOULDBLOCK = 11;
const ENOMSG = 42;
const EEMPTY = 43;

enum MMapProt {
    PROT_EXEC = 1,
    PROT_READ = 2,
    PROT_WRITE = 4,
}
enum MMapFlags {
    MAP_UNMAP = 1,
    MAP_FIXED = 2,
    MAP_PRIVATE = 4,
}
struct MMap {
    MMapFlags flags;
    // MMapProt prot;
    void* addr;
}
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



enum EPERM = 1;
enum ENOENT = 2;
enum ESRCH = 3;
enum EINTR = 4;
enum EIO = 5;
enum ENXIO = 6;
enum E2BIG = 7;
enum ENOEXEC = 8;
enum EBADF = 9;
enum ECHILD = 10;
enum EAGAIN = 11;
enum ENOMEM = 12;
enum EACCES = 13;
enum EFAULT = 14;
enum ENOTBLK = 15;
enum EBUSY = 16;
enum EEXIST = 17;
enum EXDEV = 18;
enum ENODEV = 19;
enum ENOTDIR = 20;
enum EISDIR = 21;
enum EINVAL = 22;
enum ENFILE = 23;
enum EMFILE = 24;
enum ENOTTY = 25;
enum ETXTBSY = 26;
enum EFBIG = 27;
enum ENOSPC = 28;
enum ESPIPE = 29;
enum EROFS = 30;
enum EMLINK = 31;
enum EPIPE = 32;
enum ERANGE = 33;
enum EDEADLK = 34;
enum ENAMETOOLONG = 35;
enum ENOLCK = 36;
enum ENOSYS = 37;
enum ENOTEMPTY = 38;
enum ELOOP = 39;
enum ENOMSG = 40;
enum EEMPTY = 41;

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
module libsys.errno;

static import vshared.share;

const EPERM = vshared.share.EPERM;
const ENOENT = vshared.share.ENOENT;
const ESRCH = vshared.share.ESRCH;
const EINTR = vshared.share.EINTR;
const EIO = vshared.share.EIO;
const ENXIO = vshared.share.ENXIO;
const E2BIG = vshared.share.E2BIG;
const ENOEXEC = vshared.share.ENOEXEC;
const EBADF = vshared.share.EBADF;
const ECHILD = vshared.share.ECHILD;
const EAGAIN = vshared.share.EAGAIN;
const ENOMEM = vshared.share.ENOMEM;
const EACCES = vshared.share.EACCES;
const EFAULT = vshared.share.EFAULT;
const ENOTBLK = vshared.share.ENOTBLK;
const EBUSY = vshared.share.EBUSY;
const EEXIST = vshared.share.EEXIST;
const EXDEV = vshared.share.EXDEV;
const ENODEV = vshared.share.ENODEV;
const ENOTDIR = vshared.share.ENOTDIR;
const EISDIR = vshared.share.EISDIR;
const EINVAL = vshared.share.EINVAL;
const ENFILE = vshared.share.ENFILE;
const EMFILE = vshared.share.EMFILE;
const ENOTTY = vshared.share.ENOTTY;
const ETXTBSY = vshared.share.ETXTBSY;
const EFBIG = vshared.share.EFBIG;
const ENOSPC = vshared.share.ENOSPC;
const ESPIPE = vshared.share.ESPIPE;
const EROFS = vshared.share.EROFS;
const EMLINK = vshared.share.EMLINK;
const EPIPE = vshared.share.EPIPE;
const EDOM = vshared.share.EDOM;
const ERANGE = vshared.share.ERANGE;
const EDEADLK = vshared.share.EDEADLK;
const ENAMETOOLONG = vshared.share.ENAMETOOLONG;
const ENOLCK = vshared.share.ENOLCK;
const ENOSYS = vshared.share.ENOSYS;
const ENOTEMPTY = vshared.share.ENOTEMPTY;
const ELOOP = vshared.share.ELOOP;
const EWOULDBLOCK = vshared.share.EWOULDBLOCK;
const ENOMSG = vshared.share.ENOMSG;

/// The errno
__gshared long errno = 0;

long error_out(long e) {
    errno = 0;
    if (e) errno = e;
    return e;
}

T must_succeed(string F = __FILE__, string fn = __FUNCTION__, int L = __LINE__, T)(T v) {
    if (errno) {
        import libsys.entry;

        perror!(F, L)(fn);
        cause_assert("must_succeed failed.".ptr, F.ptr, L);
    }
    return v;
}

void perror(string F = __FILE__, int L = __LINE__)(string e) {
    import libsys.io;
    string err = "Unknown error";

    switch (errno) {
        case EPERM: err = "<EPERM>"; break;
        case ENOENT: err = "<ENOENT>"; break;
        case ESRCH: err = "<ESRCH>"; break;
        case EINTR: err = "<EINTR>"; break;
        case EIO: err = "<EIO>"; break;
        case ENXIO: err = "<ENXIO>"; break;
        case E2BIG: err = "<E2BIG>"; break;
        case ENOEXEC: err = "<ENOEXEC>"; break;
        case EBADF: err = "Bad file descriptor"; break;
        case ECHILD: err = "<ECHILD>"; break;
        case EAGAIN: err = "<EAGAIN>"; break;
        case ENOMEM: err = "<ENOMEM>"; break;
        case EACCES: err = "<EACCES>"; break;
        case EFAULT: err = "<EFAULT>"; break;
        case ENOTBLK: err = "<ENOTBLK>"; break;
        case EBUSY: err = "<EBUSY>"; break;
        case EEXIST: err = "<EEXIST>"; break;
        case EXDEV: err = "<EXDEV>"; break;
        case ENODEV: err = "<ENODEV>"; break;
        case ENOTDIR: err = "<ENOTDIR>"; break;
        case EISDIR: err = "<EISDIR>"; break;
        case EINVAL: err = "<EINVAL>"; break;
        case ENFILE: err = "<ENFILE>"; break;
        case EMFILE: err = "<EMFILE>"; break;
        case ENOTTY: err = "<ENOTTY>"; break;
        case ETXTBSY: err = "<ETXTBSY>"; break;
        case EFBIG: err = "<EFBIG>"; break;
        case ENOSPC: err = "<ENOSPC>"; break;
        case ESPIPE: err = "<ESPIPE>"; break;
        case EROFS: err = "<EROFS>"; break;
        case EMLINK: err = "<EMLINK>"; break;
        case EPIPE: err = "<EPIPE>"; break;
        case EDOM: err = "<EDOM>"; break;
        case ERANGE: err = "<ERANGE>"; break;
        case EDEADLK: err = "<EDEADLK>"; break;
        case ENAMETOOLONG: err = "<ENAMETOOLONG>"; break;
        case ENOLCK: err = "<ENOLCK>"; break;
        case ENOSYS: err = "<ENOSYS>"; break;
        case ENOTEMPTY: err = "<ENOTEMPTY>"; break;
        case ELOOP: err = "<ELOOP>"; break;
        case ENOMSG: err = "<ENOMSG>"; break;
    default:
        printf(WARN, "unknown error {}", errno);
    }

    errno = 0;

    printf!(F, L)("{}: {}", e, err);
}
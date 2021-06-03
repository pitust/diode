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
const ENOMSG = vshared.share.ENOMSG;
const EEMPTY = vshared.share.EEMPTY;

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
        case EPERM: err = "Permission denied"; break;
        case ENOENT: err = "No such file or directory"; break;
        case ESRCH: err = "No such process"; break;
        case EINTR: err = "Interrupted system call"; break;
        case EIO: err = "IO error"; break;
        case ENXIO: err = "The device configuration is missing or is invalid"; break;
        case E2BIG: err = "Too many arguments!"; break;
        case ENOEXEC: err = "Executable format incorrect"; break;
        case EBADF: err = "An invalid file descriptor was used"; break;
        case ECHILD: err = "No child processes"; break;
        case EAGAIN: err = "Resource temporarily unavailable, try again later"; break;
        case ENOMEM: err = "No memory left"; break;
        case EACCES: err = "Permission denied"; break;
        case EFAULT: err = "Bad addresss (memory operand passed is invalid)"; break;
        case ENOTBLK: err = "The target device is not a block device"; break;
        case EBUSY: err = "The target resource is busy"; break;
        case EEXIST: err = "The file cannot be created as it already exists"; break;
        case EXDEV: err = "It is prohibited to hardlink across different devices (use symbolic links?)"; break;
        case ENODEV: err = "The desired operation is not supported by the device"; break;
        case ENOTDIR: err = "The target is a file not a directory"; break;
        case EISDIR: err = "The target is not a regular file but instead a directory"; break;
        case EINVAL: err = "Invalid argument"; break;
        case ENFILE: err = "Too many open files"; break;
        case EMFILE: err = "Too many open files"; break;
        case ENOTTY: err = "Inappropriate ioctl for device"; break;
        case ETXTBSY: err = "Target text file is busy; try again later"; break;
        case EFBIG: err = "The file is too large"; break;
        case ENOSPC: err = "No space left on the device"; break;
        case ESPIPE: err = "Attempt to illegaly seek out-of-bounds"; break;
        case EROFS: err = "This file system is not writable"; break;
        case EMLINK: err = "Too many hard links to a single file; consider using symbolic links instead"; break;
        case EPIPE: err = "Broken pipe"; break;
        case ERANGE: err = "The result is too large"; break;
        case EDEADLK: err = "This operation would cause a deadlock, which was avoided"; break;
        case ENAMETOOLONG: err = "This file name is too long"; break;
        case ENOLCK: err = "No locks are available"; break;
        case ENOSYS: err = "Not implemented"; break;
        case ENOTEMPTY: err = "The target directory not empty"; break;
        case ELOOP: err = "Too much symbolic link nesting, i give up"; break;
        case ENOMSG: err = "You asked me not to wait, and i can't find the message you want"; break;
        case EEMPTY: err = "The target file is empty"; break;
    default:
        printf(WARN, "unknown error {}", errno);
    }

    errno = 0;

    printf!(F, L)("{}: {}", e, err);
}
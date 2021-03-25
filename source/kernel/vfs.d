module kernel.vfs;

import kernel.refptr;


/// Errno
enum errno {
    ///OK
    EOK = 0,
    ///Operation not permitted
    EPERM = 1,
    ///No such file or directory
    ENOENT = 2,
    ///No such process
    ESRCH = 3,
    ///Interrupted system call
    EINTR = 4,
    ///Input/output error
    EIO = 5,
    ///Device not configured
    ENXIO = 6,
    ///Argument list too long
    E2BIG = 7,
    ///Exec format error
    ENOEXEC = 8,
    ///Bad file descriptor
    EBADF = 9,
    ///No child processes
    ECHILD = 10,
    ///Resource deadlock avoided
    EDEADLK = 11,
    ///Cannot allocate memory
    ENOMEM = 12,
    ///Permission denied
    EACCES = 13,
    ///Bad address
    EFAULT = 14,
    ///Block device required
    ENOTBLK = 15,
    ///Resource busy
    EBUSY = 16,
    ///File exists
    EEXIST = 17,
    ///Cross-device link
    EXDEV = 18,
    ///Operation not supported by device
    ENODEV = 19,
    ///Not a directory
    ENOTDIR = 20,
    ///Is a directory
    EISDIR = 21,
    ///Invalid argument
    EINVAL = 22,
    ///Too many open files in system
    ENFILE = 23,
    ///Too many open files
    EMFILE = 24,
    ///Inappropriate ioctl for device
    ENOTTY = 25,
    ///Text file busy
    ETXTBSY = 26,
    ///File too large
    EFBIG = 27,
    ///No space left on device
    ENOSPC = 28,
    ///Illegal seek
    ESPIPE = 29,
    ///Read-only file system
    EROFS = 30,
}

/// A file handle
struct File {
    /// Where be i?
    errno function(File*, ulong*) _tell;
    /// How long be i?
    errno function(File*, ulong*) _size;
    /// Seek
    errno function(File*, ulong) _seek;
    /// Write
    errno function(File*, void* data, ref ulong size) _write;
    /// Read
    errno function(File*, void* data, ref ulong size) _read;
    /// Close
    void function(File*) _close;
    
    /// fs-defined data
    void* data;

    /// the fs name
    string fs;

    /// Is it closed?
    bool closed = false;

    ~this() {
        if (closed) return;
        closed = true;
        _close(&this);
    }
    /// Copy ctor
    this(ref DirectoryReader rhs) {
        assert(0, "Cannot copy a DirectoryReader");
    }
}

/// A Directory Reader
struct DirectoryReader {
    /// Implement interator api
    bool function(DirectoryReader*) _empty;
    /// Implement interator api
    void function(DirectoryReader*) _popFront;
    /// Implement interator api.
    Ref!VFSNode* function(DirectoryReader*) _front;
    /// Handle being dropped
    void function(DirectoryReader*) _drop;

    /// Some state
    void* state;

    /// Implement interator api
    bool empty() {
        return _empty(&this);
    }
    /// Implement interator api
    void popFront() {
        _popFront(&this);
    }
    /// Implement interator api
    Ref!VFSNode* front() {
        return _front(&this);
    }

    ~this() {
        _drop(&this);
    }
    /// Copy ctor
    this(ref DirectoryReader rhs) {
        assert(0, "Cannot copy a DirectoryReader");
    }
}

/// A VFS Node
struct VFSNode {
    /// Start reading a directory
    errno function(VFSNode*, DirectoryReader*) _readdir;
    /// Get a child
    errno function(VFSNode*, string name, Ref!VFSNode*) _child;
    /// Get a handle
    errno function(VFSNode*, File*) _open;
    /// Create a file
    errno function(VFSNode*, string name) _create;
    /// Create a directory
    errno function(VFSNode*, string name) _mkdir;
    /// Delete a child
    errno function(VFSNode*, string name) _unlink;
    /// Handle being dropped
    void function(VFSNode*) _drop;

    /// Data
    void* data;

    /// Start reading a directory
    errno readdir(DirectoryReader* r) {
        return _readdir(&this, r);
    }
    /// Create a directory
    errno mkdir(string name) {
        return _mkdir(&this, name);
    }
    /// Create a file
    errno create(string name) {
        return _create(&this, name);
    }
    /// Get a child
    errno child(string name, Ref!VFSNode* to) {
        return _child(&this, name, to);
    }
    /// Get a handle
    errno open(File* f) {
        return _open(&this, f);
    }
    /// Delete a child
    errno unlink(string name) {
        return _unlink(&this, name);
    }

    ~this() {
        _drop(&this);
    }
    /// Copy ctor
    this(ref VFSNode rhs) {
        assert(0, "Cannot copy a VFSNode");
    }

}
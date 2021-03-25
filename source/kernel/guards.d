module kernel.guards;

import kernel.platform;
import kernel.io;

private __gshared ulong rc = 0;

/// SMAP guard
struct SMAPGuard {
    @disable this();
    package bool is_legit = false;

    ///
    this(ref SMAPGuard rhs) {
        if (is_legit) {
            rc += 1;
            is_legit = true;
        }
    }

    ~this() {
        if (is_legit) {
            rc -= 1;
            if (rc == 0) {
            printk(DEBUG, "Reenabling SMAP");
                clac();
            }
        }
    }

    /// Kill this guard 
    void die() {
        assert(is_legit);
        is_legit = false;
        rc -= 1;
        
        if (rc == 0) {
            printk(DEBUG, "Reenabling SMAP");
            clac();
        }
    }
}
/// Disable SMAP
SMAPGuard no_smap() {
    bool fake = false;
    stac();
    printk(DEBUG, "Disable SMAP");
    SMAPGuard the = *cast(SMAPGuard*)&fake;
    the.is_legit = true;
    rc += 1;
    return the;
}
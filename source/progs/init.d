module progs.init;

import libsys.errno;
import libsys.entry;
import libsys.port;
import libsys.loaf;
import libsys.mem;
import libsys.io;
import libsys.syscall;
import vshared.share;

enum BootstrapCmd {
    NOTIFY_EXIT = 1,
    NOTIFY_PING = 2,
    NOTIFY_PROXIED_MSG = 3,
}

struct BootstrapCmdExit {
    BootstrapCmd cmd;
    ulong code;
}

struct BootstrapCmdProxiedExit {
    BootstrapCmd cmd;
    ulong pid;
    ulong code;
}

struct Meme {
    ulong x;
    ulong y;
    ulong z;
}

int app() {
    printf("Hello, world!");
    port_t p;
    if (meh_port_create(p)) {
        perror("meh_port_create");
        exit(1);
    }
    long f = fork();
    printf("fork(): {} (pid={})", f, getpid());
    if (f) {
        // parent
        Meme x = Meme(69, 420, 1337);
        meh_port_send(p, loaf_encode(x));
        meh_port_delete(p);
    } else {
        // child
        byte[] da;
        if (meh_port_recv(p, da)) { perror("meh_port_recv"); return 1; }
        Meme x;
        loaf_decode(x, da);
        printf("m: {}", x);
        meh_port_delete(p);
    }
    return 3;
}

mixin entry!app;

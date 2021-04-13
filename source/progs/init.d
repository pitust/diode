module progs.init;

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

int app() {
    printf("Hello, world!");
    port_t p = port_t(0);
    // p.send_fat(BootstrapCmdProxiedExit(BootstrapCmd.NOTIFY_PROXIED_MSG, 69, 1234));
    printf("hmm: {} (we are {})", fork(), getpid());
    // meh_port_recv
    return 3;
}

mixin entry!app;

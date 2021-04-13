module kernel.ports.kbootstrap;

import kernel.io;
import kernel.port;
import kernel.loafencode;
import vshared.share;

enum BootstrapCmd {
    NOTIFY_EXIT = 1,
    NOTIFY_PING = 2,
    NOTIFY_PROXIED_EXIT = 3,
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

PortError bootstrap_send(FakePort*, long pid, byte[] data) {
    BootstrapCmd c;
    decode(c, data);
    if (c == BootstrapCmd.NOTIFY_EXIT) {
        BootstrapCmdExit c2;
        decode(c2, data);
        printk("Pid {} exited with code {}", pid, c2.code);
        return PortError.EOK;
    } else if (c == BootstrapCmd.NOTIFY_PING) {
        printk(">>>>>> Ping! <<<<<<");
        return PortError.EOK;
    } else if (c == BootstrapCmd.NOTIFY_PROXIED_EXIT) {
        BootstrapCmdProxiedExit c2;
        decode(c2, data);
        printk("Pid {} exited with code {}", c2.pid, c2.code);
        return PortError.EOK;
    } else {
        printk(WARN, "Unimplemented bootstrap CMD: {hex} (aka {hex})", c, cast(ulong) c);
    }
    return PortError.EINVAL;
}

PortError bootstrap_recv(FakePort*, long pid, ref byte[] data) {
    printk(WARN, "User({}) EINVAL: Invalid operation on bootstrap port, recv", pid);
    return PortError.EINVAL;
}

FakePort create_bootstrap() {
    return FakePort(&bootstrap_recv, &bootstrap_send);
}

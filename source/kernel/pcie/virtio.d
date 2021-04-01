module kernel.pcie.virtio;

import core.volatile;
import kernel.io;

ulong load_u32(uint a) {
    return load_u32(cast(ulong) a);
}

ulong load_u32(ulong a) {
    return cast(ulong)volatileLoad(cast(uint*) a);
}

void store_u32(ulong a, uint v) {
    volatileStore(cast(uint*) a, v);
}

ulong load_u64(uint a) {
    return load_u64(cast(ulong) a);
}

ulong load_u64(ulong a) {
    return volatileLoad(cast(ulong*) a);
}

enum VirtIOPorts {
    MagicValue = 0x000,
    Version = 0x004,
    DeviceId = 0x008,
    VendorId = 0x00c,
    HostFeatures = 0x010,
    HostFeaturesSel = 0x014,
    GuestFeatures = 0x020,
    GuestFeaturesSel = 0x024,
    GuestPageSize = 0x028,
    QueueSel = 0x030,
    QueueNumMax = 0x034,
    QueueNum = 0x038,
    QueueAlign = 0x03c,
    QueuePfn = 0x040,
    QueueNotify = 0x050,
    InterruptStatus = 0x060,
    InterruptAck = 0x064,
    Status = 0x070,
    Config = 0x100,
}

void init_virtio_blk(ulong ptr) {
    printk("Initializing virtio-blk @ {ptr}", ptr);
    assert(load_u32(ptr + VirtIOPorts.MagicValue) != 0x74_72_69_76);
    assert(load_u32(ptr + 8) != 0);
    debug assert(load_u32(ptr + 8) == 1);
    store_u32(ptr + VirtIOPorts.Status, 0);
    store_u32(ptr + VirtIOPorts.Status, 1 << 0);
    printk("{hex}", load_u32(ptr + VirtIOPorts.Status));
    store_u32(ptr + VirtIOPorts.Status, 1 << 0 | 1 << 3);
    printk("{hex}", load_u32(ptr + VirtIOPorts.Version));
    printk("Features: {hex}", load_u32(ptr + VirtIOPorts.HostFeatures));
    store_u32(ptr + VirtIOPorts.GuestFeatures, 0);
    store_u32(ptr + VirtIOPorts.Status, 1 << 1 | 1 << 4 | 1 << 8);
    printk("{hex}", load_u32(ptr + VirtIOPorts.Status));
    assert(load_u32(ptr + VirtIOPorts.Status) & (1 << 8), "Guest can't support us!");
}

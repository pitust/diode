module kernel.pcie.mcfg;

import kernel.io;
import kernel.mm;
import kernel.acpi.rsdp;

uint load_u32(uint a) {
    return load_u32(cast(ulong) a);
}

uint load_u32(ulong a) {
    return *cast(uint*) a;
}

ulong load_u64(uint a) {
    return load_u64(cast(ulong) a);
}

ulong load_u64(ulong a) {
    return *cast(ulong*) a;
}

extern (C) struct MCFGEntry {
    align(1) ulong base;
    align(1) ushort group;
    align(1) ubyte buslo;
    align(1) ubyte bushi;
    align(1) uint _;
}

__gshared ulong[256] busbase;

void parse_mcfg() {
    ulong table = cast(ulong) find_table("MCFG").unwrap();
    uint entc = (load_u32(table + 4) - 44) >> 4;
    MCFGEntry[] e = array(cast(MCFGEntry*)(table + 44), entc);
    foreach (MCFGEntry ent; e) {
        foreach (i; cast(int)(ent.buslo) .. (cast(int)(ent.bushi) + 1)) {
            busbase[i] = ent.base + ((i - ent.buslo) << 20);
        }
    }
}

ubyte pci_readbyte(ulong bus, ulong dev, ulong fn, ulong offset) {
    return *cast(byte*)(busbase[bus] + ((dev << 15) | (fn << 12)) | offset);
}

ushort pci_readshort(ulong bus, ulong dev, ulong fn, ulong offset) {
    return *cast(ushort*)(busbase[bus] + ((dev << 15) | (fn << 12)) | offset);
}

uint pci_readint(ulong bus, ulong dev, ulong fn, ulong offset) {
    return *cast(uint*)(busbase[bus] + ((dev << 15) | (fn << 12)) | offset);
}

ulong pci_readlong(ulong bus, ulong dev, ulong fn, ulong offset) {
    return *cast(ulong*)(busbase[bus] + ((dev << 15) | (fn << 12)) | offset);
}

enum Class {
    MSC = 1
}

enum MSCSubClass {
    SCSI = 0,
    IDE = 1,
    FDC = 2,
    IPI = 3,
    RAID = 4,
    ATA = 5,
    SATA = 6,
    SAS = 7,
    NVM = 8,
}

enum MSCSATAProgif {
    VENDOR = 0,
    AHCI = 1,
    SSB = 2
}

enum HeaderType {
    REGULAR_MULTIFUNCTION = 0x80,
    PCI_TO_PCI_MULTIFUNCTION = 0x81,
    PCI_TO_CBUS_MULTIFUNCTION = 0x82,
    REGULAR = 0x00,
    PCI_TO_PCI = 0x01,
    PCI_TO_CBUS = 0x02,
}

void scan_pci() {
    printk("PCI devices:");
    foreach (bus; 0 .. 256) {
        foreach (device; 0 .. 32) {
            foreach (fn; 0 .. 8) {
                ushort vendor = pci_readshort(bus, device, fn, 0);
                if (vendor != 0xFFFF) {
                    ushort devid = pci_readshort(bus, device, fn, 2);
                    printk(" - {}.{}.{}: {hex}:{hex}", bus, device, fn, vendor, devid);
                    // printk("BAR0: {hex}", pci_readint(bus, device, fn, 0x10));
                    // printk("BAR1: {hex}", pci_readint(bus, device, fn, 0x14));
                    // printk("BAR2: {hex}", pci_readint(bus, device, fn, 0x18));
                    // printk("BAR3: {hex}", pci_readint(bus, device, fn, 0x1C));
                    // printk("BAR4: {hex}", pci_readint(bus, device, fn, 0x20));
                    // printk("BAR5: {hex}", pci_readint(bus, device, fn, 0x24));
                    if (vendor == 0x1af4) {
                        if (devid == 0x1001) {
                            import kernel.pcie.virtio;
                            
                            assert(pci_readint(bus, device, fn, 0x20) & 4, "Invalid BAR");
                            ulong ptr = pci_readlong(bus, device, fn, 0x20) & ~0xf;
                            init_virtio_blk(ptr);
                        } else {
                            printk("Unimplemented virtio device {}", device - 0xfff);
                        }
                    }
                }
            }
        }
    }
}

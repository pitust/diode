module kernel.stivale;

import kernel.io : Hex;
import kernel.optional;

/// A tag
extern (C) struct Tag {
    /// Tag ID
    align(8) Hex!ulong ident;
    /// Next tag pointer
    align(8) Tag* next;
}
/// The header
extern (C) struct StivaleHeader {
    /// The bootloader brand
    char[64] brand;
    /// The bootloader name?
    char[64] loader;
    /// The tags!
    Tag* tag0;
}

private const ulong HEADER_TAG_FRAMEBUFFER_ID = 0x3ecc1bc43d0f7971;
private const ulong HEADER_TAG_FB_MTRR_ID = 0x4c7bb07731282e00;
private const ulong HEADER_TAG_SMP_ID = 0x1ab015085f3273df;
private const ulong HEADER_TAG_5LV_PAGING_ID = 0x932f477032007e8f;
private const ulong STRUCT_TAG_CMDLINE_ID = 0xe5e76a1b4597a781;
/// Command line stivale2 tag
extern (C) struct TagCommandLine {
    /// the tag struct
    align(8) Tag tag;
    /// The command line
    char* cmdline;
}

private const ulong STRUCT_TAG_MEMMAP_ID = 0x2187f79e8612de07;
/// Memory map entry
extern (C) struct MemoryMapEntry {
    /// Base address
    align(8) ulong base;
    /// Size
    align(8) ulong size;
    /// The type of this entry, 1 = usable ram
    align(4) uint type;
    /// Padding
    align(4) uint pad;
}
/// Memory map stivale2 tag
extern (C) struct TagMemoryMap {
    /// the tag struct
    align(8) Tag tag;
    //// Amount of entries
    align(8) ulong entcount;
    /// The memory map entries
    align(8) MemoryMapEntry[0x1000] entries;

}

/// A module
extern(C) struct Module {
    ///
    ulong begin;
    ///
    ulong end;
    ///
    char[128] name;
}

/// Memory map stivale2 tag
extern (C) struct TagModules {
    /// the tag struct
    align(8) Tag tag;
    /// Amount of modules
    align(8) ulong modulecount;
    /// Modules
    align(8) Module[0x8] modules;

}

private const ulong STRUCT_TAG_FRAMEBUFFER_ID = 0x506461d2950408fa;
private const ulong STRUCT_TAG_FB_MTRR_ID = 0x6bc1a78ebe871172;
private const ulong STRUCT_TAG_MODULES_ID = 0x4b6fe466aade04ce;
private const ulong STRUCT_TAG_RSDP_ID = 0x9e1786930a375e78;
private const ulong STRUCT_TAG_EPOCH_ID = 0x566a7bed888e1407;
private const ulong STRUCT_TAG_FIRMWARE_ID = 0x359d837855e3858c;
private const ulong STRUCT_TAG_SMP_ID = 0x34d1d96339647025;
private const ulong STRUCT_TAG_PXE_SERVER_INFO = 0x29d1e96239247032;

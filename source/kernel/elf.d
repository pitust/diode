module kernel.elf;

///
extern (C) struct ELF {
    ///
    char[16] ident;
    ///
    ushort e_type;
    ///
    ushort e_machine;
    ///
    uint e_version;
    ///
    ulong e_entry;
    ///
    ulong e_phoff;
    ///
    ulong e_shoff;
    ///
    uint e_flags;
    ///
    ushort e_ehsize;
    ///
    ushort e_phentsize;
    ///
    ushort e_phnum;
    ///
    ushort e_shentsize;
    ///
    ushort e_shnum;
    ///
    ushort e_shstrndx;

}

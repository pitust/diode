module kernel.elf;

import kernel.io;
import kernel.mm;
import kernel.cpio;
import kernel.pmap;
import kernel.util;
import kernel.task;
import kernel.guards;

///
extern (C) struct ELF {
    char[16] ident;
    ushort e_type;
    ushort e_machine;
    uint e_version;
    ulong e_entry;
    ulong e_phoff;
    ulong e_shoff;
    uint e_flags;
    ushort e_ehsize;
    ushort e_phentsize;
    ushort e_phnum;
    ushort e_shentsize;
    ushort e_shnum;
    ushort e_shstrndx;
}

///
struct ProgramHeader {
    uint p_type;
    uint p_flags;
    ulong p_offset;
    ulong p_vaddr;
    ulong p_paddr;
    ulong p_filesz;
    ulong p_memsz;
    ulong p_align;
}

const ushort ET_NONE = 0;
const ushort ET_REL = 1;
const ushort ET_EXEC = 2;
const ushort ET_DYN = 3;
const ushort ET_CORE = 4;

const ushort EM_M32 = 1;
const ushort EM_SPARC = 2;
const ushort EM_386 = 3;
const ushort EM_68K = 4;
const ushort EM_88K = 5;
const ushort EM_486 = 6;
const ushort EM_860 = 7;
const ushort EM_MIPS = 8;
const ulong EM_PARISC = 15;
const ulong EM_SPARC32PLUS = 18;
const ulong EM_PPC = 20;
const ulong EM_PPC64 = 21;
const ulong EM_SPU = 23;
const ulong EM_SH = 42;
const ulong EM_SPARCV9 = 43;
const ulong EM_IA_64 = 50;
const ulong EM_X86_64 = 62;
const ulong EM_S390 = 22;
const ulong EM_CRIS = 76;
const ulong EM_V850 = 87;
const ulong EM_M32R = 88;
const ulong EM_H8_300 = 46;
const ulong EM_MN10300 = 89;
const ulong EM_BLACKFIN = 106;
const ulong EM_FRV = 0x5441;
const ulong EM_AVR32 = 0x18ad;
const ulong EM_SMIDISCA = 0xffef;

bool load(out ulong rip, CPIOFile exe) {
    ELF elf = *cast(ELF*) exe.data.ptr;
    if (elf.ident != "\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00")
        return false;
    if (elf.e_type != ET_EXEC)
        return false;
    if (elf.e_machine != EM_X86_64)
        return false;
    if (elf.e_version != 1)
        return false;

    ProgramHeader* _phdrs = cast(ProgramHeader*)(exe.data.ptr + elf.e_phoff);
    ProgramHeader[] phs = array(_phdrs, elf.e_phnum);
    foreach (ref ProgramHeader ph; phs) {
        if (ph.p_type !=  /* PT_LOAD */ 1)
            continue;
        ulong pagec = (ph.p_memsz + 4095) / 4096;
        foreach (i; 0 .. pagec) {
            void* raw = page();
            ulong va = cast(ulong)(ph.p_vaddr + (i * 4096));
            *get_user_pte_ptr(cast(void*) va).unwrap() = 7 | cast(ulong) raw;
        }
        auto smap = no_smap();
        memcpy(cast(byte*) ph.p_vaddr, cast(byte*)(ph.p_offset + exe.data.ptr), ph.p_filesz);
        memset(cast(byte*)(ph.p_vaddr + ph.p_filesz), 0, ph.p_memsz - ph.p_filesz);
        smap.die();
    }
    rip = elf.e_entry;
    return true;
}

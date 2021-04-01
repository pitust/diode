module kernel.cpio;

import kernel.mm;
import kernel.io;

struct CPIOFile {
    string name;
    ubyte[] data;
    ulong uid;
}

void find(out CPIOFile file, string name, ref CPIOFile[] arr) {
    foreach (ref fl; arr) {
        if (name == fl.name) { file = fl; return; }
    }
    printk(FATAL, "Unable to find {}", name);
    assert(0, "Unable to find crucial file, aborting!");
}
bool try_find(out CPIOFile file, string name, ref CPIOFile[] arr) {
    foreach (ref fl; arr) {
        if (name == fl.name) { file = fl; return true; }
    }
    printk(WARN, "Unable to find {}", name);
    return false;
}

int parse_oct(ubyte[] raw, int start, int len) {
    int v = 0;
    int end = start + len;
    
    ubyte[] seg = raw[start .. end];
    foreach (i; 0..len) {
        v <<= 3;
        v |= (seg[i] - '0');
    }
    return v;
}

CPIOFile[] parse_cpio(ubyte[] raw) {
    int cursor = 0;
    CPIOFile[] filez = alloca!(CPIOFile)(0);
    while (cursor < raw.length) {
        int filebegin = cursor;
        cursor += 76;
        int uid = parse_oct(raw,  filebegin + 24, 6);
        int namesz = parse_oct(raw,  filebegin + 59, 6);
        int filesz = parse_oct(raw,  filebegin + 65, 11);
        CPIOFile f;
        f.name = alloca!(immutable(char))(namesz - 1, cast(char)0);
        f.data = alloca!(ubyte)(filesz, cast(ubyte)0);
        char[] s = transmute!(string, char[])(f.name);
        foreach (i; 0..(namesz - 1)) {
            s[i] = cast(char)raw[cursor++];
        }
        cursor++;
        foreach (i; 0..filesz) {
            f.data[i] = cast(char)raw[cursor++];
        }
        f.uid = uid;
        if (f.name == "TRAILER!!!") break;
        push(filez, f);
    }
    return filez;
}


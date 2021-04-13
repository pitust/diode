module kernel.hashmap;

import kernel.mm;

struct HMI {
    ulong addr;
    ulong* rc;
    bool isthere;
}

private ulong hash(ulong i, ulong v) {
    return (v * 1345) % i;
}

struct HashMap {
    HMI[] data = [];
    ulong c = 0;

    ~this() {
        free(data);
    }

    void deleteElem(ulong addr) {
        ulong v = hash(data.length, addr);
        while (data[v].isthere && data[v].addr != addr) v = hash(data.length, v);
        if (data[v].isthere) c -= 1;
        data[v].isthere = false;
    }

    void rehashSelf() {
        HMI[] elems = [];
        foreach (ref HMI e; data) {
            if (e.isthere) push(elems, e);
        }
        ulong size = (elems.length + 2) * 2;
        data = realloca(data, size);
        foreach (ref HMI e; data) {
            e.isthere = false;
        }
        c = 0;
        foreach (ref HMI e; elems) {
            insertElem(e.addr, e.rc);
        }
        free(elems);
    }

    void insertElem(ulong addr, ulong* rc) {
        c += 1;
        if (c >= data.length) {
            rehashSelf();
            c += 1;
        }
        ulong v = hash(data.length, addr);
        while (data[v].isthere) { v += 1; v %= data.length; }
        data[v].isthere = true;
        data[v].rc = rc;
        data[v].addr = addr;
    }

    ulong** getElem(ulong addr) {
        assert(data.length != 0);
        ulong v = hash(data.length, addr);
        while (data[v].isthere && data[v].addr != addr) { v += 1; v %= data.length; }
        return &data[v].rc;
    }

    bool hasElem(ulong addr) {
        if (data.length == 0) return false;
        ulong v = hash(data.length, addr);
        while (data[v].isthere && data[v].addr != addr) { v += 1; v %= data.length; }
        return data[v].isthere;
    }

    bool opBinaryRight(string s)(ulong k) if (s == "in")
    {
        return hasElem(k);
    }

    ref ulong* opIndex(ulong addr) {
        assert(addr in this);
        return *getElem(addr);
    }
}
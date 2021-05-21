module kernel.hashmap;

import kernel.mm;
import std.typecons;

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

struct BetterHashMap(U) {
    HashMap _h;

    ref U* opIndex(ulong addr) {
        assert(addr in this);
        return *cast(U**)_h.getElem(addr);
    }

    bool opBinaryRight(string s)(ulong k) if (s == "in")
    {
        return _h.hasElem(k);
    }

    void deleteElem(ulong addr) {
        if (!(addr in _h)) return;
        ulong* a = _h[addr];
        free(a);
        _h.deleteElem(addr);
    }

    void insertElem(Args...)(ulong addr, Args argz) {
        U* a = alloc!U(U(argz));
        _h.insertElem(addr, cast(ulong*)a);
    }

    BHMIter!U iter() {
        return BHMIter!(U)(_h.data);
    }
}

struct BHMIter(T) {
    HMI[] _inner;
    ulong i = 0;

    /// Is it empty?
    bool empty() const {
        ulong i = this.i;
        while (!this._inner[i].isthere && i < _inner.length) i++;
        // The range is consumed when begin equals end
        return _inner.length > i;
    }

    /// Next element pls
    void popFront() {
        // Skipping the first element is achieved by
        // incrementing the beginning of the range
        i++;
        while (!this._inner[i].isthere && i < _inner.length) i++;
    }

    /// First element ptr (reborrowed)
    Tuple!(ulong, T*) front() const {
        return tuple(cast(ulong)this._inner[i].addr, cast(T*) this._inner[i].rc);
    }
}
module kernel.mm;

private extern(C) struct MPageHeader {
    align(4) MPageHeader* next;
    ulong pagecount;
}

private __gshared MPageHeader* first = cast(MPageHeader*)0;

/// Allocate a page
void* page() {
    assert(first != cast(MPageHeader*)0);
    if (first.pagecount == 1) {
        void* result = cast(void*)first;
        first = first.next;
        return result;
    }
    first.pagecount -= 1;
    return cast(void*)(first + first.pagecount * 4096);
}

/// Add a bunch of pages to the memory manager
void addpage(ulong addr, ulong pagecount) {
    MPageHeader* next = first;
    first = cast(MPageHeader*)addr;
    import kernel.io : printk;
    first.next = next;
    first.pagecount = pagecount;
}
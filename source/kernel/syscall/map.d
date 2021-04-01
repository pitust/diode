module kernel.syscall.map;

import kernel.io;
import kernel.mm;
import kernel.pmap;
import kernel.task;

/// Map
long sys_map(void* data) {
    assert(0, "sys_map");
}
/// sbrk
long sys_sbrk(void* data) {
    assert(0, "sys_sbrk");
}
/// set up stack
long sys_make_user_stack(void* data) {
    ulong top = cur_t.user_stack_top = cast(ulong)alloc_user_virt();
    cur_t.user_stack_bottom = top - 0x1000;
    ulong* pte = get_user_pte_ptr(cast(void*)(cur_t.user_stack_bottom)).unwrap();
    void* pg = page();
    push(cur_t.memoryowned, cast(ulong)pg);
    *pte = 7 | cast(ulong)pg;
    printk(DEBUG, "Allocated user stack: {ptr}", cur_t.user_stack_top);
    return cast(long)cur_t.user_stack_top;
    assert(0, "sys_make_user_stack");
}

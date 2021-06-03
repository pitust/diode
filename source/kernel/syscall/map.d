module kernel.syscall.map;

import kernel.io;
import kernel.mm;
import kernel.pmap;
import kernel.util;
import kernel.task;
import vshared.share;
import kernel.syscall.util;

/// Get stack bounds
long sys_get_stack_bounds(void* data) {
    copy_to_user(data, &cur_t.user_stack_top, 8);
    return 0;
}

/// Map
long sys_map(void* data) {
    MMap map;
    copy_from_user(data, &map, MMap.sizeof);
    if (map.flags & MMapFlags.MAP_FIXED && (cast(ulong)map.addr) < (1UL << 32)) return EINVAL;
    if (map.flags & MMapFlags.MAP_UNMAP) {
        *get_user_pte_ptr(map.addr).unwrap() = 0;
        return 0;
    }
    if (!(map.flags & MMapFlags.MAP_PRIVATE)) return EINVAL;
    
    if (map.flags & MMapFlags.MAP_FIXED) {
        printk(WARN, "TODO: mmap(MAP_FIXED)");
        return ENOSYS;
    } else {
        void* addr = alloc_user_virt();
        auto ptep = get_user_pte_ptr(cast(void*) addr);
        while (ptep.is_none()) {
            addr = alloc_user_virt();
            ptep = get_user_pte_ptr(cast(void*) addr);
        }
        map.addr = addr;
        user_map(addr);
        copy_to_user(data, &map, map.sizeof);
        return 0;
    }

    assert(0);
}
/// sbrk
long sys_sbrk(void* data) {
    assert(0, "sys_sbrk");
}
/// set up stack
long sys_make_user_stack(void* data) {
    ulong top = cur_t.user_stack_top = cast(ulong)alloc_user_virt();
    cur_t.user_stack_bottom = top - 0x1000;
    user_map(cast(void*)(cur_t.user_stack_bottom));
    printk(DEBUG, "Allocated user stack: {ptr}", cur_t.user_stack_top);
    return cast(long)cur_t.user_stack_top;
}

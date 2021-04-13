module kernel.task;

import kernel.mm;
import kernel.io;
import kernel.irq;
import kernel.port;
import kernel.util;
import ldc.attributes;
import kernel.hashmap;
import kernel.platform;

/// A `t` - a DIOS task.
struct t {
    private ulong[5] state;
    private ulong juice;
    private t* prev;
    private t* next;
    /// The niceness value
    ulong niceness;
    /// the TID
    ulong tid;
    /// The mech ports owned by this `t`
    AnyPort[] ports;
    /// The low (user) pages owned by this `t`
    ulong[256] pages;
    /// Pages mapped
    ulong[] memoryowned;
    /// rsp0
    ulong rsp0val;
    
    HashMap pages_that_we_own;
    
    ulong user_stack_top = 0;
    ulong user_stack_bottom = 0;
}

/// A task creation request
private struct r {
    void function(void*) func;
    void* arg;
}

/// Current task
__gshared t* cur_t;
private __gshared t zygote_t;
private __gshared lock tidlock;
private __gshared ulong tidbase = 1;
private __gshared bool is_task_inited = false;

static assert(t.sizeof < 4096);

/// Ensure tasks are ready
void ensure_task_init() {
    if (!is_task_inited) {
        printk(DEBUG, "Initing task structures");
        is_task_inited = true;
        zygote_t.juice = 1;
        zygote_t.niceness = 20;
        zygote_t.tid = 1;
        zygote_t.next = &zygote_t;
        zygote_t.prev = &zygote_t;
        cur_t = &zygote_t;
    }
}

private __gshared bool is_go_commit_die = false;

private extern (C) void task_trampoline(r* the_r) {
    void function(void*) func = the_r.func;
    void* arg = the_r.arg;
    free(the_r);
    rsp0 = cast(void*)cur_t.rsp0val;
    func(arg);
    task_exit();
    assert(0);
}

private extern(C) void altstack_task_setup(void* data, ulong* target_buf);

/// Create a task
void task_create(T)(void function(T*) func, T* arg, void* stack) {
    r the_r;
    the_r.func = cast(void function(void*))func;
    the_r.arg = cast(void*)arg;
    const r* borrow_r = alloc!r(the_r);
    void* argg = cast(void*)borrow_r;

    t* the_t = cast(t*)page();
    memset(cast(byte*)the_t, 0, 4096);
    void*[0] a;

    ulong* s = the_t.state.ptr;
    asm {
        mov R13, stack;
        mov R14, s;
        mov R15, argg;
        xchg R13, RSP;
        mov RDI, R15;
        mov RSI, s;
        call altstack_task_setup;
        xchg R13, RSP;
    }
    the_t.next = cur_t.next;
    cur_t.next.prev = the_t;
    the_t.prev = cur_t;
    cur_t.next = the_t;
    the_t.tid = ++tidbase;
    the_t.user_stack_top = 0;
    the_t.user_stack_bottom = 0;
    the_t.rsp0val = cast(ulong)alloc_stack();
}

private ulong ncn_to_juice(ulong u) {
    return 41 - (20 + u);
}

/// Goodbye, cruel world!
void task_exit() {
    assert(cur_t.tid != 1, "Bootstrap task cannot be killed!");
    asm {
        cli;
    }
    t* self = cur_t;
    self.prev.next = self.next;
    self.next.prev = self.prev;
    cur_t = cur_t.next;
    free(cur_t.pages_that_we_own.data);
    free(self);
    task_pls_die(cur_t.state.ptr);
    assert(0);
}

private extern(C) void task_switch(ulong* buf);
private extern(C) void task_pls_die(ulong* buf);

private extern(C) void task_enqueue(ulong* buf) {
    ensure_task_init();
    cur_t.state[0] = buf[0];
    cur_t.state[1] = buf[1];
    cur_t.state[2] = buf[2];
    cur_t.state[3] = buf[3];
    cur_t.state[4] = buf[4];
    cur_t = cur_t.next;
}

/// Force a yield.
void sched_yield() {
    const ulong flg = flags;
    cli();
    ulong* cr3;
    asm {
        mov RAX, CR3;
        mov cr3, RAX;
    }
    foreach (i; 1..256) {
        cur_t.pages[i] = cr3[i];
        // if (cr3[i]) printk("i={} (tid={})", i, cur_t.tid);
    }
    asm {
        mov RAX, CR3;
        mov CR3, RAX;
    }
    task_switch(cur_t.next.state.ptr);
    rsp0 = cast(void*)cur_t.rsp0val;
    foreach (i; 1..256) {
        cr3[i] = cur_t.pages[i];
        // if (cr3[i]) printk("i={} (tid={})", i, cur_t.tid);
    }
    asm {
        mov RAX, CR3;
        mov CR3, RAX;
    }

    flags = flg;
}

/// Fake a yield, resetting the juice. Useful after changing the niceness in the kernel.
void fake_yield() {
    cur_t.juice = ncn_to_juice(cur_t.niceness);
}

/// Attempt to yield. Does not guarantee an actual yield.
void sched_mayyield() {
    cur_t.juice -= 1;
    if (cur_t.juice)
        return;
    sched_yield();
}

/// Map
void user_map(void* user) {
    import kernel.mm;
    import kernel.pmap;
    
    void* raw = page();
    memset(cast(byte*)raw, 0, 4096);
    *get_user_pte_ptr(user).unwrap() = 7 | cast(ulong) raw;
    push(cur_t.memoryowned, cast(ulong)raw);
    cur_t.pages_that_we_own.insertElem(cast(ulong)user, cast(ulong*)0);
}

module kernel.task;

import kernel.mm;
import kernel.platform;
import kernel.io;
import kernel.irq;
import kernel.port;
import kernel.util;
import ldc.attributes;

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
    PortRights[] ports;
    /// The fake mech ports owned by this `t`
    FakePort[] fakeports;
    /// The low (user) pages owned by this `t`
    ulong[256] pages;
    /// Pages mapped
    ulong[] memoryowned;
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

// llvm.eh.sjlj.longjmp

// llvm.eh.sjlj.setjmp

/// Ensure tasks are ready
void ensure_task_init() {
    if (!is_task_inited) {
        printk("Initing task structures");
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
    // black_box(the_r);
    // sched_yield();
    func(arg);
    // cli();
    // cur_t.next.prev = cur_t.prev;
    // cur_t.prev.next = cur_t.next;
    // t* nx = cur_t.next;
    // free!t(cur_t);
    // cur_t = *&nx;
    // is_go_commit_die = true;
    // asm {
    //     int 3;
    // }

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

    t* the_t = alloc!(t)();
    memset(cast(byte*)the_t.pages.ptr, 0, 2048);
    void*[0] a;
    // the_t.memoryowned = *&a;
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

    // assert(0);
}

private ulong ncn_to_juice(ulong u) {
    return 41 - (20 + u);
}

private extern(C) void task_switch(ulong* buf);

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
    foreach (i; 0..256) {
        cur_t.pages[i] = cr3[i];
        cr3[i] = 0;
    }
    task_switch(cur_t.next.state.ptr);
    foreach (i; 0..256) {
        cr3[i] = cur_t.pages[i];
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

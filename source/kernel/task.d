module kernel.task;

import kernel.mm : alloc, free;
import kernel.platform : flags, setflags, cli, setjmp, longjmp, jmpbuf, lock;
import kernel.io;
import kernel.irq;
import ldc.attributes;
private @weak T black_box(T)(T a) {
    return a;
}

/// A `t` - a DIOS task.
struct t {
    private ISRFrame state;
    private ulong juice;
    private t* prev;
    private t* next;
    /// The niceness value
    ulong niceness;
    /// the TID
    ulong tid;
}

/// A task creation request
private struct r {
    void function(void*) func;
    void* arg;
}

private __gshared t* cur_t;
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

private extern (C) void _onothertaskdostuff(r* the_r) {
    void function(void*) func = black_box(the_r.func);
    void* arg = black_box(the_r.arg);
    black_box(the_r);
    sched_yield();
    func(arg);
    cli();
    cur_t.next.prev = cur_t.prev;
    cur_t.prev.next = cur_t.next;
    t* nx = cur_t.next;
    free!t(cur_t);
    cur_t = *&nx;
    is_go_commit_die = true;
    asm {
        int 3;
    }
}

/// Create a task
void task_create(T)(void function(T*) func, T* arg, void* stack) {
    r the_r;
    the_r.func = cast(void function(void*)) func;
    the_r.arg = cast(void*) arg;
    const r* borrow_r = &the_r;
    ulong tgd = cast(ulong)&_onothertaskdostuff;
    t* task = alloc!t();
    task.juice = cur_t.juice;
    task.niceness = cur_t.niceness;
    task.state.rdi = cast(ulong)borrow_r;
    task.state.rsi = 0;
    task.state.rdx = 0;
    task.state.rcx = 0;
    task.state.rip = tgd;
    task.state.cs = 0x08;
    task.state.flags = flags;
    task.state.rsp = cast(ulong)stack;
    task.state.ss = 0x10;
    task.next = cur_t.next;
    task.prev = cur_t;
    tidlock.lock();
    task.tid = ++tidbase;
    tidlock.unlock();
    cur_t.next = task;
    sched_yield();
}

private ulong ncn_to_juice(ulong u) {
    return 41 - (20 + u);
}

/// Force a yield.
void sched_yield() {
    const ulong flg = flags;
    cli();
    asm {
        int 3;
    }
    setflags(flg);
}

/// Force a yield.
void sched_yield(ISRFrame* fr) {
    if (is_go_commit_die) {
        is_go_commit_die = false;
        *fr = cur_t.state;
        return;
    }
    ensure_task_init();
    cur_t.state = *fr;
    cur_t = cur_t.next;
    *fr = cur_t.state;
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

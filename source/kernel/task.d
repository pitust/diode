module kernel.task;

import kernel.mm : alloc, free;
import kernel.io;

/// A `t` - a DIOS task.
struct t {
    private ulong state;
    private ulong juice;
    /// The niceness value
    ulong niceness;
    /// next `t`
    t* next;

    /// IO thingy
    void __noshow_next() {
    }
}

/// A task creation request
private struct r {
    void function(void*) func;
    void* arg;
}

private extern (C) void handle_creat(r* the_r) {
    void* arg = the_r.arg;
    void function(void*) func = the_r.func;
    debug (sched)
        printk("The r: {}", the_r);
    free!r(the_r);
    debug (sched)
        printk("Starting a task...");
    sched_yield();
    debug (sched)
        printk("Task scheudled!");
    func(arg);
    task_exit();

}

/// This sets up a call to `rip` with the argument of `rdi` with stack at `stack`. The state necessary to resume 
/// into the newly created task is put into `their_state`
private extern (C) ulong task_call(ulong rdi, void* stack, ulong rip);
private extern (C) void asm_switch();
private extern (C) void asm_exit(ulong state);

private __gshared t* cur_t;
private __gshared t zygote_t;
private __gshared bool is_task_inited = false;

/// Ensure tasks are ready
void ensure_task_init() {
    if (!is_task_inited) {
        debug (sched)
            printk("Initing task structures");
        is_task_inited = true;
        zygote_t.juice = 1;
        zygote_t.niceness = 20;
        zygote_t.next = cast(t*) 0;
        cur_t = &zygote_t;
    }
}

/// Create a task
void task_create(T)(void function(T*) func, T* arg, void* stack) {
    ensure_task_init();
    asm {
        cli;
    }
    t* new_t = alloc!(t)();
    new_t.next = cur_t.next;
    if (cur_t.next == cast(t*) 0) {
        cur_t.next = new_t;
        new_t.next = cur_t;
    }
    new_t.niceness = cur_t.niceness;

    r* the_r = alloc!r();
    the_r.func = cast(void function(void*)) func;
    the_r.arg = cast(void*) arg;

    ulong stk2 = task_call(cast(ulong) the_r, stack, cast(ulong)&handle_creat);
    new_t.state = stk2;

    debug (sched)
        printk("The r (in task_create): {} [stack be {}, trampoline top {ptr}]", the_r, stack, stk2);

    sched_yield();
}

private ulong ncn_to_juice(ulong u) {
    return 41 - (20 + u);
}

private extern (C) void task_exit() {
    debug (sched)
        printk("Exiting the task!");
    assert(cur_t.next != cast(t*) 0);
    t* self = cur_t;
    cur_t = cur_t.next;
    cur_t.juice = ncn_to_juice(cur_t.niceness);
    if (cur_t.next == self)
        cur_t.next = cast(t*) 0;
    debug (sched)
        printk("Our new target: {}", cur_t);
    free!(t)(self);
    debug (sched)
        printk("`self` is freed, we are literally done!");
    asm_exit(cur_t.state);
}

private extern (C) ulong sched_switch(ulong cur) {
    cur_t.state = cur;
    cur_t = cur_t.next;
    debug (sched)
        printk("Saved: {hex} to {hex}", cur, cur_t.state);
    return cur_t.state;
}

/// Force a yield.
void sched_yield() {
    if (cur_t.next == cast(t*) 0) {
        debug (sched)
            printk("yield failed because we are too lonely!");
        fake_yield();
        return;
    }
    debug (sched)
        printk("yield... {hex}", cur_t.next.state);
    asm_switch();
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

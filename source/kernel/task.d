module kernel.task;

import kernel.mm : alloc, free;
import kernel.platform : flags, setflags, cli;
import kernel.io;

/// A `t` - a DIOS task.
struct t {
    private ulong state;
    private ulong juice;
    /// The niceness value
    ulong niceness;
}

/// A `c` - the state of a dios task
private struct c {
    ulong state;
    c* prev;
    c* next;
    t* data;
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
    asm_exit();

}

/// This sets up a call to `rip` with the argument of `rdi` with stack at `stack`. The state necessary to resume 
/// into the newly created task is put into `their_state`
private extern (C) ulong task_call(ulong rdi, void* stack, ulong rip);
private extern (C) void asm_switch();
private extern (C) void asm_exit();
private extern (C) void createc(c* the_c, void* stack, ulong the_rdi, ulong the_rip);

private __gshared t* cur_t;
private __gshared t zygote_t;
private __gshared bool is_task_inited = false;

/// Deallocate a `c`
extern (C) void dealloc_c(c* cc) {
    free!(c)(cc);
}

/// Ensure tasks are ready
void ensure_task_init() {
    if (!is_task_inited) {
        debug (sched)
            printk("Initing task structures");
        is_task_inited = true;
        zygote_t.juice = 1;
        zygote_t.niceness = 20;
        cur_t = &zygote_t;
    }
}

/// Create a task
void task_create(T)(void function(T*) func, T* arg, void* stack) {
    ensure_task_init();
    const ulong oldflags = flags();
    cli();
    t* new_t = alloc!(t)();
    new_t.niceness = cur_t.niceness;

    r* the_r = alloc!r();
    the_r.func = cast(void function(void*)) func;
    the_r.arg = cast(void*) arg;

    c* the_c = alloc!c();
    // c.data = new_t;

    createc(the_c, stack, cast(ulong)the_r, cast(ulong)&handle_creat);

    sched_yield();
    setflags(oldflags);
}

private ulong ncn_to_juice(ulong u) {
    return 41 - (20 + u);
}


/// Force a yield.
void sched_yield() {
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

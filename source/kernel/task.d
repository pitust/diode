module kernel.task;

/// A `t` - a DIOS task.
struct t {
    private ulong state;
    private ulong juice;
    /// The niceness value
    ulong niceness;
    /// next `t`
    t* next;
    /// is we 
}

private extern(C) ulong setjmp(ulong* jmpbuf);
private extern(C) void longjmp(ulong* jmpbuf, ulong ix);
/// This sets up a call to `rip` with the argument of `rdi` with stack at `stack`. The state necessary to resume 
/// into the newly created task is put into `their_state`
private extern(C) void task_call(ulong* their_state, ulong* stack, ulong rip, ulong rdi);

private void task_create() {

}

private __gshared t* cur_t;
private ulong ncn_to_juice(ulong u) {
    return 41 - (20 + u);
}
private extern(C) void task_exit() {
    assert(cur_t.next != cast(t*)0);
    const t* self = cur_t;
    cur_t = cur_t.next;
    cur_t.juice = ncn_to_juice(cur_t.niceness);
    if (cur_t.next == self) cur_t.next = cast(t*)0;
    longjmp(&cur_t.state, 1);
}
/// Force a yield.
void sched_yield() {
    t* self = cur_t;
    if (self.next == cast(t*)0) {
        fake_yield();
        return;
    }
    if (setjmp(&self.state)) return;
    cur_t = cur_t.next;
    fake_yield();
    longjmp(&cur_t.state, 1);
}
/// Fake a yield, resetting the juice. Useful after changing the niceness in the kernel.
void fake_yield() {
    cur_t.juice = ncn_to_juice(cur_t.niceness);
}
/// Attempt to yield. Does not guarantee an actual yield.
void sched_mayyield() {
    cur_t.juice -= 1;
    if (cur_t.juice) return;
    sched_yield();   
}
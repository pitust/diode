#include <stdint.h>


void __assert(char*, char*, int);
#define assert(e)  \
    ((void) ((e) ? ((void)0) : __assert (#e, __FILE__, __LINE__)))

void task_enqueue(void** buf);
void task_switch(void** buf2) {
    void* buf1v[5];
    if (__builtin_setjmp(buf1v)) {
        return;
    }
    task_enqueue(buf1v);
    __builtin_longjmp(buf2, 1);
}
void altstack_task_setup_internal(void* data, void** target_buf, void** exit_buf) {
    if (!__builtin_setjmp(target_buf)) {
        __builtin_longjmp(exit_buf, 1);
    }
    task_trampoline(data);
}
void altstack_task_setup(void* data, void** target_buf) {
    void* buf1v[5];
    if (__builtin_setjmp(buf1v)) {
        return;
    }
    altstack_task_setup_internal(data, target_buf, buf1v);
    /* never gets here */
    assert(0);
}
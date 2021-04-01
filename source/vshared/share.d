module vshared.share;

enum Syscall {
    EXIT = 1,
    MAP,
    SBRK,
    SEND,
    RECV,
    CREATE_PORT,
    EXEC,
    KPRINT
}
struct KPrintBuffer {
    ulong len;
    char* ptr;
}
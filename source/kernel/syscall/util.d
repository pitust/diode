module kernel.syscall.util;

import kernel.guards;


/// Is we safe now?
__gshared bool is_safe_function = false;

/// Copy from user to your area
void copy_from_user(void* user, void* buf, ulong len) {
    if ((cast(ulong)user) >= 0xffff_8000_0000_0000) {
        return;
    }
    is_safe_function = true;
    const auto g = no_smap();
    asm {
        mov R8, fail;
        mov RSI, user;
        mov RDI, buf;
        xor RCX, RCX;
        mov RDX, len;

    loop:
        cmp RCX, RDX;
        jge fail;
        
        mov AL, [RCX + RSI];
        mov [RCX + RDI], AL;
        inc RCX;
        jmp loop;
    fail:           ;
    }
    is_safe_function = false;
}

/// Copy to user from your area
void copy_to_user(void* user, void* buf, ulong len) {
    if ((cast(ulong)user) >= 0xffff_8000_0000_0000) {
        return;
    }
    is_safe_function = true;
    const auto g = no_smap();
    asm {
        mov R8, fail;
        mov RSI, buf;
        mov RDI, user;
        xor RCX, RCX;
        mov RDX, len;

    loop:
        cmp RCX, RDX;
        jge fail;
        
        mov AL, [RCX + RSI];
        mov [RCX + RDI], AL;

        inc RCX;
        jmp loop;
    fail:           ;
    }
    is_safe_function = false;
}
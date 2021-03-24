module kernel.util;

import kernel.io;

/// Int -> String
char* intToString(long value, char* str, int base) {
    char* rc;
    char* ptr;
    char* low;
    // Check for supported base.
    if (base < 2 || base > 36) {
        *str = '\0';
        return str;
    }
    rc = ptr = str;
    // Set '-' for negative decimals.
    if (value < 0 && base == 10) {
        *ptr++ = '-';
    }
    // Remember where the numbers start.
    low = ptr;
    // The actual conversion.
    do {
        // Modulo is negative for negative value. This trick makes abs() unnecessary.
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz"[cast(
                    int)(35 + value % base)];
        value /= base;
    }
    while (value);
    // Terminating the string.
    *ptr-- = '\0';
    // Invert the numbers.
    while (low < ptr) {
        const char tmp = *low;
        *low++ = *ptr;
        *ptr-- = tmp;
    }
    return rc;
}

/// Int -> String
char* intToString(ulong value, char* str, int base) {
    char* rc;
    char* ptr;
    char* low;
    // Check for supported base.
    if (base < 2 || base > 36) {
        *str = '\0';
        return str;
    }
    rc = ptr = str;
    // Set '-' for negative decimals.
    if (value < 0 && base == 10) {
        *ptr++ = '-';
    }
    // Remember where the numbers start.
    low = ptr;
    // The actual conversion.
    do {
        // Modulo is negative for negative value. This trick makes abs() unnecessary.
        *ptr++ = "0123456789abcdefghijklmnopqrstuvwxyz"[cast(
                    uint)(value % base)];
        value /= base;
    }
    while (value);
    // Terminating the string.
    *ptr-- = '\0';
    // Invert the numbers.
    while (low < ptr) {
        const char tmp = *low;
        *low++ = *ptr;
        *ptr-- = tmp;
    }
    return rc;
}

/// Int -> String
char* intToString(uint value, char* str, int base) {
    return intToString(cast(ulong) value, str, base);
}
/// Int -> String
char* intToString(int value, char* str, int base) {
    return intToString(cast(long) value, str, base);
}

/// Print some 1337 h4x0r hex
void puthex(int value) {
    char[32] arr;
    arr[0] = 0;
    char* rc;
    char* ptr;
    char* low;
    rc = ptr = arr.ptr;
    // Remember where the numbers start.
    low = ptr;
    // The actual conversion.
    do {
        // Modulo is negative for negative value. This trick makes abs() unnecessary.
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz"[35
            + value % 16];
        value /= 16;
    }
    while (value);
    // Terminating the string.
    *ptr-- = '\0';
    // Invert the numbers.
    while (low < ptr) {
        const char tmp = *low;
        *low++ = *ptr;
        *ptr-- = tmp;
    }
    putsk(rc);
}

/// Print a decimal
void putdec(int value) {
    char[32] arr;
    arr[0] = 0;
    char* rc;
    char* ptr;
    char* low;
    rc = ptr = arr.ptr;
    // Remember where the numbers start.
    low = ptr;
    // The actual conversion.
    if (value < 0) {
        *ptr++ = '-';
    }
    do {
        // Modulo is negative for negative value. This trick makes abs() unnecessary.
        *ptr++ = "zyxwvutsrqponmlkjihgfedcba9876543210123456789abcdefghijklmnopqrstuvwxyz"[35
            + value % 10];
        value /= 10;
    }
    while (value);
    // Terminating the string.
    *ptr-- = '\0';
    // Invert the numbers.
    while (low < ptr) {
        const char tmp = *low;
        *low++ = *ptr;
        *ptr-- = tmp;
    }
    putsk(rc);
}

/// A (pointer; len) tuple to iterator translation layer
struct PtrRange(T) {
    private int begin;
    private int end;
    private T* data;

    @disable this();
    /// Create a PtrRange
    this(int len, T* argdata) {
        this.begin = 0;
        this.data = argdata;
        this.end = len;
    }

    invariant() {
        // There is a bug if begin is greater than end
        assert(begin <= end);
    }

    /// Is it empty?
    bool empty() const {
        // The range is consumed when begin equals end
        return begin == end;
    }

    /// Next element pls
    void popFront() {
        // Skipping the first element is achieved by
        // incrementing the beginning of the range
        ++begin;
    }

    /// First element ptr (reborrowed)
    T* front() const {
        // The front element is the one at the beginning
        return cast(T*)&data[begin];
    }
}


/// An iterator based on pointer transforms
struct PtrTransformIter(T) {
    private T* function(T*) transformer;
    private T* data;

    @disable this();
    /// Create a PtrRange
    this(T* data, T* function(T*) transformer) {
        this.data = data;
        this.transformer = transformer;
    }

    /// Is it empty?
    bool empty() const {
        // The range is consumed when begin equals end
        return this.data == cast(T*)0;
    }

    /// Next element pls
    void popFront() {
        // Skipping the first element is achieved by
        // incrementing the beginning of the range
        this.data = this.transformer(this.data);
    }

    /// First element ptr (reborrowed)
    T* front() const {
        return cast(T*)this.data;
    }
}

/// memcmp - compare memory areas
///
/// # Description
/// The memcmp() function compares the first n bytes (each interpreted as unsigned char) of the memory areas s1 and s2.
///
/// # Return Value
/// The  memcmp()  function  returns an integer less than, equal to, or greater than zero if the first n bytes of s1 is found, respectively, to be less than, to match, or be greater than the
/// first n bytes of s2.
///
/// Not the above guarantee about memcmp's return value is guaranteed by linux and not the standard, as seen in CVE-2012-2122 "optimized memcmp"
/// glibc memcmp when SSE/AVX is on will return whatever.
/// So we return 1/0/-1.
///
/// For a nonzero return value, the sign is determined by the sign of the difference between the first pair of bytes (interpreted as unsigned char) that differ in s1 and s2.
///
/// If n is zero, the return value is zero.
extern (C) int memcmp(const byte* s1, const byte* s2, size_t n) {
    foreach (i; 0 .. n) {
        if (s1[i] < s2[i])
            return -1;
        if (s1[i] > s2[i])
            return 1;
    }
    return 0;
}

/// strlen - calculate the length of a string
/// 
/// The strlen() function calculates the length of the string pointed to by s, excluding the terminating null byte ('\0').
///
/// The strlen() function returns the number of bytes in the string pointed to by s.
extern(C) size_t strlen(const char* s) {
    size_t i = 0;
    for (;s[i] != 0;i++) {}
    return i;
}


/// memcpy - copy memory area
///
/// The  memcpy() function copies n bytes from memory area src to memory area dest.
/// The memory areas must not overlap. Use memmove(3) if the memory
/// areas do overlap.
///
/// The memcpy() function returns a pointer to dest.
extern(C) byte* memcpy(byte* dst, const byte* src, size_t n) {
    size_t i = 0;
    while (i + 8 <= n) { *(cast(ulong*)(&dst[i])) = *(cast(ulong*)(&src[i])); i += 8; }
    while (i + 4 <= n) { *(cast(uint*)(&dst[i])) = *(cast(uint*)(&src[i])); i += 4; }
    while (i + 2 <= n) { *(cast(ushort*)(&dst[i])) = *(cast(ushort*)(&src[i])); i += 2; }
    while (i + 1 <= n) { *(cast(byte*)(&dst[i])) = *(cast(byte*)(&src[i])); i += 1; }
    return dst;
}


/// memset - fill memory with a constant byte
///
/// The memset() function fills the first len bytes of the memory 
/// area pointed to by mem with the constant byte data.
///
/// The memset() function returns a pointer to the memory area mem.
extern(C) byte* memset(byte* mem, byte data, size_t len) {
    for (size_t i = 0;i < len;i++) mem[i] = data;
    return mem;
}

module libsys.util;


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
extern (C) size_t strlen(const char* s) {
    size_t i = 0;
    for (; s[i] != 0; i++) {
    }
    return i;
}

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
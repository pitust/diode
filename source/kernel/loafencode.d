module kernel.loafencode;

import kernel.io ;
import kernel.mm;
import std.traits;

private template isEnum(alias symb) {
    static if (is(symb == enum))
        enum bool isEnum = true;
    else
        enum bool isEnum = false;
}

/// Loaf encoder
void encode(T)(ref T v, ref byte[] data) {

    static if (isIntegral!(T)) {
        static if (isSigned!(T)) {
            if (v < 0) {
                push(data, 1);
                v = -v;
            } else {
                push(data, 0);
            }
        }
        while (v > 0) {
            byte nibble = cast(byte)(v & 0xff);
            // encoding: 0x01 <nibble>
            if (nibble == 0 || nibble == 1) {
                push(data, 1);
            }
            push(data, nibble);
            v = v >> 8;
        }
        push(data, 0);
    } else static if(isEnum!(T)) {
        encode(cast(ulong)v, data);
    } else {
        static foreach (member; __traits(allMembers, T)) {
            {
                static if (__traits(compiles, encode(__traits(getMember, v, member), data))) {
                    encode(__traits(getMember, v, member), data);
                } else {
                    static assert(0, "Can't print " ~ T.stringof ~ "." ~ member);
                }
            }
        }
    }

}

void decode(T)(ref T v, ref byte[] data) {
    ulong pos;
    decode(v, pos, data);
}
/// Loaf decoder
void decode(T)(ref T v, ref ulong pos, ref byte[] data) {
    static if (isIntegral!(T)) {
        bool sign = false;
        static if (isSigned!(T)) {
            sign = data[pos++] == 1;
        }
        ulong val = 0;
        ulong bits = 0;
        while (data[pos] != 0) {
            byte nibble = data[pos++];
            if (nibble == 1) {
                nibble = data[pos++];
            } else if (nibble == 0) {
                break;
            }
            val >>= 8;
            val |= (cast(ulong)nibble) << 64 - 8;
            bits += 8;
        }
        val >>= 64 - bits;
        pos++;
        static if (isSigned!(T)) {
            if (sign) {
                v = -cast(T)val;
                return;
            }
        }
        v = cast(T)val;
        return;
    } else static if (isEnum!(T)) {
        static assert(0);
    } else {
        static foreach (member; __traits(allMembers, T)) {
            {
                decode(__traits(getMember, v, member), pos, data);
            }
        }
    }
}
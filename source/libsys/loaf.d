module libsys.loaf;

import std.traits;
import libsys.mem;

private template isEnum(alias symb) {
    static if (is(symb == enum))
        enum bool isEnum = true;
    else
        enum bool isEnum = false;
}

byte[] loaf_encode(T)(T v) {
    return loaf_encode(v);
}
/// Loaf encoder
byte[] loaf_encode(T)(ref T v) {
    static if (isIntegral!(T)) {
        byte[] data = arr!(byte)();
        static if (isSigned!(T)) {
            if (v < 0) {
                data = concat(data, 1);
                v = -v;
            } else {
                data = concat(data, 0);
            }
        }
        while (v > 0) {
            byte nibble = cast(byte)(v & 0xff);
            // encoding: 0x01 <nibble>
            if (nibble == 0 || nibble == 1) {
                data = concat(data, 1);
            }
            data = concat(data, nibble);
            v = v >> 8;
        }
        return concat(data, 0);
    } else static if(isEnum!(T)) {
        return encode(cast(ulong)v);
    } else {
        byte[] data = arr!byte();
        static foreach (member; __traits(allMembers, T)) {
            {
                static if (__traits(compiles, loaf_encode(__traits(getMember, v, member)))) {
                    data = concat(data, loaf_encode(__traits(getMember, v, member)));
                } else {
                    loaf_encode(__traits(getMember, v, member));
                    static assert(0, "Can't print " ~ T.stringof ~ "." ~ member);
                }
            }
        }
        return data;
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
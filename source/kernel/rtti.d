module kernel.rtti;

import kernel.mm;
import kernel.io;
import kernel.optional;

/// Member info
struct MemberInfo {
    /// Name    
    string name;
    /// Offset
    ulong offset;
    /// Type
    TypeInfo* info;
}

/// Type information
struct TypeInfo {
    /// The type ID
    ulong type_id;

    /// Printer
    void function(void* self, string subarray, int prenest = 0, bool is_field = false) print;

    /// Name
    string name;

    /// Members
    MemberInfo[] members;

    /// opFormatter
    void opFormatter(string subarray, int _prenest) {
        debug assert(subarray == "");
        putsk("[TypeInfo for ");
        putsk(name);
        putsk("]");
    }

    /// Hide derefs so that TypeInfo* works nicely
    static void __hide_deref() {
    }
}

/// TypeInfo for an unknown type aka void*
TypeInfo* unknown_typeinfo() {
    struct TypeinfoInternal {
        void typeidgen(bool _q1, bool _q2) {
            // cool!
        }

        static void printer(void* self, string subarray, int prenest = 0, bool is_field = false) {
            putdyn(subarray, self, prenest, is_field);
        }
    }

    __gshared TypeInfo tyi;
    tyi.type_id = cast(ulong) cast(void*)(&TypeinfoInternal.typeidgen);
    tyi.print = &TypeinfoInternal.printer;
    tyi.name = "void*";
    return &tyi;
}

/// Get TypeInfo for `T`
TypeInfo* typeinfo(T)() {
    static if (is(T == void*)) {
        return unknown_typeinfo();
    } else {
        struct TypeinfoInternal {
            void typeidgen(bool _q1, bool _q2) {
                // cool!
            }

            static void printer(void* self, string subarray, int prenest = 0, bool is_field = false) {
                static if (__traits(compiles, putdyn(subarray, *cast(T*) self, prenest, is_field))) {
                    putdyn(subarray, *cast(T*) self, prenest, is_field);
                } else {
                    putsk("<unprintable>");
                }
            }
        }

        __gshared TypeInfo tyi;
        tyi.type_id = cast(ulong) cast(void*)(&TypeinfoInternal.typeidgen);
        tyi.print = &TypeinfoInternal.printer;
        tyi.name = T.stringof;
        static if (__traits(compiles, __traits(allMembers, *(cast(T*)0)))) {
            enum members = __traits(allMembers, *(cast(T*)0));
            MemberInfo[members.length] mem;
            int i = 0;
            foreach (member; members) {
                mem[i].name = member;
                mem[i].offset = cast(ulong)&__traits(getMember, (cast(T*)0), member);
                mem[i++].info = typeinfo!(typeof(__traits(getMember, (cast(T*)0), member)))();
            }
            tyi.members = mem;
        } else {
            MemberInfo[0] mem;
            tyi.members = mem;
        }
        return &tyi;
    }
}

/// Get TypeInfo for `T`
TypeInfo* dynamic_typeinfo(void* of) {
    Option!(TypeInfo*) maybeti = mmGetHeapBlock(of).map!(TypeInfo*)((HeapBlock* hb) {
        return hb.typeinfo;
    });
    if (maybeti.is_none())
        return unknown_typeinfo();
    return maybeti.unwrap();
}

/// Dynamic Cast
Option!(T*) dynamic_cast(T)(TypeInfo* tyi, void* v) {
    if (tyi == typeinfo!(T)())
        return Option!(T*)(cast(T*) v);
    return Option!(T*)();
}

/// Dynamic Cast
Option!(T*) dynamic_cast(T)(void* v) {
    return dynamic_cast!(T)(dynamic_typeinfo(v), v);
}

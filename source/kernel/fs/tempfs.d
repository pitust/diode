module kernel.fs.tempfs;

import kernel.io;
import kernel.mm;
import kernel.vfs;
import kernel.util;
import kernel.refptr;

private Ref!VFSNode filenode() {
    assert(0);
}

private struct Child {
    string name;
    Ref!VFSNode node;
}
private struct a { Child[] d; }
private void* wrap_data(Child[] d) {
    return cast(void*)alloc!(a)();
}
private void rewrap_data(void* og, Child[] d) {
    (cast(a*)(og)).d = d;
}
private void free_datawrap(void* d) {
    free(cast(a*)d);
}
private Child[] unwrap_data(void* d) {
    return (cast(a*)d).d;
}

private void vfsdrop(VFSNode* self) {
    Child[] a = unwrap_data(self.data);
    free_datawrap(self.data);
    foreach (ref Child c; a) {
        c.node.data._drop(&c.node.data());
        free(c.name);
    }

    free(a);
}

private errno vfscreate(VFSNode* self, string name) {
    Child[] a = unwrap_data(self.data);

    immutable(char)[] name2 = alloca_unsafe!(immutable(char))(name.length);
    memcpy(cast(byte*)name2.ptr, cast(byte*)name.ptr, name.length * char.sizeof);
    Child c = Child(name2, filenode());
    push(a, c);
    rewrap_data(self.data, a);

    
    return errno.EOK;
}
private errno vfschild(VFSNode* self, string name, Ref!VFSNode* outp) {
    assert(0);
    Child[] a = unwrap_data(self.data);

    foreach (Child c; a) {
        if (c.name == name) {
            *outp = c.node;
        }
    }

    return errno.EOK;
}

/// Create a new tmpfs directory node
Ref!VFSNode create() {
    Ref!VFSNode the = Ref!(VFSNode).mk();
    Child[] a = alloca!(Child)(0);
    the.data.data = wrap_data(a);
    the.data._drop = &vfsdrop;
    the.data._create = &vfscreate;
    the.data._child = &vfschild;
    return the;
}
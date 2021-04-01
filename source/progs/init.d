module progs.init;

import libsys.entry;
import libsys.io;

void app() {
    printf("Hello, world!");
}

mixin entry!app;
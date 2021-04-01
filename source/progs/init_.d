module progs.init_;

import libsys.entry;
import libsys.io;

int app() {
    printf(DEBUG, "level=DEBUG");
    printf(INFO, "level=INFO");
    printf(WARN, "level=WARN");
    printf(ERROR, "level=ERROR");
    printf(FATAL, "level=FATAL");
    return 1;
}

mixin entry!app;
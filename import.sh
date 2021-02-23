cd build/env
find * -type d | xargs -L 1 echfs-utils -g -p0 ../../build/kernel.hdd mkdir
find * -type f | xargs -L 1 bash -c 'python <(echo "import os;import sys;print(f'"'"'echfs-utils -g -p0 ../../build/kernel.hdd import {sys.argv[1]} {sys.argv[1]}'"'"');os.system(f'"'"'echfs-utils -g -p0 ../../build/kernel.hdd import {sys.argv[1]} {sys.argv[1]}'"'"')") $1 || true' --

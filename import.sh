cd build/env
find * -type d | xargs -L 1 echfs-utils -g -p0 ../../build/kernel.hdd mkdir
find * -type f | xargs -L 1 bash -c 'python3 ../../import.py $1 || true' --

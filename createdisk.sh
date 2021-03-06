#!/bin/sh
set -e
set -v
IMPORT_PY=`echo \`pwd\`/$0 | sed 's/createdisk\.sh//g'`import.py
KERN=`echo $1`
WORK_DIR=`pwd`
HDD=`echo $1 | sed 's/\.elf/.hdd/g'`
MAGIC_CPIO=$2
if [ ! -e $HDD ]; then truncate $HDD -s 64M; duogpt $HDD; fi
cd $WORK_DIR
mkdir -vp env
cd env
mkdir -vp boot
cd boot
cp ../../kernel.elf .
cp ../../initrd.bin .
cp $HOME/limine/limine.sys .
cd ..
cat >limine.cfg <<EOF
TIMEOUT=0

:DIOS
KERNEL_PATH=boot:///boot/kernel.elf
PROTOCOL=stivale2
MODULE_PATH=boot:///boot/initrd.bin
MODULE_STRING=initrd.bin
CMDLINE=info!
EOF


echfs-utils -g -p0 ../kernel.hdd format 512

find * -type d | xargs -L 1 echfs-utils -g -p0 ../kernel.hdd mkdir
find * -type f | xargs -L 1 bash -c 'python3 '$IMPORT_PY' $1 || true' --

limine-install ../kernel.hdd

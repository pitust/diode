#!/bin/sh
set -e
set -v

TARGET_PATH=`pwd`/initrd.bin

cd `echo \`pwd\`/$0 | sed 's/createinitrd\.sh//g'`data
find . | cpio -o >$TARGET_PATH
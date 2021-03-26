import os
import sys
print(f'echfs-utils -g -p0 ../kernel.hdd import {sys.argv[1]} {sys.argv[1]}')
os.system(f'echfs-utils -g -p0 ../kernel.hdd import {sys.argv[1]} {sys.argv[1]}')
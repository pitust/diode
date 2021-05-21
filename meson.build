project('code', ['d', 'c'],
    default_options : [
        'c_std=c99'
    ]
)

libled_src = run_command('find', ['source/libled', '-type', 'f']).stdout().strip().split('\n')
libsys_src = run_command('find', ['source/libsys', '-type', 'f']).stdout().strip().split('\n')
kernelsrc = run_command('find', ['source/kernel', '-type', 'f']).stdout().strip().split('\n')
initrd_members = files(run_command('find', ['data', '-type', 'f']).stdout().strip().split('\n'))

yasm = generator(find_program('yasm'),
    output : '@BASENAME@.o',
    arguments : [ '-felf64', '@INPUT@', '-o', '@OUTPUT@', '-i', meson.current_build_dir() + '/', '-gdwarf2' ]
)

link = generator(find_program('ld.lld'),
    output : '@BASENAME@.elf',
    arguments : [ '@INPUT@', '-o', '@OUTPUT@', '-m', 'elf_x86_64' ]
)

crt = yasm.process([
    'source/crt.s'
])

kernel_stlib = build_target('kernel', 'source/vshared/share.d', kernelsrc, [
    'source/task.c',
], yasm.process([
    'source/boot.s'
]),
    include_directories: ['source'],
    link_args: ['-betterC', '--gcc=fake-gcc'],
    d_module_versions: ['DiodeNoDebug'],
    d_args: ['-betterC'],
    target_type: 'static_library'
)

kernel = custom_target('kernel.elf', 
    build_by_default: true,
    command: [find_program('ld.lld'), kernel_stlib, '-o', 'kernel.elf', '-m', 'elf_x86_64', '-T../source/kernel.ld'],
    output: 'kernel.elf'
)

src = include_directories('source')

userinit_stlib = build_target('init', 'source/vshared/share.d', libsys_src, libled_src, crt, 'source/progs/init.d',
    include_directories: ['source'],
    d_args: ['-betterC'],
    link_args: ['-betterC', '--gcc=fake-gcc'],
    target_type: 'static_library'
)

userinit = custom_target('init.elf', 
    build_by_default: true,
    command: [find_program('ld.lld'), userinit_stlib, '-o', 'init.elf', '-m', 'elf_x86_64', '-T../source/user.ld'],
    output: 'init.elf'
)

initrd_user_bins = custom_target('userbins', 
    build_by_default: true,
    command: ['sh', files('copyfiles.sh'), userinit],
    output: 'env_out'
)

initrd = custom_target('initrd', 
    build_by_default: true,
    command: ['/bin/sh', files('createinitrd.sh'), initrd_user_bins, files('data/banner.txt'), kernel],
    output: 'initrd.bin'
)

iso = custom_target('iso', 
    build_by_default: true,
    command: ['/bin/sh', files('createdisk.sh'), kernel],
    output: 'kernel.hdd',
    depends: [initrd]
)

qemu = find_program('qemu-system-x86_64')

run_target('run',
    command: [
        qemu,
        '-drive', 'id=asd,file=kernel.hdd,if=none',
        '-device', 'virtio-blk-pci,drive=asd',
        '-s',
        '-debugcon', 'stdio',
        '-global', 'isa-debugcon.iobase=0xe9',
        '-cpu', 'max',
        '-machine', 'q35'
    ],
    depends: [iso]
)
run_target('runp',
    command: [
        qemu,
        '-drive', 'id=asd,file=kernel.hdd,if=none',
        '-device', 'virtio-blk-pci,drive=asd',
        '-s',
        '-debugcon', 'stdio',
        '-global', 'isa-debugcon.iobase=0xe9',
        '-cpu', 'max',
        '-machine', 'q35',
        '-S'
    ],
    depends: [iso]
)

run_target('nsnr',
    command: [
        qemu,
        '-device', 'virtio-blk-pci,drive=kernel.hdd',
        '-s',
        '-debugcon', 'stdio',
        '-global', 'isa-debugcon.iobase=0xe9',
        '-cpu', 'max',
        '-no-shutdown', '-no-reboot',
        '-machine', 'q35'
    ],
    depends: [iso]
)


run_target('rstop',
    command: [
        qemu,
        '-S',
        '-hda', iso,
        '-s',
        '-debugcon', 'stdio',
        '-global', 'isa-debugcon.iobase=0xe9',
        '-cpu', 'max'
    ]
)
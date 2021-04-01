project('code', ['d', 'c'],
    default_options : [
        'c_std=c99'
    ]
)

libsys = run_command('find', ['source/libsys', '-type', 'f']).stdout().strip().split('\n')
kernelsrc = run_command('find', ['source/kernel', '-type', 'f']).stdout().strip().split('\n')
initrd_members = files(run_command('find', ['data', '-type', 'f']).stdout().strip().split('\n'))

yasm = generator(find_program('yasm'),
    output : '@BASENAME@.o',
    arguments : [ '-felf64', '@INPUT@', '-o', '@OUTPUT@', '-i', meson.current_build_dir() + '/', '-gdwarf2' ]
)

crt = yasm.process([
    'source/crt.s'
])

kernel = executable('kernel.elf', 'source/vshared/share.d', kernelsrc, [
    'source/task.c',
], yasm.process([
    'source/boot.s'
]),
    include_directories: ['source'],
    link_args: ['-L=-T../source/kernel.ld'],
    d_module_versions: ['DiodeNoDebug']
)

userinit = executable('init.elf', 'source/vshared/share.d', libsys, crt, 'source/progs/init.d',
    include_directories: ['source'],
    link_args: ['-L=-T../source/user.ld']
)

initrd_user_bins = custom_target('userbins', 
    build_by_default: true,
    command: ['sh', files('copyfiles.sh'), userinit],
    output: 'env_out'
)

initrd = custom_target('initrd', 
    build_by_default: true,
    command: ['/bin/sh', files('createinitrd.sh'), initrd_user_bins],
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
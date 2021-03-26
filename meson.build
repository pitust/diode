project('code', ['d', 'c'],
    default_options : [
        'c_std=c99'
    ]
)

c1 = run_command('find', ['source/kernel', '-type', 'f'])
initrd_members = files(run_command('find', ['data', '-type', 'f']).stdout().strip().split('\n'))
sources = c1.stdout().strip().split('\n')

yasm = generator(find_program('yasm'),
    output : '@BASENAME@.o',
    arguments : [ '-felf64', '@INPUT@', '-o', '@OUTPUT@', '-i', meson.current_build_dir() + '/', '-gdwarf2' ]
)

kernel = executable('kernel.elf', sources, [
    'source/task.c',
], yasm.process([
    'source/boot.s'
]),
    include_directories: ['source']
)

initrd = custom_target('initrd', 
    build_by_default: true,
    command: ['/bin/sh', files('createinitrd.sh'), initrd_members],
    output: 'initrd.bin'
)

iso = custom_target('iso', 
    build_by_default: true,
    command: ['/bin/sh', files('createdisk.sh'), kernel],
    output: 'kernel.hdd',
    depends: [initrd]
)

run_target('run',
    command: [
        find_program('qemu-system-x86_64'),
        '-hda', iso,
        '-s',
        '-debugcon', 'stdio',
        '-global', 'isa-debugcon.iobase=0xe9',
        '-cpu', 'max'
    ]
)
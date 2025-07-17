# rv32ima.sh
A risc-v emulator running in pure shell script

### what
Bash and posix shells are fully turing complete! Typically the shell is used to call external commands, but even if you limit yourself to just builtins, (`echo`, `printf`, `read`, `return`) it's still possible to emulate a full RISC-V cpu running at a decent clock speed!

### why
I love bash! see [minecraft.sh](https://github.com/velzie/minecraft.sh) or [asm.sh](https://github.com/velzie/asm.sh) or [kiki](https://github.com/velzie/kiki) or [my bash SSG](https://github.com/velzie/bashtro). it's funny and an interesting challenge

### can it run linux?

kind of? not really

I got buildroot to load and it hits the first banner after ~30 minutes, but doesn't progress much further

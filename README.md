# rv32ima.sh
A risc-v emulator running in pure shell script

### what
Bash and posix shells are fully turing complete! Typically the shell is used to call external commands, but even if you limit yourself to just builtins, (`echo`, `printf`, `read`, `return`) it's still possible to emulate a full RISC-V cpu running at a decent clock speed!

### why
I love bash! see [minecraft.sh](https://github.com/velzie/minecraft.sh) or [asm.sh](https://github.com/velzie/asm.sh) or [kiki](https://github.com/velzie/kiki) or [my bash SSG](https://github.com/velzie/bashtro). it's funny and an interesting challenge

### can it run linux?

kind of? not really

I got buildroot to load and it hits the first banner after ~30 minutes, but doesn't progress much further

Here's an example of it printing the fibonacci sequence from a C program compiled to risc-v
<img width="1284" height="306" alt="image" src="https://github.com/user-attachments/assets/9d78c4a0-1ac6-4563-b045-9f46281c18a7" />

### try yourself
- clone repo
- run `make` to compile buildroot and the baremetal programs
- `bash src/runbin.sh baremetal/baremetal.bin sixtyfourmb.dtb` to run the c program, `bash src/runbin.sh buildroot/output/images/Image sixtyfourmb.dtb` to run buildroot

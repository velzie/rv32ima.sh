#shellcheck shell=ksh
export LC_ALL=C

MEMSIZE=8000

. src/util-pure.sh
. src/fmt.sh
. src/elf.sh
. src/risc.sh


dumpmem() {
    local i
    for ((i=0; i<MEMSIZE; i++)); do
        printf "%02x" $(memreadbyte $i)
    done
}

dodump() {
    dumpmem | fromhex > dump
}

parseelf < $1

loadblob $1
dtb_size=$(stat -c%s $2)
dtb_ptr=$((MEMSIZE - dtb_size - 192)) # 192 is completely arbitrary i just wanted it to match with minirv32ima
i=0
while read int; do
    MEMORY[i+(dtb_ptr/4)]=$((int))
    i=$((i + 1))
done < <(od -t d4 -An -v -w4 $2)

init 0 $dtb_ptr

while true; do
    step
done


# a=$(readn 4 < test.bin | tohex)
#     echo "$a"
# echo $(((((0x$a)) & 0xff)))

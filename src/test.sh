#shellcheck shell=ksh
export LC_ALL=C

MEMSIZE=2000000

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

# parseelf < $1

init 0 2155481920
loadblob $1

while true; do
    step
done


# a=$(readn 4 < test.bin | tohex)
#     echo "$a"
# echo $(((((0x$a)) & 0xff)))

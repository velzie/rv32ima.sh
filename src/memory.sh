declare -a MEMORY
MEMORY=()


function memloadfile {

echo "starting blob load"
i=0
    while read int; do
        MEMORY[i]=$((int))
        i=$((i + 1))
    done < <(od -t d4 -An -v -w4 $1)
#    content=$(readint)
#    echo "loaded hex"

#    for ((i=0; i<${#content}; i+=2)); do
#     # echo "$i ${content:i:2}"
#      memwritebyte $((i/2)) $(( "0x${content:i:2}" ))
#    done
   echo "blob loaded"
}
function memreadbyte {
    local offs=$1
    local align=$((offs%4))
    offs=$((offs/4))

    rval=$(((MEMORY[offs] >> (align*8)) & 0xFF))
}

function memwritebyte {
    local offs=$1
    # if ((offs < 2401136)); then
    #     echo "HIT"
    # fi
    local align=$((offs%4))
    offs=$((offs/4))
    local mask=$(( ~(0xFF << (align*8)) ))
    local new=$2

    MEMORY[offs]=$(((MEMORY[offs] & mask) | (new << (align*8)) ))
}

function memreadword {
    local offs=$1


    if ((offs%4 == 0)); then
        # aligned read
        rval=$((MEMORY[offs/4] & 0xFFFFFFFF))
    else
        b1=$(memreadbyte $offs)
        b2=$(memreadbyte $((1+$offs)))
        b3=$(memreadbyte $((2+$offs)))
        b4=$(memreadbyte $((3+$offs)))

        rval=$(((b4<<24 | b3<<16 | b2<<8 | b1) & 0xFFFFFFFF))
    fi
}

function memreadhalfword {
    local offs=$1

    b1=$(memreadbyte $offs)
    b2=$(memreadbyte $((1+offs)))

    rval=$((b2<<8 | b1))
}

function memwritehalfword {
    local offs=$1
    local new=$2
    # if ((offs < 2401136)); then
    #     # echo "hit this THAT"
    #     exit 1
    # fi
    memwritebyte "$offs" "$((new))"
    memwritebyte "$((1+offs))" "$((new >> 8))"
}

function memwriteword {
    local offs=$1
    # if ((offs < 2401136)); then
    #     :
    #     # echo "IGNORING write to $offs at cycle $CYCLEL" >&2
    #     # return
    #     # exit 1
    # fi

    local new=$2

    memwritebyte "$offs" "$((new))"
    memwritebyte $((1+offs)) $((new >> 8))
    memwritebyte $((2+offs)) $((new >> 16))
    memwritebyte $((3+offs)) $((new >> 24))
}

memzero() {
    # zero mem and regs
    for ((i=0; i<32; i++)); do
        REGS[i]=0
    done
    for ((i=0; i<$((MEMSIZE/4)); i++)); do
        MEMORY[i]=0
    done

    # echo "initialized $MEMSIZE bytes to 0"
}

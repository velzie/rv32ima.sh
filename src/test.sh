#shellcheck shell=ksh
export LC_ALL=C

. src/util-pure.sh


parsei() {
    local b1 b2 b3 b4 hex

    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    b3=$(readn 1 | tohex)
    b4=$(readn 1 | tohex)
    hex="$b4$b3$b2$b1"
    int=$((0x$hex))
    op=$((int & 0xff))
    echo $op
    case $op in
        19)
        rd=
        ;;
    esac
}

parsei < test.bin
# a=$(readn 4 < test.bin | tohex)
#     echo "$a"
# echo $(((((0x$a)) & 0xff)))

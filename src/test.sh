#shellcheck shell=ksh
export LC_ALL=C

. src/util-pure.sh


# rv32 instruction format
# | 31–25 | 24–20 | 19–15 | 14–12 | 11–7  | 6–0   |
# | funct7| rs2   | rs1   | funct3| rd    | opcode|
parsei() {
    local b1 b2 b3 b4 hex

    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    b3=$(readn 1 | tohex)
    b4=$(readn 1 | tohex)
    hex="$b4$b3$b2$b1"
    int=$((0x$hex))

    op=$((    int & 2#00000000000000000000000001111111))
    rd=$((    int & 2#00000000000000000000111110000000))
    funct3=$((int & 2#00000000000000000111000000000000))
    rs1=$((   int & 2#00000000000011111000000000000000))
    rs2=$((   int & 2#00000001111100000000000000000000))
    funct7=$((int & 2#11111110000000000000000000000000))
    echo "$op $rd $funct3 $rs1 $rs2 $funct7"


    case $op in
        51)
        rd=
        ;;
    esac
}

parsei < test.bin
# a=$(readn 4 < test.bin | tohex)
#     echo "$a"
# echo $(((((0x$a)) & 0xff)))

#shellcheck shell=ksh
export LC_ALL=C

. src/util-pure.sh

fmtreg() {
    case $1 in
        0) echo "zero";;
        1) echo "ra";;
        2) echo "sp";;
        3) echo "gp";;
        4) echo "tp";;
        8) echo "s0/fp";;
        *) echo "unknown register $1";;
    esac
}
fmtifunct() {
    case $1 in
        0) echo "addi";;
        4) echo "xori";;
        6) echo "ori";;
        7) echo "andi";;
        1) echo "slli";;
        5) echo "srli/srai";;
        2) echo "slti";;
        3) echo "sltiu";;
    esac
}

# Register ABI Name Description Saver
# x0 zero Zero constant —
# x1 ra Return address Callee
# x2 sp Stack pointer Callee
# x3 gp Global pointer —
# x4 tp Thread pointer —
# x5-x7 t0-t2 Temporaries Caller
# x8 s0 / fp Saved / frame pointer Callee
# x9 s1 Saved register Callee
# x10-x11 a0-a1 Fn args/return values Caller
# x12-x17 a2-a7 Fn args Caller
# x18-x27 s2-s11 Saved registers Callee
# x28-x31 t3-t6 Temporaries Caller
# f0-7 ft0-7 FP temporaries Caller
# f8-9 fs0-1 FP saved registers Callee
# f10-11 fa0-1 FP args/return values Caller
# f12-17 fa2-7 FP args Caller
# f18-27 fs2-11 FP saved registers Callee
# f28-31 ft8-11 FP temporaries Caller

# rv32 instruction format
parsei() {
    local b1 b2 b3 b4 hex

    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    b3=$(readn 1 | tohex)
    b4=$(readn 1 | tohex)
    hex="$b4$b3$b2$b1"
    if [ ${#hex} != 8 ]; then return 1; fi;

    int=$((0x$hex))

    op=$((    int & 2#00000000000000000000000001111111))


    case $op in
        51)
        # R-type (register)
        # | 31–25 | 24–20 | 19–15 | 14–12 | 11–7  | 6–0   |
        # | funct7| rs2   | rs1   | funct3| rd    | opcode|
        rd=$((    int & 2#00000000000000000000111110000000))
        funct3=$((int & 2#00000000000000000111000000000000))
        rs1=$((   int & 2#00000000000011111000000000000000))
        rs2=$((   int & 2#00000001111100000000000000000000))
        funct7=$((int & 2#11111110000000000000000000000000))

        echo "TYPE R $op $rd $funct3 $rs1 $rs2 $funct7"
        ;;
        19)
        # I-type (immediate)
        # | 31–20       | 19–15 | 14–12 | 11–7  | 6–0   |
        # | imm   | rs1   | funct3| rd    | opcode|
        rd=$(((int >> 7) & ((1 << 6)-1)))
        funct3=$(((int >> 12) & ((1 << 4)-1)))
        rs1=$(((int >> 15) & ((1 << 6)-1)))
        imm=$(((int >> 20) & ((1 << 12)-1)))
        if [ $((imm >> 11)) = 1 ]; then
            imm=$((imm ^ 2#111111111111))
            imm=$((-(imm + 1)))
        fi
        # echo "TYPE I $op $rd $funct3 $rs1 $imm"
        echo "$(fmtifunct $funct3) $(fmtreg $rd),$(fmtreg $rs1),$imm"
        ;;

        *) echo "unknown opcode $op"
    esac
}

while parsei; do
    :
done < test.bin
# a=$(readn 4 < test.bin | tohex)
#     echo "$a"
# echo $(((((0x$a)) & 0xff)))

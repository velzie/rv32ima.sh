



sextendimm() {
    if [ $((imm >> 11)) = 1 ]; then
        imm=$((imm ^ 2#111111111111))
        imm=$((-(imm + 1)))
    fi
}
xt() {
    local size
    size=$(($2 - $1))
    if [[ -n $2 ]]; then
        echo "$(((int >> $1) & ((1 << (size+1))-1)))"
    else
        echo "$(((int >> $1) & 1))"
    fi
}
disasm() {
    op=$(xt 0 6)


    case $op in
        51)
        # R-type (register)
        # | 31–25 | 24–20 | 19–15 | 14–12 | 11–7  | 6–0   |
        # | funct7| rs2   | rs1   | funct3| rd    | opcode|
        rd=$(xt 7 11)
        funct3=$(xt 12 14)
        rs1=$(xt 15 19)
        rs2=$(xt 20 24)
        funct7=$(xt 25 31)

        case $funct3 in
            0)
            case $funct7 in
                0)
                inst="add"
                ;;
                32)
                inst="sub"
                ;;
            esac
            ;;
            4)
            inst="xor"
            ;;
            6)
            inst="or"
            ;;
            7)
            inst="and"
            ;;
            1)
            inst="sll"
            ;;
            5)
            case $funct7 in
                0x00)
                inst="srl"
                ;;
                0x20)
                inst="sra"
                ;;
            esac
            ;;
            2)
            inst="slt"
            ;;
            3)
            inst="sltu"
            ;;
            *) echo "UNKNOWN WHAT"
        esac
        echo "$inst $(fmtreg $rd),$(fmtreg $rs1),$(fmtreg $rs2)"
        ;;
        19|3|103|115)
        # I-type (immediate)
        # | 31–20       | 19–15 | 14–12 | 11–7  | 6–0   |
        # | imm[11:0]   | rs1   | funct3| rd    | opcode|

        rd=$(xt 7 11)
        funct3=$(xt 12 14)
        rs1=$(xt 15 19)
        imm=$(xt 20 31)
        sextendimm

        case $op in
            19)
            case $funct3 in
                0) inst="addi";;
                4) inst="xori";;
                6) inst="ori";;
                7) inst="andi";;
                1) inst="slli";;
                5)
                case $funct7 in
                    0) inst="srli";;
                    32) inst="srai";;
                esac
                ;;
                2) inst="slti";;
                3) inst="sltiu";;
            esac
            ;;
            3) # load instructions
            case $funct3 in
                0) inst="lb";;
                1) inst="lh";;
                2) inst="lw";;
                4) inst="lbu";;
                5) inst="lhu";;
            esac
            ;;
            103)
            case $funct3 in
                0) inst="jalr";;
            esac
            ;;
            115)
            case $imm in
                0) inst="ecall";;
                1) inst="ebreak";;
            esac
            ;;
        esac
        # echo "TYPE I $op $rd $funct3 $rs1 $imm"
        echo "$inst $(fmtreg $rd),$(fmtreg $rs1),$imm"
        ;;
        35)
        # S-type (Store)
        # | 31–25    | 24–20 | 19–15 | 14–12 | 11–7    | 6–0   |
        # | imm[11:5]| rs2   | rs1   | funct3| imm[4:0]| opcode|
        imm1=$(xt 7 11)
        funct3=$(xt 12 14)
        rs1=$(xt 15 19)
        rs2=$(xt 20 24)
        imm2=$(xt 25 31)
        imm=$((imm1 + (imm2 << 5)))
        sextendimm
        case $funct3 in
            0)
            inst="sb"
            ;;
            1)
            inst="sh"
            ;;
            2)
            inst="sw"
            ;;
            *) echo "unknown S-type funct3 $funct3"
        esac
        echo "$inst $(fmtreg $rs2),$imm($(fmtreg $rs1))"
        ;;
        99)
        # B-type (Branch)
        # | 31 | 30–25 | 24–20 | 19–15 | 14–12 | 11 | 10–8 | 7 | 6–0   |
        # | imm[12] | imm[10:5] | rs2 | rs1 | funct3 | imm[4:1] | imm[11] | opcode |
        funct3=$(xt 12 14)
        rs1=$(xt 15 19)
        rs2=$(xt 20 24)
        imm=$((
            ($(xt 7) << 11) |
            ($(xt 31) << 12) |
            ($(xt 8 11) << 1) |
            ($(xt 25 30) << 5)
        ))
        sextendimm
        case $funct3 in
            0)
            inst="beq"
            ;;
            1)
            inst="bne"
            ;;
            4)
            inst="blt"
            ;;
            5)
            inst="bge"
            ;;
            6)
            inst="bltu"
            ;;
            7)
            inst="bgeu"
            ;;
            *) echo "unknown Btype funct3 $funct3"
        esac
        echo "$inst $(fmtreg $rs1),$(fmtreg $rs2),$imm"
        ;;
        111)
        # J-Type
        # | 31 | 30–21 | 20 | 19–12 | 11–7  | 6–0   |
        # | imm[20] | imm[10:1] | imm[11] | imm[19:12] | rd | opcode |
        rd=$(xt 7 11)
        imm=$((
            ($(xt 12 19) << 12) |
            ($(xt 20) << 11) |
            ($(xt 21 30) << 1) |
            ($(xt 31) << 20)
        ))
        sextendimm
        echo "jal $(fmtreg $rd),$imm"
        ;;
        55|23)
        # U-Type (Upper Immediate)
        # | 31–12         | 11–7  | 6–0   |
        # | imm[31:12]    | rd    | opcode|
        rd=$(xt 7 11)
        imm=$((
            $(xt 12 31) << 12
        ))
        sextendimm
        case $op in
            55)
            inst="lui"
            ;;
            23)
            inst="auipc"
            ;;
            *) echo "unknown Utype opcode $op"
        esac
        echo "$inst $(fmtreg $rd),$imm"
        ;;
        *) echo "unknown opcode $op"
    esac
}

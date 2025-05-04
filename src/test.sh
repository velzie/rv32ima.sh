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
        5) echo "t0";;
        6) echo "t1";;
        7) echo "t2";;
        8) echo "s0";;
        9) echo "s1";;
        10) echo "a0";;
        11) echo "a1";;
        12) echo "a2";;
        13) echo "a3";;
        14) echo "a4";;
        15) echo "a5";;
        16) echo "a6";;
        17) echo "a7";;
        18) echo "s2";;
        *) echo "unknown register $1";;
    esac
}
sextendimm() {
    if [ $((imm >> 11)) = 1 ]; then
        imm=$((imm ^ 2#111111111111))
        imm=$((-(imm + 1)))
    fi
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


xt() {
    local size
    size=$(($2 - $1))
    if [[ -n $2 ]]; then
        echo "$(((int >> $1) & ((1 << (size+1))-1)))"
    else
        echo "$(((int >> $1) & 1))"
    fi
}
parsei() {
    local b1 b2 b3 b4 hex

    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    b3=$(readn 1 | tohex)
    b4=$(readn 1 | tohex)
    hex="$b4$b3$b2$b1"
    if [ ${#hex} != 8 ]; then return 1; fi;

    int=$((0x$hex))

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
            ($(xt 12 31) << 12)
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

# while parsei; do
#     :
# done < $1

readchar() {
    echosafe $((0x$(readn 1 | tohex)))
}
readint() {
    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    b3=$(readn 1 | tohex)
    b4=$(readn 1 | tohex)
    echosafe $((0x$b4$b3$b2$b1))
}
readshort() {
    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    echosafe $((0x$b2$b1))
}
readstring() {
    while true; do
        char=$(readn 1 | tohex)
        if [ "$char" = "00" ]; then
            break
        fi
        echosafe "$char" | fromhex
    done
}
eslice() {
    local start=$2
    local size=$3
    if [ -n "$size" ]; then
        echosafe "${1:$((start*2)):$((size*2))}"
    else
        echosafe "${1:$((start*2))}"
    fi
}
sliceint() {
    eslice $1 $2 4 | fromhex | readint
}
sliceshort() {
    eslice $1 $2 2 | fromhex | readshort
}
parsesectheader() {
    sh_name=$(sliceint $1 0)
    sh_type=$(sliceint $1 4)
    sh_flags=$(sliceint $1 8)
    sh_addr=$(sliceint $1 12)
    sh_offset=$(sliceint $1 16)
    sh_size=$(sliceint $1 20)
}
parseelf() {
    if (( 0x$(readhex 4) != 0x7f454c46 )); then
        echo "Not an ELF file"
        return 1
    fi
    if (( $(readchar) != 0x01 )); then
        echo "Not 32 bit"
        return 1
    fi
    if (( $(readchar) != 0x01 )); then
        echo "Not little endian"
        return 1
    fi

    eatn 1 # ELF header version
    eatn 1 # OS ABI
    eatn 8 # ELF header padding
    type=$(readshort)
    echo "ELF type $type"
    if (( $(readshort) != 0xf3 )); then
        echo "Not RISC-V"
        return 1
    fi
    # readn 20 | tohex
    elfversion=$(readint)
    echo "ELF version $elfversion"
    e_entry=$(readint)
    e_phoff=$(readint)
    e_shoff=$(readint)
    echo "Entry point $e_entry"
    echo "Program header offset $e_phoff"
    echo "Section header offset $e_shoff"
    flags=$(readint)
    echo "Flags $flags"
    headersize=$(readshort)
    echo "Header Size $headersize"
    e_phentsize=$(readshort)
    echo "Program header entry size $e_phentsize"
    e_phnum=$(readshort)
    echo "Program header count $e_phnum"
    e_shentsize=$(readshort)
    echo "Section header entry size $e_shentsize"
    e_shnum=$(readshort)
    echo "Section header count $e_shnum"
    e_shstrndx=$(readshort)
    echo "Section header string table index $e_shstrndx"

    # eat the remainder of the data
    elfbody=$(tohex)
    # pad the header so the offsets match
    elfbody="$(repeat $headersize 00)$elfbody"
    # section header table
    sh_table=$(eslice $elfbody $e_shoff $((e_shnum * e_shentsize)))
    # take the `shstrndx`th section header
    sh_strtab=$(eslice $sh_table $(((e_shstrndx) * e_shentsize)) $e_shentsize)
    parsesectheader $sh_strtab
    # string table
    sh_strs=$(eslice $elfbody $sh_offset $sh_size)

    # loop through section headers until we find .text
    for ((i=0; i<e_shnum; i++)); do
        sh=$(eslice $sh_table $((i * e_shentsize)) $e_shentsize)
        parsesectheader $sh
        name=$(eslice $sh_strs $sh_name | fromhex | readstring)
        echo "section $i: $name"
        if [[ $name == ".text" ]]; then
            echo "Found .text section"

            while parsei; do
               :
            done < <(eslice $elfbody $sh_offset $sh_size | fromhex)
            break
        fi
    done

}
parseelf < $1

# a=$(readn 4 < test.bin | tohex)
#     echo "$a"
# echo $(((((0x$a)) & 0xff)))

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

declare -a MEMORY
declare -a REGS
REGS=()
MEMORY=()
PC=0
MEMSIZE=2000000
INTMAX=$((2**31))
RAM_IMAGE_OFFSET=0
reset() {
    # zero mem and regs
    for ((i=0; i<32; i++)); do
        REGS[i]=0
    done
    for ((i=0; i<$((MEMSIZE/4)); i++)); do
        MEMORY[i]="0"
    done
}

memreadbyte() {
    local offs=$1
    local align=$((offs%4))
    offs=$((offs/4))

    echo $(((MEMORY[offs] >> (align*8)) & 0xFF))
}
memwritebyte() {
    local offs=$1
    local align=$((offs%4))
    offs=$((offs/4))
    local mask=$(( ~(0xFF << (align*8)) ))
    local new=$2

    MEMORY[offs]=$(((MEMORY[offs] & mask) | (new << (align*8)) ))
}
memreadword() {
    b1=$(memreadbyte $1)
    b2=$(memreadbyte $((1+$1)))
    b3=$(memreadbyte $((2+$1)))
    b4=$(memreadbyte $((3+$1)))

    echo $((b4<<24 | b3<<16 | b2<<8 | b1))
}
memwritehalfword() {
    local offs=$1
    local new=$2

    memwritebyte $offs $((new >> 8))
    memwritebyte $((1+$offs)) $((new))
}
memwritehalfword() {
    local offs=$1
    local new=$2

    memwritebyte $offs $((new >> 8))
    memwritebyte $((1+$offs)) $((new))
}
memwriteword() {
    local offs=$1
    local new=$2

    memwritebyte $offs $((new >> 24))
    memwritebyte $((1+$offs)) $((new >> 16))
    memwritebyte $((2+$offs)) $((new >> 8))
    memwritebyte $((3+$offs)) $((new))
}
echo "filling"
reset
echo "filled"

memreadword 0

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

step() {

    if ((PC % 4 != 0)); then
        echo "PC not aligned"
    fi
    int=$(memreadword $PC)
    # printf "%08x" $int | sed 's/../& /g' | awk '{for(i=4;i>0;i--) printf $i}' | xxd -r -p > t
    # riscv32-unknown-linux-gnu-objdump -D -b binary -m riscv:rv32 t | grep -P '^\s*[0-9a-f]+:\s+[0-9a-f]+\s+' | sed -E 's/^\s*[0-9a-f]+:\s+[0-9a-f]+\s+//'   # echo -en "$int: "

    # printf "%08x" $int
    # disasm $int

    local rval=0
    local rdid=$(((int >> 7) & 0x1f))

    local sum=$((REGS[rs1] + imm))
    rval=$((((((sum + INTMAX) % (INTMAX * 2)) + (INTMAX * 2)) % (INTMAX * 2)) - (INTMAX)))

    opcode=$((int & 0x7f))
    # echo "$PC"
    case $opcode in
        $((0x37))) # LUI
            # U type
            # (rd = imm << 12)
            # since it's already 12 bytes up in the instruction we don't need to shift it again
            rval=$((int & 0xfffff000))
            ;;
        $((0x3f))) # AUIPC
            # U type
            # (rd = pc + imm << 12)
            rval=$((PC + (int & 0xfffff000)))
            ;;
        $((0x6f))) # JAL
            # J type
            # (rd = pc + 4; pc += imm)
            imm=$(( ((int & 0x80000000) >> 11) | ( (int & 0x7fe00000) >> 20) | ((int & 0x00100000) >> 9) | (int & 0x000ff000) ))
            # sext is -1,048,576 to +1,048,574
            if ((imm & 0x00100000)); then imm=$((imm | 0xffffffffffe00000)); fi
            rval=$((PC + 4))
            PC=$((PC + imm - 4))
            ;;
        $((0x67))) # JALR
            # I type
            # (rd = pc + 4; pc = rs1 + imm)
            sextendimm
            # rval=$((PC + 4))
            # PC=$((REGS[rs1] + imm))
            ;;
        $((0x63))) # BRANCH
            # B type
            imm=$(( ((int & 0xf00)>>7) | ((int & 0x7e000000)>>20) | ((int & 0x80) << 4) | ((int >> 31)<<12) ))
            # max value for a relative jump in B type is 4096 so it has to be sign extended to that
            if (( imm & 0x1000 )); then imm=$((imm | 0xffffffffffffe000)); fi
            rs1=$(((int >> 15) & 0x1f))
            rs2=$(((int >> 20) & 0x1f))
            rs1val=$((REGS[rs1]))
            rs2val=$((REGS[rs2]))

            jumpto=$((PC + imm - 4))
            rdid=0
            funct3=$(((int >> 12) & 0x7))
            case $funct3 in
                $((0x0))) if [ $rs1val -eq $rs2val ]; then PC=$jumpto; fi ;;
                $((0x1))) if [ $rs1val -ne $rs2val ]; then PC=$jumpto; fi ;;
                $((0x4))) if [ $rs1val -lt $rs2val ]; then PC=$jumpto; fi ;;
                $((0x5))) if [ $rs1val -ge $rs2val ]; then PC=$jumpto; fi ;;
                $((0x6))) if [ $rs1val -lt $rs2val ]; then PC=$jumpto; fi ;; # zero ext here
                $((0x7))) if [ $rs1val -ge $rs2val ]; then PC=$jumpto; fi ;; # zero ext here
                *) trap=3;;
            esac
            ;;
        $((0x03))) # LOAD
            rs1=$(((int >> 15) & 0x1f))
            rs1val=$((REGS[rs1]))
            imm=$((int >> 20))
            # sign extend between -2048 and +2047
            if (( imm & 0x800 )); then imm=$((imm | 0xfffffffffffff000)); fi
            rsval=$((rs1val + imm - RAM_IMAGE_OFFSET))
            if ((rsval > MEMSIZE - 4)); then
                echo "peek out of bounds. uart?"
            else
                funct3=$(((int >> 12) & 0x7))
                case $funct3 in
                    $((0x0)))
                        # load byte with sign extension
                        rval=$(memreadbyte $rsval)
                        ;;
                    $((0x1)))
                        # load halfword with sign extension
                        rval=$(memreadhalfword $rsval)
                        ;;
                    $((0x2)))
                        # load word
                        rval=$(memreadword $rsval)
                        ;;
                    $((0x4)))
                        # load byte
                        rval=$(memreadbyte $rsval)
                        ;;
                    $((0x5)))
                        # load halfword without sign extension
                        rval=$(memreadhalfword $rsval)
                        ;;
                    *) trap=3;;
                esac
            fi
            ;;
        $((0x23))) # STORE
            rs1=$(((int >> 15) & 0x1f))
            rs1val=$((REGS[rs1]))
            rs2=$(((int >> 20) & 0x1f))
            rs2val=$((REGS[rs2]))
            imm=$(( ( ( int >> 7 ) & 0x1f ) | ( ( int & 0xfe000000 ) >> 20 ) ))
            # sign extend between -2048 and +2047
            if (( imm & 0x800 )); then imm=$((imm | 0xfffffffffffff000)); fi
            rsval=$((rs1val + imm - RAM_IMAGE_OFFSET))
            if ((rsval > MEMSIZE - 4)); then
                echo "peek out of bounds. uart?"
            else
                funct3=$(((int >> 12) & 0x7))
                case $funct3 in
                    $((0x0))) # store byte
                        memwritebyte $rsval $rs2val
                    ;;
                    $((0x1))) # store halfword
                        memwritehalfword $rsval $rs2val
                    ;;
                    $((0x2))) # store word
                        memwriteword $rsval $rs2val
                    ;;
                    *) trap=3;;
                esac
            fi
            ;;
        $((0x13))|$((0x33))) # OP/OP-IMM
            imm=$((int >> 20))
            if (( imm & 0x800 )); then imm=$((imm | 0xfffffffffffff000)); fi
            rs1=$(((int >> 15) & 0x1f))
            rs1val=$((REGS[rs1]))

            # 0110011 for OP 0010011 for OP Immediate
            # the 0x20 is the 0100000 difference
            not_imm=$((int & 0x20))
            if ((not_imm)); then
                # both sets are the same just load from register if OP
                rs2=$(((int >> 20) & 0x1f))
                rs2val=$((REGS[rs2]))
            else
                # and immediate otherwise
                rs2val=$imm
            fi

            funct3=$(((int >> 12) & 0x7))
            if ((not_imm)) && ((int & 0x02000000)); then
                echo "rv32M extension"
            else
                case $funct3 in
                    0) # add/sub/addi
                        # there's no subi because the imm is signed
                        if ((not_imm)) && ((int & 0x40000000)); then # add and subtract differentiated by the funct7
                            rval=$((rs1val - rs2val))
                        else
                            rval=$((rs1val + rs2val))
                        fi
                    ;;
                    1) # sll/slli
                        rval=$((rs1val << (rs2val & 0x1f)))
                    ;;
                    2) # slt/slti
                        # this one compares the values and sets the result to 1 if true, 0 otherwise
                        # thats why it looks weird
                        if ((rs1val < rs2val)); then
                            rval=1
                        else
                            rval=0
                        fi
                    ;;
                    3)  # sltu/sltiu
                        # same thing except unsigned/zero extended
                        # todo
                        if ((rs1val < rs2val)); then
                            rval=1
                        else
                            rval=0
                        fi
                    ;;
                    4)  # xor/xori
                        rval=$((rs1val ^ rs2val))
                    ;;
                    5) # srl/sra/srli/srai
                        # also differentiated by func7 (or imm but it's in the same place)
                        if ((int & 0x40000000)); then
                            # todo zero extend this one
                            rval=$((rs1val >> (rs2val & 0x1f)))
                        else
                            rval=$((rs1val >> (rs2val & 0x1f)))
                        fi
                    ;;
                    6) # or/ori
                        rval=$((rs1val | rs2val))
                    ;;
                    7) # and/andi
                        rval=$((rs1val & rs2val))
                    ;;
                esac
            fi
            ;;
        $((0x0f)))
            # dumbass fence thing
            # this is a single core processor
            rdid=0
            ;;
        $((0x73))) #Zifencei/Zicsr/ecall/ebreak
            csrno=$((int >> 20))
            funct3=$(((int >> 12) & 0x7))
            if ((funct3 & 3)); then
                echo "ziscr"
            elif ((funct3 == 0)); then
                echo "ecall"
                echo "syscall id is ${REGS[17]}"
                echo "syscall arguments 1-6: ${REGS[10]} ${REGS[11]} ${REGS[12]} ${REGS[13]} ${REGS[14]} ${REGS[15]}"

                case ${REGS[17]} in
                    64)
                        echo "write called"
                        ;;
                    93)
                        echo "exit called! exit code ${REGS[10]}"
                        exit 0
                        ;;
                    *)
                        echo "unknown syscall $syscall_id"
                        ;;
                esac
            else
                trap=3
            fi

            ;;
        *) echo "unknown opcode $opcode"
    esac

    if ((trap)); then
        echo "trap $trap"
        exit 1
    fi

    if ((rdid)); then
        REGS[rdid]=$rval
    fi

    PC=$((PC + 4))
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
    sh_link=$(sliceint $1 24)
    sh_info=$(sliceint $1 28)
    sh_addralign=$(sliceint $1 32)
    sh_entsize=$(sliceint $1 36)
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

    PC=$e_entry

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
    # for ((i=0; i<e_shnum; i++)); do
    #     sh=$(eslice $sh_table $((i * e_shentsize)) $e_shentsize)
    #     parsesectheader $sh
    #     name=$(eslice $sh_strs $sh_name | fromhex | readstring)
    #     echo "section $i: $name"
    #     # if [[ $name == ".text" ]]; then
    #     #     echo "Found .text section"

    #     #     while parsei; do
    #     #        :
    #     #     done < <(eslice $elfbody $sh_offset $sh_size | fromhex)
    #     #     break
    #     # fi
    # done

    ph_table=$(eslice $elfbody $e_phoff $((e_phnum * e_phentsize)))
    for ((i=0; i<e_phnum; i++)); do
        ph=$(eslice $ph_table $((i * e_phentsize)) $e_phentsize)

        p_type=$(sliceint $ph 0)
        p_offset=$(sliceint $ph 4)
        p_vaddr=$(sliceint $ph 8)
        p_paddr=$(sliceint $ph 12)
        p_filesz=$(sliceint $ph 16)
        p_memsz=$(sliceint $ph 20)
        p_flags=$(sliceint $ph 24)
        p_align=$(sliceint $ph 28)


        case $p_type in
            1) # PT_LOAD
                # wherever i map must be a multiple of p_align
                echo "type $p_type offset $p_offset addr $p_vaddr/$p_paddr filesz $p_filesz memsz $p_memsz flags $p_flags align $p_align"

                MEMORY[0]=1
                for ((j=0; j<p_memsz; j++)); do
                    offs=$((p_vaddr+j))
                    if ((j > p_filesz)); then
                        memwritebyte $offs 0
                    else
                        memwritebyte $offs $((0x$(eslice $elfbody $((p_offset+j)) 1)))
                    fi
                done
                echo "loaded PT_LOAD into memory"
            ;;
            1879048195) # PT_RISCV_ATTRIBUTES
                # load this later
                :
            ;;
            *)
            echo "unknown p_type $p_type, ignoring"
            ;;
        esac
    done


}
dumpmem() {
    local i
    # for ((i=0; i<$MEMSIZE; i++)); do
    #     printf "%02x" "${MEMORY[$i]}"
    # done
}
parseelf < $1
while true; do
    step
done
dumpmem | fromhex > dump


# a=$(readn 4 < test.bin | tohex)
#     echo "$a"
# echo $(((((0x$a)) & 0xff)))

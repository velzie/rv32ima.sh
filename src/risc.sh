
declare -a MEMORY
declare -a REGS
REGS=()
MEMORY=()
PC=0
INTMAX=$((2**31))
RAM_IMAGE_OFFSET=2147483648
USERMODE=0


csr_read() {
    local csrno=$1


    # echo "csr read $csrno"
}

csr_write() {
    local csrno=$1
    local val=$2

    case $csrno in
        $((0x136)))
            printf "%d" $val
            ;;
        $((0x137)))
            printf "%08x" $val
            ;;
        $((0x138)))
            # echo "WRITING STRING at $val"
            offs=$((val - RAM_IMAGE_OFFSET))
            while true; do
                byte=$(memreadbyte $offs)
                # echo "btye $byte"
                if ((byte == 0)); then
                    break
                fi
                printf "%02x" $byte | fromhex
                offs=$((offs+1))
            done
            ;;
        $((0x139)))
            printf "PRINTED CHAR %c" $val
            ;;
    esac

    # echo "csr write $csrno $val"
}

reset() {
    # zero mem and regs
    for ((i=0; i<32; i++)); do
        REGS[i]=0
    done
    for ((i=0; i<$((MEMSIZE/4)); i++)); do
        MEMORY[i]="0"
    done

    echo "initialized $MEMSIZE bytes to 0"
}

init() {
    local pc=$1
    local dtb_ptr=$2

    REGS[11]=$dtb_ptr
    PC=$RAM_IMAGE_OFFSET
    CYCLEH=0
    CYCLEL=0
    MSTATUS=0
    TIMERH=0
    TIMERL=0
    TIMERMATCHH=0
    TIMERMATCHL=0
    MSCRATCH=0
    MTVEC=0
    MIE=0
    MIP=0
    MEPC=0
    MTVAL=0
    MCAUSE=0
    EXTRAFLAGS=0
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
    if (($1%4 == 0)); then
        # aligned read
        echo "${MEMORY[$1/4]}"
    else
        b1=$(memreadbyte $1)
        b2=$(memreadbyte $((1+$1)))
        b3=$(memreadbyte $((2+$1)))
        b4=$(memreadbyte $((3+$1)))

        echo $((b4<<24 | b3<<16 | b2<<8 | b1))
    fi
}

memreadhalfword() {
    b1=$(memreadbyte $1)
    b2=$(memreadbyte $((1+$1)))

    echo $((b1<<8 | b2))
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

    memwritebyte $offs $((new))
    memwritebyte $((1+offs)) $((new >> 8))
    memwritebyte $((2+offs)) $((new >> 16))
    memwritebyte $((3+offs)) $((new >> 24))
}

reset

# echo "-"
# memwriteword 999964 65836
# memwriteword 999960 8
# memreadword 999964
# echo "-"
# exit

# emulate 32-bit unsigned less than by splitting the number into two 16-bit components
# code stolen from riscvscript
rv32_unsigned_lt() {
    local x=$1
    local y=$2

    local x_lower=$((x & 0x0000ffff))
    local x_upper=$(( ( x >> 16 ) & 0x0000ffff))

    local y_lower=$((y & 0x0000ffff))
    local y_upper=$(( ( y >> 16 ) & 0x0000ffff))

    if (( x_upper == y_upper )); then
        return $((x_lower < y_lower))
    fi

    return $((x_upper < y_upper));
}
diasm() {
    printf "%08x" $int | sed 's/../& /g' | awk '{for(i=4;i>0;i--) printf $i}' | xxd -r -p > t
    riscv32-unknown-linux-gnu-objdump -D -b binary -M no-aliases -m riscv:rv32 t | grep -P '^\s*[0-9a-f]+:\s+[0-9a-f]+\s+' | sed -E 's/^\s*[0-9a-f]+:\s+[0-9a-f]+\s+//'   # echo -en "$int: "
}

step() {

    # echo "-start of frame-"
    if ((PC % 4 != 0)); then
        echo "PC not aligned"
    fi
    int=$(memreadword $((PC-RAM_IMAGE_OFFSET)))

    # printf "%08x" $int
    # diasm $int

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
        $((0x17))) # AUIPC
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
            # echo "SETTING RA to $rval"
            PC=$((PC + imm - 4))
            # echo "JAL'd $imm"
            ;;
        $((0x67))) # JALR
            # I type
            # (rd = pc + 4; pc = rs1 + imm)
            imm=$((int >> 20))
            # sign extend between -2048 and +2047
            if (( imm & 0x800 )); then imm=$((imm | 0xfffffffffffff000)); fi
            rs1=$(((int >> 15) & 0x1f))
            rs1val=$((REGS[rs1]))

            rval=$((PC + 4))
            newpc=$((rs1val + imm))

            # to my knowldege this aligns the PC? not sure why that's needed or what the -4 is for. look up later
            PC=$(((newpc & ~1) - 4))
            # echo "JALR'd $imm rs1 $rs1val newpc $newpc"
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
                # BEQ, BNE, BLT, BGE
                $((0x0))) if (( rs1val == rs2val )); then PC=$jumpto; fi ;;
                $((0x1))) if (( rs1val != rs2val )); then PC=$jumpto; fi ;;
                $((0x4))) if (( rs1val < rs2val )); then PC=$jumpto; fi ;;
                $((0x5))) if (( rs1val >= rs2val )); then PC=$jumpto; fi ;;

                #  BLTU, BGEU (zero extended / unsigned variants)
                $((0x6))) if rv32_unsigned_lt rs1val rs2val; then PC=$jumpto; fi ;; # zero ext here
                $((0x7))) if ! rv32_unsigned_lt rs1val rs2val; then PC=$jumpto; fi ;; # zero ext here
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
            # echo "LW rsval: $rsval read $(memreadword $rsval)"
            # memreadword $rsval
            if ((rsval > MEMSIZE - 4)); then
                echo "peek out of bounds. uart?"
            else
                funct3=$(((int >> 12) & 0x7))
                case $funct3 in
                    $((0x0)))
                        # load byte with sign extension
                        rval=$(memreadbyte $rsval)
                        if ((rval > 0x7f)); then rval=$((rval | 0xffffffffffffff00)); fi
                        ;;
                    $((0x1)))
                        # load halfword with sign extension
                        rval=$(memreadhalfword $rsval)
                        if ((rval > 0x7fff)); then rval=$((rval | 0xffffffffffff0000)); fi
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
                        # load halfword
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
            rdid=0
            # echo "SW rsval: $rsval write $rs2val"
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
                            # echo "ADDING $rs1val $rs2val"
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
                        if rv32_unsigned_lt rs1val rs2val; then
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
                rs1imm=$(((int >> 15) & 0x1f))
                rs1val=${REGS[rs1imm]}
                writeval=$rs1val
                case $csrno in
					$((0x340))) rval=MSCRATCH;;
					$((0x305))) rval=MTVEC;;
					$((0x304))) rval=MIE;;
					$((0xC00))) rval=CYCLE;;
					$((0x344))) rval=MIP;;
					$((0x341))) rval=MEPC;;
					$((0x300))) rval=MSTATUS;;
					$((0x342))) rval=MCAUSE;;
					$((0x343))) rval=MTVAL;;
					$((0xf11))) rval=0xff0ff0ff;;
					$((0x301))) rval=0x40401101;;
					*)
    					csr_read $csrno $val
					;;
				esac
				case $funct3 in
				    1) writeval=$rs1val;;
				    2) writeval=$((rval | rs1val));;
					3) writeval=$((rval & ~rs1val));;
					5) writeval=$rs1imm;;
					6) writeval=$((rval | rs1imm));;
					7) writeval=$((rval & ~rs1imm));;
					*) echo "unknown funct3 $funct3";;
				esac
				case $csrno in
                    $((0x340))) MSCRATCH=$writeval;;
                    $((0x305))) MTVEC=$writeval;;
                    $((0x304))) MIE=$writeval;;
                    $((0x344))) MIP=$writeval;;
                    $((0x341))) MEPC=$writeval;;
                    $((0x300))) MSTATUS=$writeval;;
                    $((0x342))) MCAUSE=$writeval;;
                    $((0x343))) MTVAL=$writeval;;
                    *)
                    csr_write $csrno $writeval
                    ;;
				esac
            elif ((funct3 == 0)); then
                echo "syscall (id:${REGS[17]}) args 1-6: ${REGS[10]} ${REGS[11]} ${REGS[12]} ${REGS[13]} ${REGS[14]} ${REGS[15]}"

                case ${REGS[17]} in
                    64)
                        echo "write called"
                        len=${REGS[12]}
                        # dodump
                        for ((i=0; i<len; i++)); do
                            printf "%02x" $(memreadbyte $((REGS[11] + i))) | fromhex
                        done
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
        *)
        echo "unknown opcode $opcode"
        trap=3
        ;;
    esac

    if ((trap)); then
        echo "Segmentation Fault"
        exit 1
    fi

    if ((rdid)); then
        REGS[rdid]=$rval
    fi

    # echo "a0 ${REGS[10]} a2 ${REGS[12]} a5 ${REGS[15]} s0 ${REGS[8]}"


    PC=$((PC + 4))
    # echo "-end of frame-"
}

loadblob() {
   content=$(tohex)

   for ((i=0; i<${#content}; i+=2)); do
    # echo "$i ${content:i:2}"
     memwritebyte $((i/2)) $(( "0x${content:i:2}" ))
   done
}

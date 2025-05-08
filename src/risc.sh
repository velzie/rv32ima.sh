
declare -a MEMORY
declare -a REGS
REGS=()
MEMORY=()
PC=0
INTMAX=$((2**31))
RAM_IMAGE_OFFSET=2147483648
USERMODE=0

function phex {
    local val=$1
    printf "%08x" $val
}

function csr_read {
    local csrno=$1


    # echo "csr read $csrno"
}

function csr_write {
    local csrno=$1
    local val=$2

    case $csrno in
        $((0x136)))
            if ((val & 0x80000000)); then val=$((val | 0xFFFFFFFF00000000)); fi
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
                ((offs++))
            done
            ;;
        $((0x139)))
            printf "PRINTED CHAR %c" $val
            ;;
    esac

    # echo "csr write $csrno $val"
}

handle_control_load() {
    # emulate UART
    case $1 in
        $((0x10000005)))
            # is there kb input
            echo "$((0x60 | 0))"
            ;;
        # $(()
        #  0xffffffff
        $((0x1100bffc)))
            echo "$TIMERH"
            ;;
        $((0x1100bff8)))
            echo "$TIMERL"
            ;;
    esac
}
function handle_control_store {
    local addr=$1
    local val=$2
    case $addr in
        $((0x10000000)))
            # printf "%c" $2
            printf "\\$(printf '%03o' $2)"
            ;;
        $((0x11100000)))
            echo "syscon (interpreting as poweroff)"
            exit 1
            ;;
    esac
}

reset() {
    # zero mem and regs
    for ((i=0; i<32; i++)); do
        REGS[i]=0
    done
    for ((i=0; i<$((MEMSIZE/4)); i++)); do
        MEMORY[i]=0
    done

    # echo "initialized $MEMSIZE bytes to 0"
}

function init {
    local pc=$1
    local dtb_ptr=$2
    dtb_ptr=$((dtb_ptr+RAM_IMAGE_OFFSET))

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

function memreadbyte {
    local offs=$1
    local align=$((offs%4))
    offs=$((offs/4))

    echo $(((MEMORY[offs] >> (align*8)) & 0xFF))
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
        echo "$((MEMORY[offs/4] & 0xFFFFFFFF))"
    else
        b1=$(memreadbyte $offs)
        b2=$(memreadbyte $((1+$offs)))
        b3=$(memreadbyte $((2+$offs)))
        b4=$(memreadbyte $((3+$offs)))

        echo "$(((b4<<24 | b3<<16 | b2<<8 | b1) & 0xFFFFFFFF))"
    fi
}

function memreadhalfword {
    local offs=$1

    b1=$(memreadbyte $offs)
    b2=$(memreadbyte $((1+offs)))

    echo "$((b2<<8 | b1))"
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

reset

# echo "-"
# memwriteword 999964 65836
# memwriteword 999960 8
# memreadword 999964
# echo "-"
# exit

# emulate 32-bit unsigned less than by splitting the number into two 16-bit components
# code stolen from riscvscript
function rv32_unsigned_lt {
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

function step {

    ((CYCLEL++))

    # echo "-start of frame-"
    if ((PC % 4 != 0)); then
        echo "PC not aligned"
    fi
    int=$(memreadword $((PC-RAM_IMAGE_OFFSET)))
    # i should NOT have to do this something is very wrong
    int=$((int & 0xFFFFFFFF))

    # dumpstate

    # printf "%08x" $int
    # diasm

    local rval=0
    local rdid=$(((int >> 7) & 0x1f))

    opcode=$((int & 0x7f))

    # echo "READ AS $(memreadword 1301196)"
    # if (($(memreadword 1301196) != 29433987)); then
    #     echo "FUCKED AT $CYCLEL"
    #     exit 1
    # fi



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
            rval=$(((PC + (int & 0xfffff000)) & 0xFFFFFFFF ))
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

            if ((funct3 < 0x6)); then
                # comparisons (other than bltu/bgeu) need to happen with signed registers
                if ((rs1val & 0x80000000)); then rs1val=$((rs1val | 0xFFFFFFFF00000000)); fi
                if ((rs2val & 0x80000000)); then rs2val=$((rs2val | 0xFFFFFFFF00000000)); fi
            fi

            case $funct3 in
                # BEQ, BNE, BLT, BGE
                $((0x0))) if (( rs1val == rs2val )); then PC=$jumpto; fi ;;
                $((0x1))) if (( rs1val != rs2val )); then PC=$jumpto; fi ;;
                $((0x4))) if (( rs1val < rs2val )); then PC=$jumpto; fi ;;
                $((0x5))) if (( rs1val >= rs2val )); then PC=$jumpto; fi ;;

                #  BLTU, BGEU (zero extended / unsigned variants)
                $((0x6))) if (( rs1val < rs2val )); then PC=$jumpto; fi ;;
                $((0x7))) if (( rs1val >= rs2val )); then PC=$jumpto; fi ;;
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
            rsval=$((rsval & 0xFFFFFFFF)) # convert to unsigned uint32
            # memreadword $rsval
            if ((rsval > MEMSIZE - 4)); then
                # undo the offset
                rsval=$((rsval+RAM_IMAGE_OFFSET))
                rsval=$((rsval & 0xFFFFFFFF)) # uint32 it again. logic here is FUCKED! this needs to be fixed
                if ((0x10000000 <= rsval && rsval < 0x12000000)); then
                    rval=$(handle_control_load $rsval)
                else
                    echo "memory access out of bounds"
                    trap=6
                fi
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
            rsval=$((rsval & 0xFFFFFFFF)) # convert to unsigned uint32
            rdid=0
            # echo "SW rsval: $(phex $rsval) write $rs2val"
            if ((rsval > MEMSIZE - 4)); then
                rsval=$((rsval+RAM_IMAGE_OFFSET))
                rsval=$((rsval & 0xFFFFFFFF)) # uint32 it again.

                if ((0x10000000 <= rsval && rsval < 0x12000000)); then
                    handle_control_store $rsval $rs2val
                else
                    echo "memory access out of bounds"
                    trap=6
                fi
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

            # all ints are stored as unsigned in memory and in registers
            # explicitly convert to signed for the purposes of bash math
            if ((rs1val & 0x80000000)); then rs1val=$((rs1val | 0xFFFFFFFF00000000)); fi

            # 0110011 for OP 0010011 for OP Immediate
            # the 0x20 is the 0100000 difference
            not_imm=$((int & 0x20))
            if ((not_imm)); then
                # both sets are the same just load from register if OP
                rs2=$(((int >> 20) & 0x1f))
                rs2val=$((REGS[rs2]))

                if ((rs2val & 0x80000000)); then rs2val=$((rs2val | 0xFFFFFFFF00000000)); fi
            else
                # and immediate otherwise
                rs2val=$imm
            fi

            funct3=$(((int >> 12) & 0x7))
            if ((not_imm)) && ((int & 0x02000000)); then
                case $funct3 in
                    0) rval=$((rs1val * rs2val));; # MUL
                    1) rval=$(((rs1val * rs2val) >> 32));; # MULH
                    2) # rs1 is signed but rs2 is unsigned (?)
                    rs2val=$((rs2val & 0xFFFFFFFF));
                    rval=$(((rs1val * rs2val) >> 32));; # MULHSU
                    3) # both are unsigned
                    rs1val=$((rs1val & 0xFFFFFFFF));
                    rs2val=$((rs2val & 0xFFFFFFFF));
                    rval=$(((rs1val * rs2val) >> 32));; # MULHU

                    4) if ((rs2val == 0)); then rval=-1; else rval=$((rs1val/rs2val)); fi;; # DIV
                    5)
                    rs1val=$((rs1val & 0xFFFFFFFF));
                    rs2val=$((rs2val & 0xFFFFFFFF));
                    if ((rs2val == 0)); then rval=0xffffffff; else rval=$((rs1val/rs2val)); fi;; # DIVU
                    6) if ((rs2val == 0)); then rval=$rs1val; else rval=$((rs1val%rs2val)); fi;; # REM
                    7)
                    rs1val=$((rs1val & 0xFFFFFFFF));
                    rs2val=$((rs2val & 0xFFFFFFFF));
                    if ((rs2val == 0)); then rval=$rs1val; else rval=$((rs1val%rs2val)); fi;; # REMU

                esac
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
                        rs1val=$((rs1val & 0xFFFFFFFF))
                        rs2val=$((rs2val & 0xFFFFFFFF))
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
                            rval=$((rs1val >> (rs2val & 0x1f)))
                        else
                            rs2val=$((rs2val & 0xFFFFFFFF));
                            rs1val=$((rs1val & 0xFFFFFFFF));
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

            # now that the math is done make it unsigned again
            rval=$((rval & 0xFFFFFFFF))
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
                # echo "ASKED FOR CSR $csrno $CYCLEL $rdid $CYCLEL" >&2
                case $csrno in
					$((0x340))) rval=$MSCRATCH;;
					$((0x305))) rval=$MTVEC;;
					$((0x304))) rval=$MIE;;
					$((0xC00))) rval=$CYCLEL;;
					$((0x344))) rval=$MIP;;
					$((0x341))) rval=$MEPC;;
					$((0x300))) rval=$MSTATUS;;
					$((0x342))) rval=$MCAUSE;;
					$((0x343))) rval=$MTVAL;;
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
                echo "fuck trapping here"
                trap=3
            fi
            ;;
        $((0x2F))) # RV32A
            # this is a single core processor so the atomic operations aren't very interesting
            # worth noting that this is another access point for memory though
            rs1val=$((REGS[(int >> 15) & 0x1f]))
            rs2val=$((REGS[(int >> 20) & 0x1f]))
            irmid=$(((int >> 27) & 0x1f))
            rs1val=$((rs1val-RAM_IMAGE_OFFSET))
            if ((rs1val > (MEMSIZE - 4))); then
                echo "trap 8 lol $rs1val"
                trap=8
                rval=$((rs1val + RAM_IMAGE_OFFSET))
            else
                rval=$(memreadword "$rs1val")
      #           switch( irmid )
				# {
				# 	case 2: //LR.W (0b00010)
				# 		dowrite = 0;
				# 		CSR( extraflags ) = (CSR( extraflags ) & 0x07) | (rs1<<3);
				# 		break;
				# 	case 3:  //SC.W (0b00011) (Make sure we have a slot, and, it's valid)
				# 		rval = ( CSR( extraflags ) >> 3 != ( rs1 & 0x1fffffff ) );  // Validate that our reservation slot is OK.
				# 		dowrite = !rval; // Only write if slot is valid.
				# 		break;
				# 	case 1: break; //AMOSWAP.W (0b00001)
				# 	case 0: rs2 += rval; break; //AMOADD.W (0b00000)
				# 	case 4: rs2 ^= rval; break; //AMOXOR.W (0b00100)
				# 	case 12: rs2 &= rval; break; //AMOAND.W (0b01100)
				# 	case 8: rs2 |= rval; break; //AMOOR.W (0b01000)
				# 	case 16: rs2 = ((int32_t)rs2<(int32_t)rval)?rs2:rval; break; //AMOMIN.W (0b10000)
				# 	case 20: rs2 = ((int32_t)rs2>(int32_t)rval)?rs2:rval; break; //AMOMAX.W (0b10100)
				# 	case 24: rs2 = (rs2<rval)?rs2:rval; break; //AMOMINU.W (0b11000)
				# 	case 28: rs2 = (rs2>rval)?rs2:rval; break; //AMOMAXU.W (0b11100)
				# 	default: trap = (2+1); dowrite = 0; break; //Not supported.
				# }
				# if( dowrite ) MINIRV32_STORE4( rs1, rs2 );
                dowrite=1
                case "$irmid" in
                    2) # LR.W
                    dowrite=0
                    EXTRAFLAGS=$(((EXTRAFLAGS & 0x07) | (rs1val << 3)))
                    ;;
                    3) # SC.W
                        rval=$(( (EXTRAFLAGS>>3) != (rs1val & 0x1fffffff) ))
                        dowrite=$((!rval))
                    ;;
                    1);; # AMOSWAP.W is ignored by the ref impl for some reason. not sure why?
                    0) rs2val=$((rs2val += rval));; # AMOADD.W
                    8) rs2val=$((rs2val | rval));; # AMOOR.W
                    *)
                        trap=3
                        echo "unimplemented atomic $irmid"
                        dowrite=0
                    ;;
                esac

                if ((dowrite)); then memwriteword "$rs1val" "$rs2val"; fi
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

    PC=$((PC + 4))
    # echo "-end of frame-"


}
dumpstate() {
    pc_offset=$((PC - RAM_IMAGE_OFFSET))
    ir=0
    # printf "fucking pc $PC fucking $(memreadword 1301196) != 29433987"
    printf 'PC: %08x ' $PC
    if ((pc_offset >=0 )) && ((pc_offset < (MEMSIZE - 3))); then
        ir=$(memreadword $((pc_offset)))
        ir=$((ir & 0xffffffff))
        printf '[0x%08x] ' $ir
    else
        printf '[xxxxxxxxxx] '
    fi
    printf 'Z:%08x ra:%08x sp:%08x gp:%08x tp:%08x t0:%08x t1:%08x t2:%08x s0:%08x s1:%08x a0:%08x a1:%08x a2:%08x a3:%08x a4:%08x a5:%08x ' ${REGS[0]} ${REGS[1]} ${REGS[2]} ${REGS[3]} ${REGS[4]} ${REGS[5]} ${REGS[6]} ${REGS[7]} ${REGS[8]} ${REGS[9]} ${REGS[10]} ${REGS[11]} ${REGS[12]} ${REGS[13]} ${REGS[14]} ${REGS[15]}
    printf 'a6:%08x a7:%08x s2:%08x s3:%08x s4:%08x s5:%08x s6:%08x s7:%08x s8:%08x s9:%08x s10:%08x s11:%08x t3:%08x t4:%08x t5:%08x t6:%08x\n' ${REGS[16]} ${REGS[17]} ${REGS[18]} ${REGS[19]} ${REGS[20]} ${REGS[21]} ${REGS[22]} ${REGS[23]} ${REGS[24]} ${REGS[25]} ${REGS[26]} ${REGS[27]} ${REGS[28]} ${REGS[29]} ${REGS[30]} ${REGS[31]}
    # echo "a0 ${REGS[10]} a2 ${REGS[12]} a5 ${REGS[15]} s0 ${REGS[8]}"
}

loadblob() {

# echo "starting blob load"
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
   # echo "blob loaded"
}

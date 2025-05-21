
function readchar {
    echosafe $((0x$(readn 1 | tohex)))
}
function readint {
    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    b3=$(readn 1 | tohex)
    b4=$(readn 1 | tohex)
    echosafe $((16#$b4$b3$b2$b1))

}
function readshort {
    b1=$(readn 1 | tohex)
    b2=$(readn 1 | tohex)
    echosafe $((0x$b2$b1))
}
function readstring {
    while true; do
        char=$(readn 1 | tohex)
        if [ "$char" = "00" ]; then
            break
        fi
        echosafe "$char" | fromhex
    done
}
function eslice {
    local start=$2
    local size=$3
    if [ -n "$size" ]; then
        echosafe "${1:$((start*2)):$((size*2))}"
    else
        echosafe "${1:$((start*2))}"
    fi
}
function sliceint {
    eslice $1 $2 4 | fromhex | readint
}
function sliceshort {
    eslice $1 $2 2 | fromhex | readshort
}
function parsesectheader {
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

function parseelf {
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

                for ((j=0; j<p_memsz; j++)); do
                    printf "\x1b[1G\x1b[2KLoading memory %i%%" $(((j*100)/(p_memsz) + 1))
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

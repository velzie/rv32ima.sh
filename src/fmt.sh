
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

#!/bin/bash
~/src/mini-rv32ima/mini-rv32ima/mini-rv32ima -s -m 8000000 -f baremetal/baremetal.bin > dump1
ksh src/test.sh baremetal/baremetal.bin > dump2
bash diff.sh

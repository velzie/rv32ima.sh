#!/bin/bash

OFFSET=10
(~/src/mini-rv32ima/mini-rv32ima/mini-rv32ima -s -m 8000000 -b sixtyfourmb.dtb -f $1 > dump1) &
pid=$!
(sleep $OFFSET; ksh src/test.sh $1 sixtyfourmb.dtb > dump2) &
pid2=$!

sleep $OFFSET
sleep 5
echo "killing $pid $pid2"
kill -9 $pid $pid2

# bash diff.sh
python3 diff.py

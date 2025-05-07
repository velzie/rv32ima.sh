exec {f1}<dump1
exec {f2}<dump2

count=0

compare_registers() {
  local dump1="$1"
  local dump2="$2"

  # Strip [0x...] and parse dump1
  for pair in $(echo "$dump1" | sed 's/\[[^]]*\]//g'); do
    key=${pair%%:*}
    val=${pair#*:}
    [[ -n $key && -n $val ]] && declare "reg1_$key=$val"
  done

  # Strip [0x...] and parse dump2
  for pair in $(echo "$dump2" | sed 's/\[[^]]*\]//g'); do
    key=${pair%%:*}
    val=${pair#*:}
    [[ -n $key && -n $val ]] && declare "reg2_$key=$val"
  done

  # Compare
  for var in ${!reg1_@}; do
    reg=${var#reg1_}
    val1=${!var}
    val2=$(eval "echo \${reg2_$reg}")
    if [[ "$val1" != "$val2" ]]; then
      echo "$reg differs: $val1 vs $val2"
    fi
  done
}
while true; do
    IFS= read -r l1 <&$f1
    IFS= read -r l2 <&$f2
    if [ "$l1" != "$l2" ]; then
        echo "diffs at line $count"
        echo "------reference------"
        echo "$l1"
        echo "------actual------"
        echo "$l2"
        compare_registers "$l1" "$l2"
        exit 1
    fi
    ((count++))
done

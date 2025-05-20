
while true; do
    printf "\x1b[1G\x1b[2KSeconds since shell started: %i" $SECONDS;
    IFS= read -r -t 0.001 -n 1 -s holder;
    if [[ -n $holder ]]; then
      printf "\n"
      break
    fi
done;
printf "\"%s\"\n" $holder
$(printf "%d" "'$holder")

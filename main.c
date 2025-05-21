#include "doom/doomtype.h"
#include "lib/syscalls.h"
#include <stdio.h>
#include <stdlib.h>
void _start() {
  while (true) {
    char c = sys_char();
    if (c == 'w') {
      puts("\033[1Ddetected!!\n ");
    }
  }
  exit(1);
}

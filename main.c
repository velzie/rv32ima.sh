#include "doom/doomtype.h"
#include "lib/syscalls.h"
#include <stdio.h>
#include <stdlib.h>
void _start() {
  while (true) {
    char str[256] = {};
    int len = snprintf(str, 255, "Hello from printf %i \n", sys_ticks());
    sys_write(str, len);
  }
  exit(1);
}

#pragma once
#include <stdio.h>

static inline void sys_write(const char *str, size_t len) {
  asm volatile("li a7, 64;"
               "mv a1, %[str];"
               "mv a2, %[len];"
               "ecall;"
               :
               : [str] "r"(str), [len] "r"(len)
               : "a7", "a1", "a2");
}

int sys_ticks();

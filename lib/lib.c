#include "syscalls.h"
#include <limits.h>
#include <stdint.h>
#include <string.h>

#define ALIGN (sizeof(size_t))
#define ONES ((size_t)-1 / UCHAR_MAX)
#define HIGHS (ONES * (UCHAR_MAX / 2 + 1))
#define HASZERO(x) ((x) - ONES & ~(x) & HIGHS)

size_t strlen(const char *s) {
  const char *a = s;
#ifdef __GNUC__
  typedef size_t __attribute__((__may_alias__)) word;
  const word *w;
  for (; (uintptr_t)s % ALIGN; s++)
    if (!*s)
      return s - a;
  for (w = (const void *)s; !HASZERO(*w); w++)
    ;
  s = (const void *)w;
#endif
  for (; *s; s++)
    ;
  return s - a;
}

int puts(const char *s) {
  sys_write(s, strlen(s));
  return 0;
}

int printf(const char *restrict fmt, ...) {
  int ret;
  va_list ap;
  __builtin_va_start(ap, fmt);
  puts(fmt);
  __builtin_va_end(ap);
  return ret;
}

#include "_divsi3.c"

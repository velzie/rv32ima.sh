#include "syscalls.h"
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
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

void *memset(void *dest, int c, size_t n) {
  unsigned char *s = dest;
  size_t k;

  /* Fill head and tail with minimal branching. Each
   * conditional ensures that all the subsequently used
   * offsets are well-defined and in the dest region. */

  if (!n)
    return dest;
  s[0] = c;
  s[n - 1] = c;
  if (n <= 2)
    return dest;
  s[1] = c;
  s[2] = c;
  s[n - 2] = c;
  s[n - 3] = c;
  if (n <= 6)
    return dest;
  s[3] = c;
  s[n - 4] = c;
  if (n <= 8)
    return dest;

  /* Advance pointer to align it at a 4-byte boundary,
   * and truncate n to a multiple of 4. The previous code
   * already took care of any head/tail that get cut off
   * by the alignment. */

  k = -(uintptr_t)s & 3;
  s += k;
  n -= k;
  n &= -4;

#ifdef __GNUC__
  typedef uint32_t __attribute__((__may_alias__)) u32;
  typedef uint64_t __attribute__((__may_alias__)) u64;

  u32 c32 = ((u32)-1) / 255 * (unsigned char)c;

  /* In preparation to copy 32 bytes at a time, aligned on
   * an 8-byte bounary, fill head/tail up to 28 bytes each.
   * As in the initial byte-based head/tail fill, each
   * conditional below ensures that the subsequent offsets
   * are valid (e.g. !(n<=24) implies n>=28). */

  *(u32 *)(s + 0) = c32;
  *(u32 *)(s + n - 4) = c32;
  if (n <= 8)
    return dest;
  *(u32 *)(s + 4) = c32;
  *(u32 *)(s + 8) = c32;
  *(u32 *)(s + n - 12) = c32;
  *(u32 *)(s + n - 8) = c32;
  if (n <= 24)
    return dest;
  *(u32 *)(s + 12) = c32;
  *(u32 *)(s + 16) = c32;
  *(u32 *)(s + 20) = c32;
  *(u32 *)(s + 24) = c32;
  *(u32 *)(s + n - 28) = c32;
  *(u32 *)(s + n - 24) = c32;
  *(u32 *)(s + n - 20) = c32;
  *(u32 *)(s + n - 16) = c32;

  /* Align to a multiple of 8 so we can fill 64 bits at a time,
   * and avoid writing the same bytes twice as much as is
   * practical without introducing additional branching. */

  k = 24 + ((uintptr_t)s & 4);
  s += k;
  n -= k;

  /* If this loop is reached, 28 tail bytes have already been
   * filled, so any remainder when n drops below 32 can be
   * safely ignored. */

  u64 c64 = c32 | ((u64)c32 << 32);
  for (; n >= 32; n -= 32, s += 32) {
    *(u64 *)(s + 0) = c64;
    *(u64 *)(s + 8) = c64;
    *(u64 *)(s + 16) = c64;
    *(u64 *)(s + 24) = c64;
  }
#else
  /* Pure C fallback with no aliasing violations. */
  for (; n; n--, s++)
    *s = c;
#endif

  return dest;
}

void *memcpy(void *restrict dest, const void *restrict src, size_t n) {
  unsigned char *d = dest;
  const unsigned char *s = src;

#ifdef __GNUC__

#if __BYTE_ORDER == __LITTLE_ENDIAN
#define LS >>
#define RS <<
#else
#define LS <<
#define RS >>
#endif

  typedef uint32_t __attribute__((__may_alias__)) u32;
  uint32_t w, x;

  for (; (uintptr_t)s % 4 && n; n--)
    *d++ = *s++;

  if ((uintptr_t)d % 4 == 0) {
    for (; n >= 16; s += 16, d += 16, n -= 16) {
      *(u32 *)(d + 0) = *(u32 *)(s + 0);
      *(u32 *)(d + 4) = *(u32 *)(s + 4);
      *(u32 *)(d + 8) = *(u32 *)(s + 8);
      *(u32 *)(d + 12) = *(u32 *)(s + 12);
    }
    if (n & 8) {
      *(u32 *)(d + 0) = *(u32 *)(s + 0);
      *(u32 *)(d + 4) = *(u32 *)(s + 4);
      d += 8;
      s += 8;
    }
    if (n & 4) {
      *(u32 *)(d + 0) = *(u32 *)(s + 0);
      d += 4;
      s += 4;
    }
    if (n & 2) {
      *d++ = *s++;
      *d++ = *s++;
    }
    if (n & 1) {
      *d = *s;
    }
    return dest;
  }

  if (n >= 32)
    switch ((uintptr_t)d % 4) {
    case 1:
      w = *(u32 *)s;
      *d++ = *s++;
      *d++ = *s++;
      *d++ = *s++;
      n -= 3;
      for (; n >= 17; s += 16, d += 16, n -= 16) {
        x = *(u32 *)(s + 1);
        *(u32 *)(d + 0) = (w LS 24) | (x RS 8);
        w = *(u32 *)(s + 5);
        *(u32 *)(d + 4) = (x LS 24) | (w RS 8);
        x = *(u32 *)(s + 9);
        *(u32 *)(d + 8) = (w LS 24) | (x RS 8);
        w = *(u32 *)(s + 13);
        *(u32 *)(d + 12) = (x LS 24) | (w RS 8);
      }
      break;
    case 2:
      w = *(u32 *)s;
      *d++ = *s++;
      *d++ = *s++;
      n -= 2;
      for (; n >= 18; s += 16, d += 16, n -= 16) {
        x = *(u32 *)(s + 2);
        *(u32 *)(d + 0) = (w LS 16) | (x RS 16);
        w = *(u32 *)(s + 6);
        *(u32 *)(d + 4) = (x LS 16) | (w RS 16);
        x = *(u32 *)(s + 10);
        *(u32 *)(d + 8) = (w LS 16) | (x RS 16);
        w = *(u32 *)(s + 14);
        *(u32 *)(d + 12) = (x LS 16) | (w RS 16);
      }
      break;
    case 3:
      w = *(u32 *)s;
      *d++ = *s++;
      n -= 1;
      for (; n >= 19; s += 16, d += 16, n -= 16) {
        x = *(u32 *)(s + 3);
        *(u32 *)(d + 0) = (w LS 8) | (x RS 24);
        w = *(u32 *)(s + 7);
        *(u32 *)(d + 4) = (x LS 8) | (w RS 24);
        x = *(u32 *)(s + 11);
        *(u32 *)(d + 8) = (w LS 8) | (x RS 24);
        w = *(u32 *)(s + 15);
        *(u32 *)(d + 12) = (x LS 8) | (w RS 24);
      }
      break;
    }
  if (n & 16) {
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
  }
  if (n & 8) {
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
  }
  if (n & 4) {
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
    *d++ = *s++;
  }
  if (n & 2) {
    *d++ = *s++;
    *d++ = *s++;
  }
  if (n & 1) {
    *d = *s;
  }
  return dest;
#endif

  for (; n; n--)
    *d++ = *s++;
  return dest;
}

int puts(const char *s) {
  sys_write(s, strlen(s));
  return 0;
}

int sys_ticks() {
  int ticks;
  asm volatile("li a7, 65;"
               "ecall;"
               "mv %[ticks], a1;"
               : [ticks] "=r"(ticks)
               :
               : "a7", "a1");
  return ticks;
}
void exit(int i) {
  asm volatile("li a7, 93;"
               "ecall;"
               :
               :
               : "a7");
}

int islower(int c) { return (unsigned)c - 'a' < 26; }
int toupper(int c) {
  if (islower(c))
    return c & 0x5f;
  return c;
}

int isupper(int c) { return (unsigned)c - 'A' < 26; }
int tolower(int c) {
  if (isupper(c))
    return c | 32;
  return c;
}

int strcasecmp(const char *_l, const char *_r) {
  const unsigned char *l = (void *)_l, *r = (void *)_r;
  for (; *l && *r && (*l == *r || tolower(*l) == tolower(*r)); l++, r++)
    ;
  return tolower(*l) - tolower(*r);
}
int strncasecmp(const char *_l, const char *_r, size_t n) {
  const unsigned char *l = (void *)_l, *r = (void *)_r;
  if (!n--)
    return 0;
  for (; *l && *r && n && (*l == *r || tolower(*l) == tolower(*r));
       l++, r++, n--)
    ;
  return tolower(*l) - tolower(*r);
}

#define ALIGN (sizeof(size_t))
#define ONES ((size_t)-1 / UCHAR_MAX)
#define HIGHS (ONES * (UCHAR_MAX / 2 + 1))
#define HASZERO(x) ((x) - ONES & ~(x) & HIGHS)

char *__stpncpy(char *restrict d, const char *restrict s, size_t n) {
#ifdef __GNUC__
  typedef size_t __attribute__((__may_alias__)) word;
  word *wd;
  const word *ws;
  if (((uintptr_t)s & ALIGN) == ((uintptr_t)d & ALIGN)) {
    for (; ((uintptr_t)s & ALIGN) && n && (*d = *s); n--, s++, d++)
      ;
    if (!n || !*s)
      goto tail;
    wd = (void *)d;
    ws = (const void *)s;
    for (; n >= sizeof(size_t) && !HASZERO(*ws);
         n -= sizeof(size_t), ws++, wd++)
      *wd = *ws;
    d = (void *)wd;
    s = (const void *)ws;
  }
#endif
  for (; n && (*d = *s); n--, s++, d++)
    ;
tail:
  memset(d, 0, n);
  return d;
}
char *strncpy(char *restrict d, const char *restrict s, size_t n) {
  __stpncpy(d, s, n);
  return d;
}

char *__stpcpy(char *restrict d, const char *restrict s) {
#ifdef __GNUC__
  typedef size_t __attribute__((__may_alias__)) word;
  word *wd;
  const word *ws;
  if ((uintptr_t)s % ALIGN == (uintptr_t)d % ALIGN) {
    for (; (uintptr_t)s % ALIGN; s++, d++)
      if (!(*d = *s))
        return d;
    wd = (void *)d;
    ws = (const void *)s;
    for (; !HASZERO(*ws); *wd++ = *ws++)
      ;
    d = (void *)wd;
    s = (const void *)ws;
  }
#endif
  for (; (*d = *s); s++, d++)
    ;

  return d;
}
char *strcpy(char *restrict dest, const char *restrict src) {
  __stpcpy(dest, src);
  return dest;
}

static int parse_number(char c) {
  if ('0' <= c && c <= '9')
    return c & 0x0F; // first nibble is a number
  return -1;
}

static bool will_overflow_add(int a, int b) {
  return a >= 0 ? b > INT_MAX - a : b < INT_MIN - a;
}
static bool will_overflow_mult(int a, int b) {
  int x = a * b;
  return a != 0 && x / a != b;
}

// custom atoi impl because why not
int atoi(const char *s) {
  size_t s_len = strlen(s);
  enum { STATE_SIGN, STATE_NUMBER } state = STATE_SIGN;
  int8_t sign = 1;
  const char *start_ptr = s;
  const char *end_ptr = s;
  for (size_t c = 0; c < s_len; c++) {
    if (state == STATE_SIGN) {
      if (' ' == s[c])
        continue;

      start_ptr = s + c;
      if ('-' == s[c]) {
        sign = -1;
        state = STATE_NUMBER;
        continue;
      } else if ('+' == s[c]) {
        state = STATE_NUMBER;
        continue;
      }

      if (parse_number(s[c]) != -1) {
        state = STATE_NUMBER;
        start_ptr = s + c - 1;
      } else {
        return 0; // starts with a non sign
      }
    }
    if (state == STATE_NUMBER) {
      int parsed_num = parse_number(s[c]);
      if (parsed_num == -1) {
        break;
      }
      end_ptr = s + c;
    }
  }

  uint32_t place = 1;
  int accumulator = 0;
  int buffer_accumulator = 0;

  bool overflow = false;
  for (; end_ptr > start_ptr && end_ptr >= s; end_ptr--) {
    int parsed = parse_number(*end_ptr);
    if (parsed == 0 && overflow == true) {
      continue;
    }
    if (__builtin_mul_overflow(parsed, place, &parsed)) {
      overflow = true;
    }
    printf("%c: %i\n", *end_ptr, parsed);

    if (!will_overflow_add(parsed, accumulator)) {
      buffer_accumulator += parsed;
    } else {
      overflow = true;
    }

    if (accumulator > buffer_accumulator) {
      overflow = true;
    }

    if (overflow) {
      if (sign < 0) {
        return INT_MIN;
      }
      return INT_MAX;
    }
    overflow = false;
    if (__builtin_mul_overflow(place, 10, &place)) {
      overflow = true;
    }
    accumulator = buffer_accumulator;
  }
  return accumulator * sign;
}

int fprintf(FILE *__restrict __stream, const char *__restrict __format, ...) {
  return 0; // no filesystem
}
size_t fwrite(const void *__restrict ptr, size_t size, size_t n,
              FILE *__restrict s) {
  return 0;
}
int fputc(int c, FILE *stream) { return 0; }
int fflush(FILE *stream) { return 0; }
FILE *fopen(const char *__restrict filename, const char *__restrict modes) {
  return NULL;
}
int fclose(FILE *stream) {}

#include "_divsi3.c"
#include "printf.c"

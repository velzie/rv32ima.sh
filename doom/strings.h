#pragma once
#ifndef LINUX
#include <limits.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

// from glibc
size_t strlen(const char *str) {
  const char *char_ptr;
  const unsigned long int *longword_ptr;
  unsigned long int longword, himagic, lomagic;

  /* Handle the first few characters by reading one character at a time.
     Do this until CHAR_PTR is aligned on a longword boundary.  */
  for (char_ptr = str;
       ((unsigned long int)char_ptr & (sizeof(longword) - 1)) != 0; ++char_ptr)
    if (*char_ptr == '\0')
      return char_ptr - str;

  /* All these elucidatory comments refer to 4-byte longwords,
     but the theory applies equally well to 8-byte longwords.  */

  longword_ptr = (unsigned long int *)char_ptr;

  /* Bits 31, 24, 16, and 8 of this number are zero.  Call these bits
     the "holes."  Note that there is a hole just to the left of
     each byte, with an extra at the end:

     bits:  01111110 11111110 11111110 11111111
     bytes: AAAAAAAA BBBBBBBB CCCCCCCC DDDDDDDD

     The 1-bits make sure that carries propagate to the next 0-bit.
     The 0-bits provide holes for carries to fall into.  */
  himagic = 0x80808080L;
  lomagic = 0x01010101L;
  if (sizeof(longword) > 4) {
    /* 64-bit version of the magic.  */
    /* Do the shift in two steps to avoid a warning if long has 32 bits.  */
    himagic = ((himagic << 16) << 16) | himagic;
    lomagic = ((lomagic << 16) << 16) | lomagic;
  }
  if (sizeof(longword) > 8)
    return -1;

  /* Instead of the traditional loop which tests each character,
     we will test a longword at a time.  The tricky part is testing
     if *any of the four* bytes in the longword in question are zero.  */
  for (;;) {
    longword = *longword_ptr++;

    if (((longword - lomagic) & ~longword & himagic) != 0) {
      /* Which of the bytes was the zero?  If none of them were, it was
         a misfire; continue the search.  */

      const char *cp = (const char *)(longword_ptr - 1);

      if (cp[0] == 0)
        return cp - str;
      if (cp[1] == 0)
        return cp - str + 1;
      if (cp[2] == 0)
        return cp - str + 2;
      if (cp[3] == 0)
        return cp - str + 3;
      if (sizeof(longword) > 4) {
        if (cp[4] == 0)
          return cp - str + 4;
        if (cp[5] == 0)
          return cp - str + 5;
        if (cp[6] == 0)
          return cp - str + 6;
        if (cp[7] == 0)
          return cp - str + 7;
      }
    }
  }
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

static int atoi(char *s) {
  size_t s_len = strlen(s);
  enum { STATE_SIGN, STATE_NUMBER } state = STATE_SIGN;
  int8_t sign = 1;
  char *start_ptr = s;
  char *end_ptr = s;
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
#endif

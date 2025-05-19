#include "_udivmodsi4.c"
#include "si.h"

// GNU CODE
// TODO: figure out licences

static const UQItype __divsi3_table[] = {
    0, 0,  0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 1,  0, 0, 0, 0, 0, 0,
    0, 0,  0, 0, 0, 0, 0, 0, 0, 2,  1, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0,
    0, 3,  1, 1, 0, 0, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 4,  2, 1, 1, 0, 0, 0,
    0, 0,  0, 0, 0, 0, 0, 0, 0, 5,  2, 1, 1, 1, 0, 0, 0, 0,  0, 0, 0, 0, 0, 0,
    0, 6,  3, 2, 1, 1, 1, 0, 0, 0,  0, 0, 0, 0, 0, 0, 0, 7,  3, 2, 1, 1, 1, 1,
    0, 0,  0, 0, 0, 0, 0, 0, 0, 8,  4, 2, 2, 1, 1, 1, 1, 0,  0, 0, 0, 0, 0, 0,
    0, 9,  4, 3, 2, 1, 1, 1, 1, 1,  0, 0, 0, 0, 0, 0, 0, 10, 5, 3, 2, 2, 1, 1,
    1, 1,  1, 0, 0, 0, 0, 0, 0, 11, 5, 3, 2, 2, 1, 1, 1, 1,  1, 1, 0, 0, 0, 0,
    0, 12, 6, 4, 3, 2, 2, 1, 1, 1,  1, 1, 1, 0, 0, 0, 0, 13, 6, 4, 3, 2, 2, 1,
    1, 1,  1, 1, 1, 1, 0, 0, 0, 14, 7, 4, 3, 2, 2, 2, 1, 1,  1, 1, 1, 1, 1, 0,
    0, 15, 7, 5, 3, 3, 2, 2, 1, 1,  1, 1, 1, 1, 1, 1,
};

SItype __divsi3(SItype a, SItype b) {
  int neg = 0;
  SItype res;
  int cfg;

  if (b == 0) { // divide by zero
    // this is replacing some complex bullshit, its fine since doom will
    // probably never divide by zero
    return 0;
  }

  if (((USItype)(a | b)) < 16)
    res = __divsi3_table[(a << 4) + b];
  else {

    if (a < 0) {
      a = -a;
      neg = !neg;
    }

    if (b < 0) {
      b = -b;
      neg = !neg;
    }

    res = __udivmodsi4(a, b, 0);

    if (neg)
      res = -res;
  }

  return res;
}

long __modsi3(long a, long b) {
  int neg = 0;
  long res;

  if (a < 0) {
    a = -a;
    neg = 1;
  }

  if (b < 0)
    b = -b;

  res = __udivmodsi4(a, b, 1);

  if (neg)
    res = -res;

  return res;
}

USItype __mulsi3(USItype a, USItype b) {
  USItype result;

  result = 0;

  if (a == 0)
    return 0;

  while (b != 0) {
    if (b & 1)
      result += a;
    a <<= 1;
    b >>= 1;
  }

  return result;
}

long __udivsi3(long a, long b) { return __udivmodsi4(a, b, 0); }

long __umodsi3(long a, long b) { return __udivmodsi4(a, b, 1); }

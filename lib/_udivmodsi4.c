#include "si.h"

USItype __udivmodsi4(USItype num, USItype den, int modwanted) {
  USItype bit = 1;
  USItype res = 0;

  while (den < num && bit && !(den & (1L << 31))) {
    den <<= 1;
    bit <<= 1;
  }
  while (bit) {
    if (num >= den) {
      num -= den;
      res |= bit;
    }
    bit >>= 1;
    den >>= 1;
  }
  if (modwanted)
    return num;
  return res;
}

#pragma once

static short max(short a, short b) {
  if (a < b)
    return b;
  return a;
}
static short min(short a, short b) {
  if (a > b)
    return b;
  return a;
}

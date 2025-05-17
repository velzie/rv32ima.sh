void _start() {
  char *str = "Hello World!\n\0";
  asm("li a7, 64;"
      "la a1, 0x%0;"
      "li a2, 14;"
      "ecall;"
      :
      : "r"(str)
      : "a7", "a1", "a2");
}

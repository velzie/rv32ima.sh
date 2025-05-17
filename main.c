void _start() {
  const char str[] = "Hello World!\n\0";
  const char str2[] = "World 2!\n\0";
  asm volatile("li a7, 64;"
               "mv a1, %[str];"
               "li a2, 14;"
               "ecall;"
               :
               : [str] "r"(&str)
               : "a7", "a1", "a2");
  asm volatile("li a7, 64;"
               "mv a1, %[str2];"
               "li a2, 9;"
               "ecall;"
               :
               : [str2] "r"(&str2)
               : "a7", "a1", "a2");
}

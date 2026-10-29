#include <windows.h>
#include <stdio.h>
int main() { printf("%08lx\n", (unsigned long)GetProcAddress(GetModuleHandleA("kernel32.dll"), "ReadFile")); return 0; }

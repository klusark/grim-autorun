/* Prints dwords of the running game's memory: rdmem <hex address> [count] */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
	PROCESSENTRY32 pe;
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	DWORD pid = 0, v[1024];
	SIZE_T n = 0;
	int i, cnt = argc > 2 ? atoi(argv[2]) : 1;
	pe.dwSize = sizeof pe;
	if (Process32First(snap, &pe)) do { if (_stricmp(pe.szExeFile, "GRIMFANDANGO.exe") == 0) pid = pe.th32ProcessID; } while (Process32Next(snap, &pe));
	if (!pid) { printf("not running\n"); return 1; }
	HANDLE p = OpenProcess(PROCESS_VM_READ, FALSE, pid);
	ReadProcessMemory(p, (void *)(ULONG_PTR)strtoul(argv[1], NULL, 16), v, cnt * 4, &n);
	for (i = 0; i < (int)(n / 4); i++) printf("%08lx ", v[i]);
	printf("\n");
	return 0;
}

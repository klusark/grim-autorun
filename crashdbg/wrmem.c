/* Writes one dword into the running original game: wrmem <hex address> <hex value> */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
	PROCESSENTRY32 pe;
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	DWORD pid = 0, v = (DWORD)strtoul(argv[2], NULL, 16);
	SIZE_T n = 0;
	pe.dwSize = sizeof pe;
	if (Process32First(snap, &pe)) do { if (_stricmp(pe.szExeFile, "GRIMFANDANGO.exe") == 0) pid = pe.th32ProcessID; } while (Process32Next(snap, &pe));
	if (!pid) { printf("not running\n"); return 1; }
	HANDLE p = OpenProcess(PROCESS_VM_WRITE | PROCESS_VM_OPERATION, FALSE, pid);
	WriteProcessMemory(p, (void *)(ULONG_PTR)strtoul(argv[1], NULL, 16), &v, 4, &n);
	printf("wrote %lu bytes\n", (unsigned long)n);
	return 0;
}

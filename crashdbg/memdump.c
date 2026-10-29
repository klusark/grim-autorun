/* Dumps memory of a running process: memdump <exe name> <hex address> <bytes> <out file> */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv) {
	PROCESSENTRY32 pe;
	HANDLE snap, proc = NULL;
	DWORD pid = 0;
	unsigned long addr, size;
	char *buf;
	SIZE_T n = 0;
	FILE *f;
	if (argc < 5) {
		printf("usage: memdump <exe> <hex addr> <bytes> <file>\n");
		return 1;
	}
	snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	pe.dwSize = sizeof pe;
	if (Process32First(snap, &pe)) {
		do {
			if (!_stricmp(pe.szExeFile, argv[1])) pid = pe.th32ProcessID;
		} while (Process32Next(snap, &pe));
	}
	CloseHandle(snap);
	if (!pid) {
		printf("no process %s\n", argv[1]);
		return 1;
	}
	proc = OpenProcess(PROCESS_VM_READ, FALSE, pid);
	addr = strtoul(argv[2], NULL, 16);
	size = strtoul(argv[3], NULL, 0);
	buf = malloc(size);
	if (!proc || !ReadProcessMemory(proc, (void *)(ULONG_PTR)addr, buf, size, &n)) {
		printf("cannot read (%lu)\n", GetLastError());
		return 1;
	}
	f = fopen(argv[4], "wb");
	fwrite(buf, 1, n, f);
	fclose(f);
	printf("read %lu bytes of pid %lu\n", (unsigned long)n, pid);
	return 0;
}

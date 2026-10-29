/* Samples EIP (and a few return addresses from the stack) of every thread of the running game */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
	PROCESSENTRY32 pe;
	THREADENTRY32 te;
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	DWORD pid = 0;
	int round, rounds = argc > 1 ? atoi(argv[1]) : 10;
	pe.dwSize = sizeof pe;
	if (Process32First(snap, &pe)) {
		do {
			if (_stricmp(pe.szExeFile, "GRIMFANDANGO.exe") == 0) pid = pe.th32ProcessID;
		} while (Process32Next(snap, &pe));
	}
	CloseHandle(snap);
	if (!pid) { printf("not running\n"); return 1; }
	{
		HANDLE proc = OpenProcess(PROCESS_VM_READ, FALSE, pid);
		for (round = 0; round < rounds; round++) {
			HANDLE ts = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
			te.dwSize = sizeof te;
			if (Thread32First(ts, &te)) {
				do {
					if (te.th32OwnerProcessID == pid) {
						HANDLE t = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT, FALSE, te.th32ThreadID);
						if (t) {
							WOW64_CONTEXT c;
							c.ContextFlags = WOW64_CONTEXT_FULL;
							SuspendThread(t);
							if (Wow64GetThreadContext(t, &c)) {
								DWORD st[24];
								SIZE_T n = 0;
								int i;
								printf("tid %lu eip %08lx esp %08lx stack:", te.th32ThreadID, c.Eip, c.Esp);
								ReadProcessMemory(proc, (void *)(ULONG_PTR)c.Esp, st, sizeof st, &n);
								for (i = 0; i < (int)(n / 4); i++) if (st[i] >= 0x400000 && st[i] < 0x500000) printf(" %08lx", st[i]);
								printf("\n");
							}
							ResumeThread(t);
							CloseHandle(t);
						}
					}
				} while (Thread32Next(ts, &te));
			}
			CloseHandle(ts);
			Sleep(300);
		}
	}
	return 0;
}

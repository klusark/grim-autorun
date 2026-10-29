#include <windows.h>
#include <stdio.h>
int main(int argc, char **argv) {
	STARTUPINFO si; PROCESS_INFORMATION pi; DEBUG_EVENT ev;
	memset(&si, 0, sizeof si); si.cb = sizeof si;
	if (!CreateProcess(argv[1], argc > 3 ? argv[3] : NULL, NULL, NULL, FALSE, DEBUG_ONLY_THIS_PROCESS, NULL, argv[2], &si, &pi)) { printf("cannot start\n"); return 1; }
	for (;;) {
		if (!WaitForDebugEvent(&ev, INFINITE)) break;
		DWORD cont = DBG_CONTINUE;
		if (ev.dwDebugEventCode == OUTPUT_DEBUG_STRING_EVENT) {
			char buf[512]; SIZE_T n = 0; int len = ev.u.DebugString.nDebugStringLength; if (len > 500) len = 500;
			ReadProcessMemory(pi.hProcess, ev.u.DebugString.lpDebugStringData, buf, len, &n); buf[n] = 0;
			printf("ODS: %s\n", buf);
		}
		if (ev.dwDebugEventCode == EXCEPTION_DEBUG_EVENT) {
			DWORD code = ev.u.Exception.ExceptionRecord.ExceptionCode;
			if (code == EXCEPTION_ACCESS_VIOLATION) {
				CONTEXT c; c.ContextFlags = CONTEXT_FULL;
				HANDLE t = OpenThread(THREAD_ALL_ACCESS, FALSE, ev.dwThreadId);
				GetThreadContext(t, &c);
				printf("AV at %08lx accessing %p (write=%d)\n", c.Eip, (void*)ev.u.Exception.ExceptionRecord.ExceptionInformation[1], (int)ev.u.Exception.ExceptionRecord.ExceptionInformation[0]);
				printf("EAX=%08lx EBX=%08lx ECX=%08lx EDX=%08lx ESI=%08lx EDI=%08lx EBP=%08lx ESP=%08lx\n", c.Eax, c.Ebx, c.Ecx, c.Edx, c.Esi, c.Edi, c.Ebp, c.Esp);
				DWORD s[96]; SIZE_T n = 0;
				ReadProcessMemory(pi.hProcess, (void*)c.Esp, s, sizeof s, &n);
				int i; for (i = 0; i < (int)(n / 4); i++) printf("%s%08lx", (i % 8) ? " " : "\n", s[i]);
				printf("\n");
				fflush(stdout);
				TerminateProcess(pi.hProcess, 1);
				return 0;
			}
			printf("exception %08lx first=%d at %p\n", code, (int)ev.u.Exception.dwFirstChance, ev.u.Exception.ExceptionRecord.ExceptionAddress);
			cont = DBG_EXCEPTION_NOT_HANDLED;
		}
		if (ev.dwDebugEventCode == EXIT_PROCESS_DEBUG_EVENT) { printf("exited %lu\n", ev.u.ExitProcess.dwExitCode); return 0; }
		ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, cont);
	}
	return 0;
}

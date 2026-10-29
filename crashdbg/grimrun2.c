/* Runs the original Grim Fandango under a debugger and starts grimpatch.bin in it.

   The game's software blitter overruns a heap buffer, which only faults without a debugger attached
   (the debug heap pads allocations). The exe is patched so that F12 alone runs grimpatch.bin; F12
   is sent to all windows of the game until its log shows that the script has started.

   usage: grimrun2 <exe> <dir> <command line> <first F12 after seconds> */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define LOGFILE "C:/GOG Games/GRIMDATA/grimdebug.log"
#define MARKER "running autorun_all.lua"

static DWORD g_pid;
static HWND g_wnds[16];
static int g_nwnds;

static BOOL CALLBACK collect(HWND h, LPARAM l) {
	DWORD pid = 0;
	GetWindowThreadProcessId(h, &pid);
	if (pid == g_pid && g_nwnds < 16) g_wnds[g_nwnds++] = h;
	return TRUE;
}

static int script_started(void) {
	static char buf[1 << 22];
	size_t n;
	FILE *f = fopen(LOGFILE, "rb");
	if (!f) return 0;
	n = fread(buf, 1, sizeof buf - 1, f);
	buf[n] = 0;
	fclose(f);
	return strstr(buf, MARKER) != NULL;
}

static void press_f12(void) {
	int i;
	g_nwnds = 0;
	EnumWindows(collect, 0);
	printf("windows of the game: %d\n", g_nwnds);
	/* the game asks for Backspace to be held (GetKeyState) when F12 arrives */
	for (i = 0; i < g_nwnds; i++) {
		if (IsWindowVisible(g_wnds[i])) {
			DWORD fg = GetWindowThreadProcessId(GetForegroundWindow(), NULL);
			DWORD me = GetCurrentThreadId();
			AttachThreadInput(me, fg, TRUE);
			SetForegroundWindow(g_wnds[i]);
			AttachThreadInput(me, fg, FALSE);
			break;
		}
	}
	Sleep(500);
	keybd_event(VK_BACK, 0, 0, 0);
	Sleep(300);
	for (i = 0; i < g_nwnds; i++) {
		PostMessage(g_wnds[i], WM_KEYDOWN, VK_F12, 0x00580001);
		Sleep(50);
		PostMessage(g_wnds[i], WM_KEYUP, VK_F12, 0xC0580001);
	}
	Sleep(300);
	keybd_event(VK_BACK, 0, KEYEVENTF_KEYUP, 0);
	fflush(stdout);
}

int main(int argc, char **argv) {
	STARTUPINFO si;
	PROCESS_INFORMATION pi;
	DEBUG_EVENT ev;
	int delay = argc > 4 ? atoi(argv[4]) : 15;
	int tries = 0;
	DWORD start, last = 0;
	memset(&si, 0, sizeof si);
	si.cb = sizeof si;
	if (!CreateProcess(argv[1], argv[3], NULL, NULL, FALSE, DEBUG_ONLY_THIS_PROCESS, NULL, argv[2], &si, &pi)) {
		printf("cannot start\n");
		return 1;
	}
	g_pid = pi.dwProcessId;
	start = GetTickCount();
	for (;;) {
		DWORD cont = DBG_CONTINUE;
		DWORD now = GetTickCount();
		if (tries < 10 && now - start > (DWORD)delay * 1000 && now - last > 6000) {
			if (script_started()) {
				printf("the script has started\n");
				tries = 10;
			} else {
				tries++;
				last = now;
				printf("F12 number %d\n", tries);
				press_f12();
			}
			fflush(stdout);
		}
		if (!WaitForDebugEvent(&ev, 200)) continue;
		if (ev.dwDebugEventCode == EXCEPTION_DEBUG_EVENT) {
			DWORD code = ev.u.Exception.ExceptionRecord.ExceptionCode;
			if (code == EXCEPTION_ACCESS_VIOLATION) {
				printf("access violation at %p, accessing %p\n", ev.u.Exception.ExceptionRecord.ExceptionAddress, (void *)ev.u.Exception.ExceptionRecord.ExceptionInformation[1]);
{
 WOW64_CONTEXT c; HANDLE t = OpenThread(THREAD_ALL_ACCESS, FALSE, ev.dwThreadId);
 c.ContextFlags = WOW64_CONTEXT_FULL;
 if (t && Wow64GetThreadContext(t, &c)) {
  DWORD st[64]; SIZE_T n = 0; int i;
  printf("eax %08lx ebx %08lx ecx %08lx edx %08lx esi %08lx edi %08lx ebp %08lx esp %08lx\nstack:", c.Eax, c.Ebx, c.Ecx, c.Edx, c.Esi, c.Edi, c.Ebp, c.Esp);
  ReadProcessMemory(pi.hProcess, (void *)(ULONG_PTR)c.Esp, st, sizeof st, &n);
  for (i = 0; i < (int)(n / 4); i++) if (st[i] >= 0x400000 && st[i] < 0x500000) printf(" %08lx", st[i]);

  for (i = 0; i < 14; i++) { DWORD m[10]; SIZE_T k = 0; int q; printf("st[%d]=%08lx", i, st[i]); if (st[i] > 0x10000 && ReadProcessMemory(pi.hProcess, (void *)(ULONG_PTR)st[i], m, sizeof m, &k)) { printf(" ->"); for (q = 0; q < 10 && q * 4 < (int)k; q++) printf(" %lx", m[q]); } printf("\n"); }
  printf("\n");
 }
}
				fflush(stdout);
				TerminateProcess(pi.hProcess, 1);
				return 2;
			}
			cont = DBG_EXCEPTION_NOT_HANDLED;
		}
		if (ev.dwDebugEventCode == EXIT_PROCESS_DEBUG_EVENT) {
			printf("the game exited with %lu\n", ev.u.ExitProcess.dwExitCode);
			return 0;
		}
		ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, cont);
	}
	return 0;
}

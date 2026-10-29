/* Runs the original Grim Fandango under a debugger (its heap overrun in the software blitter only
   faults without one), prints crashes, and after a delay presses Backspace+F12 in its window,
   which makes the game run grimpatch.bin.
   usage: grimrun <exe> <dir> <command line> <inject delay seconds> */
#include <windows.h>
#include <stdio.h>

static DWORD g_pid;
static BYTE g_orig;
static HANDLE g_proc;
static int g_bp;
static int g_bpset;
static DWORD BPADDR = 0x402fd0;
static HWND g_wnd;

static BOOL CALLBACK find_wnd(HWND h, LPARAM l) {
	DWORD pid = 0;
	GetWindowThreadProcessId(h, &pid);
	if (pid == g_pid && IsWindowVisible(h)) { g_wnd = h; return FALSE; }
	return TRUE;
}

static void key(BYTE vk, DWORD flags) { keybd_event(vk, 0, flags, 0); }

static int script_started(void) {
	FILE *f = fopen("C:\GOG Games\GRIMDATA\grimdebug.log", "rb");
	static char buf[1 << 20];
	size_t n;
	if (!f) return 0;
	n = fread(buf, 1, sizeof buf - 1, f);
	buf[n] = 0;
	fclose(f);
	return strstr(buf, "running autorun_all.lua") != NULL;
}

static void inject(void) {
	g_wnd = NULL;
	{ DWORD v = 99; SIZE_T nn = 0; ReadProcessMemory(g_proc, (void *)0x1002bee0, &v, 4, &nn); printf("lua_assume_binary = %lu (read %lu)\n", v, (unsigned long)nn); }
	EnumWindows(find_wnd, 0);
	printf("window %p\n", (void *)g_wnd);
	if (g_wnd) {
		DWORD fg = GetWindowThreadProcessId(GetForegroundWindow(), NULL);
		DWORD me = GetCurrentThreadId();
		AttachThreadInput(me, fg, TRUE);
		SetForegroundWindow(g_wnd);
		AttachThreadInput(me, fg, FALSE);
		Sleep(800);
	}
	/* (the exe is patched so that F12 alone runs grimpatch.bin) */
	Sleep(300);
	/* F12 is the debugger's hotkey while one is attached, so the message is posted to the window instead */
	PostMessage(g_wnd, WM_KEYDOWN, VK_F12, 0x00580001);
	Sleep(100);
	PostMessage(g_wnd, WM_KEYUP, VK_F12, 0xC0580001);
	Sleep(300);

	printf("chord sent\n");
	fflush(stdout);
}

int main(int argc, char **argv) {
	STARTUPINFO si; PROCESS_INFORMATION pi; DEBUG_EVENT ev;
	int delay = argc > 4 ? atoi(argv[4]) : 20;
	DWORD start;
	int injected = 0;
	memset(&si, 0, sizeof si); si.cb = sizeof si;
	if (!CreateProcess(argv[1], argv[3], NULL, NULL, FALSE, DEBUG_ONLY_THIS_PROCESS, NULL, argv[2], &si, &pi)) { printf("cannot start\n"); return 1; }
	g_pid = pi.dwProcessId;
	g_proc = pi.hProcess;
	g_bp = getenv("GRIMBP") != NULL; if (g_bp) BPADDR = strtoul(getenv("GRIMBP"), NULL, 16);
	start = GetTickCount();
	for (;;) {
		DWORD cont = DBG_CONTINUE;
		if (g_bp && !g_bpset && GetTickCount() - start > (DWORD)(getenv("GRIMBPDELAY") ? atoi(getenv("GRIMBPDELAY")) : 0) * 1000) {
			BYTE cc = 0xCC; SIZE_T n;
			ReadProcessMemory(pi.hProcess, (void *)BPADDR, &g_orig, 1, &n);
			WriteProcessMemory(pi.hProcess, (void *)BPADDR, &cc, 1, &n);
			g_bpset = 1;
			printf("bp set at %lx, orig byte %02x\n", (unsigned long)BPADDR, g_orig); fflush(stdout);
		}
		if (injected < 8 && GetTickCount() - start > (DWORD)delay * 1000 + (DWORD)injected * 6000) {
			/* resend F12 until the script has announced itself in the game's log */
			if (!script_started()) { injected++; inject(); } else injected = 8;
		}
		if (!WaitForDebugEvent(&ev, 200)) continue;
		if (ev.dwDebugEventCode == EXCEPTION_DEBUG_EVENT) {
			DWORD code = ev.u.Exception.ExceptionRecord.ExceptionCode;
			if (g_bp && code == EXCEPTION_BREAKPOINT && (DWORD)ev.u.Exception.ExceptionRecord.ExceptionAddress == BPADDR) {
				CONTEXT c; c.ContextFlags = CONTEXT_FULL;
				HANDLE t = OpenThread(THREAD_ALL_ACCESS, FALSE, ev.dwThreadId);
				GetThreadContext(t, &c);
				DWORD a[4]; SIZE_T n;
				ReadProcessMemory(pi.hProcess, (void *)(c.Esp + 4), a, sizeof a, &n);
				if (1) { printf("bp hit eax=%08lx ecx=%08lx args %08lx %08lx %08lx\n", c.Eax, c.Ecx, a[0], a[1], a[2]); fflush(stdout); }
				if (getenv("GRIMDUMP")) { unsigned char db[40]; SIZE_T dn = 0; int di; ReadProcessMemory(pi.hProcess, (void *)a[1], db, 32, &dn); printf("  buf:"); for (di = 0; di < (int)dn; di++) printf(" %02x", db[di]); printf("\n"); fflush(stdout); }
				if (getenv("GRIMSTR")) { char sb[200]; SIZE_T sn = 0; ReadProcessMemory(pi.hProcess, (void *)a[0], sb, 199, &sn); sb[sn] = 0; printf("  string: %s\n", sb); fflush(stdout); }
				if (0) { printf("wndproc msg %lx key %lx\n", a[1], a[2]); fflush(stdout); }
				WriteProcessMemory(pi.hProcess, (void *)BPADDR, &g_orig, 1, &n);
				c.Eip = BPADDR; c.EFlags |= 0x100;
				SetThreadContext(t, &c);
				CloseHandle(t);
				ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, DBG_CONTINUE);
				continue;
			}
			if (g_bp && code == EXCEPTION_SINGLE_STEP) {
				BYTE cc = 0xCC; SIZE_T n;
				WriteProcessMemory(pi.hProcess, (void *)BPADDR, &cc, 1, &n);
				ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, DBG_CONTINUE);
				continue;
			}
			if (code == EXCEPTION_ACCESS_VIOLATION) {
				CONTEXT c; c.ContextFlags = CONTEXT_FULL;
				HANDLE t = OpenThread(THREAD_ALL_ACCESS, FALSE, ev.dwThreadId);
				GetThreadContext(t, &c);
				printf("AV at %08lx accessing %p (write=%d)\n", c.Eip, (void *)ev.u.Exception.ExceptionRecord.ExceptionInformation[1], (int)ev.u.Exception.ExceptionRecord.ExceptionInformation[0]);
				fflush(stdout);
				TerminateProcess(pi.hProcess, 1);
				return 2;
			}
			cont = DBG_EXCEPTION_NOT_HANDLED;
		}
		if (0) {
			BYTE cc = 0xCC; SIZE_T n;
			ReadProcessMemory(pi.hProcess, (void *)BPADDR, &g_orig, 1, &n);
			WriteProcessMemory(pi.hProcess, (void *)BPADDR, &cc, 1, &n);
			printf("bp set, orig byte %02x\n", g_orig);
		}
		if (ev.dwDebugEventCode == EXIT_PROCESS_DEBUG_EVENT) { printf("exited %lu\n", ev.u.ExitProcess.dwExitCode); return 0; }
		ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, cont);
	}
	return 0;
}

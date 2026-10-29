/* grimrun2 with breakpoints: runs the original Grim Fandango under a debugger, starts grimpatch.bin in it (F12), and at each
   address of GRIMTRACE_BP (hex, comma separated) logs the registers and the stack round ESP, with every stack word that points
   into the process read as 12 floats. The log is GRIMTRACE_LOG (default C:/GOG Games/GRIMDATA/grimtrace.log); at most GRIMTRACE_MAX
   hits (default 20000) are logged, then the breakpoints stay but are not logged.

   usage: grimtrace <exe> <dir> <command line> <first F12 after seconds> */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

#define LOGFILE "C:/GOG Games/GRIMDATA/grimdebug.log"
#define MARKER "running autorun_all.lua"
#define STATUS_WX86_SINGLE_STEP_ 0x4000001E
#define STATUS_WX86_BREAKPOINT_ 0x4000001F

static DWORD g_pid;
static HWND g_wnds[16];
static int g_nwnds;
static DWORD g_bp[64];
static BYTE g_orig[64];
static int g_nbp;
static int g_rearm = -1;
static FILE *g_log;
static long g_hits, g_max;

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
}

static void arm(HANDLE proc, int i, int on) {
	BYTE cc = 0xCC;
	SIZE_T n;
	DWORD old;
	VirtualProtectEx(proc, (void *)(ULONG_PTR)g_bp[i], 1, PAGE_EXECUTE_READWRITE, &old);
	if (on)
		WriteProcessMemory(proc, (void *)(ULONG_PTR)g_bp[i], &cc, 1, &n);
	else
		WriteProcessMemory(proc, (void *)(ULONG_PTR)g_bp[i], &g_orig[i], 1, &n);
	VirtualProtectEx(proc, (void *)(ULONG_PTR)g_bp[i], 1, old, &old);
	FlushInstructionCache(proc, (void *)(ULONG_PTR)g_bp[i], 1);
}

static void dump(HANDLE proc, int i, WOW64_CONTEXT *c) {
	DWORD st[40];
	SIZE_T n = 0;
	int k, q;
	DWORD base = c->Esp - 0x30;
	if (g_hits++ >= g_max) return;
	fprintf(g_log, "BP %08lx hit %ld eax %08lx ebx %08lx ecx %08lx edx %08lx esi %08lx edi %08lx ebp %08lx esp %08lx\n", g_bp[i], g_hits,
	        c->Eax, c->Ebx, c->Ecx, c->Edx, c->Esi, c->Edi, c->Ebp, c->Esp);
	ReadProcessMemory(proc, (void *)(ULONG_PTR)base, st, sizeof st, &n);
	for (k = 0; k < (int)(n / 4); k++) {
		float f;
		memcpy(&f, &st[k], 4);
		fprintf(g_log, "  [esp%+04d] %08lx %.9g", (int)(k * 4) - 0x30, st[k], f);
		if (st[k] > 0x10000 && st[k] < 0x7fff0000) {
			float m[12];
			SIZE_T r = 0;
			if (ReadProcessMemory(proc, (void *)(ULONG_PTR)st[k], m, sizeof m, &r) && r == sizeof m) {
				fprintf(g_log, " ->");
				for (q = 0; q < 12; q++) fprintf(g_log, " %.9g", m[q]);
			}
		}
		fprintf(g_log, "\n");
	}
	/* GRIMTRACE_PEEK=reg+hexoff,...: 4 words at a register plus an offset (eax ebx ecx edx esi edi ebp esp) */
	{
		const char *pk = getenv("GRIMTRACE_PEEK");
		while (pk && *pk) {
			char r[4] = {0};
			DWORD base2 = 0, w[4] = {0};
			unsigned long off;
			SIZE_T rr = 0;
			memcpy(r, pk, 3);
			off = strtoul(pk + 4, (char **)&pk, 16);
			if (!strcmp(r, "eax")) base2 = c->Eax; else if (!strcmp(r, "ebx")) base2 = c->Ebx; else if (!strcmp(r, "ecx")) base2 = c->Ecx;
			else if (!strcmp(r, "edx")) base2 = c->Edx; else if (!strcmp(r, "esi")) base2 = c->Esi; else if (!strcmp(r, "edi")) base2 = c->Edi;
			else if (!strcmp(r, "ebp")) base2 = c->Ebp; else if (!strcmp(r, "esp")) base2 = c->Esp;
			ReadProcessMemory(proc, (void *)(ULONG_PTR)(base2 + off), w, sizeof w, &rr);
			{
				float f[4];
				memcpy(f, w, sizeof f);
				fprintf(g_log, "  peek %s+%lx: %08lx %08lx %08lx %08lx / %.9g %.9g %.9g %.9g\n", r, off, w[0], w[1], w[2], w[3], f[0], f[1], f[2], f[3]);
			}
			while (*pk == ',') pk++;
		}
	}
	/* the x87 top (the result of a float function): the 80 bit register converted by hand (printf of a long double is wrong here) */
	{
		unsigned char *r = (unsigned char *)c->FloatSave.RegisterArea;
		unsigned long long man;
		unsigned short se;
		double v;
		memcpy(&man, r, 8);
		memcpy(&se, r + 8, 2);
		v = ldexp((double)man, (int)(se & 0x7fff) - 16383 - 63);
		if (se & 0x8000) v = -v;
		fprintf(g_log, "  st0 %.17g\n", v);
	}
	fflush(g_log);
}

int main(int argc, char **argv) {
	STARTUPINFO si;
	PROCESS_INFORMATION pi;
	DEBUG_EVENT ev;
	int delay = argc > 4 ? atoi(argv[4]) : 15;
	int tries = 0;
	int armed = 0;
	DWORD start, last = 0;
	const char *bps = getenv("GRIMTRACE_BP");
	const char *logname = getenv("GRIMTRACE_LOG");
	const char *mx = getenv("GRIMTRACE_MAX");
	g_max = mx ? atol(mx) : 20000;
	g_log = fopen(logname ? logname : "C:/GOG Games/GRIMDATA/grimtrace.log", "w");
	if (bps) {
		const char *p = bps;
		while (*p && g_nbp < 64) {
			g_bp[g_nbp++] = strtoul(p, (char **)&p, 16);
			while (*p == ',' || *p == ' ') p++;
		}
	}
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
		if (ev.dwDebugEventCode == CREATE_PROCESS_DEBUG_EVENT && !armed) {
			int i;
			SIZE_T n;
			for (i = 0; i < g_nbp; i++) {
				ReadProcessMemory(pi.hProcess, (void *)(ULONG_PTR)g_bp[i], &g_orig[i], 1, &n);
				arm(pi.hProcess, i, 1);
			}
			armed = 1;
			fprintf(g_log, "armed %d breakpoints\n", g_nbp);
			fflush(g_log);
		}
		if (ev.dwDebugEventCode == EXCEPTION_DEBUG_EVENT) {
			DWORD code = ev.u.Exception.ExceptionRecord.ExceptionCode;
			DWORD addr = (DWORD)(ULONG_PTR)ev.u.Exception.ExceptionRecord.ExceptionAddress;
			if (code == EXCEPTION_BREAKPOINT || code == STATUS_WX86_BREAKPOINT_) {
				int i, hit = -1;
				for (i = 0; i < g_nbp; i++)
					if (g_bp[i] == addr) hit = i;
				if (hit >= 0) {
					WOW64_CONTEXT c;
					HANDLE t = OpenThread(THREAD_ALL_ACCESS, FALSE, ev.dwThreadId);
					c.ContextFlags = WOW64_CONTEXT_FULL | WOW64_CONTEXT_FLOATING_POINT;
					if (t && Wow64GetThreadContext(t, &c)) {
						dump(pi.hProcess, hit, &c);
						arm(pi.hProcess, hit, 0);
						c.Eip = addr;
						c.EFlags |= 0x100;
						Wow64SetThreadContext(t, &c);
						g_rearm = hit;
					}
					if (t) CloseHandle(t);
				}
				/* (the loader's own breakpoints: go on) */
			} else if (code == EXCEPTION_SINGLE_STEP || code == STATUS_WX86_SINGLE_STEP_) {
				if (g_rearm >= 0) {
					arm(pi.hProcess, g_rearm, 1);
					g_rearm = -1;
				}
			} else if (code == EXCEPTION_ACCESS_VIOLATION) {
				printf("access violation at %08lx, accessing %p\n", addr, (void *)ev.u.Exception.ExceptionRecord.ExceptionInformation[1]);
				fflush(stdout);
				TerminateProcess(pi.hProcess, 1);
				return 2;
			} else {
				cont = DBG_EXCEPTION_NOT_HANDLED;
			}
		}
		if (ev.dwDebugEventCode == EXIT_PROCESS_DEBUG_EVENT) {
			printf("the game exited with %lu\n", ev.u.ExitProcess.dwExitCode);
			fclose(g_log);
			return 0;
		}
		ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, cont);
	}
	return 0;
}

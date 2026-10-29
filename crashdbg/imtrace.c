/* grimrun2 with breakpoints in IMUSE.DLL: runs the original Grim Fandango under a debugger, starts grimpatch.bin in it (F12), and logs
   every call of the entry points of the sound library with its arguments (a string argument of the Sounds* functions is read), the thread, the
   caller's return address and the guard counter of the library (DAT_100172c0) at the entry. The DLL is loaded at a different address in every
   run: the breakpoints are placed when its load is reported.

   imtrace.log      every call except the polls (ImGetParam / SoundsGetParam / ImHeartbeat)
   imtrace_ring.log the last IMTRACE_RING (default 300000) events, polls included: written when the heartbeat of the library has not run
                    for 5 s (the frozen sound: a leaked guard counter), at most once a minute, and when the game exits.
   IMTRACE_ALL=1 puts the polls in imtrace.log too. IMTRACE_DIR is the directory of the logs (default C:/GOG Games/GRIMDATA).

   usage: imtrace <exe> <dir> <command line> <first F12 after seconds>  (the arguments of grimrun2) */
#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define LOGFILE "C:/GOG Games/GRIMDATA/grimdebug.log"
#define MARKER "running autorun_all.lua"
#define STATUS_WX86_SINGLE_STEP_ 0x4000001E
#define STATUS_WX86_BREAKPOINT_ 0x4000001F
#define COUNTER_RVA 0x172c0u
#define LASTHB_RVA 0x172bcu

typedef struct { DWORD rva; const char *name; int nargs; int strarg; int poll; } Hook;
static const Hook hooks[] = {
	{ 0x4b40, "ImPause", 0, -1, 0 }, { 0x4b60, "ImResume", 0, -1, 0 },
	{ 0x4c80, "ImStartSound", 3, -1, 0 }, { 0x4cd0, "ImStopSound", 1, -1, 0 }, { 0x4ce0, "ImStopAllSounds", 0, -1, 0 },
	{ 0x4d10, "ImSetParam", 3, -1, 0 }, { 0x4d30, "ImGetParam", 2, -1, 1 }, { 0x4d90, "ImFadeParam", 4, -1, 0 },
	{ 0x4e80, "ImStartStream", 3, -1, 0 }, { 0x4ec0, "ImSwitchStream", 3, -1, 0 },
	{ 0x5190, "ImHeartbeat", 0, -1, 2 },
	{ 0x7410, "SoundsLoadStartSound", 3, 0, 0 }, { 0x7470, "SoundsLoadProcessStartSound", 3, 0, 0 }, { 0x7500, "SoundsStopSound", 1, 0, 0 },
	{ 0x7520, "SoundsGetParam", 2, 0, 1 }, { 0x7550, "SoundsSetParam", 3, 0, 0 }, { 0x7580, "SoundsFadeParam", 4, 0, 0 },
	{ 0x4c60, "ImSetGroupVol", 2, -1, 1 },
	{ 0x4d00, "ImGetNextSound", 2, -1, 1 },
	{ 0x4db0, "ImSetHook", 2, -1, 1 },
	{ 0x4dd0, "ImGetHook", 2, -1, 1 },
	{ 0x4de0, "ImSetTrigger", 2, -1, 1 },
	{ 0x4e10, "ImCheckTrigger", 2, -1, 1 },
	{ 0x4e30, "ImClearTrigger", 2, -1, 1 },
	{ 0x4e50, "ImDeferCommand", 2, -1, 1 },
	{ 0x4ef0, "ImProcessStreams", 2, -1, 1 },
	{ 0x4f00, "ImQueryStream", 2, -1, 1 },
	{ 0x4f30, "ImFeedStream", 2, -1, 1 },
	{ 0x4ba0, "ImSave", 2, -1, 1 },
	{ 0x4c10, "ImRestore", 2, -1, 1 },
	{ 0x71c0, "ImSetState", 2, -1, 1 },
	{ 0x71d0, "ImSetSequence", 2, -1, 1 },
	{ 0x71e0, "ImSetCuePoint", 2, -1, 1 },
	{ 0x71f0, "ImSetAttribute", 2, -1, 1 },
	{ 0x7670, "SoundsFillStreamsWhileMusicCritical", 2, -1, 1 },
	{ 0x7790, "SoundsFloodMusicBuffer", 2, -1, 1 },
	{ 0x7810, "SoundsPeriodic", 2, -1, 1 },
	{ 0x75d0, "SoundsIsSoundInUse", 2, -1, 1 },
	{ 0x7640, "SoundsIsSoundPlaying", 2, -1, 1 },
	{ 0x88d0, "SoundStartVoiceStream", 2, -1, 1 },
	{ 0x8970, "SoundStopVoiceStream", 2, -1, 1 },
	{ 0x8990, "SoundGetVoiceTime", 2, -1, 1 },
	{ 0x7830, "SoundsGetMusicPosition", 2, -1, 1 },
	{ 0x2260, "in_SwitchStreamImpl", 2, -1, 3 },
	{ 0x2a00, "in_RefillStreams_2a00", 2, -1, 3 },
	{ 0x49e0, "in_SetGroupVolImpl_49e0", 2, -1, 3 },
	{ 0xa300, "in_Scheduler_a300", 2, -1, 3 },
	{ 0xa6d0, "in_Refill_a6d0", 2, -1, 3 },
	{ 0xa8d0, "in_Pause_a8d0", 2, -1, 3 },
	{ 0xa8f0, "in_Resume_a8f0", 2, -1, 3 },
	{ 0xa910, "in_Save_a910", 2, -1, 3 },
	{ 0xa970, "in_Restore_a970", 2, -1, 3 },
	{ 0xaa00, "in_Volumes_aa00", 2, -1, 3 },
	{ 0xaa40, "in_Heartbeat_aa40", 2, -1, 3 },
	{ 0xabb0, "in_StopSound_abb0", 2, -1, 3 },
	{ 0xac20, "in_NextSound_ac20", 2, -1, 3 },
	{ 0xac60, "in_Query_ac60", 2, -1, 3 },
	{ 0xace0, "in_Query_ace0", 2, -1, 3 },
	{ 0xada0, "in_SetParam_ada0", 2, -1, 3 },
	{ 0xab00, "in_StartSound_ab00", 2, -1, 3 },
};
#define NHOOKS ((int)(sizeof hooks / sizeof hooks[0]))

static DWORD g_pid, g_mainTid;
static HWND g_wnds[16];
static int g_nwnds;
static DWORD g_base;
static BYTE g_orig[NHOOKS];
static struct { DWORD tid; int hook; } g_step[64];
static int g_nstep;
static FILE *g_log;
static char g_dir[512];
static int g_all;
static char (*g_ring)[200];
static long g_ringN, g_ringSize, g_hits[NHOOKS];
static DWORD g_lastDump;
static long long g_us, g_qpc0, g_qpf;
static int g_dumps;
static long g_hbCalls;

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

static void arm(HANDLE proc, int i, int on) {
	BYTE cc = 0xCC;
	SIZE_T n;
	DWORD old;
	void *a = (void *)(ULONG_PTR)(g_base + hooks[i].rva);
	VirtualProtectEx(proc, a, 1, PAGE_EXECUTE_READWRITE, &old);
	WriteProcessMemory(proc, a, on ? &cc : &g_orig[i], 1, &n);
	VirtualProtectEx(proc, a, 1, old, &old);
	FlushInstructionCache(proc, a, 1);
}

static int readdw(HANDLE proc, DWORD addr, DWORD *v) {
	SIZE_T n = 0;
	return ReadProcessMemory(proc, (void *)(ULONG_PTR)addr, v, 4, &n) && n == 4;
}

static void dump_ring(const char *why) {
	char name[600];
	FILE *f;
	long i, n = g_ringN < g_ringSize ? g_ringN : g_ringSize;
	/* (imtrace_ring_1.log is the first freeze: the one with the start of it; the later ones only replace imtrace_ring.log) */
	if (g_dumps++ == 0) snprintf(name, sizeof name, "%s/imtrace_ring_1.log", g_dir);
	else snprintf(name, sizeof name, "%s/imtrace_ring.log", g_dir);
	f = fopen(name, "w");
	if (!f) return;
	fprintf(f, "%s (%ld events kept of %ld)\n", why, n, g_ringN);
	for (i = g_ringN - n; i < g_ringN; i++) fprintf(f, "%s\n", g_ring[i % g_ringSize]);
	fclose(f);
	fprintf(g_log, "RING DUMPED: %s\n", why);
	fflush(g_log);
}

static void hit(HANDLE proc, int h, WOW64_CONTEXT *c, DWORD tid) {
	char line[200], extra[120] = "";
	DWORD args[4] = { 0, 0, 0, 0 }, ret = 0, counter = 0xffffffff;
	int i;
	SIZE_T n = 0;
	g_hits[h]++;
	if (hooks[h].poll == 2) g_hbCalls++;
	readdw(proc, c->Esp, &ret);
	for (i = 0; i < hooks[h].nargs; i++) readdw(proc, c->Esp + 4 + 4 * i, &args[i]);
	if (g_base) readdw(proc, g_base + COUNTER_RVA, &counter);
	if (hooks[h].strarg >= 0 && args[hooks[h].strarg] > 0x10000) {
		char s[48];
		memset(s, 0, sizeof s);
		if (ReadProcessMemory(proc, (void *)(ULONG_PTR)args[hooks[h].strarg], s, 40, &n) && n > 0) {
			for (i = 0; i < 40; i++) if ((unsigned char)s[i] < 32 || (unsigned char)s[i] > 126) { s[i] = 0; break; }
			snprintf(extra, sizeof extra, " \"%s\"", s);
		}
	}
	{
		LARGE_INTEGER q;
		QueryPerformanceCounter(&q);
		g_us = (q.QuadPart - g_qpc0) * 1000000 / g_qpf;
	}
	snprintf(line, sizeof line, "%llu t%lu%s %s(%lx,%lx,%lx,%lx)%s ret=%08lx counter=%lu", g_us, (unsigned long)tid,
	         tid == g_mainTid ? "m" : "", hooks[h].name, args[0], args[1], args[2], args[3], extra, ret, (unsigned long)counter);
	strcpy(g_ring[g_ringN % g_ringSize], line);
	g_ringN++;
	if (!hooks[h].poll || g_all) {
		fprintf(g_log, "%s\n", line);
		fflush(g_log);
	}
}

static void check_freeze(HANDLE proc) {
	DWORD counter, last, now = GetTickCount();
	if (!g_base || g_hbCalls < 20) return;
	if (!readdw(proc, g_base + COUNTER_RVA, &counter) || !readdw(proc, g_base + LASTHB_RVA, &last)) return;
	if (last == 0xffffffffu || last == 0) return;
	/* (the heartbeat stamps timeGetTime(), which is GetTickCount() to the resolution that matters here) */
	if (now - last > 5000 && now - last < 0x7fffffff && now - g_lastDump > 60000) {
		char why[200];
		g_lastDump = now;
		snprintf(why, sizeof why, "FREEZE: heartbeat %lu ms old, counter %lu", (unsigned long)(now - last), (unsigned long)counter);
		dump_ring(why);
	}
}

int main(int argc, char **argv) {
	STARTUPINFO si;
	PROCESS_INFORMATION pi;
	DEBUG_EVENT ev;
	int delay = argc > 4 ? atoi(argv[4]) : 15;
	int tries = 0;
	DWORD start, last = 0;
	const char *d = getenv("IMTRACE_DIR"), *rs = getenv("IMTRACE_RING");
	char name[600];
	snprintf(g_dir, sizeof g_dir, "%s", d ? d : "C:/GOG Games/GRIMDATA");
	g_all = getenv("IMTRACE_ALL") != NULL;
	{
		LARGE_INTEGER q;
		QueryPerformanceFrequency(&q);
		g_qpf = q.QuadPart;
		QueryPerformanceCounter(&q);
		g_qpc0 = q.QuadPart;
	}
	g_ringSize = rs ? atol(rs) : 300000;
	g_ring = calloc(g_ringSize, sizeof *g_ring);
	snprintf(name, sizeof name, "%s/imtrace.log", g_dir);
	g_log = fopen(name, "w");
	memset(&si, 0, sizeof si);
	si.cb = sizeof si;
	if (!CreateProcess(argv[1], argv[3], NULL, NULL, FALSE, DEBUG_ONLY_THIS_PROCESS, NULL, argv[2], &si, &pi)) {
		printf("cannot start\n");
		return 1;
	}
	g_pid = pi.dwProcessId;
	g_mainTid = pi.dwThreadId;
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
		if (!WaitForDebugEvent(&ev, 200)) {
			check_freeze(pi.hProcess);
			continue;
		}
		if (ev.dwDebugEventCode == LOAD_DLL_DEBUG_EVENT) {
			char path[MAX_PATH] = "";
			if (ev.u.LoadDll.hFile) GetFinalPathNameByHandleA(ev.u.LoadDll.hFile, path, sizeof path, 0);
			if (strstr(path, "iMUSE.dll") || strstr(path, "IMUSE.DLL") || strstr(path, "imuse.dll") || strstr(path, "iMUSE.DLL")) {
				int i;
				SIZE_T nn;
				g_base = (DWORD)(ULONG_PTR)ev.u.LoadDll.lpBaseOfDll;
				for (i = 0; i < NHOOKS; i++) {
					BYTE b = 0;
					if (hooks[i].poll == 3 && !getenv("IMTRACE_INTERNALS")) continue; /* (the internal functions slow the game down: IMTRACE_INTERNALS=1) */
					ReadProcessMemory(pi.hProcess, (void *)(ULONG_PTR)(g_base + hooks[i].rva), &b, 1, &nn);
					/* (a second report of the same load: the breakpoint is there already, the byte under it is kept) */
					if (b != 0xCC) g_orig[i] = b;
					arm(pi.hProcess, i, 1);
				}
				fprintf(g_log, "IMUSE.DLL at %08lx, %d breakpoints armed (%s)\n", (unsigned long)g_base, NHOOKS, path);
				fflush(g_log);
			}
			if (ev.u.LoadDll.hFile) CloseHandle(ev.u.LoadDll.hFile);
		}
		if (ev.dwDebugEventCode == EXCEPTION_DEBUG_EVENT) {
			DWORD code = ev.u.Exception.ExceptionRecord.ExceptionCode;
			DWORD addr = (DWORD)(ULONG_PTR)ev.u.Exception.ExceptionRecord.ExceptionAddress;
			if (code == EXCEPTION_BREAKPOINT || code == STATUS_WX86_BREAKPOINT_) {
				int i, h = -1;
				if (g_base)
					for (i = 0; i < NHOOKS; i++)
						if (g_base + hooks[i].rva == addr) h = i;
				if (h >= 0) {
					WOW64_CONTEXT c;
					HANDLE t = OpenThread(THREAD_ALL_ACCESS, FALSE, ev.dwThreadId);
					c.ContextFlags = WOW64_CONTEXT_FULL;
					if (t && Wow64GetThreadContext(t, &c)) {
						hit(pi.hProcess, h, &c, ev.dwThreadId);
						arm(pi.hProcess, h, 0);
						c.Eip = addr;
						c.EFlags |= 0x100;
						Wow64SetThreadContext(t, &c);
						if (g_nstep < 64) { g_step[g_nstep].tid = ev.dwThreadId; g_step[g_nstep].hook = h; g_nstep++; }
					}
					if (t) CloseHandle(t);
				}
				/* (the loader's own breakpoints: go on) */
			} else if (code == EXCEPTION_SINGLE_STEP || code == STATUS_WX86_SINGLE_STEP_) {
				int i;
				for (i = 0; i < g_nstep; i++)
					if (g_step[i].tid == ev.dwThreadId) {
						arm(pi.hProcess, g_step[i].hook, 1);
						g_step[i] = g_step[--g_nstep];
						break;
					}
			} else if (code == EXCEPTION_ACCESS_VIOLATION) {
				printf("access violation at %p, accessing %p\n", ev.u.Exception.ExceptionRecord.ExceptionAddress, (void *)ev.u.Exception.ExceptionRecord.ExceptionInformation[1]);
				fflush(stdout);
				dump_ring("access violation");
				TerminateProcess(pi.hProcess, 1);
				return 2;
			} else {
				cont = DBG_EXCEPTION_NOT_HANDLED;
			}
		}
		if (ev.dwDebugEventCode == EXIT_PROCESS_DEBUG_EVENT) {
			int i;
			printf("the game exited with %lu\n", ev.u.ExitProcess.dwExitCode);
			for (i = 0; i < NHOOKS; i++) fprintf(g_log, "hits %-28s %ld\n", hooks[i].name, g_hits[i]);
			dump_ring("game exited");
			fclose(g_log);
			return 0;
		}
		ContinueDebugEvent(ev.dwProcessId, ev.dwThreadId, cont);
		if (now - g_lastDump > 1000) check_freeze(pi.hProcess);
	}
	return 0;
}

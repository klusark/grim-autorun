/* Replacement for the Grim Fandango Remastered InputDialog helper, which the
 * shipped executable stubs out. Signature matches the stubbed function.
 *
 * It also provides GrimLogDebug/Warning/Error for the original executable. The
 * retail PrintDebug, PrintWarning and PrintError Lua builtins do nothing, and
 * patches/grim/debuglog.py points them at these exports, which append the message to
 * grimdebug.log next to the executable. */

#define _CRT_SECURE_NO_WARNINGS

#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define ID_PROMPT 100
#define ID_EDIT   101

static struct {
	const char *title;
	const char *prompt;
	char *buf;
	int size;
	const char *deflt;
} g;

static INT_PTR CALLBACK dlgProc(HWND h, UINT msg, WPARAM w, LPARAM l) {
	switch (msg) {
	case WM_INITDIALOG:
		SetWindowTextA(h, g.title ? g.title : "");
		SetDlgItemTextA(h, ID_PROMPT, g.prompt ? g.prompt : "");
		SetDlgItemTextA(h, ID_EDIT, g.deflt ? g.deflt : "");
		SetForegroundWindow(h);
		SetFocus(GetDlgItem(h, ID_EDIT));
		SendDlgItemMessageA(h, ID_EDIT, EM_SETSEL, 0, -1);
		return FALSE; /* focus set above */
	case WM_COMMAND:
		if (LOWORD(w) == IDOK) {
			GetDlgItemTextA(h, ID_EDIT, g.buf, g.size);
			EndDialog(h, 1);
			return TRUE;
		}
		if (LOWORD(w) == IDCANCEL) {
			EndDialog(h, 0);
			return TRUE;
		}
		break;
	}
	return FALSE;
}

static WORD *align(WORD *p) {
	return (WORD *)(((ULONG_PTR)p + 3) & ~(ULONG_PTR)3);
}

static WORD *addItem(WORD *p, DWORD style, short x, short y, short cx, short cy, WORD id, WORD cls, const char *text) {
	DLGITEMTEMPLATE *it;
	p = align(p);
	it = (DLGITEMTEMPLATE *)p;
	it->style = WS_CHILD | WS_VISIBLE | style;
	it->dwExtendedStyle = 0;
	it->x = x;
	it->y = y;
	it->cx = cx;
	it->cy = cy;
	it->id = id;
	p = (WORD *)(it + 1);
	*p++ = 0xFFFF;
	*p++ = cls; /* 0x0080 button, 0x0081 edit, 0x0082 static */
	while (*text)
		*p++ = (WORD)(unsigned char)*text++;
	*p++ = 0;
	*p++ = 0; /* no creation data */
	return p;
}

/* int __cdecl InputDialogStub(title, prompt, buf, bufsize, default) */
__declspec(dllexport) int __cdecl InputDialogStub(const char *title, const char *prompt, char *buf, int size, const char *deflt) {
	static BYTE tmpl[1024];
	DLGTEMPLATE *dt = (DLGTEMPLATE *)tmpl;
	WORD *p;
	HWND parent = GetForegroundWindow();

	if (!buf || size < 2)
		return 0;

	g.title = title;
	g.prompt = prompt;
	g.buf = buf;
	g.size = size;
	g.deflt = deflt;

	memset(tmpl, 0, sizeof(tmpl));
	dt->style = DS_MODALFRAME | DS_CENTER | DS_SETFONT | DS_SETFOREGROUND | WS_POPUP | WS_CAPTION | WS_SYSMENU;
	dt->dwExtendedStyle = WS_EX_TOPMOST;
	dt->cdit = 4;
	dt->x = 0;
	dt->y = 0;
	dt->cx = 250;
	dt->cy = 70;
	p = (WORD *)(dt + 1);
	*p++ = 0; /* no menu */
	*p++ = 0; /* default class */
	*p++ = 0; /* title set at init */
	*p++ = 9; /* font size */
	{
		const char *font = "MS Shell Dlg";
		while (*font)
			*p++ = (WORD)(unsigned char)*font++;
		*p++ = 0;
	}
	p = addItem(p, SS_LEFT, 7, 7, 236, 16, ID_PROMPT, 0x0082, "");
	p = addItem(p, WS_BORDER | WS_TABSTOP | ES_AUTOHSCROLL, 7, 25, 236, 14, ID_EDIT, 0x0081, "");
	p = addItem(p, WS_TABSTOP | BS_DEFPUSHBUTTON, 130, 47, 50, 14, IDOK, 0x0080, "OK");
	p = addItem(p, WS_TABSTOP | BS_PUSHBUTTON, 190, 47, 50, 14, IDCANCEL, 0x0080, "Cancel");

	return DialogBoxIndirectParamA(GetModuleHandleA(NULL), dt, parent, dlgProc, 0) == 1;
}

/* Logging for the original executable */

typedef unsigned int LuaObject;
typedef LuaObject (__cdecl *Lua2CFn)(int);
typedef int (__cdecl *LuaIsFn)(LuaObject);
typedef const char *(__cdecl *LuaGetStringFn)(LuaObject);

static void installHook(void);

static CRITICAL_SECTION logLock;
static FILE *logFile;
static DWORD logStart;
static Lua2CFn luaLua2C;
static LuaIsFn luaIsNil;
static LuaIsFn luaIsString;
static LuaGetStringFn luaGetString;

/* A crash of the game leaves grimcrash.dmp (a minidump: exception, modules, stacks) next to the exe, for cleanroom/tools/crashstack.py.
 * The filter lets the crash go on (Windows' own handling and the exit code stay as they were). dbghelp.dll is loaded only then. */
typedef BOOL (WINAPI *MiniDumpWriteDumpFn)(HANDLE, DWORD, HANDLE, int, void *, void *, void *);

typedef struct { DWORD thread; EXCEPTION_POINTERS *pointers; BOOL clientPointers; } CrashInfo;   /* MINIDUMP_EXCEPTION_INFORMATION (packed on x86) */

static LONG WINAPI crashFilter(EXCEPTION_POINTERS *ep) {
	static volatile LONG writing;
	char path[MAX_PATH + 16], *slash;
	HMODULE dbg;
	MiniDumpWriteDumpFn write;
	HANDLE f;
	CrashInfo info;

	if (InterlockedExchange(&writing, 1))   /* (an exception while the dump is written) */
		return EXCEPTION_CONTINUE_SEARCH;
	if (GetModuleFileNameA(NULL, path, MAX_PATH) && (dbg = LoadLibraryA("dbghelp.dll")) != NULL &&
	    (write = (MiniDumpWriteDumpFn)GetProcAddress(dbg, "MiniDumpWriteDump")) != NULL) {
		slash = strrchr(path, '\\');
		strcpy(slash ? slash + 1 : path, "grimcrash.dmp");
		f = CreateFileA(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
		if (f != INVALID_HANDLE_VALUE) {
			info.thread = GetCurrentThreadId();
			info.pointers = ep;
			info.clientPointers = FALSE;
			write(GetCurrentProcess(), GetCurrentProcessId(), f, 0 /* MiniDumpNormal */, &info, NULL, NULL);
			CloseHandle(f);
		}
	}
	InterlockedExchange(&writing, 0);
	return EXCEPTION_CONTINUE_SEARCH;
}

/* The Remastered installs its own unhandled-exception filter (Steam's), which replaces the one above, and the game also ends itself
 * with exit() on some errors. So the exe's imports of ExitProcess and TerminateProcess (of itself) are pointed at functions that write
 * the same dump first, with the stack of the thread that ends the process and a made-up exception record: code EXIT_CODE_MARK, the
 * exit code as its first parameter and the caller as its address. A crash that goes through the game's own filter ends here as well,
 * and the faulting frames are still on that stack. A clean exit writes a dump too (cleanroom/run.py reads it only for a run that
 * did not finish). */
#define EXIT_CODE_MARK 0xE0455849u

static void (WINAPI *realExitProcess)(UINT);
static BOOL (WINAPI *realTerminateProcess)(HANDLE, UINT);

static void dumpExit(UINT code, void *caller) {
	CONTEXT ctx;
	EXCEPTION_RECORD rec;
	EXCEPTION_POINTERS ep;

	memset(&rec, 0, sizeof rec);
	RtlCaptureContext(&ctx);
	rec.ExceptionCode = EXIT_CODE_MARK;
	rec.ExceptionAddress = caller;
	rec.NumberParameters = 1;
	rec.ExceptionInformation[0] = code;
	ep.ExceptionRecord = &rec;
	ep.ContextRecord = &ctx;
	crashFilter(&ep);
}

static void WINAPI hookedExitProcess(UINT code) {
	dumpExit(code, __builtin_return_address(0));
	realExitProcess(code);
}

static BOOL WINAPI hookedTerminateProcess(HANDLE h, UINT code) {
	if (h == GetCurrentProcess() || GetProcessId(h) == GetCurrentProcessId())
		dumpExit(code, __builtin_return_address(0));
	return realTerminateProcess(h, code);
}

static void (__cdecl *realUnderscoreExit)(int);
static void (__cdecl *realAmsgExit)(int);
static void (__cdecl *realCrtExit)(int);
static void (__cdecl *realTerminate)(void);

static void __cdecl hookedUnderscoreExit(int code) {
	dumpExit((UINT)code, __builtin_return_address(0));
	realUnderscoreExit(code);
}

static void __cdecl hookedCrtExit(int code) {
	dumpExit((UINT)code, __builtin_return_address(0));
	realCrtExit(code);
}

static void __cdecl hookedAmsgExit(int code) {
	dumpExit((UINT)code, __builtin_return_address(0));
	realAmsgExit(code);
}

static void __cdecl hookedTerminate(void) {
	dumpExit(0xFFFFFFFFu, __builtin_return_address(0));
	realTerminate();
}

/* Points the exe's import of dll!fn (any dll when dll is NULL) at newFn; the old target is returned. */
static void *hookImport(const char *dll, const char *fn, void *newFn) {
	BYTE *base = (BYTE *)GetModuleHandleA(NULL);
	IMAGE_NT_HEADERS *nt = (IMAGE_NT_HEADERS *)(base + ((IMAGE_DOS_HEADER *)base)->e_lfanew);
	IMAGE_DATA_DIRECTORY dir = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
	IMAGE_IMPORT_DESCRIPTOR *d;

	if (!dir.VirtualAddress)
		return NULL;
	for (d = (IMAGE_IMPORT_DESCRIPTOR *)(base + dir.VirtualAddress); d->Name; d++) {
		IMAGE_THUNK_DATA *names, *slots;
		if (dll && _stricmp((const char *)(base + d->Name), dll) != 0)
			continue;
		names = (IMAGE_THUNK_DATA *)(base + (d->OriginalFirstThunk ? d->OriginalFirstThunk : d->FirstThunk));
		slots = (IMAGE_THUNK_DATA *)(base + d->FirstThunk);
		for (; names->u1.AddressOfData; names++, slots++) {
			DWORD old;
			void *was;
			if (IMAGE_SNAP_BY_ORDINAL(names->u1.Ordinal) ||
			    strcmp((const char *)((IMAGE_IMPORT_BY_NAME *)(base + names->u1.AddressOfData))->Name, fn) != 0)
				continue;
			if (!VirtualProtect(&slots->u1.Function, sizeof(void *), PAGE_READWRITE, &old))
				return NULL;
			was = (void *)slots->u1.Function;
			slots->u1.Function = (ULONG_PTR)newFn;
			VirtualProtect(&slots->u1.Function, sizeof(void *), old, &old);
			return was;
		}
	}
	return NULL;
}

static void logLine(const char *level, const char *text);

/* Every exception of a fatal kind (access violation, illegal instruction...) is told in grimdebug.log when it is raised, before any handler
 * of the game sees it: a game that catches it and goes on or quits leaves no other trace. The tests only read the "CR " lines. */
static LONG WINAPI logException(EXCEPTION_POINTERS *ep) {
	static volatile LONG count;
	EXCEPTION_RECORD *r = ep->ExceptionRecord;
	HMODULE mod = NULL;
	char name[MAX_PATH] = "?", text[MAX_PATH + 160], *slash;

	switch (r->ExceptionCode) {
	case 0xC0000005: case 0xC000001D: case 0xC0000094: case 0xC0000096: case 0xC000008C: case 0xC0000374: case 0xC0000409:
		if (InterlockedIncrement(&count) > 200)
			break;
		if (GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)r->ExceptionAddress, &mod))
			GetModuleFileNameA(mod, name, MAX_PATH);
		slash = strrchr(name, '\\');
		sprintf(text, "exception 0x%08lX at %s+0x%lX%s", (unsigned long)r->ExceptionCode, slash ? slash + 1 : name,
		        (unsigned long)((BYTE *)r->ExceptionAddress - (BYTE *)mod),
		        r->ExceptionCode == 0xC0000005 && r->NumberParameters >= 2 ? (r->ExceptionInformation[0] ? ", writing" : ", reading") : "");
		if (r->ExceptionCode == 0xC0000005 && r->NumberParameters >= 2)
			sprintf(text + strlen(text), " address 0x%lX", (unsigned long)r->ExceptionInformation[1]);
		logLine("EXC", text);
		break;
	}
	return EXCEPTION_CONTINUE_SEARCH;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
	(void)inst;
	(void)reserved;
	if (reason == DLL_PROCESS_ATTACH) {
		InitializeCriticalSection(&logLock);
		SetUnhandledExceptionFilter(crashFilter);
		AddVectoredExceptionHandler(1, logException);
		realExitProcess = (void (WINAPI *)(UINT))hookImport("kernel32.dll", "ExitProcess", (void *)hookedExitProcess);
		realTerminateProcess = (BOOL (WINAPI *)(HANDLE, UINT))hookImport("kernel32.dll", "TerminateProcess", (void *)hookedTerminateProcess);
		realUnderscoreExit = (void (__cdecl *)(int))hookImport(NULL, "_exit", (void *)hookedUnderscoreExit);   /* (the Remastered's: MSVCR100) */
		realCrtExit = (void (__cdecl *)(int))hookImport(NULL, "exit", (void *)hookedCrtExit);
		realAmsgExit = (void (__cdecl *)(int))hookImport(NULL, "_amsg_exit", (void *)hookedAmsgExit);
		realTerminate = (void (__cdecl *)(void))hookImport(NULL, "?terminate@@YAXXZ", (void *)hookedTerminate);
		/* installHook(); not used: it is for the grimrun.lua experiment */
	} else if (reason == DLL_PROCESS_DETACH) {
		if (logFile)
			fclose(logFile);
		DeleteCriticalSection(&logLock);
	}
	return TRUE;
}

static void openLog(void) {
	char path[MAX_PATH + 16];
	char *slash;
	SYSTEMTIME t;

	if (!GetModuleFileNameA(NULL, path, MAX_PATH))
		return;
	slash = strrchr(path, '\\');
	strcpy(slash ? slash + 1 : path, "grimdebug.log");
	logFile = fopen(path, "ab");
	if (!logFile)
		return;
	logStart = GetTickCount();
	GetLocalTime(&t);
	fprintf(logFile, "---- %04d-%02d-%02d %02d:%02d:%02d ----\n", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);
}

static void logLine(const char *level, const char *text) {
	size_t len = strlen(text);

	while (len > 0 && (text[len - 1] == '\n' || text[len - 1] == '\r'))
		len--;

	EnterCriticalSection(&logLock);
	if (!logFile)
		openLog();
	if (logFile) {
		fprintf(logFile, "[%8lu] %-5s %.*s\n", (unsigned long)(GetTickCount() - logStart), level, (int)len, text);
		fflush(logFile);
	}
	LeaveCriticalSection(&logLock);
}

static int resolveLua(void) {
	HMODULE lua;

	if (luaGetString)
		return 1;
	lua = GetModuleHandleA("lua.dll");
	if (!lua)
		return 0;
	luaLua2C = (Lua2CFn)GetProcAddress(lua, "lua_lua2C");
	luaIsNil = (LuaIsFn)GetProcAddress(lua, "lua_isnil");
	luaIsString = (LuaIsFn)GetProcAddress(lua, "lua_isstring");
	luaGetString = (LuaGetStringFn)GetProcAddress(lua, "lua_getstring");
	if (!luaLua2C || !luaIsNil || !luaIsString || !luaGetString) {
		luaGetString = NULL;
		return 0;
	}
	return 1;
}

/* Called as a Lua builtin, so the message is the first Lua argument */
static void logFromLua(const char *level) {
	LuaObject obj;

	if (!resolveLua()) {
		logLine(level, "(lua.dll functions not found)");
		return;
	}
	obj = luaLua2C(1);
	if (luaIsNil(obj))
		logLine(level, "(nil)");
	else if (luaIsString(obj))
		logLine(level, luaGetString(obj));
	else
		logLine(level, "(not a string)");
}

/* Script runner for the original executable. The game calls lua_updatetasks(0) once per
 * frame from its main thread, so that import is replaced by a function that first looks for
 * grimrun.lua next to the executable. When it is there it is renamed to grimrun.lua.ran and
 * run with the game's own lua_dofile, which keeps the Lua state single threaded. Output
 * goes through PrintDebug (grimdebug.log) or whatever the script writes itself. */

typedef int (__cdecl *UpdateTasksFn)(int);
typedef int (__cdecl *DoFileFn)(const char *);

#define POLL_FRAMES 10

static UpdateTasksFn origUpdateTasks;
static int hookAnnounced;

static void scriptPath(char *out, size_t size, const char *name) {
	char *slash;

	if (!GetModuleFileNameA(NULL, out, (DWORD)size)) {
		out[0] = 0;
		return;
	}
	slash = strrchr(out, '\\');
	strcpy(slash ? slash + 1 : out, name);
}

static void runScript(void) {
	char path[MAX_PATH + 16];
	char ran[MAX_PATH + 16];
	char msg[MAX_PATH + 64];
	HMODULE lua;
	DoFileFn doFile;
	int *assumeBinary;
	int saved = 0;
	int result;

	scriptPath(path, sizeof(path) - 8, "grimrun.lua");
	if (!path[0] || GetFileAttributesA(path) == INVALID_FILE_ATTRIBUTES)
		return;
	strcpy(ran, path);
	strcat(ran, ".ran");
	/* If the editor still has the file open the move fails and it is tried again later */
	if (!MoveFileExA(path, ran, MOVEFILE_REPLACE_EXISTING))
		return;

	lua = GetModuleHandleA("lua.dll");
	doFile = lua ? (DoFileFn)GetProcAddress(lua, "lua_dofile") : NULL;
	if (!doFile) {
		logLine("RUN", "lua_dofile not found");
		return;
	}
	/* The game only accepts compiled chunks unless TextAllowed is set in the registry */
	assumeBinary = (int *)GetProcAddress(lua, "lua_assume_binary");
	if (assumeBinary) {
		saved = *assumeBinary;
		*assumeBinary = 0;
	}
	logLine("RUN", "grimrun.lua");
	result = doFile(ran);
	if (assumeBinary)
		*assumeBinary = saved;
	sprintf(msg, "grimrun.lua finished, lua_dofile returned %d", result);
	logLine("RUN", msg);
}

static int __cdecl hookedUpdateTasks(int arg) {
	static int frames;

	if (!hookAnnounced) {
		hookAnnounced = 1;
		logLine("INFO", "script runner active, drop grimrun.lua next to the executable");
	}
	if (++frames >= POLL_FRAMES) {
		frames = 0;
		runScript();
	}
	return origUpdateTasks(arg);
}

/* Replace the lua_updatetasks entry of the executable's import table */
static void installHook(void) {
	BYTE *base = (BYTE *)GetModuleHandleA(NULL);
	IMAGE_DOS_HEADER *dos = (IMAGE_DOS_HEADER *)base;
	IMAGE_NT_HEADERS *nt;
	IMAGE_IMPORT_DESCRIPTOR *imp;
	DWORD rva;

	if (!base || dos->e_magic != IMAGE_DOS_SIGNATURE)
		return;
	nt = (IMAGE_NT_HEADERS *)(base + dos->e_lfanew);
	rva = nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
	if (!rva)
		return;
	for (imp = (IMAGE_IMPORT_DESCRIPTOR *)(base + rva); imp->Name; imp++) {
		IMAGE_THUNK_DATA *names;
		IMAGE_THUNK_DATA *slots;
		int i;

		if (lstrcmpiA((const char *)(base + imp->Name), "lua.dll") != 0)
			continue;
		names = (IMAGE_THUNK_DATA *)(base + (imp->OriginalFirstThunk ? imp->OriginalFirstThunk : imp->FirstThunk));
		slots = (IMAGE_THUNK_DATA *)(base + imp->FirstThunk);
		for (i = 0; names[i].u1.AddressOfData; i++) {
			IMAGE_IMPORT_BY_NAME *name;
			DWORD oldProtect;

			if (names[i].u1.Ordinal & IMAGE_ORDINAL_FLAG)
				continue;
			name = (IMAGE_IMPORT_BY_NAME *)(base + names[i].u1.AddressOfData);
			if (strcmp((const char *)name->Name, "lua_updatetasks") != 0)
				continue;
			if (!VirtualProtect(&slots[i].u1.Function, sizeof(DWORD), PAGE_READWRITE, &oldProtect))
				return;
			origUpdateTasks = (UpdateTasksFn)slots[i].u1.Function;
			slots[i].u1.Function = (DWORD)(ULONG_PTR)hookedUpdateTasks;
			VirtualProtect(&slots[i].u1.Function, sizeof(DWORD), oldProtect, &oldProtect);
			return;
		}
	}
}

/* PrintDebug("CRSNAP:<file>") saves the back buffer to <file> (a 24-bit .bmp, relative to the game folder) with the
 * game's own screenshot code (Render_SaveScreenshotBmp, the Backspace+S debug key), for the tests of grim_tools/cleanroom
 * that look at where a text is drawn. Only on the executable whose bytes are known: v1.01. */
typedef void (__cdecl *SaveScreenshotFn)(const char *);
#define SAVE_SCREENSHOT_ADDR 0x00487340
static const unsigned char saveScreenshotStart[] = { 0x83, 0xec, 0x38, 0xb8, 0x08, 0x00, 0x00, 0x00, 0x56, 0x89, 0x44, 0x24 };

static int snapFromLua(void) {
	LuaObject obj;
	const char *s;

	if (!resolveLua())
		return 0;
	obj = luaLua2C(1);
	if (!luaIsString(obj))
		return 0;
	s = luaGetString(obj);
	if (strncmp(s, "CRSNAP:", 7) != 0)
		return 0;
	if (IsBadReadPtr((const void *)SAVE_SCREENSHOT_ADDR, sizeof(saveScreenshotStart)) ||
	    memcmp((const void *)SAVE_SCREENSHOT_ADDR, saveScreenshotStart, sizeof(saveScreenshotStart)) != 0) {
		logLine("ERROR", "CRSNAP: not the known executable, no screenshot");
		return 1;
	}
	((SaveScreenshotFn)SAVE_SCREENSHOT_ADDR)(s + 7);
	return 1;
}

__declspec(dllexport) void __cdecl GrimLogDebug(void) {
	if (snapFromLua())
		return;
	logFromLua("DEBUG");
}

__declspec(dllexport) void __cdecl GrimLogWarning(void) {
	logFromLua("WARN");
}

__declspec(dllexport) void __cdecl GrimLogError(void) {
	logFromLua("ERROR");
}

/* Called by patches/grim/framelimit.py's stub once per frame of the original executable: holds the game to 60 frames
 * a second (unthrottled it runs at ~850 and some of its per frame arithmetic stops working). */
__declspec(dllexport) void __cdecl GrimFrameLimit(void) {
	static LARGE_INTEGER freq, next;
	static int init;
	static int fps = 60;
	LARGE_INTEGER now;
	if (!init) {
		const char *e = getenv("GRIM_FPS"); /* the frame rate to hold the game to, 60 if not set */
		if (e && atoi(e) > 0 && atoi(e) <= 1000)
			fps = atoi(e);
		timeBeginPeriod(1);
		QueryPerformanceFrequency(&freq);
		QueryPerformanceCounter(&next);
		init = 1;
	}
	for (;;) {
		QueryPerformanceCounter(&now);
		if (now.QuadPart >= next.QuadPart)
			break;
		if ((next.QuadPart - now.QuadPart) * 1000 / freq.QuadPart >= 2)
			Sleep(1);
	}
	next.QuadPart += freq.QuadPart / fps;
	if (now.QuadPart > next.QuadPart + freq.QuadPart / 10)
		next.QuadPart = now.QuadPart; /* long stall (a load): do not run to catch up */
}

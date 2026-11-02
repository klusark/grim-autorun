/* Replacement for the Grim Fandango Remastered InputDialog helper, which the
 * shipped executable stubs out. Signature matches the stubbed function.
 *
 * It also provides GrimLogDebug/Warning/Error for the original executable. The
 * retail PrintDebug, PrintWarning and PrintError Lua builtins do nothing, and
 * patches/grim/debuglog.py points them at these exports, which append the message to
 * grimdebug.log next to the executable. */

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

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved) {
	(void)inst;
	(void)reserved;
	if (reason == DLL_PROCESS_ATTACH) {
		InitializeCriticalSection(&logLock);
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

__declspec(dllexport) void __cdecl GrimLogDebug(void) {
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

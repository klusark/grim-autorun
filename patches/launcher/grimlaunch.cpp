// Starts the original Grim Fandango v1.01 exe (GRIMFANDANGO.EXE), the Grim Fandango Remastered exe (GrimFandango.exe, debuglog only) or
// the Escape from Monkey Island v1.1 exe (Monkey4.exe, or the patched Monkey4_f12.exe) suspended, applies the patches to the process in memory and resumes it. The game is recognized from the exe's bytes.
// No debugger is attached and the exe on disk is not changed.
//
// Grim patches (on by default unless marked):
//   debuglog   PrintDebug / PrintWarning / PrintError append to grimdebug.log next to the exe (patch.dll); also for the Remastered
//              (whose windowed patch keeps its SDL window a window instead of borderless over the desktop)
//   framelimit 60 fps limiter (patch.dll)                                                       (off)
//   simtime    fixed frame time, --simtime-ms N (default 17)
//   config     the game reads its settings from grim.ini next to the exe instead of the registry (patch.dll)
//   windowed   the game runs in a window: its own -w switch is added to the command line unless you pass it (full screen
//              at a high desktop resolution makes its software blitter overrun a heap buffer and crash), and it no longer goes to
//              exclusive full screen at startup (device scan, mode enumeration) or for movies, which blanked the monitor
//
// EMI patches:
//   debuglog   PrintDebug appends its text to grimdebug.log next to the exe (no dll: the release exe drops the text, see patchEmiDebuglog)
//   datadir    the game's data folder ("Install Path" in the registry) is the folder of the exe
//   nocd       no disc check (the movies of the data folder are not looked for)
//   simtime    fixed frame time, --simtime-ms N (default 17)
//   nopause    the game goes on when its window is not the active one (it stops otherwise)
//   offscreen  the window opens 20000 pixels off the screen and never takes the focus (for unattended runs)    (off)
//   f11        F11 runs lua_dofile("grimpatch.bin"), as in Monkey4_f12.exe (skipped when the exe already has it)
//   undo640    puts the desktop mode back first thing, when the exe has the 640x480 compatibility setting (below)
//   windowed   the game's own -w switch is added to the command line unless you pass it
//
// EMI windowed and the GOG install: the GOG installer gives Monkey4.exe the Windows compatibility setting "640x480 DISABLEDWM
// DISABLETHEMES" (AppCompatFlags\Layers, HKCU and HKLM, keyed on the path). It switches the desktop to 640x480 while the process loads,
// the 656x500 window no longer fits, its client area is cut to 640x461, the 640x480 z-buffer cannot be attached to the smaller back
// buffer, and the game stops with "Could not initialize your hardware!". $__COMPAT_LAYER does not remove a registry layer (they are
// merged), so undo640 calls ChangeDisplaySettingsA(NULL, 0) at the exe's entry point instead. The registry is not changed.
//
// config: when grim.ini does not exist yet it is written from the registry (the Grim Fandango v1.0 key under HKLM\SOFTWARE, 32-bit
// view). $GRIM_INI names another file. --no-ini leaves grim.ini alone.
// Format: [Grim] then name=value lines. A string that would read back as a number is quoted; REG_BINARY is written as hex:.
//
// patch.dll is needed by debuglog, framelimit and config. Build it once, next to the exe, with the 32-bit MinGW gcc:
//   cd patches\patch
//   set PATH=C:\msys64\mingw32\bin;%PATH%
//   gcc -shared -O2 -static-libgcc -o <game folder>\patch.dll patch.c config.c -luser32 -lgdi32 -lwinmm
// (config_test.c is a host test of config.c: gcc -DCONFIG_TEST -o ct config_test.c && ./ct)
//
// build (64-bit is fine, the game is a 32-bit process):  g++ -O2 -static -o grimlaunch.exe grimlaunch.cpp
// usage:  grimlaunch [--with a,b|all] [--only a,b] [--skip a,b] [--simtime-ms N] [--no-ini] [--resume-delay MS] <GRIMFANDANGO.exe|Monkey4_f12.exe> [game arguments...]
#include <windows.h>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <initializer_list>
#include <map>
#include <string>
#include <vector>

// import table slots of kernel32's LoadLibraryA and GetProcAddress (v1.01; the Remastered's are set in main, with its load address)
static DWORD g_iatLoadLibraryA = 0x4d7154;
static DWORD g_iatGetProcAddress = 0x4d7158;
static const char DLL_NAME[] = "patch.dll";

static const DWORD ARENA_WANTED = 0x5F000000;   // the code and strings the launcher puts into the process; lua.dll and the system dlls stay clear
static const DWORD ARENA_SIZE = 0x10000;
static DWORD g_arena = ARENA_WANTED;

static const char REG_KEY[] = "SOFTWARE\\LucasArts Entertainment Company LLC\\Grim Fandango\\v1.0";

static HANDLE g_proc;
static DWORD g_next = ARENA_WANTED;
static std::map<std::string, DWORD> g_strings;
static int g_simtimeMs = 17;

[[noreturn]] static void die(const std::string &what) {
	fprintf(stderr, "%s (error %lu)\n", what.c_str(), GetLastError());
	if (g_proc)
		TerminateProcess(g_proc, 1);
	exit(1);
}

static std::string hex(DWORD v) {
	char s[16];
	sprintf(s, "0x%lx", (unsigned long)v);
	return s;
}

static std::string bytes(std::initializer_list<unsigned char> l) {
	return std::string(l.begin(), l.end());
}

static std::string read(DWORD va, size_t n) {
	std::string b(n, '\0');
	if (!ReadProcessMemory(g_proc, (LPCVOID)(ULONG_PTR)va, &b[0], n, nullptr))
		die("ReadProcessMemory " + hex(va));
	return b;
}

static void write(DWORD va, const std::string &data) {
	DWORD old;
	if (!VirtualProtectEx(g_proc, (LPVOID)(ULONG_PTR)va, data.size(), PAGE_EXECUTE_READWRITE, &old))
		die("VirtualProtectEx " + hex(va));
	if (!WriteProcessMemory(g_proc, (LPVOID)(ULONG_PTR)va, data.data(), data.size(), nullptr))
		die("WriteProcessMemory " + hex(va));
	VirtualProtectEx(g_proc, (LPVOID)(ULONG_PTR)va, data.size(), old, &old);
}

static std::string le32(DWORD v) {
	return std::string((const char *)&v, 4);
}

static void expect(DWORD va, const std::string &expected, const char *what) {
	if (read(va, expected.size()) != expected)
		die(std::string("unexpected bytes at ") + what + " (" + hex(va) + "): not the v1.01 exe, or already patched");
}

// the code cave, handed out front to back
static DWORD alloc(size_t size, unsigned align = 16) {
	DWORD va = (g_next + align - 1) & ~(align - 1);
	if (va + size > g_arena + ARENA_SIZE)
		die("the patch memory in the process is full");
	g_next = va + size;
	return va;
}

static DWORD cstring(const std::string &s) {
	auto it = g_strings.find(s);
	if (it != g_strings.end())
		return it->second;
	DWORD va = alloc(s.size() + 1, 1);
	write(va, s + '\0');
	return g_strings[s] = va;
}

// Code that does LoadLibraryA(patch.dll), GetProcAddress(export) and
//   then == 0: jumps to the export, which returns to the caller (a missing export makes the function return 0)
//   then != 0: calls the export, then jumps to `then` (a missing export is skipped)
static DWORD loaderStub(const char *exportName, DWORD then = 0) {
	DWORD dll = cstring(DLL_NAME), fn = cstring(exportName);
	auto build = [&](DWORD va) {
		std::string c;
		c += '\x68'; c += le32(dll);                                // push "patch.dll"
		c += "\xFF\x15"; c += le32(g_iatLoadLibraryA);                // call [LoadLibraryA]
		c += "\x85\xC0\x74"; c += '\0';                              // test eax,eax; jz fail
		size_t jz1 = c.size() - 1;
		c += '\x68'; c += le32(fn); c += '\x50';                     // push export name; push eax
		c += "\xFF\x15"; c += le32(g_iatGetProcAddress);              // call [GetProcAddress]
		c += "\x85\xC0\x74"; c += '\0';                              // test eax,eax; jz fail
		size_t jz2 = c.size() - 1;
		size_t fail;
		if (!then) {
			c += "\xFF\xE0";                                         // jmp eax
			fail = c.size();
			c += "\x33\xC0\xC3";                                     // xor eax,eax; ret
		} else {
			c += "\xFF\xD0";                                         // call eax
			fail = c.size();
			c += '\xE9'; c += le32(then - (va + c.size() + 4));      // jmp then
		}
		c[jz1] = (char)(fail - (jz1 + 1));
		c[jz2] = (char)(fail - (jz2 + 1));
		return c;
	};
	size_t size = build(0).size();
	DWORD va = alloc(size, 1);
	write(va, build(va));
	return va;
}

static std::string jmp(DWORD from, DWORD to) {
	return bytes({0xE9}) + le32(to - (from + 5));
}

// ---- grim.ini from the registry ----

struct RegValue {
	std::string name;
	DWORD type;
	std::vector<unsigned char> data;
};

// the values of one key; a value that is already in vals (same name, not case sensitive) is replaced
static void readValues(HKEY root, const char *path, REGSAM access, std::vector<RegValue> &vals) {
	HKEY key;
	if (RegOpenKeyExA(root, path, 0, KEY_READ | access, &key) != ERROR_SUCCESS)
		return;
	for (DWORD i = 0;; i++) {
		char name[16384];
		DWORD nameLen = sizeof name, type = 0, size = 0;
		if (RegEnumValueA(key, i, name, &nameLen, nullptr, &type, nullptr, &size) != ERROR_SUCCESS)
			break;
		RegValue v;
		v.type = type;
		v.data.resize(size);
		nameLen = sizeof name;
		DWORD got = size;
		if (RegEnumValueA(key, i, name, &nameLen, nullptr, &type, v.data.data(), &got) != ERROR_SUCCESS)
			continue;
		v.data.resize(got);
		v.name = name;
		bool replaced = false;
		for (auto &old : vals)
			if (_stricmp(old.name.c_str(), name) == 0) {
				old = v;
				replaced = true;
			}
		if (!replaced)
			vals.push_back(v);
	}
	RegCloseKey(key);
}

static bool isNumber(const std::string &s) {
	char *end;
	if (s.empty())
		return false;
	strtod(s.c_str(), &end);
	return *end == 0;
}

static std::string encodeString(const std::string &v) {
	// the reader trims the line and reads a number for an unquoted value that strtod accepts; quote everything else that would change
	bool quote = isNumber(v) || v.compare(0, 4, "hex:") == 0 || (!v.empty() && (v[0] == '"' || isspace((unsigned char)v[0]) ||
		isspace((unsigned char)v.back())));
	return quote ? "\"" + v + "\"" : v;
}

static std::string encodeBinary(const std::vector<unsigned char> &d) {
	static const char digits[] = "0123456789abcdef";
	std::string s = "hex:";
	for (unsigned char b : d) {
		s += digits[b >> 4];
		s += digits[b & 15];
	}
	return s;
}

// writes grim.ini from the registry as the game sees it; false if there are no values
static bool writeIniFromRegistry(const std::string &path) {
	std::vector<RegValue> vals;
	readValues(HKEY_LOCAL_MACHINE, REG_KEY, KEY_WOW64_32KEY, vals);
	// the game is not elevated, so its writes to HKLM go to this virtual store, and its reads see those values first
	std::string virtualStore = std::string("Software\\Classes\\VirtualStore\\MACHINE\\SOFTWARE\\WOW6432Node\\") + (REG_KEY + 9);
	readValues(HKEY_CURRENT_USER, virtualStore.c_str(), 0, vals);
	if (vals.empty())
		return false;
	std::string out = "[Grim]\r\n";
	int count = 0;
	for (auto &v : vals) {
		if (_stricmp(v.name.c_str(), "version") == 0)
			continue;
		std::string value;
		if (v.type == REG_SZ || v.type == REG_EXPAND_SZ)
			value = encodeString(std::string((const char *)v.data.data(), strnlen((const char *)v.data.data(), v.data.size())));
		else if (v.type == REG_DWORD && v.data.size() >= 4)
			value = std::to_string((int)(v.data[0] | v.data[1] << 8 | v.data[2] << 16 | (DWORD)v.data[3] << 24));   // the game reads numbers as int
		else
			value = encodeBinary(v.data);                            // REG_BINARY, which is also where the game keeps its numbers
		out += v.name + "=" + value + "\r\n";
		count++;
	}
	FILE *f = fopen(path.c_str(), "wb");
	if (!f)
		die("cannot write " + path);
	fwrite(out.data(), 1, out.size(), f);
	fclose(f);
	printf("wrote %d values from the registry to %s\n", count, path.c_str());
	return true;
}

// ---- the patches ----

enum Game { GRIM = 1, EMI = 2, REMASTERED = 4 };
static Game g_game;
static DWORD g_delta;   // the load address of the exe minus the one it was linked for (the Remastered is not fixed to it)

static void patchDebuglog() {
	// v1.01: the three builtins are the same do-nothing function. The Remastered keeps three functions that read the argument
	// (isnil, isstring, getstring) and drop it. Either way the table slot of the builtin is pointed at the logger.
	static const struct { DWORD slot, builtin; const char *fn; } GRIM_SLOTS[] = {
		{0x004EAB8C, 0x0049DDD0, "GrimLogError"}, {0x004EAB94, 0x0049DDD0, "GrimLogWarning"}, {0x004EAB9C, 0x0049DDD0, "GrimLogDebug"},
	}, REMASTERED_SLOTS[] = {
		{0x005C8A54, 0x0044B7A0, "GrimLogError"}, {0x005C8A5C, 0x0044B760, "GrimLogWarning"}, {0x005C8A64, 0x0044B7E0, "GrimLogDebug"},
	};
	const auto *slots = g_game == REMASTERED ? REMASTERED_SLOTS : GRIM_SLOTS;
	for (int k = 0; k < 3; k++)
		expect(slots[k].slot + g_delta, le32(slots[k].builtin + g_delta), "a logging builtin");
	for (int k = 0; k < 3; k++)
		write(slots[k].slot + g_delta, le32(loaderStub(slots[k].fn)));
}

static void patchFramelimit() {
	static const DWORD CALL_SITE = 0x00401753, TIME_FN = 0x00478140;
	expect(CALL_SITE, bytes({0xE8}) + le32(TIME_FN - (CALL_SITE + 5)), "the frame time call");
	write(CALL_SITE + 1, le32(loaderStub("GrimFrameLimit", TIME_FN) - (CALL_SITE + 5)));
}

static void patchSimtime() {
	expect(0x00401721, bytes({0xa1, 0x48, 0x5a, 0x4f, 0x00}), "the fixed frame time load");
	write(0x00401721, bytes({0xb8}) + le32(g_simtimeMs));
}

static void patchConfig() {
	static const DWORD REG_OPEN = 0x004038A0;
	expect(REG_OPEN, bytes({0x81, 0xec, 0x88, 0x00, 0x00, 0x00}), "Reg_Open");
	write(REG_OPEN, jmp(REG_OPEN, loaderStub("GrimRegOpen")));
}

// The DirectDraw setup (0x4760d0) runs in windowed mode too. To list the display modes it takes exclusive full screen (cooperative level
// 0x51, then 0x11) and only then goes back to DDSCL_NORMAL (8): on a big monitor that blanks the whole screen. Listing the modes does not
// need exclusive access, so both calls ask for DDSCL_NORMAL, as the last one already does.
//
// The device enumeration callback (0x4761b0) tests every DirectDraw device the same way (cooperative level 0x11), which shows as a
// flash of WS_EX_TOPMOST on the window. And the window is first created as a popup the size of the screen and only turned into the
// window afterwards: it is created 640x480 instead, so it never covers the screen.
static void patchWindowed() {
	expect(0x00476111, bytes({0x6a, 0x51}), "DirectDraw cooperative level (first)");    // push 0x51
	expect(0x00476145, bytes({0x6a, 0x11}), "DirectDraw cooperative level (second)");   // push 0x11
	expect(0x00476179, bytes({0x6a, 0x08}), "DirectDraw cooperative level (last)");     // push DDSCL_NORMAL
	expect(0x00476297, bytes({0x6a, 0x11}), "DirectDraw cooperative level (device test)");   // push 0x11
	expect(0x004ac2d5, bytes({0x6a, 0x01, 0xff, 0xd7, 0x50}), "CreateWindowExA height");   // push 1; call GetSystemMetrics; push eax
	expect(0x004ac2da, bytes({0x6a, 0x00, 0xff, 0xd7, 0x50}), "CreateWindowExA width");    // push 0; call GetSystemMetrics; push eax
	// Starting a movie (0x4022a0) switches a windowed game to full screen (0x402930) and the end of the movie (0x4022e6) switches back:
	// the monitor goes black for a moment each time. The jump over the switch is made unconditional, so movies play in the window.
	expect(0x004022ac, bytes({0x74, 0x0f}), "movie switch to full screen");                  // je 0x4022bd
	write(0x004022ac, bytes({0xeb, 0x0f}));                                                  // jmp 0x4022bd
	write(0x00476111, bytes({0x6a, 0x08}));
	write(0x00476145, bytes({0x6a, 0x08}));
	write(0x00476297, bytes({0x6a, 0x08}));
	write(0x004ac2d5, bytes({0x68}) + le32(480));                                            // push 480
	write(0x004ac2da, bytes({0x68}) + le32(640));                                            // push 640
}

// The Remastered's SetFullscreen(int on) (0x4e85b0) makes the SDL window borderless over the desktop; the setting is read from its
// own saved settings. The argument is loaded into esi at 0x4e85c8 (mov esi,[ebp+8]); it is zeroed instead, so the window stays a window.
static void patchRemasteredWindowed() {
	expect(0x004E85C8 + g_delta, bytes({0x8b, 0x75, 0x08}), "SetFullscreen's argument");
	write(0x004E85C8 + g_delta, bytes({0x31, 0xf6, 0x90}));   // xor esi,esi; nop
}

// The Remastered measures time with SDL_GetTicks and, for the GetTime builtin, GetTickCount. Both now read a clock in the process that
// moves only when the game does something with time: SDL_GL_SwapWindow (once a frame) adds the frame time (--simtime-ms, 17), and
// SDL_Delay adds the milliseconds it was asked to wait and returns at once. With vsync off (SDL_GL_SetSwapInterval does nothing), a run
// takes as long as the frames take to draw, and the game sees the same time on every run. The clock is read through the thunks the
// game calls (jmp [import]) because the imports are not bound yet; the swap and delay stubs jump on through the bound import slots.
static void patchRemasteredSimtime() {
	static const DWORD THUNK_GETTICKS = 0x0054CDBE, THUNK_DELAY = 0x0054CDE2, THUNK_SWAP = 0x0054CE12, THUNK_INTERVAL = 0x0054CE18;
	static const DWORD IAT_DELAY = 0x005714A0, IAT_SWAP = 0x00571480, CALL_GETTICKCOUNT = 0x00451434, IAT_GETTICKCOUNT = 0x00571054;
	auto thunk = [&](DWORD iat) { return bytes({0xff, 0x25}) + le32(iat + g_delta); };   // jmp [import]
	expect(THUNK_GETTICKS + g_delta, thunk(0x005714B8), "the SDL_GetTicks thunk");
	expect(THUNK_DELAY + g_delta, thunk(IAT_DELAY), "the SDL_Delay thunk");
	expect(THUNK_SWAP + g_delta, thunk(IAT_SWAP), "the SDL_GL_SwapWindow thunk");
	expect(THUNK_INTERVAL + g_delta, thunk(0x0057147C), "the SDL_GL_SetSwapInterval thunk");
	expect(CALL_GETTICKCOUNT + g_delta, bytes({0xff, 0x15}) + le32(IAT_GETTICKCOUNT + g_delta), "the GetTime builtin's call");
	DWORD clock = alloc(4, 4);
	write(clock, le32(1000));
	DWORD ticks = alloc(6, 1);
	write(ticks, bytes({0xa1}) + le32(clock) + bytes({0xc3}));                                                  // mov eax,[clock]; ret
	DWORD swap = alloc(16, 1);
	write(swap, bytes({0x81, 0x05}) + le32(clock) + le32(g_simtimeMs) + bytes({0xff, 0x25}) + le32(IAT_SWAP + g_delta));   // add [clock],ms; jmp [swap]
	DWORD delay = alloc(16, 1);
	write(delay, bytes({0x8b, 0x44, 0x24, 0x04, 0x01, 0x05}) + le32(clock) + bytes({0xc3}));                  // mov eax,[esp+4]; add [clock],eax; ret
	write(THUNK_GETTICKS + g_delta, jmp(THUNK_GETTICKS + g_delta, ticks));
	write(THUNK_SWAP + g_delta, jmp(THUNK_SWAP + g_delta, swap));
	write(THUNK_DELAY + g_delta, jmp(THUNK_DELAY + g_delta, delay));
	write(THUNK_INTERVAL + g_delta, bytes({0x33, 0xc0, 0xc3}));                                               // xor eax,eax; ret
	write(CALL_GETTICKCOUNT + g_delta, bytes({0xe8}) + le32(ticks - (CALL_GETTICKCOUNT + g_delta + 5)) + bytes({0x90}));   // call ticks; nop
}

// ---- EMI (Monkey4.exe v1.1) ----

// WndProc 0x406700: its WM_KEYDOWN handler range-checks the key at 0x4068cb (cmp eax,0x44 / ja default, 0x406880). The hook sends F11
// (edi = VK_F11) to lua_dofile (0x4420c0, cdecl) before the default path. Monkey4_f12.exe has the same hook in the exe, with its code at
// 0x4abe90 (past .text VirtualSize).
static const DWORD EMI_KEY_CHECK = 0x004068cb, EMI_KEY_BACK = 0x004068d0, EMI_KEY_DEFAULT = 0x00406880, EMI_DOFILE = 0x004420c0;
static const DWORD EMI_F12_CAVE = 0x004abe90;

static void patchEmiF11() {
	std::string at = read(EMI_KEY_CHECK, 5);
	if (at == jmp(EMI_KEY_CHECK, EMI_F12_CAVE)) {
		printf("f11 is already in the exe\n");
		return;
	}
	if (at != bytes({0x83, 0xf8, 0x44, 0x77, 0xb0}))
		die("unexpected bytes at the EMI key check (" + hex(EMI_KEY_CHECK) + "): not the v1.1 Monkey4.exe");
	DWORD file = cstring("grimpatch.bin");
	auto build = [&](DWORD va) {
		std::string c = bytes({0x83, 0xf8, 0x44, 0x77, 0x05});              // cmp eax,0x44; ja +5
		c += jmp(va + c.size(), EMI_KEY_BACK);                               // in range: back to the key handler
		c += bytes({0x83, 0xff, 0x7a, 0x0f, 0x85});                          // cmp edi,VK_F11; jne default
		c += le32(EMI_KEY_DEFAULT - (va + c.size() + 4));
		c += '\x68'; c += le32(file);                                        // push "grimpatch.bin"
		c += '\xe8'; c += le32(EMI_DOFILE - (va + c.size() + 4));            // call lua_dofile
		c += bytes({0x83, 0xc4, 0x04});                                      // add esp,4
		c += jmp(va + c.size(), EMI_KEY_DEFAULT);
		return c;
	};
	DWORD va = alloc(build(0).size());
	write(va, build(va));
	write(EMI_KEY_CHECK, jmp(EMI_KEY_CHECK, va));
}

// The 640x480 compatibility setting (see the top) changes the display mode while the process loads, before the exe's entry point.
// The entry point (0x48a9cd, the CRT start) first calls ChangeDisplaySettingsA(NULL, 0), which puts back the mode in the registry, then
// runs the five bytes it replaced (push ebp; mov ebp,esp; push -1) and continues.
static const DWORD EMI_ENTRY = 0x0048a9cd, EMI_IAT_CHANGEDISPLAYSETTINGSA = 0x004ac330;
static bool g_layer640;

static void patchEmiUndo640() {
	expect(EMI_ENTRY, bytes({0x55, 0x8b, 0xec, 0x6a, 0xff}), "the EMI entry point");
	std::string c = bytes({0x6a, 0x00, 0x6a, 0x00, 0xff, 0x15}) + le32(EMI_IAT_CHANGEDISPLAYSETTINGSA);   // ChangeDisplaySettingsA(0, 0)
	c += bytes({0x55, 0x8b, 0xec, 0x6a, 0xff});
	DWORD va = alloc(c.size() + 5);
	write(va, c + jmp(va + c.size(), EMI_ENTRY + 5));
	write(EMI_ENTRY, jmp(EMI_ENTRY, va));
}

static std::string g_dir;   // the folder of the exe
static const DWORD EMI_IAT_CREATEFILEA = 0x004ac194, EMI_IAT_WRITEFILE = 0x004ac120;

// The release Monkey4.exe builds PrintDebug's text (its argument and "\n", 0x418420..0x4184f0) and frees it without writing it anywhere.
// At 0x4184f2 the text is at [esp+0x18] (null when the argument was not a string); the hook appends it to grimdebug.log next to the
// exe (CreateFileA with FILE_APPEND_DATA, opened on the first call, then WriteFile: not buffered, so a killed game loses nothing), then
// runs the seven bytes it replaced (mov edx,[esp+0x18]; pop edi; cmp edx,ebx) and goes on at 0x4184f9.
static void patchEmiDebuglog() {
	static const DWORD AT = 0x004184f2;
	expect(AT, bytes({0x8b, 0x54, 0x24, 0x18, 0x5f, 0x3b, 0xd3}), "EMI PrintDebug");
	DWORD handle = alloc(4, 4), written = alloc(4, 4), path = cstring(g_dir + "\\grimdebug.log");
	write(handle, le32(0));
	std::string c = bytes({0x8b, 0x54, 0x24, 0x18, 0x85, 0xd2, 0x74, 0x00});   // mov edx,[esp+0x18]; test edx,edx; jz done
	size_t jzDone = c.size() - 1;
	c += bytes({0x60, 0x8b, 0xf2, 0xa1}) + le32(handle);                         // pushad; mov esi,edx; mov eax,[handle]
	c += bytes({0x85, 0xc0, 0x75, 0x00});                                        // test eax,eax; jnz have
	size_t jnzHave = c.size() - 1;
	c += bytes({0x6a, 0x00, 0x68}) + le32(0x80) + bytes({0x6a, 0x04, 0x6a, 0x00, 0x6a, 0x03, 0x6a, 0x04, 0x68}) + le32(path);
	c += bytes({0xff, 0x15}) + le32(EMI_IAT_CREATEFILEA);                         // CreateFileA(path, FILE_APPEND_DATA, share r/w, 0, OPEN_ALWAYS, NORMAL, 0)
	c += bytes({0xa3}) + le32(handle);                                           // mov [handle],eax
	c[jnzHave] = (char)(c.size() - (jnzHave + 1));
	c += bytes({0x8b, 0xfe, 0x33, 0xc0, 0x83, 0xc9, 0xff, 0xf2, 0xae, 0xf7, 0xd1, 0x49});   // ecx = strlen(esi)
	c += bytes({0x6a, 0x00, 0x68}) + le32(written) + bytes({0x51, 0x56, 0xff, 0x35}) + le32(handle);
	c += bytes({0xff, 0x15}) + le32(EMI_IAT_WRITEFILE);                           // WriteFile(handle, text, len, &written, 0)
	c += bytes({0x61});                                                          // popad
	c[jzDone] = (char)(c.size() - (jzDone + 1));
	c += bytes({0x8b, 0x54, 0x24, 0x18, 0x5f, 0x3b, 0xd3});                       // done: the replaced bytes
	DWORD va = alloc(c.size() + 5);
	write(va, c + jmp(va + c.size(), AT + 7));
	write(AT, jmp(AT, va) + bytes({0x90, 0x90}));
}

// The frame time (0x40bfe0, called once a frame from 0x40bea2) is the time since the last frame from the performance counter, unless the
// int its argument points at is above 0: then it is that many milliseconds (* 0.001). The int is loaded at 0x40c04d (mov eax,[esp+0x14];
// xor edx,edx; mov eax,[eax]); it is --simtime-ms instead, so every frame is that long (the result is still capped at 0.125 s).
static void patchEmiSimtime() {
	static const DWORD LOAD = 0x0040c04d;
	expect(LOAD, bytes({0x8b, 0x44, 0x24, 0x14, 0x33, 0xd2, 0x8b, 0x00}), "the EMI frame time");
	write(LOAD, bytes({0xb8}) + le32(g_simtimeMs) + bytes({0x33, 0xd2, 0x90}));   // mov eax,ms; xor edx,edx; nop
}

// The main loop (0x4065ac) pumps the messages and runs a frame (0x407280 -> 0x40be30) only while the byte at 0x4d4ef4 (set when the
// window is activated, 0x4067bd) or the one at 0x4d4ef5 (written nowhere in the exe: it stays 0) is set. A game started behind other
// windows, or one whose window loses the focus, stops at once and waits. The second byte is set to 1, so the game runs either way.
static void patchEmiNopause() {
	static const DWORD RUN_IN_BACKGROUND = 0x004d4ef5;
	expect(0x00407289, bytes({0xa0}) + le32(RUN_IN_BACKGROUND), "the EMI frame check");
	write(RUN_IN_BACKGROUND, bytes({0x01}));
}

// The window out of sight, for runs nobody watches (the clean-room tests). EMI's Direct3D does not start on a desktop of its own
// (cleanroom/tools/offscreen.c: "Please make sure you are not running any application that takes exclusive control of your
// hardware"), so the window stays on the user's desktop, 20000 pixels off the screen, and never takes the focus:
//   CreateWindowExA (0x4064fb) and MoveWindow (0x462f19, the windowed resize) go through stubs that put x and y at -20000;
//   CreateWindowExA also gets WS_EX_NOACTIVATE and WS_EX_TOOLWINDOW (no taskbar button);
//   ShowWindow(SW_SHOWNORMAL) at 0x406501 becomes SW_SHOWNOACTIVATE;
//   SetActiveWindow (0x407243) and SetForegroundWindow (0x46316b) are not called (pop the pushed argument instead).
// Drawing goes on as before (into the back buffer; the copy to the window is clipped away). nopause keeps the game running.
static void patchEmiOffscreen() {
	static const DWORD CREATE = 0x004064fb, SHOW_ARG = 0x00406501, ACTIVATE = 0x00407243, FOREGROUND = 0x0046316b, MOVE = 0x00462f19;
	static const DWORD IAT_CREATEWINDOWEXA = 0x004ac30c, IAT_MOVEWINDOW = 0x004ac33c;
	expect(CREATE, bytes({0xff, 0x15}) + le32(IAT_CREATEWINDOWEXA), "the EMI CreateWindowExA call");
	expect(SHOW_ARG, bytes({0x6a, 0x01, 0x50}), "the EMI ShowWindow argument");
	expect(ACTIVATE, bytes({0xff, 0x15, 0xd8, 0xc2, 0x4a, 0x00}), "the EMI SetActiveWindow call");
	expect(FOREGROUND, bytes({0xff, 0x15, 0x2c, 0xc3, 0x4a, 0x00}), "the EMI SetForegroundWindow call");
	expect(MOVE, bytes({0xff, 0x15}) + le32(IAT_MOVEWINDOW), "the EMI MoveWindow call");
	const DWORD far_ = (DWORD)-20000;
	// CreateWindowExA(exstyle [esp+4], class, name, style, x [esp+0x14], y [esp+0x18], ...)
	std::string c = bytes({0x81, 0x4c, 0x24, 0x04}) + le32(0x08000080);                 // or dword [esp+4],NOACTIVATE|TOOLWINDOW
	c += bytes({0xc7, 0x44, 0x24, 0x14}) + le32(far_) + bytes({0xc7, 0x44, 0x24, 0x18}) + le32(far_);
	c += bytes({0xff, 0x25}) + le32(IAT_CREATEWINDOWEXA);                                 // jmp [CreateWindowExA]
	DWORD create = alloc(c.size());
	write(create, c);
	// MoveWindow(hwnd [esp+4], x [esp+8], y [esp+0xc], w, h, repaint)
	c = bytes({0xc7, 0x44, 0x24, 0x08}) + le32(far_) + bytes({0xc7, 0x44, 0x24, 0x0c}) + le32(far_);
	c += bytes({0xff, 0x25}) + le32(IAT_MOVEWINDOW);
	DWORD move = alloc(c.size());
	write(move, c);
	write(CREATE, bytes({0xe8}) + le32(create - (CREATE + 5)) + bytes({0x90}));
	write(MOVE, bytes({0xe8}) + le32(move - (MOVE + 5)) + bytes({0x90}));
	write(SHOW_ARG, bytes({0x6a, 0x04}));                                                // SW_SHOWNOACTIVATE
	write(ACTIVATE, bytes({0x58, 0x90, 0x90, 0x90, 0x90, 0x90}));                         // pop eax (the window)
	write(FOREGROUND, bytes({0x58, 0x90, 0x90, 0x90, 0x90, 0x90}));
}

// The disc check (0x407380, disc 1 or 2) looks for Movies\intro_a.m4b or Movies\herm.m4b in the data folder and asks for the CD when
// it is missing; it passes at once when the byte at 0x4bfafc is 0 (1 in the exe). The byte is set to 0.
static void patchEmiNocd() {
	static const DWORD CHECK_DISC = 0x004bfafc;
	expect(CHECK_DISC, bytes({0x01}), "the EMI disc check flag");
	write(CHECK_DISC, bytes({0x00}));
}

// The game finds its archives (local.m4b, patch.m4b ...) in the current folder and then in "Install Path" of
// HKLM\SOFTWARE\LucasArts Entertainment Company LLC\Monkey4\Retail, which 0x406140(buffer, size) reads (its only caller, 0x4073c8,
// keeps it at 0x4d4d80). The function copies the folder of the exe instead: a copy of the exe elsewhere (the clean-room tests) reads
// only its own folder, never the install's data. For the install itself this is the same folder.
static void patchEmiDatadir() {
	static const DWORD READ_INSTALL_PATH = 0x00406140;
	expect(READ_INSTALL_PATH, bytes({0x51, 0x8b, 0x44, 0x24, 0x0c, 0x8d, 0x4c, 0x24, 0x0c}), "the EMI Install Path read");
	if (g_dir.size() >= 0x100)
		die("the folder of the exe is too long for the game's buffer");
	DWORD path = cstring(g_dir);
	std::string c = bytes({0x56, 0x57, 0x8b, 0x7c, 0x24, 0x0c, 0xbe}) + le32(path);   // push esi; push edi; mov edi,[esp+0xc]; mov esi,path
	c += bytes({0xac, 0xaa, 0x84, 0xc0, 0x75, 0xfa});                                 // copy: lodsb; stosb; test al,al; jnz copy
	c += bytes({0x5f, 0x5e, 0xb0, 0x01, 0xc3});                                       // pop edi; pop esi; mov al,1; ret
	DWORD va = alloc(c.size());
	write(va, c);
	write(READ_INSTALL_PATH, jmp(READ_INSTALL_PATH, va));
}

static const struct { const char *name; void (*apply)(); bool def; int games; } PATCHES[] = {
	{"debuglog", patchDebuglog, true, GRIM | REMASTERED},
	{"framelimit", patchFramelimit, false, GRIM},
	{"simtime", patchSimtime, true, GRIM},
	{"config", patchConfig, true, GRIM},
	{"debuglog", patchEmiDebuglog, true, EMI},
	{"datadir", patchEmiDatadir, true, EMI},
	{"nocd", patchEmiNocd, true, EMI},
	{"simtime", patchEmiSimtime, true, EMI},
	{"nopause", patchEmiNopause, true, EMI},
	{"offscreen", patchEmiOffscreen, false, EMI},
	{"f11", patchEmiF11, true, EMI},
	{"undo640", patchEmiUndo640, true, EMI},   // only when the exe has the 640x480 compatibility setting
	{"windowed", patchWindowed, true, GRIM},   // and the game's own -w switch, added to its command line in main
	{"windowed", nullptr, true, EMI},          // the -w switch only
	{"windowed", patchRemasteredWindowed, true, REMASTERED},
	{"simtime", patchRemasteredSimtime, true, REMASTERED},
};

// ---- which game: bytes of the exe on disk, read through its section table ----

static bool fileBytes(const std::string &exe, DWORD va, size_t n, std::string &out) {
	FILE *f = fopen(exe.c_str(), "rb");
	if (!f)
		return false;
	std::string d;
	char buf[65536];
	size_t got;
	while ((got = fread(buf, 1, sizeof buf, f)) > 0)
		d.append(buf, got);
	fclose(f);
	if (d.size() < 0x40)
		return false;
	DWORD pe = *(const DWORD *)&d[0x3c];
	if (pe + 0xf8 > d.size() || d.compare(pe, 4, std::string("PE\0\0", 4)))
		return false;
	WORD nsec = *(const WORD *)&d[pe + 6], optSize = *(const WORD *)&d[pe + 0x14];
	DWORD base = *(const DWORD *)&d[pe + 0x34];
	for (WORD s = 0; s < nsec; s++) {
		size_t h = pe + 0x18 + optSize + s * 40;
		if (h + 40 > d.size())
			return false;
		DWORD rva = *(const DWORD *)&d[h + 12], rawSize = *(const DWORD *)&d[h + 16], raw = *(const DWORD *)&d[h + 20];
		if (va >= base + rva && va + n <= base + rva + rawSize && raw + (va - base - rva) + n <= d.size()) {
			out = d.substr(raw + (va - base - rva), n);
			return true;
		}
	}
	return false;
}

// GrimFandango.exe of the Remastered: the PrintDebug builtin (0x44b7e0) and its slot in the builtin table (0x5c8a64)
static const DWORD RM_PRINTDEBUG = 0x0044B7E0, RM_PRINTDEBUG_SLOT = 0x005C8A64;
static const DWORD RM_IAT_LOADLIBRARYA = 0x005710F8, RM_IAT_GETPROCADDRESS = 0x00571034;

static Game detectGame(const std::string &exe) {
	std::string b;
	if (fileBytes(exe, RM_PRINTDEBUG, 9, b) && b == bytes({0x56, 0x6a, 0x01, 0xff, 0x15, 0x50, 0x11, 0x57, 0x00}) &&
	    fileBytes(exe, RM_PRINTDEBUG_SLOT, 4, b) && b == le32(RM_PRINTDEBUG))
		return REMASTERED;
	if (fileBytes(exe, 0x00401721, 5, b) && b == bytes({0xa1, 0x48, 0x5a, 0x4f, 0x00}))
		return GRIM;
	if (fileBytes(exe, EMI_KEY_CHECK, 5, b) && (b == bytes({0x83, 0xf8, 0x44, 0x77, 0xb0}) || b == jmp(EMI_KEY_CHECK, EMI_F12_CAVE)))
		return EMI;
	fprintf(stderr, "%s is neither the Grim Fandango v1.01 exe, the Remastered exe nor the EMI v1.1 exe\n", exe.c_str());
	exit(1);
}

// the Windows compatibility settings for this exe (AppCompatFlags\Layers, value named by the full path), user and machine
static std::string compatLayers(const std::string &exe) {
	static const char KEY[] = "Software\\Microsoft\\Windows NT\\CurrentVersion\\AppCompatFlags\\Layers";
	std::string all;
	for (HKEY root : {HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE})
		for (REGSAM view : {KEY_WOW64_64KEY, KEY_WOW64_32KEY}) {
			HKEY k;
			if (RegOpenKeyExA(root, KEY, 0, KEY_READ | view, &k) != ERROR_SUCCESS)
				continue;
			char v[1024];
			DWORD size = sizeof v - 1, type;
			if (RegQueryValueExA(k, exe.c_str(), nullptr, &type, (BYTE *)v, &size) == ERROR_SUCCESS && type == REG_SZ) {
				v[size] = 0;
				if (all.find(v) == std::string::npos)   // the 32- and 64-bit views can be the same key
					all += std::string(all.empty() ? "" : "; ") + v;
			}
			RegCloseKey(k);
		}
	return all;
}

static std::vector<std::string> split(const std::string &s) {
	std::vector<std::string> out;
	size_t i = 0;
	while (i <= s.size()) {
		size_t j = s.find(',', i);
		if (j == std::string::npos)
			j = s.size();
		if (j > i)
			out.push_back(s.substr(i, j - i));
		i = j + 1;
	}
	return out;
}

static bool has(const std::vector<std::string> &v, const char *name) {
	for (auto &s : v)
		if (s == name)
			return true;
	return false;
}

int main(int argc, char **argv) {
	std::vector<std::string> with, only, skip;
	bool noIni = false;
	int resumeDelay = 0;   // (a debugging aid: time to attach a debugger to the patched, still suspended game)
	int i = 1;
	for (; i < argc && !strncmp(argv[i], "--", 2); i++) {
		std::string o = argv[i];
		if (o == "--no-ini") {
			noIni = true;
			continue;
		}
		if (i + 1 >= argc) {
			fprintf(stderr, "%s needs a value\n", o.c_str());
			return 2;
		}
		if (o == "--with") with = split(argv[++i]);
		else if (o == "--only") only = split(argv[++i]);
		else if (o == "--skip") skip = split(argv[++i]);
		else if (o == "--simtime-ms") g_simtimeMs = atoi(argv[++i]);
		else if (o == "--resume-delay") resumeDelay = atoi(argv[++i]);
		else {
			fprintf(stderr, "unknown option %s\n", o.c_str());
			return 2;
		}
	}
	if (i >= argc) {
		fprintf(stderr, "usage: grimlaunch [--with a,b|all] [--only a,b] [--skip a,b] [--simtime-ms N] [--no-ini] [--resume-delay MS] <GRIMFANDANGO.exe|GrimFandango.exe|Monkey4_f12.exe> [game arguments...]\n");
		return 2;
	}
	for (auto *list : {&with, &only, &skip})
		for (auto &n : *list) {
			bool known = n == "all";
			for (auto &p : PATCHES)
				known |= n == p.name;
			if (!known) {
				fprintf(stderr, "no patch %s (Grim: debuglog, framelimit, simtime, config, windowed; Remastered: debuglog, windowed, simtime; EMI: debuglog, datadir, nocd, simtime, nopause, offscreen, f11, undo640, windowed)\n", n.c_str());
				return 2;
			}
		}

	char exe[MAX_PATH];
	if (!GetFullPathNameA(argv[i], MAX_PATH, exe, nullptr))
		die("GetFullPathName");
	std::string dir = exe;
	dir.erase(dir.find_last_of('\\'));
	g_dir = dir;
	Game game = detectGame(exe);
	g_game = game;
	printf("%s\n", game == GRIM ? "Grim Fandango v1.01" : game == REMASTERED ? "Grim Fandango Remastered" : "Escape from Monkey Island v1.1");
	fflush(stdout);
	auto enabled = [&](const char *name, bool def) {
		bool forGame = false;
		for (auto &p : PATCHES)
			forGame |= !strcmp(p.name, name) && (p.games & game);
		return forGame && (!only.empty() ? has(only, name) : (def || has(with, name) || has(with, "all"))) && !has(skip, name);
	};
	std::string cmd = std::string("\"") + exe + "\"";
	bool hasW = false;
	for (int a = i + 1; a < argc; a++) {
		cmd += std::string(" ") + argv[a];
		hasW |= !strcmp(argv[a], "-w");
	}
	if (enabled("windowed", true) && !hasW && game != REMASTERED)
		cmd += " -w";
	{
		std::string layers = compatLayers(exe), upper = layers;
		for (auto &ch : upper)
			ch = (char)toupper((unsigned char)ch);
		g_layer640 = upper.find("640X480") != std::string::npos;
		if (!layers.empty())
			printf("compatibility settings of the exe: %s\n", layers.c_str());
		if (g_layer640 && game == GRIM)
			fprintf(stderr, "warning: the exe has the 640x480 compatibility setting, which the launcher only undoes for EMI\n");
		if (g_layer640 && game == EMI && (enabled("windowed", true) || hasW) && !enabled("undo640", true))
			fprintf(stderr, "warning: the exe has the 640x480 compatibility setting and undo640 is off: the window will not open "
				"(\"Could not initialize your hardware!\")\n");
	}
	bool needDll = false;
	for (const char *n : {"debuglog", "framelimit", "config"})
		needDll |= game != EMI && enabled(n, strcmp(n, "framelimit") != 0);
	if (needDll && GetFileAttributesA((dir + '\\' + DLL_NAME).c_str()) == INVALID_FILE_ATTRIBUTES)
		fprintf(stderr, "warning: %s is not in %s, the stubs will do nothing\n", DLL_NAME, dir.c_str());
	if (enabled("config", true) && !noIni) {
		const char *env = getenv("GRIM_INI");
		std::string ini = env ? env : dir + "\\grim.ini";
		if (GetFileAttributesA(ini.c_str()) == INVALID_FILE_ATTRIBUTES && !writeIniFromRegistry(ini)) {
			fprintf(stderr, "no %s and no registry values at HKLM\\%s: the game would start with its defaults\n", ini.c_str(), REG_KEY);
			return 1;
		}
	}

	STARTUPINFOA si;
	memset(&si, 0, sizeof si);
	si.cb = sizeof si;
	PROCESS_INFORMATION pi;
	if (!CreateProcessA(nullptr, &cmd[0], nullptr, nullptr, FALSE, CREATE_SUSPENDED, nullptr, dir.c_str(), &si, &pi))
		die("CreateProcess");
	g_proc = pi.hProcess;
	if (game == REMASTERED) {
		// ASLR: the exe was mapped and relocated at a load address of the system's choosing, so the addresses move by the difference
		typedef LONG(NTAPI * QueryInfoFn)(HANDLE, ULONG, PVOID, ULONG, PULONG);
		QueryInfoFn query = (QueryInfoFn)GetProcAddress(GetModuleHandleA("ntdll.dll"), "NtQueryInformationProcess");
		ULONG_PTR peb = 0;
		if (!query || query(g_proc, 26 /* ProcessWow64Information: the 32-bit PEB */, &peb, sizeof peb, nullptr) || !peb)
			die("cannot find the PEB of the game");
		DWORD loaded = *(const DWORD *)read((DWORD)peb + 8, 4).data();   // PEB.ImageBaseAddress
		g_delta = loaded - 0x00400000;
		g_iatLoadLibraryA = RM_IAT_LOADLIBRARYA + g_delta;
		g_iatGetProcAddress = RM_IAT_GETPROCADDRESS + g_delta;
		printf("load address 0x%lx\n", (unsigned long)loaded);
	}
	// (the Remastered can be loaded anywhere, so its arena goes wherever the system puts it)
	LPVOID arena = VirtualAllocEx(g_proc, (LPVOID)(ULONG_PTR)ARENA_WANTED, ARENA_SIZE, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
	if (!arena && game == REMASTERED)
		arena = VirtualAllocEx(g_proc, nullptr, ARENA_SIZE, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
	if (!arena || (ULONG_PTR)arena > 0xFFFF0000)
		die("could not allocate the patch memory in the process");
	g_arena = g_next = (DWORD)(ULONG_PTR)arena;

	for (auto &p : PATCHES)
		if ((p.games & game) && enabled(p.name, p.def) && (p.apply != patchEmiUndo640 || g_layer640)) {
			if (p.apply)
				p.apply();
			printf("applied %s\n", p.name);
		}

	if (resumeDelay) {
		printf("pid %lu, resumed in %d ms\n", pi.dwProcessId, resumeDelay);
		fflush(stdout);
		Sleep(resumeDelay);
	}
	ResumeThread(pi.hThread);
	printf("started pid %lu\n", pi.dwProcessId);
	fflush(stdout);
	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD code = 0;
	GetExitCodeProcess(pi.hProcess, &code);
	printf("exit code %lu\n", code);
	return 0;
}

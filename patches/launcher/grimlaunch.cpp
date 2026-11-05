// Starts the original Grim Fandango v1.01 exe (GRIMFANDANGO.EXE) or Escape from Monkey Island v1.1 exe (Monkey4.exe, or the patched
// Monkey4_f12.exe) suspended, applies the patches to the process in memory and resumes it. The game is recognized from the exe's bytes.
// No debugger is attached and the exe on disk is not changed.
//
// Grim patches (on by default unless marked):
//   debuglog   PrintDebug / PrintWarning / PrintError append to grimdebug.log next to the exe (patch.dll)
//   framelimit 60 fps limiter (patch.dll)                                                       (off)
//   simtime    fixed frame time, --simtime-ms N (default 17)
//   config     the game reads its settings from grim.ini next to the exe instead of the registry (patch.dll)
//   windowed   the game runs in a window: its own -w switch is added to the command line unless you pass it (full screen
//              at a high desktop resolution makes its software blitter overrun a heap buffer and crash), and it no longer goes to
//              exclusive full screen at startup (device scan, mode enumeration) or for movies, which blanked the monitor
//
// EMI patches:
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
// usage:  grimlaunch [--with a,b|all] [--only a,b] [--skip a,b] [--simtime-ms N] [--no-ini] <GRIMFANDANGO.exe|Monkey4_f12.exe> [game arguments...]
#include <windows.h>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <initializer_list>
#include <map>
#include <string>
#include <vector>

// v1.01 import table slots of kernel32's LoadLibraryA and GetProcAddress
static const DWORD IAT_LOADLIBRARYA = 0x4d7154;
static const DWORD IAT_GETPROCADDRESS = 0x4d7158;
static const char DLL_NAME[] = "patch.dll";

static const DWORD ARENA = 0x5F000000;   // the code and strings the launcher puts into the process; lua.dll and the system dlls stay clear
static const DWORD ARENA_SIZE = 0x10000;

static const char REG_KEY[] = "SOFTWARE\\LucasArts Entertainment Company LLC\\Grim Fandango\\v1.0";

static HANDLE g_proc;
static DWORD g_next = ARENA;
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
	if (va + size > ARENA + ARENA_SIZE)
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
		c += "\xFF\x15"; c += le32(IAT_LOADLIBRARYA);                // call [LoadLibraryA]
		c += "\x85\xC0\x74"; c += '\0';                              // test eax,eax; jz fail
		size_t jz1 = c.size() - 1;
		c += '\x68'; c += le32(fn); c += '\x50';                     // push export name; push eax
		c += "\xFF\x15"; c += le32(IAT_GETPROCADDRESS);              // call [GetProcAddress]
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

static void patchDebuglog() {
	static const DWORD NOOP_BUILTIN = 0x0049DDD0;
	static const struct { DWORD slot; const char *fn; } SLOTS[] = {
		{0x004EAB8C, "GrimLogError"}, {0x004EAB94, "GrimLogWarning"}, {0x004EAB9C, "GrimLogDebug"},
	};
	for (auto &s : SLOTS)
		expect(s.slot, le32(NOOP_BUILTIN), "a logging builtin");
	for (auto &s : SLOTS)
		write(s.slot, le32(loaderStub(s.fn)));
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

enum Game { GRIM = 1, EMI = 2 };

static const struct { const char *name; void (*apply)(); bool def; int games; } PATCHES[] = {
	{"debuglog", patchDebuglog, true, GRIM},
	{"framelimit", patchFramelimit, false, GRIM},
	{"simtime", patchSimtime, true, GRIM},
	{"config", patchConfig, true, GRIM},
	{"f11", patchEmiF11, true, EMI},
	{"undo640", patchEmiUndo640, true, EMI},   // only when the exe has the 640x480 compatibility setting
	{"windowed", patchWindowed, true, GRIM},   // and the game's own -w switch, added to its command line in main
	{"windowed", nullptr, true, EMI},          // the -w switch only
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

static Game detectGame(const std::string &exe) {
	std::string b;
	if (fileBytes(exe, 0x00401721, 5, b) && b == bytes({0xa1, 0x48, 0x5a, 0x4f, 0x00}))
		return GRIM;
	if (fileBytes(exe, EMI_KEY_CHECK, 5, b) && (b == bytes({0x83, 0xf8, 0x44, 0x77, 0xb0}) || b == jmp(EMI_KEY_CHECK, EMI_F12_CAVE)))
		return EMI;
	fprintf(stderr, "%s is neither the Grim Fandango v1.01 exe nor the EMI v1.1 exe\n", exe.c_str());
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
		else {
			fprintf(stderr, "unknown option %s\n", o.c_str());
			return 2;
		}
	}
	if (i >= argc) {
		fprintf(stderr, "usage: grimlaunch [--with a,b|all] [--only a,b] [--skip a,b] [--simtime-ms N] [--no-ini] <GRIMFANDANGO.exe|Monkey4_f12.exe> [game arguments...]\n");
		return 2;
	}
	for (auto *list : {&with, &only, &skip})
		for (auto &n : *list) {
			bool known = n == "all";
			for (auto &p : PATCHES)
				known |= n == p.name;
			if (!known) {
				fprintf(stderr, "no patch %s (Grim: debuglog, framelimit, simtime, config, windowed; EMI: f11, undo640, windowed)\n", n.c_str());
				return 2;
			}
		}

	char exe[MAX_PATH];
	if (!GetFullPathNameA(argv[i], MAX_PATH, exe, nullptr))
		die("GetFullPathName");
	std::string dir = exe;
	dir.erase(dir.find_last_of('\\'));
	Game game = detectGame(exe);
	printf("%s\n", game == GRIM ? "Grim Fandango v1.01" : "Escape from Monkey Island v1.1");
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
	if (enabled("windowed", true) && !hasW)
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
		needDll |= enabled(n, strcmp(n, "framelimit") != 0);
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
	if (VirtualAllocEx(g_proc, (LPVOID)(ULONG_PTR)ARENA, ARENA_SIZE, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE) != (LPVOID)(ULONG_PTR)ARENA)
		die("could not allocate the patch memory in the process");

	for (auto &p : PATCHES)
		if ((p.games & game) && enabled(p.name, p.def) && (p.apply != patchEmiUndo640 || g_layer640)) {
			if (p.apply)
				p.apply();
			printf("applied %s\n", p.name);
		}

	ResumeThread(pi.hThread);
	printf("started pid %lu\n", pi.dwProcessId);
	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD code = 0;
	GetExitCodeProcess(pi.hProcess, &code);
	printf("exit code %lu\n", code);
	return 0;
}

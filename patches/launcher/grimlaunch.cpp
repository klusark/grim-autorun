// Starts the original Grim Fandango v1.01 exe suspended, patches the debug log into the process and resumes it. No debugger, no dll.
// The same as `python -m patches.launch`. PrintDebug / PrintWarning / PrintError append their message to grimdebug.log next to the exe.
//
// build (64-bit is fine, the game is a 32-bit process):  g++ -O2 -static -o grimlaunch.exe grimlaunch.cpp
// usage:  grimlaunch <GRIMFANDANGO.exe> [game arguments...]
// stub.h comes from `python -m patches.launcher.gen_stub`; it holds the x86 code of the three logging functions.
#include <windows.h>
#include <cstdio>
#include <cstring>
#include <string>

#include "stub.h"

static const DWORD ARENA = 0x5F000000;   // the code and data the launcher puts into the process; lua.dll and the system dlls stay clear
static const DWORD ARENA_SIZE = 0x1000;
static const DWORD DATA = ARENA + 0x800;  // layout must match gen_stub.py
static const DWORD STUB_STRIDE = 0x200;
static const DWORD NOOP_BUILTIN = 0x0049DDD0;
// function table slots of PrintError, PrintWarning, PrintDebug, and the text each logs in front of the message
static const struct { DWORD slot; const char *prefix; } LOGGERS[] = {
	{0x004EAB8C, "ERROR "}, {0x004EAB94, "WARN  "}, {0x004EAB9C, "DEBUG "},
};

static void die(const char *what) {
	fprintf(stderr, "%s (error %lu)\n", what, GetLastError());
	exit(1);
}

static void put(HANDLE proc, DWORD va, const void *data, size_t n) {
	DWORD old;
	if (!VirtualProtectEx(proc, (LPVOID)(ULONG_PTR)va, n, PAGE_EXECUTE_READWRITE, &old))
		die("VirtualProtectEx");
	if (!WriteProcessMemory(proc, (LPVOID)(ULONG_PTR)va, data, n, nullptr))
		die("WriteProcessMemory");
	VirtualProtectEx(proc, (LPVOID)(ULONG_PTR)va, n, old, &old);
}

int main(int argc, char **argv) {
	if (argc < 2) {
		fprintf(stderr, "usage: grimlaunch <GRIMFANDANGO.exe> [game arguments...]\n");
		return 2;
	}
	char exe[MAX_PATH];
	if (!GetFullPathNameA(argv[1], MAX_PATH, exe, nullptr))
		die("GetFullPathName");
	std::string dir = exe;
	dir.erase(dir.find_last_of('\\'));
	std::string log = dir + '\\' + "grimdebug.log";
	if (log.size() >= 0x120)
		die("log path too long");

	std::string cmd = std::string("\"") + exe + "\"";
	for (int i = 2; i < argc; i++)
		cmd += std::string(" ") + argv[i];

	STARTUPINFOA si = {sizeof si};
	PROCESS_INFORMATION pi;
	if (!CreateProcessA(nullptr, &cmd[0], nullptr, nullptr, FALSE, CREATE_SUSPENDED, nullptr, dir.c_str(), &si, &pi))
		die("CreateProcess");

	// the three builtins must still be the shared no-op, or this is not the exe the stubs were made for
	for (auto &l : LOGGERS) {
		DWORD cur = 0;
		if (!ReadProcessMemory(pi.hProcess, (LPCVOID)(ULONG_PTR)l.slot, &cur, 4, nullptr) || cur != NOOP_BUILTIN) {
			TerminateProcess(pi.hProcess, 1);
			fprintf(stderr, "unexpected builtin at 0x%lx: not the v1.01 exe, or already patched\n", (unsigned long)l.slot);
			return 1;
		}
	}

	if (VirtualAllocEx(pi.hProcess, (LPVOID)(ULONG_PTR)ARENA, ARENA_SIZE, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE) != (LPVOID)(ULONG_PTR)ARENA) {
		TerminateProcess(pi.hProcess, 1);
		die("could not allocate the patch memory in the process");
	}
	char data[0x170] = {};
	memcpy(data, log.c_str(), log.size());
	for (int i = 0; i < 3; i++)
		memcpy(data + 0x120 + i * 0x10, LOGGERS[i].prefix, 6);
	data[0x150] = '\n';
	put(pi.hProcess, DATA, data, sizeof data);
	for (int i = 0; i < 3; i++) {
		DWORD va = ARENA + i * STUB_STRIDE;
		put(pi.hProcess, va, STUBS[i], STUB_SIZE);
		put(pi.hProcess, LOGGERS[i].slot, &va, 4);
	}

	ResumeThread(pi.hThread);
	printf("started pid %lu, logging to %s\n", pi.dwProcessId, log.c_str());
	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD code = 0;
	GetExitCodeProcess(pi.hProcess, &code);
	printf("exit code %lu\n", code);
	return 0;
}

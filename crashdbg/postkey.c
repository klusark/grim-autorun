/* Posts a key (default F11) to the windows of a running game exe without taking the focus.
   postkey <exe name | pid:N> [virtual key in hex, default 7a = F11]  (pid:N: that process only; with a name, the last one found) */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static DWORD g_pid;
static HWND g_wnds[16];
static int g_n;

static BOOL CALLBACK collect(HWND h, LPARAM l) {
	DWORD pid = 0;
	GetWindowThreadProcessId(h, &pid);
	if (pid == g_pid && g_n < 16) g_wnds[g_n++] = h;
	return TRUE;
}

int main(int argc, char **argv) {
	const char *exe = argc > 1 ? argv[1] : "Monkey4.exe";
	UINT vk = argc > 2 ? (UINT)strtoul(argv[2], NULL, 16) : VK_F11;
	UINT scan = MapVirtualKeyA(vk, 0);
	PROCESSENTRY32 pe;
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	int i;
	pe.dwSize = sizeof pe;
	if (strncmp(exe, "pid:", 4) == 0) g_pid = (DWORD)strtoul(exe + 4, NULL, 10);
	else if (Process32First(snap, &pe)) {
		do {
			if (_stricmp(pe.szExeFile, exe) == 0) g_pid = pe.th32ProcessID;
		} while (Process32Next(snap, &pe));
	}
	if (!g_pid) { printf("%s not running\n", exe); return 1; }
	EnumWindows(collect, 0);
	for (i = 0; i < g_n; i++) {
		PostMessage(g_wnds[i], WM_KEYDOWN, vk, 1 | (scan << 16));
		Sleep(50);
		PostMessage(g_wnds[i], WM_KEYUP, vk, 1 | (scan << 16) | 0xC0000000);
	}
	printf("posted %x to %d windows of %s\n", vk, g_n, exe);
	return 0;
}

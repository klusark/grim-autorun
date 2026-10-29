/* Posts F12 to the windows of the running original game without taking the focus (the exe is patched to not need Backspace) */
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>
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

int main(void) {
	PROCESSENTRY32 pe;
	HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	int i;
	pe.dwSize = sizeof pe;
	if (Process32First(snap, &pe)) {
		do {
			if (_stricmp(pe.szExeFile, "GRIMFANDANGO.exe") == 0) g_pid = pe.th32ProcessID;
		} while (Process32Next(snap, &pe));
	}
	if (!g_pid) { printf("game not running\n"); return 1; }
	EnumWindows(collect, 0);
	for (i = 0; i < g_n; i++) {
		PostMessage(g_wnds[i], WM_KEYDOWN, VK_F12, 0x00580001);
		Sleep(50);
		PostMessage(g_wnds[i], WM_KEYUP, VK_F12, 0xC0580001);
	}
	printf("posted\n");
	return 0;
}

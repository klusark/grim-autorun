/* Self-test: opens the dialog, types a string into it and presses OK. */
#include <windows.h>
#include <stdio.h>

typedef int (__cdecl *Fn)(const char *, const char *, char *, int, const char *);

static DWORD WINAPI driver(LPVOID arg) {
	HWND dlg = NULL;
	int i;
	(void)arg;
	for (i = 0; i < 50 && !dlg; i++) {
		Sleep(100);
		dlg = FindWindowA("#32770", "Execute Command");
	}
	if (!dlg) {
		printf("dialog not found\n");
		return 1;
	}
	SetDlgItemTextA(dlg, 101, "print(1+1)");
	PostMessageA(dlg, WM_COMMAND, IDOK, 0);
	return 0;
}

int main(void) {
	HMODULE m = LoadLibraryA("grimdlg.dll");
	char buf[0x65] = { 0 };
	Fn fn;
	int r;
	if (!m) {
		printf("load failed\n");
		return 1;
	}
	fn = (Fn)GetProcAddress(m, "InputDialogStub");
	if (!fn) {
		printf("no export\n");
		return 1;
	}
	CreateThread(NULL, 0, driver, NULL, 0, NULL);
	r = fn("Execute Command", "Enter lua code:", buf, 0x65, "default text");
	printf("returned %d, buffer \"%s\"\n", r, buf);
	return r == 1 ? 0 : 2;
}

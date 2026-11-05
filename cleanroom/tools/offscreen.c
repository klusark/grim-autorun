// Runs a program on a desktop of its own, so its windows do not open on the user's screen (grim_tools/cleanroom: ScummVM and the
// original exes run the tests there). The desktop is in the same window station, so the program still draws normally (OpenGL,
// DirectDraw); nothing of it is visible and it cannot take the focus or the keyboard from the user. The programs it starts are on
// the same desktop. The exit code is the program's.
//
//   offscreen.exe <program> [arguments...]
//
// build: gcc -O2 -o offscreen.exe offscreen.c   (64-bit is fine for 32-bit programs)
#include <windows.h>
#include <stdio.h>
#include <string.h>

static const char DESKTOP[] = "grim_cleanroom";

// one argument as the C runtime reads it back: quoted when it holds a space, a tab or a quote, with the quotes and the backslashes
// in front of them escaped
static void append_arg(char *cmd, size_t size, const char *a) {
	size_t n = strlen(cmd);
	int quote = !*a || strpbrk(a, " \t\"") != NULL;
	if (n && n + 1 < size)
		cmd[n++] = ' ';
	if (quote && n + 1 < size)
		cmd[n++] = '"';
	for (const char *p = a; *p && n + 3 < size; p++) {
		if (*p == '"') {
			size_t k = 0;
			while (p - k > a && p[-1 - (int)k] == '\\')
				k++;
			for (size_t i = 0; i < k + 1 && n + 2 < size; i++)
				cmd[n++] = '\\';
		}
		cmd[n++] = *p;
	}
	if (quote) {
		size_t k = 0;
		while (k < strlen(a) && a[strlen(a) - 1 - k] == '\\')
			k++;
		for (size_t i = 0; i < k && n + 2 < size; i++)
			cmd[n++] = '\\';
		if (n + 1 < size)
			cmd[n++] = '"';
	}
	cmd[n] = 0;
}

int main(int argc, char **argv) {
	if (argc < 2) {
		fprintf(stderr, "usage: offscreen <program> [arguments...]\n");
		return 2;
	}
	HDESK desk = OpenDesktopA(DESKTOP, 0, FALSE, GENERIC_ALL);
	if (!desk)
		desk = CreateDesktopA(DESKTOP, NULL, NULL, 0, GENERIC_ALL, NULL);
	if (!desk) {
		fprintf(stderr, "offscreen: cannot create the desktop (error %lu)\n", GetLastError());
		return 2;
	}
	static char cmd[32768];
	cmd[0] = 0;
	for (int i = 1; i < argc; i++)
		append_arg(cmd, sizeof cmd, argv[i]);
	STARTUPINFOA si;
	memset(&si, 0, sizeof si);
	si.cb = sizeof si;
	si.lpDesktop = (char *)DESKTOP;
	// (the program and what it starts are in a job that ends with this process: whoever kills offscreen.exe, as run.py does with a
	// run that hangs, kills them too)
	HANDLE job = CreateJobObjectA(NULL, NULL);
	JOBOBJECT_EXTENDED_LIMIT_INFORMATION lim;
	memset(&lim, 0, sizeof lim);
	lim.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
	if (job)
		SetInformationJobObject(job, JobObjectExtendedLimitInformation, &lim, sizeof lim);
	PROCESS_INFORMATION pi;
	if (!CreateProcessA(NULL, cmd, NULL, NULL, TRUE, CREATE_SUSPENDED, NULL, NULL, &si, &pi)) {
		fprintf(stderr, "offscreen: cannot start %s (error %lu)\n", argv[1], GetLastError());
		CloseDesktop(desk);
		return 2;
	}
	if (job)
		AssignProcessToJobObject(job, pi.hProcess);
	ResumeThread(pi.hThread);
	CloseHandle(pi.hThread);
	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD code = 0;
	GetExitCodeProcess(pi.hProcess, &code);
	CloseHandle(pi.hProcess);
	CloseDesktop(desk);
	return (int)code;
}

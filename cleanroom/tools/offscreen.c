// Runs a program on a desktop of its own, so its windows do not open on the user's screen (grim_tools/cleanroom: ScummVM and the
// original exes run the tests there). The desktop is in the same window station, so the program still draws normally (OpenGL,
// DirectDraw); nothing of it is visible and it cannot take the focus or the keyboard from the user. The programs it starts are on
// the same desktop. The exit code is the program's.
//
// It is also muted: the audio sessions of the program and of what it starts (the processes of its job) are muted as they open, on
// the default output device, as the volume mixer does; the program does not see it (its own volumes are unchanged). They are
// unmuted when the program ends, so that Windows does not keep the exe muted for a visible run.
//
//   offscreen.exe <program> [arguments...]
//
// build: gcc -O2 -o offscreen.exe offscreen.c -lole32   (64-bit is fine for 32-bit programs)
#define COBJMACROS
#include <initguid.h>
#include <windows.h>
#include <mmdeviceapi.h>
#include <audiopolicy.h>
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

// ---- muting

static HANDLE g_job;
static CRITICAL_SECTION g_lock;
static ISimpleAudioVolume *g_muted[256];
static int g_n_muted;

// mutes a session when its process is in the job (kept, to unmute it at the end)
static void mute_session(IAudioSessionControl *s) {
	IAudioSessionControl2 *s2;
	if (FAILED(IAudioSessionControl_QueryInterface(s, &IID_IAudioSessionControl2, (void **)&s2)))
		return;
	DWORD pid = 0;
	IAudioSessionControl2_GetProcessId(s2, &pid);
	IAudioSessionControl2_Release(s2);
	if (!pid)
		return;
	HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
	if (!h)
		return;
	BOOL in = FALSE;
	IsProcessInJob(h, g_job, &in);
	CloseHandle(h);
	if (!in)
		return;
	ISimpleAudioVolume *v;
	if (FAILED(IAudioSessionControl_QueryInterface(s, &IID_ISimpleAudioVolume, (void **)&v)))
		return;
	ISimpleAudioVolume_SetMute(v, TRUE, NULL);
	fprintf(stderr, "offscreen: process %lu muted\n", pid);
	EnterCriticalSection(&g_lock);
	if (g_n_muted < (int)(sizeof g_muted / sizeof g_muted[0]))
		g_muted[g_n_muted++] = v;
	else
		ISimpleAudioVolume_Release(v);
	LeaveCriticalSection(&g_lock);
}

// (IAudioSessionNotification: a session opened on the device)
static HRESULT STDMETHODCALLTYPE n_query(IAudioSessionNotification *self, REFIID riid, void **out) {
	if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IAudioSessionNotification)) {
		*out = self;
		return S_OK;
	}
	*out = NULL;
	return E_NOINTERFACE;
}
static ULONG STDMETHODCALLTYPE n_addref(IAudioSessionNotification *self) { (void)self; return 1; }
static ULONG STDMETHODCALLTYPE n_release(IAudioSessionNotification *self) { (void)self; return 1; }
static HRESULT STDMETHODCALLTYPE n_created(IAudioSessionNotification *self, IAudioSessionControl *s) {
	(void)self;
	mute_session(s);
	return S_OK;
}
static IAudioSessionNotificationVtbl g_nvtbl = { n_query, n_addref, n_release, n_created };
static IAudioSessionNotification g_notify = { &g_nvtbl };
static IAudioSessionManager2 *g_mgr;

// before the program starts: be told of every new session (the sessions are enumerated once first: Windows sends the
// notifications only after that)
static void mute_start(HANDLE job) {
	g_job = job;
	InitializeCriticalSection(&g_lock);
	if (!job || FAILED(CoInitializeEx(NULL, COINIT_MULTITHREADED)))
		return;
	IMMDeviceEnumerator *e = NULL;
	IMMDevice *dev = NULL;
	if (FAILED(CoCreateInstance(&CLSID_MMDeviceEnumerator, NULL, CLSCTX_ALL, &IID_IMMDeviceEnumerator, (void **)&e)))
		return;
	if (SUCCEEDED(IMMDeviceEnumerator_GetDefaultAudioEndpoint(e, eRender, eMultimedia, &dev))) {
		if (SUCCEEDED(IMMDevice_Activate(dev, &IID_IAudioSessionManager2, CLSCTX_ALL, NULL, (void **)&g_mgr))) {
			IAudioSessionEnumerator *list;
			if (SUCCEEDED(IAudioSessionManager2_GetSessionEnumerator(g_mgr, &list)))
				IAudioSessionEnumerator_Release(list);
			if (FAILED(IAudioSessionManager2_RegisterSessionNotification(g_mgr, &g_notify))) {
				IAudioSessionManager2_Release(g_mgr);
				g_mgr = NULL;
			}
		}
		IMMDevice_Release(dev);
	}
	IMMDeviceEnumerator_Release(e);
}

// after the program ended: no more notifications, and the sessions muted unmuted
static void mute_end(void) {
	if (g_mgr) {
		IAudioSessionManager2_UnregisterSessionNotification(g_mgr, &g_notify);
		IAudioSessionManager2_Release(g_mgr);
		g_mgr = NULL;
	}
	EnterCriticalSection(&g_lock);
	for (int i = 0; i < g_n_muted; i++) {
		ISimpleAudioVolume_SetMute(g_muted[i], FALSE, NULL);
		ISimpleAudioVolume_Release(g_muted[i]);
	}
	g_n_muted = 0;
	LeaveCriticalSection(&g_lock);
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
	mute_start(job);
	ResumeThread(pi.hThread);
	CloseHandle(pi.hThread);
	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD code = 0;
	GetExitCodeProcess(pi.hProcess, &code);
	CloseHandle(pi.hProcess);
	mute_end();
	CloseDesktop(desk);
	return (int)code;
}

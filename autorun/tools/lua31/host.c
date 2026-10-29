/* A host for the Lua 3.1 of Grim Fandango (LUA.DLL of the game, 32 bit): runs scripts with the standard libraries, plus
   PrintDebug / print. Usage: lua31 <lua.dll> script.lua [script2.lua ...]  (the scripts run in order in one state) */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned int lua_Object;
typedef void (*lua_CFunction)(void);
static void (*lua_open_)(void);
static int (*lua_dostring_)(const char *);
static int (*lua_dofile_)(const char *);
static lua_Object (*lua_lua2C_)(int);
static const char *(*lua_getstring_)(lua_Object);
static int (*lua_isstring_)(lua_Object);
static void (*lua_pushCclosure_)(lua_CFunction, int);
static void (*lua_setglobal_)(const char *);
static void (*lua_strlibopen_)(void);
static void (*lua_mathlibopen_)(void);
static void (*lua_iolibopen_)(void);
static void (*lua_seterrormethod_)(void);


/* The game files: the archives (.LAB) of the game directory (LUA31_DATA, default the GOG one) are searched for a file that is not on the
   disk, the last (DATA006) first as the game does, so that readfrom("ha.set") finds the set files as in the game. */
typedef struct { char name[64]; int arch; unsigned start, size; } LabEntry;
static LabEntry *g_labs;
static int g_nlabs;
static char g_archives[16][512];
static int g_narch;

static void lab_add(const char *path, int arch) {
	FILE *f = fopen(path, "rb");
	unsigned h[4], i;
	unsigned char *ent;
	char *strs;
	if (!f) return;
	if (fread(h, 4, 4, f) != 4 || memcmp(h, "LABN", 4)) { fclose(f); return; }
	ent = (unsigned char *)malloc(h[2] * 16);
	strs = (char *)malloc(h[3] + 1);
	fread(ent, 16, h[2], f);
	fread(strs, 1, h[3], f);
	strs[h[3]] = 0;
	g_labs = (LabEntry *)realloc(g_labs, (g_nlabs + h[2]) * sizeof(LabEntry));
	for (i = 0; i < h[2]; i++) {
		unsigned off = *(unsigned *)(ent + i * 16), j;
		LabEntry *e = &g_labs[g_nlabs++];
		const char *n = strs + off;
		for (j = 0; j < 63 && n[j]; j++) e->name[j] = (char)((n[j] >= 'A' && n[j] <= 'Z') ? n[j] + 32 : n[j]);
		e->name[j] = 0;
		e->arch = arch;
		e->start = *(unsigned *)(ent + i * 16 + 4);
		e->size = *(unsigned *)(ent + i * 16 + 8);
	}
	free(ent); free(strs); fclose(f);
}

static void lab_init(void) {
	const char *dir = getenv("LUA31_DATA");
	int i;
	char path[600];
	if (!dir) dir = "C:/GOG Games/GRIMDATA";
	/* (later archives first: DATA006 holds the patches of the others) */
	for (i = 9; i >= 0; i--) {
		sprintf(path, "%s/DATA%03d.LAB", dir, i);
		if (fopen(path, "rb")) {
			strcpy(g_archives[g_narch], path);
			lab_add(path, g_narch++);
		}
	}
}

typedef struct { FILE *f; unsigned char *buf; unsigned size, pos; } HFile;

static HFile *lab_open(const char *name) {
	char low[64];
	int i, j;
	const char *base = name, *p;
	for (p = name; *p; p++) if (*p == 47 || *p == 92) base = p + 1;
	for (j = 0; j < 63 && base[j]; j++) low[j] = (char)((base[j] >= 'A' && base[j] <= 'Z') ? base[j] + 32 : base[j]);
	low[j] = 0;
	for (i = 0; i < g_nlabs; i++) {
		if (!strcmp(g_labs[i].name, low)) {
			FILE *f = fopen(g_archives[g_labs[i].arch], "rb");
			HFile *h;
			if (!f) return NULL;
			h = (HFile *)calloc(1, sizeof(HFile));
			h->buf = (unsigned char *)malloc(g_labs[i].size + 1);
			fseek(f, (long)g_labs[i].start, SEEK_SET);
			fread(h->buf, 1, g_labs[i].size, f);
			fclose(f);
			h->size = g_labs[i].size;
			return h;
		}
	}
	return NULL;
}

static int g_trace;
static char g_msg[512];

/* the table of services the DLL asks of its host (found in LUA.DLL: [0x1002beb8]): +0x18 assert, +0x20 malloc, +0x24 free,
   +0x28 realloc, +0x30 fopen, +0x34 fclose, +0x38 read(file, buf, n), +0x48 rewind(file); the other slots are traps that say which one it was */
static void *h_malloc(unsigned n, const char *f, int l) { return malloc(n ? n : 1); }
static void h_free(void *p) { free(p); }
static void *h_realloc(void *p, unsigned n, const char *f, int l) { return realloc(p, n ? n : 1); }
static void h_assert(const char *m, const char *f, int l) { fprintf(stderr, "LUA ASSERT %s at %s:%d\n", m, f, l); exit(3); }
static void *h_fopen(const char *n, const char *m) {
	FILE *f = fopen(n, m);
	HFile *h;
	if (f) {
		h = (HFile *)calloc(1, sizeof(HFile));
		h->f = f;
		return h;
	}
	if (m[0] == 'r') return lab_open(n);
	return NULL;
}
static int h_fclose(void *p) {
	HFile *h = (HFile *)p;
	int r = 0;
	if (h->f) r = fclose(h->f);
	free(h->buf);
	free(h);
	return r;
}
static void h_rewind(void *p) {
	HFile *h = (HFile *)p;
	if (h->f) rewind(h->f); else h->pos = 0;
}
static int h_read(void *p, void *b, int n) {
	HFile *h = (HFile *)p;
	if (h->f) return (int)fread(b, 1, n, h->f);
	if (h->pos + n > h->size) n = (int)(h->size - h->pos);
	memcpy(b, h->buf + h->pos, n);
	h->pos += n;
	return n;
}
#define TRAP(i) static void trap##i(void) { fprintf(stderr, "LUA host slot %d (0x%x) called\n", i, i * 4); exit(4); }
TRAP(0) TRAP(1) TRAP(2) TRAP(3) TRAP(4) TRAP(5) TRAP(7) TRAP(11) TRAP(15) TRAP(16) TRAP(17) TRAP(18)
static void *g_host[24];
static void *g_out[16];
static int (*lua_Initialize_)(void *, void *);
#define TRACE(msg) do { if (g_trace) { fputs(msg, stderr); fputc(10, stderr); fflush(stderr); } } while (0)

static void c_alert(void) {
	lua_Object o = lua_lua2C_(1);
	if (o && lua_isstring_(o)) fprintf(stderr, "LUA ERROR: %s\n", lua_getstring_(o));
}

static void c_print(void) {
	int i;
	for (i = 1; ; i++) {
		lua_Object o = lua_lua2C_(i);
		if (!o) break;
		if (lua_isstring_(o)) fputs(lua_getstring_(o), stdout); else fputs("?", stdout);
	}
	fflush(stdout);
}

#define GET(name) do { name##_ = (void *)GetProcAddress(dll, #name); if (!name##_) { fprintf(stderr, "no %s\n", #name); return 2; } } while (0)

int main(int argc, char **argv) {
	HMODULE dll;
	int i;
	g_trace = getenv("LUA31_TRACE") != NULL;
	lab_init();
	if (argc < 3) { fprintf(stderr, "usage: lua31 <lua.dll> script.lua...\n"); return 2; }
	dll = LoadLibraryA(argv[1]);
	if (!dll) { fprintf(stderr, "cannot load %s\n", argv[1]); return 2; }
	TRACE("loaded");
	GET(lua_open); GET(lua_dostring); GET(lua_dofile); GET(lua_lua2C); GET(lua_getstring); GET(lua_isstring);
	GET(lua_pushCclosure); GET(lua_setglobal); GET(lua_strlibopen); GET(lua_mathlibopen); GET(lua_iolibopen);
	GET(lua_Initialize); GET(lua_seterrormethod);
	g_host[0] = trap0; g_host[1] = trap1; g_host[2] = trap2; g_host[3] = trap3; g_host[4] = trap4; g_host[5] = trap5;
	g_host[6] = h_assert; g_host[7] = trap7; g_host[8] = h_malloc; g_host[9] = h_free; g_host[10] = h_realloc;
	g_host[11] = trap11; g_host[12] = h_fopen; g_host[13] = h_fclose; g_host[14] = h_read; g_host[15] = trap15;
	g_host[16] = trap16; g_host[17] = trap17; g_host[18] = h_rewind;
	lua_Initialize_(g_host, g_out);
	TRACE("open");
	lua_open_();
	TRACE("strlib");
	lua_strlibopen_();
	TRACE("mathlib");
	lua_mathlibopen_();
	TRACE("iolib");
	lua_iolibopen_();
	TRACE("globals");
	lua_pushCclosure_(c_print, 0); lua_setglobal_("PrintDebug");
	lua_pushCclosure_(c_print, 0); lua_setglobal_("print");
	lua_pushCclosure_(c_alert, 0); lua_setglobal_("_ALERT");
	lua_pushCclosure_(c_alert, 0); lua_seterrormethod_();
	for (i = 2; i < argc; i++) {
		int r;
		TRACE(argv[i]);
		if (argv[i][0] == 61) {
			r = lua_dostring_(argv[i] + 1);
		} else {
			FILE *fp = fopen(argv[i], "rb");
			long sz;
			char *buf;
			if (!fp) { fprintf(stderr, "cannot open %s\n", argv[i]); return 2; }
			fseek(fp, 0, SEEK_END); sz = ftell(fp); fseek(fp, 0, SEEK_SET);
			buf = (char *)malloc(sz + 1);
			fread(buf, 1, sz, fp); buf[sz] = 0; fclose(fp);
			r = lua_dostring_(buf);
			free(buf);
		}
		if (r) { fprintf(stderr, "error %d in %s\n", r, argv[i]); return 1; }
	}
	return 0;
}

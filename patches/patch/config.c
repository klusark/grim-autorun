/* grim.ini instead of the registry for the original Grim Fandango v1.01 executable.
 *
 * The executable keeps its settings in HKLM\SOFTWARE\...\Grim Fandango\v1.0 and reads and writes them only through a small wrapper
 * (W32Util/wuregistry: Reg_Open, Reg_GetInt, ...). patches/grim/config.py sends Reg_Open to GrimRegOpen; that loads grim.ini
 * from the folder of the executable (or $GRIM_INI) and overwrites the entry of every other wrapper function with a jump to the
 * functions below, which work on the file. Nothing is read from or written to the registry.
 *
 * File format, one `name=value` per line; [sections] and lines starting with ; or # are ignored; names are not case sensitive:
 *   name=text               a string (the registry's REG_SZ)
 *   name="3"                a string that looks like a number
 *   name=3, name=1.5        a number (what the game writes with SetInt / SetFloat; REG_BINARY in the registry)
 *   name=hex:0a0b0c         bytes (SetBinary), and what a number of 4 bytes may look like
 * Lua's ReadRegistryValue gets a number back for numbers and a string for strings, as it did from the registry.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#ifdef CONFIG_TEST
#define EXPORT
#else
#include <windows.h>
#define EXPORT __declspec(dllexport)
#endif

typedef struct { char *name, *value; } Entry;
static Entry *entries;
static int count, cap, opened;
static char iniPath[1024];

static void trim(char *s) {
	char *a = s, *e;
	while (isspace((unsigned char)*a))
		a++;
	memmove(s, a, strlen(a) + 1);
	e = s + strlen(s);
	while (e > s && isspace((unsigned char)e[-1]))
		*--e = 0;
}

static Entry *find(const char *name) {
	int i;
	for (i = 0; i < count; i++)
		if (!_stricmp(entries[i].name, name))
			return &entries[i];
	return NULL;
}

static void store(const char *name, const char *value) {
	Entry *e = find(name);
	if (e) {
		free(e->value);
	} else {
		if (count == cap) {
			cap = cap ? cap * 2 : 32;
			entries = (Entry *)realloc(entries, cap * sizeof *entries);
		}
		e = &entries[count++];
		e->name = _strdup(name);
	}
	e->value = _strdup(value);
}

static void save(void) {
	FILE *f = fopen(iniPath, "wb");
	int i;
	if (!f)
		return;
	fputs("[Grim]\r\n", f);
	for (i = 0; i < count; i++)
		fprintf(f, "%s=%s\r\n", entries[i].name, entries[i].value);
	fclose(f);
}

static void load(void) {
	FILE *f = fopen(iniPath, "rb");
	char line[2048];
	count = 0;
	if (!f)
		return;
	while (fgets(line, sizeof line, f)) {
		char *eq;
		trim(line);
		if (!*line || *line == ';' || *line == '#' || *line == '[')
			continue;
		eq = strchr(line, '=');
		if (!eq)
			continue;
		*eq = 0;
		trim(line);
		trim(eq + 1);
		if (*line)
			store(line, eq + 1);
	}
	fclose(f);
}

enum { T_NONE = 0, T_STRING = 1, T_NUMBER = 3 };   /* the registry's types: REG_SZ and REG_BINARY */

static int isNumber(const char *s) {
	char *end;
	if (!*s)
		return 0;
	strtod(s, &end);
	return !*end;
}

static int isQuoted(const char *s) {
	size_t n = strlen(s);
	return n >= 2 && s[0] == '"' && s[n - 1] == '"';
}

static int isHex(const char *s) {
	return !strncmp(s, "hex:", 4);
}

static int typeOf(const char *value) {
	if (isQuoted(value))
		return T_STRING;
	return isHex(value) || isNumber(value) ? T_NUMBER : T_STRING;
}

/* the text of a string value, without the quotes */
static void textOf(const char *value, char *out, int size) {
	size_t n = strlen(value);
	if (isQuoted(value)) {
		value++;
		n -= 2;
	}
	if ((int)n > size - 1)
		n = size - 1;
	memcpy(out, value, n);
	out[n] = 0;
}

static int hexByte(const char *p) {
	int v = 0, i;
	for (i = 0; i < 2; i++) {
		int c = tolower((unsigned char)p[i]);
		if (c >= '0' && c <= '9')
			v = v * 16 + c - '0';
		else if (c >= 'a' && c <= 'f')
			v = v * 16 + c - 'a' + 10;
		else
			return -1;
	}
	return v;
}

/* the bytes of a hex: value, -1 if it is not valid */
static int hexBytes(const char *value, unsigned char *out, int size) {
	int n = 0;
	const char *p = value + 4;
	while (p[0] && p[1]) {
		int b = hexByte(p);
		if (b < 0 || n >= size)
			return -1;
		out[n++] = (unsigned char)b;
		p += 2;
	}
	return *p ? -1 : n;
}

static Entry *lookup(const char *name) {
	return opened ? find(name) : NULL;
}

/* ---- the wrapper functions (cdecl, as in the executable) ---- */

int cfg_HasValue(const char *name) {
	return opened ? find(name) != NULL : 1;   /* before Reg_Open the original said yes to everything */
}

int cfg_GetInt(const char *name, int def) {
	Entry *e = lookup(name);
	unsigned char b[4];
	if (!e)
		return def;
	if (isHex(e->value))
		return hexBytes(e->value, b, 4) == 4 ? (int)(b[0] | b[1] << 8 | b[2] << 16 | (unsigned)b[3] << 24) : def;
	return typeOf(e->value) == T_NUMBER ? (int)strtod(e->value, NULL) : def;
}

float cfg_GetFloat(const char *name, float def) {
	Entry *e = lookup(name);
	unsigned char b[4];
	float f;
	if (!e)
		return def;
	if (isHex(e->value)) {
		if (hexBytes(e->value, b, 4) != 4)
			return def;
		memcpy(&f, b, 4);
		return f;
	}
	return typeOf(e->value) == T_NUMBER ? (float)strtod(e->value, NULL) : def;
}

int cfg_GetString(const char *name, char *buf, int size, const char *def) {
	Entry *e = lookup(name);
	(void)def;
	if (!e || size < 1)
		return 0;   /* like the original, the buffer is left alone when the value does not exist */
	textOf(e->value, buf, size);
	return 1;
}

int cfg_GetBinary(const char *name, void *data, int size) {
	Entry *e = lookup(name);
	return e && isHex(e->value) && hexBytes(e->value, (unsigned char *)data, size) >= 0;
}

int cfg_GetValueType(const char *name) {
	Entry *e = lookup(name);
	return e ? typeOf(e->value) : T_NONE;
}

int cfg_SetInt(const char *name, int value) {
	char s[32];
	sprintf(s, "%d", value);
	store(name, s);
	save();
	return 1;
}

int cfg_SetFloat(const char *name, float value) {
	char s[32];
	sprintf(s, "%.9g", (double)value);
	store(name, s);
	save();
	return 1;
}

void cfg_SetString(const char *name, const char *value) {
	size_t n = strlen(value);
	char *s = (char *)malloc(n + 3);
	/* a string that would be read back as something else is quoted */
	if (isNumber(value) || isHex(value) || *value == '"' || isspace((unsigned char)*value) || (n && isspace((unsigned char)value[n - 1])))
		sprintf(s, "\"%s\"", value);
	else
		strcpy(s, value);
	store(name, s);
	free(s);
	save();
}

int cfg_SetBinary(const char *name, const void *data, int size) {
	char *s = (char *)malloc(4 + 2 * size + 1);
	int i;
	strcpy(s, "hex:");
	for (i = 0; i < size; i++)
		sprintf(s + 4 + 2 * i, "%02x", ((const unsigned char *)data)[i]);
	store(name, s);
	free(s);
	save();
	return 1;
}

void cfg_Close(void) {
	opened = 0;
}

void cfg_Open(const char *path) {
	strncpy(iniPath, path, sizeof iniPath - 1);
	load();
	opened = 1;
}

#ifndef CONFIG_TEST

/* Entry points of the wrapper in the executable (v1.01) and the first bytes they must still have; a jmp to the replacement goes over them */
static const struct { DWORD addr; void *fn; unsigned char orig[6]; } HOOKS[] = {
	{0x403b20, (void *)cfg_Close,        {0xe8, 0x0b, 0x00, 0x00, 0x00, 0xc7}},   /* Reg_Close */
	{0x403cf0, (void *)cfg_HasValue,     {0x81, 0xec, 0x84, 0x00, 0x00, 0x00}},   /* Reg_HasValue */
	{0x403e00, (void *)cfg_GetInt,       {0x83, 0xec, 0x0c, 0x56, 0x8b, 0x74}},   /* Reg_GetInt */
	{0x403e90, (void *)cfg_GetFloat,     {0x83, 0xec, 0x0c, 0x56, 0x8b, 0x74}},   /* Reg_GetFloat */
	{0x403f90, (void *)cfg_GetBinary,    {0x56, 0x8b, 0x74, 0x24, 0x08, 0x56}},   /* Reg_GetBinary */
	{0x404070, (void *)cfg_GetString,    {0x83, 0xec, 0x08, 0x53, 0x8b, 0x5c}},   /* Reg_GetString */
	{0x404120, (void *)cfg_GetValueType, {0x83, 0xec, 0x08, 0x8b, 0x0d, 0xac}},   /* Reg_GetValueType */
	{0x403b80, (void *)cfg_SetInt,       {0x51, 0x8b, 0x0d, 0xac, 0x5e, 0x4f}},   /* Reg_SetInt */
	{0x403d90, (void *)cfg_SetFloat,     {0x51, 0x8b, 0x0d, 0xac, 0x5e, 0x4f}},   /* Reg_SetFloat */
	{0x403f20, (void *)cfg_SetBinary,    {0x51, 0x8b, 0x0d, 0xac, 0x5e, 0x4f}},   /* Reg_SetBinary */
	{0x404010, (void *)cfg_SetString,    {0x51, 0x8b, 0x0d, 0xac, 0x5e, 0x4f}},   /* Reg_SetString */
};

static int install(void) {
	size_t i;
	for (i = 0; i < sizeof HOOKS / sizeof *HOOKS; i++)
		if (memcmp((void *)(ULONG_PTR)HOOKS[i].addr, HOOKS[i].orig, 6))
			return 0;   /* not the v1.01 executable: nothing is changed */
	for (i = 0; i < sizeof HOOKS / sizeof *HOOKS; i++) {
		unsigned char *p = (unsigned char *)(ULONG_PTR)HOOKS[i].addr;
		DWORD old;
		VirtualProtect(p, 5, PAGE_EXECUTE_READWRITE, &old);
		p[0] = 0xE9;
		*(DWORD *)(p + 1) = (DWORD)(ULONG_PTR)HOOKS[i].fn - (HOOKS[i].addr + 5);
		VirtualProtect(p, 5, old, &old);
	}
	return 1;
}

/* Reg_Open(root, subkey, version) of the executable lands here: the arguments are not needed */
EXPORT void __cdecl GrimRegOpen(void *root, unsigned subkey, const char *version) {
	char path[1024];
	const char *env = getenv("GRIM_INI");
	char *slash;
	(void)root;
	(void)subkey;
	(void)version;
	if (env) {
		strncpy(path, env, sizeof path - 1);
		path[sizeof path - 1] = 0;
	} else {
		GetModuleFileNameA(NULL, path, sizeof path - 16);
		slash = strrchr(path, '\\');
		strcpy(slash ? slash + 1 : path, "grim.ini");
	}
	cfg_Open(path);
	if (!install())
		MessageBoxA(NULL, "grim.ini: the registry functions are not the ones of Grim Fandango v1.01, the registry is used.", "patch.dll", MB_OK);
}

#endif

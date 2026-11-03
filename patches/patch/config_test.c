/* Host test of config.c: gcc -DCONFIG_TEST -o config_test config_test.c && ./config_test */
#ifndef CONFIG_TEST
#define CONFIG_TEST
#endif
#include "config.c"
#include <assert.h>

int main(void) {
	char buf[64] = "untouched";
	unsigned char b[4] = {1, 2, 3, 0xff}, r[8];
	const char *path = "config_test.ini";
	remove(path);
	assert(cfg_HasValue("x") == 1);                       /* before Reg_Open */
	cfg_Open(path);
	assert(!cfg_HasValue("x") && cfg_GetValueType("x") == 0);
	assert(cfg_GetInt("x", 7) == 7 && cfg_GetFloat("x", 2.5f) == 2.5f);
	assert(!cfg_GetString("x", buf, sizeof buf, "d") && !strcmp(buf, "untouched"));
	cfg_SetString("GrimDataDir", "C:\\GOG Games\\GRIMDATA\\");
	cfg_SetString("TextMode", "3");                       /* a string that looks like a number */
	cfg_SetString("TextAllowed", "true");
	cfg_SetInt("Count", -5);
	cfg_SetFloat("Gamma", 0.75f);
	cfg_SetBinary("Blob", b, 4);
	cfg_Close();
	cfg_Open(path);                                        /* everything survives a reload */
	assert(cfg_HasValue("textallowed"));                   /* names are not case sensitive */
	assert(cfg_GetString("GrimDataDir", buf, sizeof buf, "") && !strcmp(buf, "C:\\GOG Games\\GRIMDATA\\"));
	assert(cfg_GetValueType("TextMode") == 1 && cfg_GetString("TextMode", buf, sizeof buf, "") && !strcmp(buf, "3"));
	assert(cfg_GetValueType("TextAllowed") == 1);
	assert(cfg_GetValueType("Count") == 3 && cfg_GetInt("Count", 0) == -5);
	assert(cfg_GetValueType("Gamma") == 3 && cfg_GetFloat("Gamma", 0) == 0.75f);
	assert(cfg_GetBinary("Blob", r, 8) && !memcmp(r, b, 4));
	assert(!cfg_GetBinary("Blob", r, 2));                  /* buffer too small */
	assert(cfg_GetInt("Blob", 0) == (int)0xff030201);
	assert(cfg_GetString("Count", buf, sizeof buf, "") && !strcmp(buf, "-5"));
	assert(cfg_GetInt("TextAllowed", 9) == 9);             /* a string is not an int */
	cfg_GetString("GrimDataDir", buf, 6, "");              /* truncates, stays terminated */
	assert(strlen(buf) == 5);
	printf("config.c ok\n");
	remove(path);
	return 0;
}

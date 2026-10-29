#include <cstdio>
#include <cmath>
#include <cstring>
namespace Grim { float originalAsinDeg(float); }
int main(int argc, char **argv) {
	FILE *f = fopen(argv[1], "r");
	char hex[16]; double a, r; int n = 0, bad = 0;
	while (fscanf(f, "%15s %lf %lf", hex, &a, &r) == 3) {
		unsigned u; sscanf(hex, "%x", &u); float x; memcpy(&x, &u, 4);
		float g = Grim::originalAsinDeg(x); n++;
		if (g != (float)r) { if (bad++ < 8) printf("asin(%.9g): got %.9g want %.9g\n", x, g, r); }
	}
	printf("%d arguments, %d differ\n", n, bad);
}

#include <cstdio>
#include <cmath>
namespace Grim { void originalTurnFrame(float &, float &, float &, float &, float, float, float); }
int main(int argc, char **argv) {
	FILE *f = fopen(argv[1], "r");
	float fx, fy, px, py, ang, ex, ey; int n = 0, bad = 0;
	while (fscanf(f, "%f %f %f %f %f %f %f", &fx, &fy, &px, &py, &ang, &ex, &ey) == 7) {
		float rx, ry; Grim::originalTurnFrame(fx, fy, rx, ry, px, py, ang); n++;
		if (fx != ex || fy != ey) { if (bad++ < 8) printf("turn by %.9g: got %.9g %.9g want %.9g %.9g\n", ang, fx, fy, ex, ey); }
	}
	printf("%d turns, %d differ\n", n, bad);
}

#include <cstdio>
#include <cmath>
namespace Grim { void originalSinCos(float, float &, float &); }
int main(int argc, char **argv) {
	FILE *f = fopen(argv[1], "r");
	float a, es, ec; int bad = 0, n = 0;
	double worst = 0;
	while (fscanf(f, "%f %f %f", &a, &es, &ec) == 3) {
		float s, c; Grim::originalSinCos(a, s, c); n++;
		double d = fmax(fabs(s - es), fabs(c - ec));
		if (d > worst) worst = d;
		if (s != es || c != ec) { if (bad++ < 8) printf("angle %.9g: got %.9g %.9g want %.9g %.9g\n", a, s, c, es, ec); }
	}
	printf("%d angles, %d differ, worst %.3g\n", n, bad, worst);
}

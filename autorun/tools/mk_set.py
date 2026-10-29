#!/usr/bin/env python3
"""Writes the hand-made set files of the engine-rule tests (STATE_PLAN.md, step 4) and packs them into a LAB the engines read as DATAUSR.LAB.
   mk_set.py [out dir, default tests/sets]      writes <dir>/t_*.set and <dir>/DATAUSR.LAB (sectors are exact numbers, listed below)
The header is the one of the game's own testroom.set (a colormap, a background, one light): the geometry sits within a few metres of the origin."""
import os, sys, subprocess

HEADER = """section: colormaps
	numcolormaps	1
	colormap	yr1_pal1.cmp


#section: objectstates
#	tot_objects 0

section: setups
	numsetups	1

	setup		test_0
	background	testroom.0.bm
	zbuffer		testroom.0.zbm
	position	0.001756	-1.943699	0.600093
	interest	-0.096604	0.021865	0.191580
	roll		0.000000
	fov		42.534630
	nclip		0.010000
	fclip		20.000000


section: lights
	numlights	1

	light		light1
	type		omni
	position		0.737363	-1.034878	1.508645
	direction	0.000000	0.000000	0.000000
	intensity	1.000000
	umbraangle		0.000000
	penumbraangle	0.000000
	color				15 15 15


section: sectors

"""


def rect(x0, y0, x1, y1, z=0.0):
    return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]


# name, type, on at the start, corners
SETS = {
    # one open floor 4 x 4 m: turn and walk rates, SetActorRot, the collision ring
    "t_flat": [("floor", "walk", True, rect(-2, -2, 2, 2))],
    # two floors that share an edge exactly, one with a gap of 2e-5 (the containment tolerance of the original, FUN_004a6980) to the pair, a
    # floor that is off, and a wall (the outer edge): the rules of the edges
    "t_edge": [
        ("e_left", "walk", True, rect(-2, -2, 0, 2)),
        ("e_right", "walk", True, rect(0, -2, 2, 2)),
        ("e_gap", "walk", True, rect(-2, 2.00002, 2, 4)),
        ("e_off", "walk", False, rect(-2, -4, 2, -2.00002)),
        # a corner of 132.7 degrees on the far side
        ("e_wedge", "walk", True, [(2, -2, 0), (4, -2, 0), (4, 0, 0), (2, 2, 0)]),
    ],
    # two floors and a stair between them (the name holds "stair": constrain), 3 slopes in 3 stairs side by side
    "t_stair": [
        ("lo", "walk", True, rect(-3, -2, 3, 0)),
        ("stair_a", "walk", True, [(-3, 0, 0), (-1.5, 0, 0), (-1.5, 1.0, 0.3), (-3, 1.0, 0.3)]),
        ("stair_b", "walk", True, [(-1, 0, 0), (1, 0, 0), (1, 1.0, 0.6), (-1, 1.0, 0.6)]),
        ("stair_c", "walk", True, [(1.5, 0, 0), (3, 0, 0), (3, 1.0, 1.0), (1.5, 1.0, 1.0)]),
        ("hi_a", "walk", True, rect(-3, 1.0, -1.5, 3, 0.3)),
        ("hi_b", "walk", True, rect(-1, 1.0, 1, 3, 0.6)),
        ("hi_c", "walk", True, rect(1.5, 1.0, 3, 3, 1.0)),
    ],
    # slivers of 3, 5 and 10 cm between two floors (the dam), and a passage of 2.5 cm
    "t_sliver": [
        ("left", "walk", True, rect(-3, -1, -1, 1)),
        ("sl3", "walk", True, rect(-1, -1, -0.97, 1)),
        ("sl5", "walk", True, rect(-0.97, -1, -0.92, 1)),
        ("sl10", "walk", True, rect(-0.92, -1, -0.82, 1)),
        ("right", "walk", True, rect(-0.82, -1, 3, 1)),
        ("narrow", "walk", True, rect(-3, 1, -1, 1.025)),
    ],
    # a hot sector (type chernobyl) in a floor: triggers and doors
    "t_hot": [
        ("floor", "walk", True, rect(-3, -2, 3, 2)),
        ("hot_door", "chernobyl", True, rect(2, -1, 3, 1)),
    ],
}


def write_set(name, sectors):
    out = HEADER
    for i, (sname, stype, on, pts) in enumerate(sectors):
        out += "\tsector\t\t%s\n\tID\t\t%d\n\ttype\t\t%s\t\n\tdefault visibility\t\t%s\t\n\theight\t\t%s\n\tnumvertices\t%d\n" % (
            sname, i, stype, "visible" if on else "invisible", "9999.00" if stype == "chernobyl" else "   0.00", len(pts))
        for j, (x, y, z) in enumerate(pts):
            out += "\t%s\t\t%.6f\t%.6f\t%7.4f\n" % ("vertices:" if j == 0 else "         ", x, y, z)
        out += "\n\n"
    return out


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    d = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "tests", "sets")
    os.makedirs(d, exist_ok=True)
    stage = os.path.join(d, "stage")
    os.makedirs(stage, exist_ok=True)
    for name, sectors in SETS.items():
        with open(os.path.join(stage, name + ".set"), "w", newline="\r\n") as f:
            f.write(write_set(name, sectors))
    subprocess.check_call([sys.executable, os.path.join(here, "mk_datausr.py"), stage, os.path.join(d, "DATAUSR.LAB")])


main()

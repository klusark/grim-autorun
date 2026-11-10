#!/usr/bin/env python3
"""Compares the actor light levels of tests/probe_light.lua: the mean light level of every mesh of Manny (rdModel_DrawMesh mesh+0x5c,
the value rdLight_CalcVertexIntensities returns) in the last held frame of every pose.

    light_cmp.py <scummvm log> <original tracer log | golden txt> [tolerance] [--write <golden txt>]

ScummVM: MESHLIGHT <mesh> <mean> lines (DEBUGFLAGS=models) after the probe's "<pose> <k>" lines.
Original: the tracer log of GRIMTRACE_BP=40d831 GRIMTRACE_PEEK="eax+0,eax+10,eax+50" (mesh name at +0, mean at +0x5c). Its poses are
told apart by the frames in which Manny is hidden (no hit of his meshes).
Golden txt: "<pose> <mesh> <mean>" lines (written with --write from an original tracer log)."""
import re
import struct
import sys

POSES = ["eva_0", "eva_90", "eva_180", "eva_270", "beam_0", "beam_90", "beam_180", "beam_270", "mid_0", "mid_270", "far_0", "far_180"]
# meshes of mannysuit.3do lit per vertex (the hands and fingers take the forearm's level and have no mean of their own)
MANNY = {"m_skirt1", "m_chest1", "m_nck_b1", "m_nck_m1", "m_nck_t1", "m_head_1", "m_shldr_r1", "uarm_r1", "m_farm_r1", "m_shldr_l1",
         "uarm_l1", "m_farm_l1", "m_thigh_r1", "m_shin_r1", "m_heel_r1", "m_toe_r1", "m_thigh_l1", "m_shin_l1", "m_heel_l1", "m_toe_l1"}
FIRST = "m_skirt1"


def load_scummvm(path):
    """{pose: {mesh: mean}} from the frame after the last probe line of each pose"""
    out = {}
    pose = None
    frame = {}
    for line in open(path, errors="ignore"):
        m = re.search(r"LIGHTPROBE (\S+) (\d+) pos", line) or re.search(r"PROBE (\S+) (\d+) pos", line)
        if m:
            if pose and frame:
                out[pose] = frame
            pose = m.group(1) if int(m.group(2)) == 8 else None
            frame = {}
            continue
        m = re.search(r"MESHLIGHT (\S+) (\S+)", line)
        if m and pose and m.group(1) in MANNY and m.group(1) not in frame:
            frame[m.group(1)] = float(m.group(2))
    if pose and frame:
        out[pose] = frame
    return out


def load_original(path):
    hits = []
    cur = None
    for line in open(path, errors="ignore"):
        if line.startswith("BP "):
            cur = {}
            hits.append(cur)
            continue
        m = re.match(r"\s+peek eax\+(\w+): (\w+) (\w+) (\w+) (\w+) / \S+ \S+ \S+ (\S+)", line)
        if m and cur is not None:
            off = int(m.group(1), 16)
            words = [int(m.group(i), 16) for i in range(2, 6)]
            if off in (0, 0x10):
                cur.setdefault("nameb", b"")
                cur["nameb"] += b"".join(struct.pack("<I", w) for w in words)
            elif off == 0x50:
                cur["mean"] = struct.unpack("<f", struct.pack("<I", words[3]))[0]
    for h in hits:
        h["name"] = h.get("nameb", b"").split(b"\0")[0].decode("latin1")
    # frames of Manny: each starts with his first mesh; a pose ends where Manny was hidden (other meshes only, more than a frame of them)
    frames = []
    gap = 0
    for h in hits:
        if h["name"] == FIRST:
            frames.append((gap, {}))
            gap = 0
        elif h["name"] in MANNY and frames:
            frames[-1][1].setdefault(h["name"], h.get("mean"))
        else:
            gap += 1
    poses = []
    for g, f in frames:
        # (Eva and Salvador draw a few dozen meshes a frame; Manny's hidden frames leave many more than that between two of his frames)
        if not poses or g > 60:
            poses.append([])
        poses[-1].append(f)
    return poses


def load_golden(path):
    out = {}
    for line in open(path):
        p, mesh, v = line.split()
        out.setdefault(p, {})[mesh] = float(v)
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    write = sys.argv[sys.argv.index("--write") + 1] if "--write" in sys.argv else None
    if write:
        args = [a for a in args if a != write]
    sv = load_scummvm(args[0])
    tol = float(args[2]) if len(args) > 2 else 0.002
    if args[1].endswith(".txt"):
        orig = load_golden(args[1])
    else:
        poses = load_original(args[1])
        print("original: %d pose groups of %s frames" % (len(poses), [len(p) for p in poses]))
        orig = {}
        for name, frames in zip(POSES, poses[-len(POSES):]):
            orig[name] = frames[-1]
        if write:
            with open(write, "w") as f:
                for p in POSES:
                    for mesh in sorted(orig.get(p, {})):
                        f.write("%s %s %.6f\n" % (p, mesh, orig[p][mesh]))
    bad = 0
    n = 0
    for p in POSES:
        o = orig.get(p, {})
        s = sv.get(p, {})
        diffs = []
        for mesh in sorted(o):
            n += 1
            if mesh not in s:
                diffs.append("%s missing" % mesh)
                bad += 1
            elif abs(s[mesh] - o[mesh]) > tol:
                diffs.append("%s %.4f/%.4f" % (mesh, s[mesh], o[mesh]))
                bad += 1
        print("%-9s %2d meshes  %s" % (p, len(o), "ok" if not diffs else "scummvm/orig: " + ", ".join(diffs)))
    print("GOLDEN light %s (%d values, %d differ)" % ("PASSED" if not bad and n else "FAILED", n, bad))
    sys.exit(1 if bad or not n else 0)


main()

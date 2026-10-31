#!/usr/bin/env python3
"""Puts the OBS recording of a fast run back in order: fastvideo.py <capture.mkv> <out.mp4> [encoder options]

The engine (frame_marker) writes the number of the simulated frame as squares along the bottom edge of every picture; OBS records at a higher rate than the
run draws, so a picture is seen once or twice. The first sighting of each number is kept, a number that was never seen is filled with the picture before it
(and counted), pictures with no valid marker (before the game window was hooked) are dropped, the marker is painted over, and the result is encoded at 60 fps.
"""
import subprocess, sys

W, H, CELL, BITS = 640, 480, 8, 32
FRAME = W * H * 3

def stamp(buf):
    """The number in the marker of a raw rgb24 picture, or None when there is no marker"""
    y = H - CELL // 2 - 1
    def cell(i):
        o = (y * W + i * CELL + CELL // 2) * 3 + 1
        return (buf[o - 3] + buf[o] + buf[o + 3]) // 3
    hi, lo = cell(0), cell(1)
    if hi < 170 or lo > 85:
        return None
    thr = (hi + lo) // 2
    n = 0
    for i in range(2, 2 + BITS):
        v = cell(i)
        if 85 < v < 170 and abs(v - thr) < 15:
            return None
        n = n * 2 + (1 if v > thr else 0)
    return n

def main():
    src, dst = sys.argv[1], sys.argv[2]
    enc = sys.argv[3:] or ["-c:v", "h264_nvenc", "-preset", "p5", "-cq", "18"]
    dec = subprocess.Popen(["ffmpeg", "-v", "error", "-i", src, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE, bufsize=FRAME * 4)
    out = subprocess.Popen(["ffmpeg", "-y", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % (W, H), "-r", "60", "-i", "-"] + enc + ["-pix_fmt", "yuv420p", dst], stdin=subprocess.PIPE)
    seen = captured = dropped = dup = filled = 0
    last = None
    prev = None
    gaps = []
    while True:
        buf = dec.stdout.read(FRAME)
        if len(buf) < FRAME:
            break
        captured += 1
        n = stamp(buf)
        if n is None:
            dropped += 1
            continue
        if last is not None and n <= last:
            dup += 1
            continue
        if last is not None and n > last + 1:
            if n - last > 100000:
                dropped += 1
                continue
            gaps.append((last + 1, n - 1))
            for _ in range(n - last - 1):
                out.stdin.write(prev)
                filled += 1
        b = bytearray(buf)
        row = b[(H - CELL - 3) * W * 3:(H - CELL - 2) * W * 3]
        for r in range(H - CELL - 2, H):
            b[r * W * 3:(r + 1) * W * 3] = row
        prev = bytes(b)
        out.stdin.write(prev)
        last = n
        seen += 1
    out.stdin.close()
    out.wait()
    dec.wait()
    print("captured %d pictures: %d frames kept, %d duplicates, %d without a marker, %d filled in over %d gaps" % (captured, seen, dup, dropped, filled, len(gaps)))
    for a, b in gaps[:20]:
        print("  missing frames %d - %d" % (a, b))

main()

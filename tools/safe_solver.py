# Plans the vault safe of Grim Fandango (vd.lua): 4 tumblers, the wheel turns tumbler 1, tumbler k+1 is
# picked up when tumbler k passes its lock value (rot + pin at the last change of direction).
# Goal: all four rots in [248, 290]. usage: safe_solver.py r1 r2 r3 r4 p1 p2 p3 p4
import sys, itertools, random
LO, HI = 248, 290
def step(state, d, pins):
    r, L, lv = list(state[0]), list(state[1]), list(state[2])
    for i in range(4):
        if L[i]:
            r[i] = (r[i] + d) % 360
            if i < 3 and r[i] == lv[i+1] and not L[i+1]:
                L[i+1] = True
    return (tuple(r), tuple(L), tuple(lv))
def reset(state, pins):
    r, L, lv = state
    L = (L[0], False, False, False)
    lv = (lv[0],) + tuple((r[i] + pins[i]) % 360 for i in (1, 2, 3))
    return (r, L, lv)
def goal(state):
    return all(LO <= x <= HI for x in state[0])
def plan(r, pins, maxdepth=14):
    start = (tuple(r), (True, False, False, False), (0,) + tuple((r[i] + pins[i]) % 360 for i in (1,2,3)))
    # states keyed by (r, L, last direction); moves = (direction, steps) stopping at events
    best = None
    from collections import deque
    seen = {}
    q = deque()
    q.append((start, +1, []))
    seen[(start[0], start[1], +1)] = 0
    while q:
        st, last, path = q.popleft()
        if goal(st): return path
        if len(path) >= maxdepth: continue
        for d in (+1, -1):
            cur = st
            if d != last:
                cur = reset(cur, pins)
            s = cur
            nowin = tuple(LO <= x <= HI for x in s[0])
            for n in range(1, 361):
                s = step(s, d, pins)
                inwin = tuple(LO <= x <= HI for x in s[0])
                event = (s[1] != cur[1]) or inwin != nowin
                nowin = inwin
                if goal(s):
                    return path + [(d, n)]
                if event:
                    key = (s[0], s[1], d)
                    if key not in seen:
                        seen[key] = len(path) + 1
                        q.append((s, d, path + [(d, n)]))
    return None
if __name__ == '__main__':
    a = [int(x) for x in sys.argv[1:]]
    print(plan(a[:4], a[4:]))

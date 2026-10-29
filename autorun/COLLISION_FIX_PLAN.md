# Plan: make ScummVM's actor heading and collision match the original Grim Fandango

For: the agent implementing this (Sonnet), working in `C:\msys64\home\Joel\scummvm` (branch `grim-actor-fixes`) with the test
tools in `C:\Users\Joel\grim_tools\autorun`. Read `AI-GUIDELINES.md` in the repo first. Never commit. Build with
`MSYSTEM=UCRT64 /c/msys64/usr/bin/bash.exe -l /c/Users/Joel/grim_tools/build_scummvm.sh` (optimised build in
`~/scummvm/build-opt`, about 2 min). Write files with the Write/Edit tools, not shell heredocs (a heredoc turns `\n` inside a
string into a real newline and breaks the file). Lua here is 3.1: no `local function`, no `break`, 32 locals, `~=`.

---------------------------------------------------------------------------------------------------------------

## 1. What is wrong, in one paragraph

The original engine does not keep an actor's heading as an angle. It keeps a forward **vector** (in a 3x3 frame: right,
forward, up) and every turn, the "immediate" `SetActorRot` included, rotates that vector by a *relative* angle. The relative
angle comes from an arcsine series in degrees; the rotation matrix comes from a 4096-entry sine table with linear
interpolation. Both are a little off (about 1e-4 to 3e-4). So after `manny:setrot(0, 90, 0)` the original's heading is
89.98 degrees, and an actor walking "due west" drifts north by about 3e-4 of the way. When that actor walks head-on into
another actor's collision **box**, the original's collision code rotates the penetration vector 90 degrees about the axis
`normal x direction` onto the face: the drift decides the axis, so it decides to which side the actor slides, and the actor
slides by the whole penetration every frame. ScummVM keeps an exact yaw, walks exactly west, and its box handling does not
slide the same way. Result: 15 of the 81 static collision cases (every head-on approach to a box face) diverge from the
original from the first contact frame on; the 66 oblique and sphere cases match to 1 cm per frame already.

Fixing it means giving ScummVM's Grim actors the original's heading model (vector + table trigonometry) and the original's
per-frame collision pass, exactly. A smaller fix that only forces the slide side would leave every heading in the game 0.02
degrees off the original and was rejected: the goal is that the same Lua script does the same thing on both engines.

## 2. Facts established (GRIMFANDANGO.EXE v1.01, the Ghidra program named `/v101/GRIMFANDANGO.EXE`)

Structures (offsets from the decompiled code; verify any you rely on):

* Actor: `+0x8` flags (bit 0 = walking a path), `+0xc` position (3 floats), `+0x18` position at the start of the frame
  (the collision pass compares the two), `+0x24/+0x28/+0x2c` pitch/yaw/roll, `+0x34` matrix-dirty flag, `+0x38` 4x3 matrix
  built by `FUN_00493790` from rot and pos through `FUN_0044eeb0`, `+0xa0` -> costume (`((+0xa0)+4)+4` = model),
  `+0xa4` -> extra data: `+0x1b4` the walker object, `+0x1c` turn rate (sign flipped by SetActorRot when immediate),
  `+0x28` the last relative turn angle, `+0x3f0` collision mode (1 box, 2 sphere), `+0x3f4` collision scale,
  `+0x3f8` collided flag, `+0x41c` speed factor.
* Walker (0x60 bytes, `FUN_004a8200` constructor): `+0x0` position, `+0xc` right, `+0x18` forward, `+0x24` up (the 3 rows
  of the frame), `+0x30` translation copy of the position, `+0x3c` reflection angle, `+0x40` distance left, `+0x44` target
  point, `+0x50` target mode flag, `+0x5c` current sector.
* Model (.3do, binary): after the hierarchy nodes: `radius` (float), then three vectors: **box min, box max, box centre**,
  then the insert offset. ScummVM already reads them (`Model::_fileMin/_fileMax/_center/_hasFileBox/_hasCenter`,
  `model.cpp` `loadBinary`). The original's model struct has them at `+0x60..+0x68` (min), `+0x6c..+0x74` (max),
  `+0x78..+0x80` (centre), radius at `+0x5c`.

Functions (decompiled; the `.cpp` port must follow them operation by operation, rounding to float where they store):

| Address | What | Status |
| --- | --- | --- |
| `FUN_0047bd20(angle, &sin, &cos)` | sin/cos in degrees from the table at `0x4df600` (4096 floats, sin(i*pi/8192) to 6 decimals, a 0 word before and after), 4 quadrants, linear interpolation; index = angle * 45.511112 truncated (`_ftol`, `FUN_004ac6f0` with the control word set to chop), fraction = x - round-down(x) (`FUN_0047c100`, control word `0x77f` = round toward minus infinity) | **ported**: `engines/grim/sincos.cpp` + `sintable.h` (not yet in `module.mk`, not yet verified against the original's outputs, see step A) |
| `FUN_0047bc20(a)` | angle to [0, 360) | ported inside `sincos.cpp` (`normalizeAngle`) |
| `FUN_0047c4a0(x)` | arcsine in degrees: for abs(x) <= 0.70710677: `(x + x^3/6 + 0.075 x^5 + 0.066797 x^7) * 57.295784`; else `90 - series(sqrt(1 - x^2))`; sign of x; the powers come from `FUN_0047bbe0(x, n)` (x^n), the sqrt from `FUN_0047c490`. Intermediates are x87 extended (`float10`), the sum is stored to float twice (see the decompile) | to port |
| `FUN_004469a0(v)` | normalize in place: `len = sqrt(x*x + z*z + y*y)` (that order), if len != 0 multiply by `1/len`; returns len (in st0) | to port (trivial, keep the operation order) |
| `FUN_004468a0(a, b)` | dot product in x87 extended | to port |
| `FUN_0044f210(out, axis, angle)` | 4x3 rotation matrix about `axis` by `angle` degrees (sin/cos from `FUN_0047bd20`); special cases for axis z = +1 and -1; otherwise the general formula in the decompile (note the `(1 - a) - b` denominators). A zero axis divides by zero: the original never gets one because its headings are never exact | to port |
| `FUN_0044ffc0(v, m)` | v = rotate v by the 3x3 of m (rows) | to port |
| `FUN_0044ff50(out, v, m)` | out = transpose(m3x3) * v (components = v dot each row) | to port |
| `FUN_0044fee0(out, v, m)` | out = m3x3 * v (rotate, no translation) | to port |
| `FUN_00450060(out, v, m)` / `FUN_004500d0(v, m)` | out = m3x3 * v + translation (m[9..11]) | to port |
| `FUN_0044eeb0(m, rot, pos)` | matrix from euler (pitch, yaw, roll in degrees, table sin/cos) and position: see the decompile for the 9 products | to port |
| `FUN_0044f650(m, out)` | matrix -> euler angles (used by `GetActorYawToPoint` through `FUN_004a82a0`; the yaw the scripts see) | **to decompile** and port |
| `FUN_0044f080(out, rot)` | rotation (euler) -> direction vector (used by SetActorRot to make the target direction) | **to decompile** and port |
| `FUN_004a8370(walker, v)` | v = transpose(frame) * (v - walker.pos): world -> walker frame | ported semantics above |
| `FUN_004a83c0(walker, angle)` | rotate the walker's forward about its up by `angle` (table), project to the sector plane (`FUN_004a6fa0`) when on a sector, then `FUN_004a8a90`: right = cross(forward, up) normalized, forward normalized | to port: this is **the turn** |
| `FUN_004a8500(walker, point)` | `GetActorYawToPoint`: point projected to the sector plane, to the walker frame, normalized; `rel = 90 - asin_deg(local.y)`, negative if `local.x > 0`; returns `yaw(frame -> euler) + rel` | to port |
| `FUN_00490900(actor, rot, immediate)` | `SetActorRot`: clears flag bit 0; if the walker exists: dir = `FUN_0044f080(rot)`, point = walker.pos + dir, to walker frame, z = 0, normalize, `rel = 90 - asin_deg(local.y)`, negative if `local.x > 0`, `FUN_004a83c0(rel)`; if immediate and turn rate > 0: turn rate = -turn rate; extra+0x28 = rel; actor pitch/roll = rot; dirty. The yaw field is **not** written here; it follows from the frame. Without a walker: rot copied | to port: this is why `setrot(0,90,0)` gives 89.98 |
| `FUN_004a8610(walker, dist, left, right)` | walk forward: `(0, dist, 0)` to world through the frame; if in the sector, set; else exit edge (`FUN_004a6d10`), adjacent sector (`FUN_004a71e0`, type 0x1000), reflection turn by `FUN_004a83c0`, recursion <= 8, remaining distance capped at 0.02 when entering a new sector (`FUN_004a89b0` re-projects the frame onto the new sector normal) | ScummVM's `walkForward` is structurally similar; port the frame math and the 0.02 cap, keep the sector logic |
| `FUN_004939a0()` | once per frame: for each actor in the list `DAT_008ca358` (count `DAT_008ca330`) whose `+0xc` != `+0x18` (12-byte compare), `FUN_004939f0(actor)` | to port: **the collision pass**, after all walking |
| `FUN_004939f0(actor)` | mover centre `c1 = pos + rot(model.centre)`, `r1 = radius * scale`; for every other actor with extra data and mode != 0: `c2 = other.matrix * other.centre`, `r2`; if `|c1 - c2| < r1 + r2`: mode 2 -> sphere push (see below); mode 1 -> box (see below); then `FUN_0049c750(actor, other, globals)` = the collision callback | to port |
| sphere branch | both collided flags set; `dir = normalize(c1 - c2)`; `push = (1 - (d - r2) / r1) * r1`; new pos = `c1 + dir * push - rot(model.centre)`; `FUN_00490870(actor, &newpos)`; walking bit kept | to port (this already nearly matches: the oblique sphere cases pass) |
| box branch | `local = transpose(other.m) * (c1 - c2) + other.centre` (mover's centre in the other's model frame); box = `[min*scale - r1, max*scale + r1]` on all three axes; strictly inside on all three or nothing; `prev = transpose(other.m) * (actor.prevpos + rot(centre) - c2) + other.centre`; `FUN_00494100(local, prev, box, &out)`; if it returns 0: `FUN_004922d0(...)` (push out through the nearest x/y side, +0.01; see the decompile and the note in step C); then `world = other.m * out + other.pos - rot(centre)`; `actor.prevpos = actor.pos`; `FUN_00490870(actor, &world)`; if the actor walks a path (bit 0): `FUN_00491650` re-plans it | to port exactly |
| `FUN_00494100(cur, prev, box, out)` | `d = cur - prev`; `far = prev - 10 d` (written over `prev`!); for each of the 6 faces: if `far` is beyond the face by more than 0.002, `t = (face - cur)/abs(d_axis)`, keep the smallest abs(t) (sign conventions per face in the decompile); none -> return 0; `out = cur + best * d` (the entry point on the face); `rem = d * abs(best)`, `len = |rem|`, `rem` normalized; `a = asin_deg(rem . normal)`; if `90 - a < 90` (the move is away from the face) return 0; `axis = normalize(normal x rem)`; `m = FUN_0044f210(axis, (90 - a) - 90)`; `rem = rotate(rem, m)`; `out += len * rem`; return 1. Head-on: `rem ~ (-1, eps, 0)`, `axis = (0, 0, sign(eps))`, angle 90: the whole penetration goes along the face, to the side of `eps` | to port exactly; **it runs for every box contact** (the trace of the static case shows 168 calls returning 1 and 0 calls of `FUN_004922d0`); an exact heading gives `axis = 0` and a division by zero in `FUN_0044f210`, which is why the heading model must be ported first |
| `FUN_00490870(actor, &pos)` | set position after a collision (used by the sphere and box branches) | **to decompile**: does it clamp to the walk sectors? |
| `FUN_0049c750` | the collision callback into Lua (`collisionHandler`), already in ScummVM as `collisionHandlerCallback` | compare the argument order |

Numbers from the original to check against (static case `collisionS_box_0_0_35`, Manny from (3.05, -4.2) walking west at
Velasco at (2.7, -4.2), Velasco box mode, yaw 0, the test harness as it is now):

* after `manny:setrot(0, 90, 0)`: yaw 20609.980469 (cumulative; mod 360 = 89.98), `GetActorYawToPoint` to the goal = 90.000000.
* frames 1..5: x = 3.0432, 3.0364, 3.0300, 3.0232, 3.0168 (y stays -4.2000 to 4 decimals; ScummVM matches these).
* first box contact: `FUN_00494100(cur = (0.2010239, -0.0004505, 0.2851491), prev = (0.2078238, -0.0004528, 0.2851491))`
  -> 1, `out = (0.2027746, 0.0012991, 0.2851491)` (local frame of Velasco's model; the x face is at 0.2027746 =
  max.x * 1 + r1 with r1 = 0.1077, so Velasco's max.x = 0.0950). Next frames: `out.y` = 0.0076983, 0.0144964, 0.0208942
  (the slide along the face by the penetration, about 6.5 mm a frame). At frame 24 the original is at (2.8985, -4.1915),
  ScummVM at (2.8900, -4.2000) and stays on y = -4.2.
* The sphere centres are the model box centres turned with the actor; Velasco's radius 0.3198, Manny's 0.3079 (scale 0.35
  -> 0.1078). Velasco's matrix after `setrot(0, 140.009003, 0)` in the original: rows `(-0.7662777, 0.6422151, 0)`,
  `(-0.6422151, -0.7662777, 0)`, `(0, 0, 1)` (true sin/cos would be 0.642788/-0.766044: the table and the relative turn).

## 3. Tools

* `C:\Users\Joel\grim_tools\crashdbg\grimtrace.exe` (source `grimtrace.c`, build `gcc -O1 -o grimtrace.exe grimtrace.c` in
  that directory): runs the original under a debugger with breakpoints. Environment: `GRIMTRACE_BP=addr,addr,...` (hex),
  `GRIMTRACE_MAX=n` hits logged (default 20000), `GRIMTRACE_PEEK=reg+hexoff,...` (4 words at a register plus offset),
  `GRIMTRACE_LOG` (default `C:/GOG Games/GRIMDATA/grimtrace.log`). At each hit it logs the registers, the stack from
  esp-0x30 to esp+0x70 and, for every stack word that points into the process, 12 floats at that address: enough to read
  the arguments of a call (breakpoint on the `CALL`) and its result (breakpoint on the instruction after). Breakpoints must
  be instruction starts. Useful ones: `00493f3b` (call `FUN_00494100`: `[esp+0]` cur, `[esp+4]` prev, `[esp+32]` out),
  `00493f43` (after it: eax = result, `[esp-4]` out), `00493f6d`/`00493f72` (`FUN_004922d0`), `0049403a` (call
  `FUN_00490870`: `[esp+0]` actor, `[esp+4]` the new position), `00493a95` (the loop over the other actors), `00493e57`
  (box branch taken), `0047c0e8` (`RET` of `FUN_0047bd20`: `[esp+4]` angle, `[esp+8]`/`[esp+12]` pointers to sin/cos,
  dereferenced in the dump).
* `crashdbg\memdump.exe <exe> <hex addr> <bytes> <file>`: dumps memory of the running game (used for the sine table).
* `sh orig_test.sh <test file> [max s] [log copy]`: runs a test file on the original (resume from save 19, inject, wait for
  `NAVTEST SUMMARY unit`), copies the log, **closes the game**. With `GRIMRUN=./grimtrace.exe GRIMTRACE_BP=... sh orig_test.sh ...`
  it runs under the tracer. A test file is switches + `test_nav.lua`, e.g.
  `printf 'AR_NT_ONLY = "coll"\nAR_NT_IDS = { collisionS_box_0_0_35 = 1 }\nAR_NT_MODE = "none"\n' > /c/msys64/tmp/w/one.lua; cat /c/msys64/tmp/w/one.lua test_nav.lua > /c/msys64/tmp/w/test_one.lua`.
  Never start two originals; `orig_test.sh` kills any running one first.
* ScummVM: `cp /c/msys64/tmp/w/one.lua nt_only_move.lua; EXTRA="nav_cases.lua nav_coll_expect.lua nt_only_move.lua" timeout 400 sh run_chapter.sh test_nav.lua 400 > logs/tn.out 2>&1`; the log is `logs/test_nav.log`.
* `python tools/compare_trace.py a.log b.log [limit_m] [prefix]`: per case, the first frame where the `NAVTRACE` positions
  differ by more than the limit. Reference traces of the original: `logs/coll_trace_orig1.log` (81 static cases, current
  harness). Re-record the original whenever `test_nav.lua`'s collision setup changes.
* `sh tools/lua31/run.sh` (tier A, 59 cases, 20 s), `python tools/test_all.py offline scummvm` (suite + summary),
  `sh run_repeat.sh 1` (full ScummVM game run, 7 min, `logs/all.log`, exit when `logs/repeat1.out` says PASS/FAILED).
* The decompiled Lua of the game is in `C:\Users\Joel\grim_lua_src` (`_actors.lua`, `_system.lua`, `re.lua`...).

## 4. Steps

Each step ends with the named check; do not go on while it fails. Keep the ScummVM style (tabs, the comment voice of the
surrounding code, no `auto` lambdas in hot paths if the file does not use them). Everything here is Grim only: guard with
`g_grim->getGameType() == GType_GRIM` and leave EMI's paths as they are.

### A. The table trigonometry, verified

1. Add `sincos.o` to `engines/grim/module.mk`. Include `sincos.h` where needed.
2. Record the original's `FUN_0047bd20` for a set of angles: run any collision case under
   `GRIMRUN=./grimtrace.exe GRIMTRACE_BP=0047c0e8 GRIMTRACE_MAX=400`; from `grimtrace.log` take `(angle, sin, cos)` triples
   (the angle is `[esp+4]` as a float, the outputs are the first float at the two pointers).
3. Write a tiny host test (`C:/msys64/tmp/w/sctest.cpp` exists: it compiles `sincos.cpp` with `sintable.h` outside ScummVM)
   that prints `originalSinCos` for those angles; it must equal the recorded values bit for bit. The current port is a
   transcription of the disassembly and has not been checked; expect to fix the fraction (`frac = x - rounddown(x)` is computed
   in extended precision, stored once as float), the index (`_ftol` truncates toward zero of the extended value, not of the
   float), and the quadrant edge words.
4. Port `FUN_0047c4a0` (`originalAsinDeg(float)`) and check it the same way (`RET` of `FUN_0047c4a0`: its address is the last
   instruction of the function; the argument is `[esp+4]`, the result st0 is printed as `st0`).
5. Port the vector helpers (`FUN_004469a0` normalize-with-length, dot, `FUN_0044f210` rotation about an axis, the three
   matrix-vector products, `FUN_0044eeb0` euler->matrix). Put them in `sincos.cpp`/`.h` (rename to `origmath.*` if that reads
   better) with a one-line comment per function naming the original's address. Use `double` for every x87 intermediate and
   cast to `float` exactly where the original stores to a float (every `FSTP float ptr` in the disassembly); test each against
   values from the trace when the function is reachable, otherwise against hand-computed values.

### B. The heading as a vector (the walker frame)

Decompile `FUN_0044f650` (matrix -> euler) and `FUN_0044f080` (euler -> direction) first; port them.

In `engines/grim/actor.h/.cpp`, for Grim actors:

1. Add the frame: `Math::Vector3d _frameRight, _frameFwd, _frameUp` (the walker's `+0xc/+0x18/+0x24`), built from the
   euler rot with the ported `FUN_0044eeb0` when the actor is created, loaded (`restoreState`), put at a position, or when
   `setRot` runs without a "walker" state. Keep `_yaw/_pitch/_roll` as the values the scripts and the renderer see, derived
   from the frame with the ported `FUN_0044f650` after every turn (the original's yaw is cumulative, 20609.98 in the trace,
   because `FUN_0044f650` returns an angle and the scripts add; check what `GetActorRot` returns in the original: the actor
   `+0x28` or the frame's euler. Match it).
2. `Actor::setRot(pitch, yaw, roll)` (called by `Lua_V1::SetActorRot`): port `FUN_00490900`: direction from the euler via
   `FUN_0044f080`, relative angle via the walker-frame + asin, then `turnFrame(rel)` = `FUN_004a83c0` (rotate forward about
   up by the table rotation, project to the sector plane when on one, recompute right, normalize). Pitch and roll are copied,
   yaw is not. Keep the existing `_rotPending` turning-flag fix. The fifth Lua argument (`isnil(arg5)` = immediate) only
   flips the sign of the turn rate as the original does; find what ScummVM's `SetActorRot` does with it today and keep the
   non-immediate (gradual) path's behaviour, implemented on the frame.
3. `TurnActor` / `Actor::turnTo` / `singleTurnTo` / `walkTowards`: every per-frame turn of `turnRate * frametime` degrees goes
   through `turnFrame(angle)` (table rotation), not through adding to `_moveYaw`. Check the original's `TurnActor` builtin
   (string "TurnActor" in Ghidra, same xref technique as `GetActorYawToPoint`: string -> data table -> function pointer next
   to it) for how it computes the angle per frame.
4. `Lua_V1::GetActorYawToPoint`: port `FUN_004a8500` (sector-plane projection of the point, frame transform, asin, sign,
   plus the frame's euler yaw).
5. `Actor::walkForward`: the move direction is `_frameFwd` transformed by the frame (the original moves `(0, dist, 0)`
   through the frame: that is `dist * _frameFwd` plus the position); keep ScummVM's sector walk, but the reflection turn
   becomes `turnFrame`, and the remaining distance is capped at 0.02 when the walk continues into a new sector
   (`FUN_004a8610`: `if (0.02 <= remaining) remaining = 0.02`). Re-project the frame onto the new sector's normal as
   `FUN_004a89b0` does.
6. The constrained walk (`_constrained`, my earlier port of `SetActorConstrain`) and the puck vector
   (`getSimplePuckVector`) read the heading from the frame.
7. Save/load: write the frame in `saveState`/`restoreState` with a new minor version (the current one is 34; see
   `savegame.cpp` and `grim.cpp` for where the version lives), and build the frame from the rot for older saves.

Check B: `manny:setrot(0, 90, 0)` then `GetActorYawToPoint` to a point due west returns 90.000000 and `manny:getrot().y`
mod 360 is 89.98 (within 0.001) as in the original; frames 1..5 of `collisionS_box_0_0_35` match the original's x to 4
decimals and y drifts north (the original's y at frame 23 is -4.1999 or so: take it from `logs/coll_trace_orig1.log`).
Add these as cases: a `turn` tier in `test_nav.lua` (setrot to 0/45/90/140/270 then read `getrot().y` and
`GetActorYawToPoint` to 4 points, recorded from the original into `nav_turn_expect.lua` the way `nav_coll_expect.lua` is
recorded) and `walk_drift` cases (walk 40 frames from a fixed heading with no steering, trace, compare).

### C. The collision pass, once per frame, exact

1. Port `FUN_00494100` (`boxEntryFace`), `FUN_004922d0` (`boxPushOut`) and the box and sphere branches of `FUN_004939f0`
   into `Actor` (replace my `handleBoxCollision`; keep `getSphereInfo` on the box centre turned by the frame, as the
   original's `FUN_0044fee0(centre, matrix)`). Use the file box (`_fileMin/_fileMax`), the other actor's full 3x3 (from the
   frame, not yaw only), `prevpos` = the position at the start of the frame. In `boxEntryFace` keep the exact order of the
   six face tests and the `0.002` margin, the sign conventions, the asin test, the cross product order (`normal x rem`), the
   rotation by `(90 - a) - 90`.
   Note on `FUN_004922d0`: the decompile reads its first argument as a world point and writes a world point, while the caller
   passes the local point and transforms the result again; the trace shows it is not reached in these cases. Trace it on a
   case that starts **inside** the box (`obstacle_start_inside`-like: place Manny at Velasco's position + 0.05) before
   porting, and port what the trace shows.
2. Decompile `FUN_00490870` and do what it does (if it clamps to the walk sectors, ScummVM's `findClosestSector` is the
   equivalent; the Velasco sliver case `collisionS_box_velasco` is the check: the original ends at 0.4201 -4.1254).
3. Run the pass once per frame after all actors have walked, for the actors whose position changed since the frame
   started, in the actor list order (`g_grim->getActiveActors()` is the list; confirm the original's order is creation
   order), against every actor with a collision mode in the same set. Remove the per-sub-step `handleCollisionWith` calls in
   `Actor::moveTo`/`walkForward` and the second pass in `Actor::update` for Grim (keep them for EMI). Where in the frame:
   find the caller of `FUN_004939a0` (`FUN_0048fcf0`) and what else it does, so the pass lands at the same point relative to
   the Lua update and the walk (`GrimEngine::mainLoop` / `Actor::update` ordering).
4. The callback: `FUN_0049c750(actor, other, ...)` vs `collisionHandlerCallback` (which calls Lua `collisionHandler` for both
   orders); check the original calls it once or twice per contact.
5. The path re-plan after a push (`FUN_00491650`, actors walking a `WalkActorTo` path): ScummVM's path walk does not re-plan
   after a push. Port it as the last item of this step; the check is an NPC walk with Manny in the way (Velasco's
   `walk_down_to_car` with Manny placed on the route; record the original).

Check C: `python tools/compare_trace.py logs/test_nav.log logs/coll_trace_orig1.log 0.002` on the static collision cases
(`AR_NT_ONLY = "coll"` with the `collisionS_` prefix) reports **81 traces the same** at 2 mm. Then the steered grid: all 81
`collision_*` cases PASS against `nav_coll_expect.lua` at the current 5 cm tolerance; then tighten `tol` to 0.02 in
`test_nav.lua` for both groups and re-record the original (`cat collonly.lua test_nav.lua > ...; sh orig_test.sh ...`) if
the harness changed. No `KNOWN` list, no tolerance widening.

### D. Regression

1. `sh tools/lua31/run.sh`: 59/59 (the planner does not change, but `GetActorYawToPoint` is used by `ar_steer`).
2. `python tools/test_all.py offline scummvm`: unit 57, walk 40, move 96, coll 162, all PASS; `flaky` list empty.
3. `sh run_repeat.sh 1`: the full game on ScummVM passes (ch57's ladder and ch13's Velasco are the sensitive chapters;
   ch38's Pearl cutscene depends on `SetActorRot`'s turning flag).
4. The original's full suite (`sh test_nav_original.sh`, 25 min) and `python tools/compare_navtest.py logs/tn_base.log logs/orig_tn_full.log`: the only differences left should be `cheat_roof` and `stairs_narrow_side`, which are separate issues.

## 5. Order and size

A (half a day, mostly verification), B (the big one: a day; the save version and the turn builtins are where it breaks),
C (half a day once B holds, the trace tools do the work), D (an hour of waiting). Report after each step with the check's
numbers, and update `NAV_PLAN.md` section 8 and `TESTS.md` at the end (the `coll` tier description, the new `turn` tier,
`grimtrace`). If a step's check cannot be reached, say which numbers differ and stop there rather than widening anything.

# Handoff: Grim Fandango / EMI accuracy work in ScummVM

Start here if you are picking up this work. This file gathers what earlier agent sessions learned
(it was copied from their memory on 2026-10-29). The detailed docs it points to are in `autorun/`.
Dates are 2026. Some notes say "uncommitted"; most of that work has since been split into commits (see
section 2), so check git before you trust a status line.

## 0. The user's standing rules

- **Goal:** make ScummVM's Grim match the original exe, frame for frame, for the whole game. Keep going
  without asking whether to continue. The original exe is the reference. Fix differences in the engine
  (`engines/grim`), not by tuning the scripts.
- **Always add tests.** Every fix or difference found gets a test in the same turn, on both engines where
  possible, with expected values measured in the original. Too many tests is fine because they are fast
  next to a game run. Say in your report which tests you added.
- **Ghidra:** rename every function you decode (`Module_Verb`, e.g. `Sector_ContainsPoint`) with
  `rename_function_by_address`, add a plate comment, run `save_program`, and add the address to
  `autorun/GHIDRA_NAMES.md`.
- **Autorun waits:** keep walk budgets short (about 10 s by default). Override per walk with
  `ar_walk_to(..., max_ms)` / `AR_WALK_MAX`. A timeout is an error, not a retry. If Manny gets stuck, fix the
  route with waypoints in the chapter or in `autorun/ar_routes_original.lua` instead of waiting longer.
  After each run, grep the log for `walk stalled`, `walk took more than` and `nav: no way`.
- **`orig_test.sh` kills `GRIMFANDANGO.exe`** before and after a test. The user often plays the original by
  hand (Backspace+F12 Lua). Run `tasklist | grep -qi grimfandango` first, and skip or ask if it is running.
- **No new Lua opcodes in the engine** for testing (GetActorTurnRate was removed for that reason). If one is
  needed, append it at the END of the opcode table (see section 6).
- **Commits:** only commit when asked. ScummVM's `AI-GUIDELINES.md` requires an `Assisted-by:` trailer and no
  AI `Co-Authored-By` line. Remove temporary instrumentation before committing. Working-copy files may be
  CRLF while HEAD is LF, so strip the CRs (`tr -d '\r'`) from modified grim files before committing.
- Never use Windows compatibility layers or anything that triggers UAC; no admin rights are needed. Ask
  before touching the registry or the install directory.
- The user does not want the Remastered exe (`patch_inputdialog.py`, `GrimFandango_patched.exe`); ignore it.

## 1. Locations

| What | Where |
|---|---|
| ScummVM source (main worktree) | `C:\msys64\home\Joel\scummvm` (branch `grim-actor-fixes-split`) |
| Other worktrees | `~/scummvm-split` (detached at the same commit), `~/scummvm-emi` (`grim-lua-validation`, has `build/` and `build-opt/`, used by EMI autorun) |
| Tools (this repo, own git repo) | `C:\Users\Joel\grim_tools` |
| Scripted playthrough | `grim_tools/autorun` (EMI: `grim_tools/emi_autorun`) |
| Decompiled Grim Lua | `C:\Users\Joel\grim_lua_src` (use these, don't decode the LAB bytecode) |
| Game data | `C:\GOG Games\GRIMDATA` (targets `grim-win`, `grim-remastered-win`, `monkey4-win`) |
| ScummVM saves | `%APPDATA%\ScummVM\Saved Games\grimNN.gsv` (gzip; the minor version is byte 11 after decompressing) |
| Ghidra | project program `/v101/GRIMFANDANGO.EXE` (v1.01) and Monkey4.exe; names in `autorun/GHIDRA_NAMES.md` |

## 2. ScummVM branches (as of 2026-10-29)

- `grim-actor-fixes-split`: the current work, split into reviewable commits on top of master (sectors and
  shrinking like the original, planner, Walker_WalkSectors, walker heading frame, constraint, box
  collision, clip plane/shadow, puck, texts/iris, `--autorun/--sim-fps`, debug aids, gamma,
  chores, lipsync, sound position, Lua fixes ...). Run `git log master..grim-actor-fixes-split`.
- `grim-actor-fixes`: the older unsplit branch the split came from ("many changes" commits).
- `grim-time-scale` / `grim-turning`: the turning port (section 7).
- `emi-*`: EMI rendering and sector work. `stash@{1}` is WIP on grim-actor-fixes.

## 3. Building and running ScummVM

- The Bash tool is Git Bash/MSYS without the right toolchain for linking. Build through an MSYS2 login shell
  with UCRT64 and put the commands in a script file to avoid quoting problems:
  `$env:MSYSTEM='UCRT64'; $env:CHERE_INVOKING='1'; & C:\msys64\usr\bin\bash.exe -l script.sh`
  (The libs, e.g. libtheoradec, exist only in /ucrt64. A MINGW64 shell once mixed toolchains and the exe
  would not start.)
- Out-of-tree builds were `~/scummvm/build` (debug) and `~/scummvm/build-opt` (-O2, used by the autorun;
  `grim_tools/build_scummvm.sh` builds it, `SVM_BUILD=build` selects the other one). **On 2026-10-29 both were
  gone**, and the source root was configured in-tree (`--disable-all-engines --enable-engines=grim,monkey4`).
  Check which one exists before you build. Recreate `build-opt` if the autorun scripts need it.
- Run with the target name only, e.g. `scummvm.exe --config=<temp ini copy> --save-slot=N grim-win`, wrapped in
  `timeout`, with stderr captured. `--list-saves --game=monkey4-win` reports "Unrecognized game".
- To drive the game without the autorun: hook `GrimEngine::mainLoop` to `debugLua()` a script file once. stdio
  and getenv are forbidden in ScummVM, so use `Common::FSNode`. Read results through `warning()`. Call
  `LuaBase::instance()->registerOpcodes()` first, because restored saves lack builtins that were added later.
- Engine options added for testing: `--autorun=file.lua`, `--sim-fps=N` (deterministic:
  fixed game time per frame; mixer, iMuse and movies are stepped by the engine), ini `sim_frame_ms=17`,
  `--show-fps`. Compare with the original only at 60 fps vs `--sim-fps=60`.
- Remote Lua console in ScummVM: `autorun/rl.sh start N`, then `rl2.sh 'lua'` (env SCUMMVM_LUA_REMOTE). The
  global `R` is returned and reset on each command, so keep results in another global (`RR`).

## 4. The scripted playthrough (autorun)

Detailed docs: `autorun/PROGRESS.md` (chapter table), `TESTS.md`, `TEST_PLAN.md`, `NAV_PLAN.md`, `STATE_PLAN.md`,
`ACCURACY_PLAN.md`, `COLLISION_FIX_PLAN.md`.

- **The whole game is scripted:** ch01..ch65 (ch65 ends in the credits). Each chapter passes standalone.
  `ar_lib_legacy.lua` serves ch01-ch14 and `ar_lib.lua` ch15+ (`AR_NEW = TRUE`); run_chapter/run_all choose by name.
  Other libraries: `ar_nav.lua` (A* over sector dumps), `ar_helpers.lua`, `ar_routes_original.lua`, `ar_safe.lua`.
- **Everything goes through real keys,** like a player: walking is keys only since 2026-10-23
  (`ar_steer`/`ar_walk_stick`/`ar_nav` + `ar_walk_path`); verbs via `ar_do` (walk, face, gaze makes it the hot
  object, press key); items via hotkeys (`ar_hold`); doors via `ar_go(door,target,viaX,viaY,viaZ)`; driving
  via held keys (`ar_drive_to`, `ar_axe_drive_to`). A failed check ends the run (fail fast; `AR_KEEP_GOING`).
  `ar_describe()` lists the touchable objects and verbs in the current set. Use `ar_fr(n)` for frame thresholds.
- **Run commands** (from an MSYS2 UCRT64 shell; tool calls time out at 600 s, so run long ones detached with
  `setsid nohup` and poll the log):
  - `SIMFPS=60 sh run_all.sh 6000`: full game, ~310 s, passed 3/3 (logs/all.log).
  - `sh run_chapter.sh chNN.lua`: one chapter.
  - Env vars: FRAMES/DUMPDIR/REAL (no skips, voices)/LOG/SAVES/EXTRALIB/GRIMOFF/GRIMON/TESTSETS/SIMMS.
  - Never leave a `ch*_dbg.lua` in the autorun dir, because run_all globs `ch*.lua`. Never edit `generated/`.
- **Save slots:** each chapter saves once with `ar_checkpoint(N)`, where N is its position among the ch*.lua
  files (ch01=1 ... ch47a=47, ch47b=48 ... ch64=65). The next chapter starts with `ar_load(N)`. Notes that
  mention grim10..grim80 use the old numbering. Stale saves need to be rebuilt after lib changes
  (`rebuild_saves.sh`).
- **Gotchas:**
  - Inventory cannot be opened near hl_door_trigger/elevator triggers, so `ar_hold` before you arrive.
  - The ev be_box elevator fires if the path crosses it (use a via point).
  - The first entry to tb runs a cutscene that ends in tw.
  - The xb bridge must be extended before tx.
  - In cc, ce_door triggers the Lupe grab until she has been spoken to.
  - Hot sectors fire only on entering.
  - ch38 needs `SetImmediateTasks(TRUE)` around the Pearl cutscene.
  - ch46: close the vault door first.
  - ch47 belt is pushed per frame.
  - Stick walks spiral (use `ar_hop`).
  - Actors (Glottis, forklift) collide but nav ignores them, so chapters add waypoints.
  - Long movies need `AR_CONTROL_TIMEOUT`.
  - Inventory of the dying Manny: hotkey + use key twice.
  - Meadow: enter the me_salcu camera sector before talking to Salvador's head.
  - zw trail grinding needs flowers inside the trail* sectors on their centre lines.
- **Tools:**
  - `tools/digest.py file.lua`: state-changing lines per function.
  - `gt.sh`: voice text lookup.
  - Engine `DumpSectors()` + `tools/sectors.py log` / `autorun/sectors.sh set`: plot sectors.
  - `plan_route.py`.

## 5. Running the original exe

- **Install exe** = v1.01 extracted from GFUPD101 + `patch_debuglog.py` + autorun patches in `gfupd/v101_autorun.exe`:
  - TextAllowed check skipped (file offset 643658+2: 74->EB).
  - ExperimentalDisplay check NOPed (7622+2).
  - GetKeyState(Backspace) NOPed (9708+11).
  - WM_ACTIVATE/WM_ACTIVATEAPP patched so the game doesn't pause unfocused.
  - Fixed 17 ms frame time: `patch_simtime.py`; switch with `sh tools/orig_clock.sh simtime|realtime`.
  - 60 fps limiter: `patch_framelimit.py` (GrimFrameLimit in grimdlg.dll; the stub must not overwrite the
    NUL of the last string in the .text cave).
  - The original runs with ScummVM's Lua patches (GRIMDATA/DATA006.LAB).
- **Lua injection:** with Backspace held, F12 calls `lua_dofile("grimpatch.bin")` from GRIMDATA (window proc
  0x402fd0). Lua init at 0x49de00 checks the registry value `TextAllowed` = "true" (HKLM\SOFTWARE\WOW6432Node\LucasArts
  Entertainment Company LLC\Grim Fandango\v1.0); the patch above skips that check.
  - grimpatch.bin must have **CRLF** line ends; write it with `mk_grimpatch.py`/`mk_cmd.py` (python text mode).
  - It must not end with `local x = dofile(..)`; end it with a PrintDebug.
  - F12 must be PostMessage'd to all 3 game windows.
- **Logging:** retail `PrintDebug` (0x49ddd0) is a no-op. `patch_debuglog.py` points the PrintDebug/Warning/Error
  slots (0x4eab8c/94/9c) at stubs in .text slack (0x4d6120) that call `grimdlg.dll` (`grimdlg/`, build with
  MSYSTEM=MINGW32, 32-bit). Output goes to `GRIMDATA/grimdebug.log`.
- **Launcher:** the exe crashes (AV in the software blitter) ~10 s after start without a debugger attached, so
  `crashdbg/grimrun2.exe` runs it under DEBUG_ONLY_THIS_PROCESS with `-w` and prints registers/stack on an AV.
  `run_original.sh` deletes the HKCU VirtualStore LucasArts key before each run and honours `GRIMRUN=` (e.g.
  `./grimtrace.exe`, `./imtrace.exe`).
- **Scripts:**
  - `build_original.sh` writes GRIMDATA/autorun_all.lua + grimpatch.bin (sets AR_ORIGINAL).
  - `orig_all.sh [chNN]` runs the whole game in pieces, retrying a failed chapter 3x, then skipping.
  - `resume_original.sh <slot> <chapter>`: slot = chapter number - 1.
  - `TESTFILE=... resume_original.sh 19 test` and `orig_test.sh <test.lua>` run tests.
  - `orl.sh 'lua'` / `orl.sh -f file.lua` is the remote Lua console. Start with `run_original.sh 99999` for no
    auto F12. The console cannot walk Manny and is not callable while the main thread is stuck in a walk.
  - A whole game takes ~1 h at `GRIM_FPS=480` and ~3 h in real time.
- **Saves:** `Load` only works for saves taken in menu render mode: `RenderModeUser(TRUE)`; `Save(..)`;
  `RenderModeUser(nil)` (`ar_checkpoint` does this). Saves taken otherwise load into engine state 4, where actors
  never update.
- **Original-only traps:**
  - The pathfinder (0x4a94d0) takes minutes for targets outside the walk boxes, so walk to the use point and
    then walk_forward through the door.
  - turn_toward_entity on the use point spins forever.
  - The software fill FUN_00474840 AVs on dirty rects with negative y, so keep text y >= 20.
  - The elevator door closes on an 8-10 s timer.
  - Beaver-lobby rocks are collision spheres.
  - No actor moves while a movie plays.
  - A key release must be sent (`ar_key_up`).
  - UnShrinkBoxes must be called before leaving a set that shrank boxes, or the original crashes.
  - The credits skip is exit_the_game.
- **Known original failures:** ch23 (police-station stair, -3.55 5.78), ch47b (belt drift loop), ch50 (temple back
  stairs, -6.98 26.2); tests `pc_stair_to_morgue`, `bs_stair_down`. ch06/25/27/64 need retries.
- **Sound freezes on the original are an original bug, not ours.** IMUSE.DLL's guard counter `DAT_100172c0` is a
  non-atomic INC/DEC. A race between the WINMM timer thread's heartbeat and a main-thread `ImGetParam` loses an
  update, and the counter stays at 1 forever. Heal it by writing 0 at iMUSE base + 0x172c0. Higher fps means more
  freezes. Tools: `tools/audio_snap.py`, `audio_hb.py`, `audio_probe.py`, `watch_audio.sh`, `crashdbg/imtrace.exe`
  (ring buffer to GRIMDATA/imtrace_ring_1.log).

## 6. Lua / engine pitfalls

- Lua 3.1:
  - No `break` (use a flag).
  - Closures cannot see enclosing locals (use globals).
  - No `local function` in orl files.
  - `local a, b` without init may fail.
  - Max 32 locals per function.
  - FALSE is nil.
- ScummVM's Lua `format("%s")` dropped the last character (use `..`). The commit "LUA: Leave room for the padding
  width in the %s format" may have fixed it; verify before relying on it.
- Lua saves store C functions by index in the luaL_reg tables, so a new builtin must go **at the end** (e.g.
  `DumpSectors` at the end of grimMainOpcodes, re-registered in postRestoreHandle). Inserting one in the middle
  hangs old saves on load.
- ScummVM runs tasks created by start_script only when the creator yields; the original starts them at once
  (`SetImmediateTasks`). Tasks run in start order, so EXTRALIB must come first.
- Mid-chapter saves hold the old helper tasks (the lib stops them by task id).
- Engine needed two video guards (video_decoder.cpp AudioTrack rate 0) and `StopMovie()` before skipping cutscenes.
- Quoting: python heredocs and sed turn `\n` into real newlines inside C/Lua strings, so use Edit/Write for those files.
- The Bash tool sometimes hits classifier errors; use PowerShell then.

## 7. Engine port status and open differences

### Frame-match pipeline (2026-10-27)
- ScummVM: `EXTRALIB=fullcmp_lib.lua LOG=ft_sv SIMMS=17 SIMFPS=60 sh run_all.sh 7000`.
- Original: `EXTRALIB=/c/Users/Joel/grim_tools/autorun/fullcmp_lib.lua sh orig_all.sh [chNN]`.
- Compare: `python3 tools/ftrace_cmp.py logs/ft_sv.log logs/ft_orig_new.log 0.01 0.05 4`. The oracle log
  `logs/ft_orig_new.log` covers ch01-ch19.
- AR step timing: `tools/arlines.py <log> chNN`.
- Goldens: `tools/golden_*.sh` (`golden_all.sh`; ch01 had its first difference at frame 2807).
- Bisect rules with GRIMOFF/GRIMON (chore_timing turn_actor_to path_planner movie_frame walk_sectors
  sim_short_frame; also exact_edges, turn_key_rule).
- Tracing the original: `GRIMRUN=./grimtrace.exe GRIMTRACE_BP=4a8610 GRIMTRACE_PEEK="ecx+0,ecx+18" sh orig_test.sh x.lua`.
  Useful BPs: 4a8610 (walk state), 4a83ce/4a843e (turn in/out), 4912e4 (yaw vector).
- Bit comparison: `tools/walk_exact.py`. The ScummVM log needs `DEBUGFLAGS=actors` for WALKSEC/UPDYAW/TURNH lines.
- Frames: `tools/framecap.py` + `framediff.py`. Coverage: `tools/covreport.py`.

### Bit-exact lesson
The original keeps intermediate values unrounded on the x87 stack and rounds to float only at FSTP (often once
per line). Match where it stores. Float constants matter (`90.2f`, not `90.2`).

### Ported exactly
- Sector geometry, welding, tolerance and search order.
- Planner (Planner_* 0x4a9430 family, `Set::grimPlanPath`).
- Walker_WalkSectors (`Actor::grimWalkSectors`).
- Constraint (FUN_004a7520).
- Actor_GetYawToPoint; TurnActorTo.
- Chores (CHORE.DLL: first update takes dt, ends at >= length).
- SetRot deadband 0.5 deg; TurnKey for one frame.
- setpos clamp (FUN_004a82c0); grimFindExitPoint; grimClampPoint; GetSectorOppositeEdge.
- Box collision (FUN_00494100); ShrinkBoxes.
- sin/cos tables (`tools/origmath/check.sh`).
- Puck (FUN_00490f50).
- SetSoundPosition (linear falloff).
- Clip planes / shadow validity.
- Lipsync phoneme table.
- No actor update in a frame that began in a movie; sim clock first frame 17 ms.

### Open
- Speech/voice duration (ch05 first line: 260 frames muted, 522 unmuted, 656 in the original).
- ch06 f153 position; ch08 f20 cutscene level; ch13 f669.
- Planner obstacle avoidance (FUN_004917e0) and collision replan (moveTo skips collisions during path walks).
- Funnel sectors (+0x78 unknown).
- Collision tier is chaotic on the original run to run (head-on slides go either side; tests accept the mirror,
  `nav_known.lua`, `SYM=1`).
- `cheat_roof` (in the original, rf:switch_to_set() ends in Ledge), `stairs_narrow_side`, `ledge_window`.
- Attached-joint rotation FIXME in Actor::draw; ChangePrimitive offsets.
- Glottis' wagon parks at different spots per frame rate.
- GetActorYawToPoint FUN_004a8500 is not ported (it regressed stairs).

### Turning port (`grim-time-scale`, 2026-10-28)
- A walker model shared by Grim and EMI ports Actor_UpdateWalker / Walker_UpdateYaw / Actor_UpdateMoveChores.
  After simplification only `_smoothTurns` (enable/disableSmoothTurns) is kept; a flagged SetActorRot eases only
  with a walker. Grim's pending negative-rate jump is dropped as an original bug. Save minor 31.
- Turn tier `ar_nt_turn_*` passes on the original 26/26 and on ScummVM 22/22 (via the debugLua hook).
- Not ported: Math_SinCosTable off-by-one (grim-actor-fixes has the table), the 70 ms chore advance at start.
  The EMI side is untested.

## 8. Tests

- `python tools/test_all.py scummvm` runs 6 tiers side by side in ~47 s.
- `sh run_repeat.sh 1` repeats full runs. Run both after any actor.cpp change.
- Offline tier A: `nav_cases.lua` under `tools/lua31`.
- In-game tiers: `test_nav.lua` (unit, walk, move, coll, slide, turn); `test_rules.lua` (273 cases; known
  differences in `rules_known.lua`).
- Expected values recorded on the original: `nav_coll_expect.lua`, `nav_slide_expect.lua`, `rules_expect.lua`.
- Fixtures: `ar_fixture.lua`; hand-made sets in `tests/sets` (`TESTSETS=1`); probes in `tests/probe_*.lua`.
- Compare logs: `tools/compare_navtest.py a.log b.log [mode]`.
- See `autorun/TESTS.md` for each "Added <date>" section.

## 9. Ghidra lookup trick

Lua builtin names in GRIMFANDANGO.EXE aren't defined strings, so `search_strings` finds nothing:
1. `search_byte_patterns` with the ASCII hex of the name (GetVisibleThings is at 0x4ebfe8).
2. Search for that address as little-endian bytes. This finds the registration table near 0x4eaa00
   ({name ptr, func ptr} pairs).
3. Decompile the function pointer that follows the name.

Layout: actor+0xa0 is the top costume record (linked list via record[0x2c]); record[1] = main model;
record[3..5] = head joints; record+0x24 = cos(|maxRoll|/2).

## 10. EMI

`emi_autorun/PROGRESS.md` covers the Monkey 4 playthrough (built on the Grim libraries; worktree `~/scummvm-emi/build-opt`).

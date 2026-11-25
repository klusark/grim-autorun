# scummvm/: the ScummVM of grim_tools

One patch on upstream ScummVM master, and the scripts that apply it and build it, shared by the autoruns
(`autorun/`, `emi_autorun/`), the clean-room tests (`cleanroom/`) and CI (`.github/workflows/scummvm-*.yml`).

| File | What it is |
|---|---|
| `grim-tools.patch` | Everything the tools need from the engine (below). Made on master 026c00f44cf. |
| `lua-coverage.patch` | Optional, on top of it: which functions, lines and instructions of the Lua ran (`GRIM_LUA_COVERAGE`). |
| `prepare.sh` | Applies the patch(es) to a checkout (`--lua-coverage`; `--no-patch` applies nothing). Safe to run again. |
| `configure.sh` | `configure.sh release\|gcov [build folder]`: the one configure line of every build (Grim and EMI only, ccache). |
| `build.sh` | The local build: worktree `~/scummvm-patched` (made on origin/master the first time), `prepare.sh`, `configure.sh`, make. |

## Building

From an MSYS2 UCRT64 login shell:

```sh
bash scummvm/build.sh                 # ~/scummvm-patched/build-opt/scummvm.exe (release)
bash scummvm/build.sh --gcov          # ~/scummvm-patched/build-cov (gcov, -DCR_GCOV), for cleanroom/tools/parallel.sh --coverage
bash scummvm/build.sh --lua-coverage ~/scummvm-luacov   # with lua-coverage.patch, in a worktree of its own
```

To move to a newer master: `git worktree remove ~/scummvm-patched`, then `build.sh` again. When the patch stops applying,
rebase it on master in a worktree and write it again with `git diff origin/master > scummvm/grim-tools.patch`.

Who uses the build:

- `cleanroom/run.py`: `~/scummvm-patched/build-opt/scummvm.exe` by default (`SCUMMVM=` for another).
- The autoruns: `autorun/run_all.sh`, `run_chapter.sh`, `tools/svm_ps.sh` and `emi_autorun/run_emi.sh` default to
  `~/scummvm-patched/build-opt` (`SVM_DIR=` for another; the old `autorun` branch is `/home/Joel/scummvm-autorun/build-opt`).
- CI: `prepare.sh` and `configure.sh` in the checkout of the branch under test.

## What the patch does

- `--autorun=FILE`: runs a Lua file as a game script once a set is up (and again after a load, with `AR_LOADED`).
- The simulated clock: `--sim-fps=N` or `sim_frame_ms` in the ini makes every frame a fixed length however long it took.
  The mixer, the video decoders, the SMUSH timer and iMUSE then run on that game time, once a frame, as the original does with
  grimlaunch's simtime, smushtime and imusetime patches. EMI's test data keeps its sound and movies on the clock, as its
  original does. In Grim the actors are not updated in a frame that began with a movie, as in the original.
- Skipped frames: with the simulated clock one frame in `sim_render_every` (default 8; 0 = only those that must be) is
  drawn, plus each change of set, setup or mode and each new movie picture; a frame not drawn still does the draw path's
  updates (`updateUndrawnFrame`).
- `SCUMMVM_LUA_REMOTE=<dir>`: runs `<dir>/cmd.lua` when it appears (stall_watch.sh's script dumps, `rl.sh`).
- The clean-room test data (`GF_TESTDATA`, marker files `grimtestdata.txt`, `grimremasteredtestdata.txt`, `emitestdata.txt`):
  loose files and the folder's own archives, no update or patch archive, no md5 check or music-table dialog, `error()` exits
  at once, minidumps of crashes, `PrintDebug("CRSNAP:<file>")` screenshots, `PrintDebug("CRGCOV")` coverage dumps, no logo.
- `antialiasing=0` in the ini skips the SDL backend's anti-aliasing probe (a faster start).
- The same table order in every run: Lua tables hash strings by their text's hash and tables, closures and prototypes by
  a creation number (`GCnode::seq`, counted from 0 again at `lua_open` and `lua_Restore`), not by their address, so
  `next()` walks a table in the same order from run to run and build to build (the EMI poker's object order changed
  between runs). C functions as keys all hash the same and keep their insertion order.

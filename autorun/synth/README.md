# Tests without game data

`sh synth/run.sh` plans and follows ways on small sets made for the purpose (`synth/sets/*.set`, the text format of the game's set files), with the
Lua 3.1 of the game replaced by Lua 5.1 (`compat.lua`). It runs `ar_nav.lua` as it is, so a change of the planner or the follower is tested in a
second, without ScummVM, the game or its archives.

* `test_planner.lua`: ways across rooms, no way between islands, a gate that is off, a 12 cm neck, a ramp.
* `test_follow.lua`: a simulated Manny (turns at a fixed rate, steps 2.5 cm, does not move into a place that is no sector) follows the way; the rule that
  a turn is not cut over the void beside a ramp (chapter 50) is checked on its own.

Adding a check: a set in `sets/` (corners as in the game's files), `defset` in `run.lua`, a `check(name, ok, why)` in a test file. A check for a fix
should fail on the code before the fix: `git show <commit>:autorun/ar_nav.lua > /tmp/old.lua; AR_NAV_FILE=/tmp/old.lua sh synth/run.sh`.

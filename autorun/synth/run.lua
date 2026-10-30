-- The tests that need no game data: the planner (ar_nav.lua) and its follower on the sets of synth/sets, in Lua 5.1 with synth/compat.lua.
--   cd autorun && lua5.1 synth/run.lua [name part]      (synth/run.sh does that)

SYNTH_DIR = "synth"
dofile("synth/compat.lua")
dofile("tools/lua31/prelude.lua")
dofile(os.getenv("AR_NAV_FILE") or "ar_nav.lua")
dofile("nav_setfile.lua")

-- (what the game gives a script: a pause for a frame, here nothing)
break_here = function() end
sleep_for = function() end

AR_SETS = { }
local function defset(name, file)
	AR_SETS[name] = { file = file, global = name, cheat = { }, door = { } }
end
defset("flat", "flat.set")
defset("ramp", "ramp.set")
defset("neck", "neck.set")
defset("islands", "islands.set")
defset("gate", "gate.set")

local only = arg and arg[1]
local passed, failed = 0, 0
local failures = { }

function check(name, ok, why)
	if only and not string.find(name, only, 1, true) then
		return
	end
	if ok then
		passed = passed + 1
	else
		failed = failed + 1
		failures[#failures + 1] = name .. ": " .. tostring(why)
		print("FAIL " .. name .. ": " .. tostring(why))
	end
end

-- The set under its name, with Manny at (x, y) on it; returns the set, its nav and the world of the planner.
function place(name, x, y)
	local set = ar_off_set(name)
	system.currentSet = set
	local nav = ar_nav_of(set)
	AR_OFF = { }
	local i = 1
	while nav.off[i] do
		AR_OFF[nav.off[i]] = TRUE
		i = i + 1
	end
	if nav.w then
		nav.w = nil
	end
	local z = 0
	local si = ar_nav_find_z(nav, x, y, 0, 100)
	if si then
		z = ar_nav_z(nav, si, x, y)
	end
	manny.pos = { x = x, y = y, z = z }
	manny.rot = { x = 0, y = 0, z = 0 }
	AR_GOAL_REGION = nil
	AR_GOAL_HOT = { }
	AR_NAV_GOAL_X = nil
	AR_ALLOW_PARTIAL = nil
	return set, nav, ar_w(nav)
end

-- The way from (x1, y1) to (x2, y2): the list of points, or nil.
function plan(name, x1, y1, x2, y2)
	local set, nav, w = place(name, x1, y1)
	local si = ar_nav_find_z(nav, x2, y2, manny.pos.z, 100)
	local gz = 0
	if si then
		gz = ar_nav_z(nav, si, x2, y2)
	end
	return ar_w_plan(nav, w, x2, y2, gz), nav, w
end

function pathlen(path)
	local n = ar_nav_len(path)
	local l = 0
	for i = 2, n do
		l = l + math.sqrt((path[i][1] - path[i - 1][1]) ^ 2 + (path[i][2] - path[i - 1][2]) ^ 2)
	end
	return l
end

dofile("synth/test_planner.lua")
dofile("synth/test_follow.lua")

print(string.format("SYNTH SUMMARY %d passed, %d failed", passed, failed))
if not SYNTH_NOEXIT then
	os.exit(failed == 0 and 0 or 1)
end

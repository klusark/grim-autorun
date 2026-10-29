-- The rules of the engine on hand-made sets (tools/mk_set.py, tests/sets; STATE_PLAN.md step 4): which sector holds a point, how Manny walks and turns,
-- what he does at an edge, a gap, a wall, a corner, a stair, a sliver. No story, no scripts of a set: the geometry is in the test.
-- The expected values are the ones of the ORIGINAL (rules_expect.lua, recorded from "NAVTEST rules_rec" lines of its log); a case without one only records.
--   ScummVM:  TESTSETS=1 EXTRA="nav_cases.lua ar_fixture.lua ar_nt_lib.lua rules_expect.lua nav_known.lua" sh run_chapter.sh test_rules.lua 600
--   original: sh orig_test.sh test_rules.lua 1800 logs/orig_rules.log       (needs tests/sets/DATAUSR.LAB in GRIMDATA)
-- AR_RULES_ONLY = "<id prefix>" runs part of it.

ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE
ar_fx_make_sets()
AR_NT_RUN.rules = 0
AR_NT_PASS.rules = 0

RULES = { }
RULES_N = 0
ar_rule = function(c)
	RULES_N = RULES_N + 1
	RULES[RULES_N] = c
end

-- which sector holds a point (the first answer of IsPointInSector; a point on an edge is the interesting one)
ar_rule_points = function(set, list)
	local i = 1
	while list[i] do
		local p = list[i]
		ar_rule({ id = "point_" .. set .. "_" .. p[1] .. "_" .. p[2], kind = "point", set = set, from = { p[1], p[2], p[3] or 0 } })
		i = i + 1
	end
end
ar_rule_points("t_edge", { { 0, 0 }, { 0, 1 }, { 0, -1.99 }, { -1, 0 }, { 1, 0 }, { 0.00001, 0 }, { -0.00001, 0 }, { 0, 2 }, { 0, 2.00001 }, { 0, 2.00003 }, { -2, 0 }, { -2.00001, 0 }, { 2, 0 }, { 2, -2 }, { 3, 0 }, { 3, 1.9 }, { 0, -2.00001 }, { 0, -2.00003 }, { 0, -3 } })
ar_rule_points("t_stair", { { 0, 0 }, { 0, 0.5, 0.3 }, { -2, 0.5, 0.15 }, { 2, 0.5, 0.5 }, { 0, 1.0, 0.6 }, { 0, 0.999, 0.6 }, { -2, 0, 0 }, { -1.25, 0.5, 0 }, { 0, 1.5, 0.6 } })
ar_rule_points("t_sliver", { { -1.5, 0 }, { -1, 0 }, { -0.985, 0 }, { -0.97, 0 }, { -0.945, 0 }, { -0.92, 0 }, { -0.87, 0 }, { -0.82, 0 }, { 0, 0 }, { -2, 1.01 }, { -2, 1.03 } })
ar_rule_points("t_flat", { { 0, 0 }, { 2, 0 }, { 2.00001, 0 }, { 2, 2 }, { 1.99999, 1.99999 }, { -2, -2 } })

-- walks: from a point with a heading, a turn key held (-1, 0, 1) or not, a number of frames of walk_forward
ar_rule_walk = function(id, set, from, yaw, key, frames, run)
	ar_rule({ id = id, kind = "walk", set = set, from = from, yaw = yaw, key = key, frames = frames, run = run })
end
local yaws = { 0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330 }
local keys = { -1, 0, 1 }
local i = 1
while yaws[i] do
	-- the rate of the walk and the heading, in the open: the same start, every heading
	ar_rule_walk("flat_dir_" .. yaws[i], "t_flat", { 0, 0, 0 }, yaws[i], 0, 30)
	ar_rule_walk("flat_run_" .. yaws[i], "t_flat", { 0, 0, 0 }, yaws[i], 0, 30, TRUE)
	local k = 1
	while keys[k] do
		-- into the wall of the floor, with the turn key held or not (the reflection and the slide of the sector walk, FUN_004a8610)
		-- (the start is 0.4 m before the wall the heading goes to)
		local dx = -sin(yaws[i])
		local dy = cos(yaws[i])
		local m = abs(dx)
		if abs(dy) > m then
			m = abs(dy)
		end
		ar_rule_walk("flat_wall_" .. yaws[i] .. "_k" .. keys[k], "t_flat", { dx * (2 / m - 0.4), dy * (2 / m - 0.4), 0 }, yaws[i], keys[k], 120)
		-- along and into the shared edge, and into the outer walls of the pair
		ar_rule_walk("edge_cross_" .. yaws[i] .. "_k" .. keys[k], "t_edge", { -0.2, 0, 0 }, yaws[i], keys[k], 80)
		-- the wedge past the corner of 132.7 degrees
		ar_rule_walk("edge_wedge_" .. yaws[i] .. "_k" .. keys[k], "t_edge", { 3, -1, 0 }, yaws[i], keys[k], 80)
		k = k + 1
	end
	-- the gap of 2e-5 (e_gap against the pair) and the sector that is off
	ar_rule_walk("edge_gap_" .. yaws[i], "t_edge", { 0.5, 1.8, 0 }, yaws[i], 0, 60)
	ar_rule_walk("edge_off_" .. yaws[i], "t_edge", { 0.5, -1.8, 0 }, yaws[i], 0, 60)
	-- slivers: across them from the left floor, and the passage of 2.5 cm
	ar_rule_walk("sliver_cross_" .. yaws[i], "t_sliver", { -1.3, 0, 0 }, yaws[i], 0, 150)
	ar_rule_walk("sliver_narrow_" .. yaws[i], "t_sliver", { -2, 0.8, 0 }, yaws[i], 0, 100)
	-- stairs of three slopes: up from the foot, and the other ways
	ar_rule_walk("stair_a_" .. yaws[i], "t_stair", { -2.25, -0.5, 0 }, yaws[i], 0, 200)
	ar_rule_walk("stair_b_" .. yaws[i], "t_stair", { 0, -0.5, 0 }, yaws[i], 0, 200)
	ar_rule_walk("stair_c_" .. yaws[i], "t_stair", { 2.25, -0.5, 0 }, yaws[i], 0, 200)
	ar_rule_walk("stair_top_b_" .. yaws[i], "t_stair", { 0, 2, 0.6 }, yaws[i], 0, 200)
	i = i + 1
end

-- The boxes shrunk, as they are with an item in the hand (ShrinkBoxes, FUN_004a9d00): the nearest place that is still on the floor, and walks along it
ar_rule_shrinkpos = function(set, r, list)
	local i = 1
	while list[i] do
		local p = list[i]
		ar_rule({ id = "shrinkpos_" .. set .. "_r" .. floor(r * 100) .. "_" .. p[1] .. "_" .. p[2], kind = "shrinkpos", set = set, radius = r, from = { p[1], p[2], p[3] or 0 } })
		i = i + 1
	end
end
SP_FLAT = { { 0, 0 }, { 1.95, 0 }, { 1.99, 1.99 }, { 2.5, 0.5 }, { -2.3, -2.3 }, { 0.05, 3 }, { -1.9, 1.95 } }
SP_EDGE = { { 0, 0 }, { -0.05, 1.9 }, { 0.05, 1.9 }, { 0, 2.00001 }, { 1.9, -1.9 }, { 0, -1.99 }, { 0.03, 0.5 }, { -1.95, 0 }, { 3.5, 0 }, { 2.5, 1 } }
SP_STAIR = { { 0, 0.5, 0.3 }, { -2.2, 0.5, 0.15 }, { 0, 0.02, 0.01 }, { 0, 0.98, 0.59 }, { 2.2, 0.5, 0.5 }, { -2.9, 0.5, 0.1 }, { 0, -1.95, 0 } }
SP_SLIVER = { { -0.95, 0 }, { -0.985, 0.5 }, { -1.5, 0 }, { -0.88, 0 }, { -2, 1.012, 0 }, { -2.95, 0.99 } }
ar_rule_shrinkpos("t_flat", 0.1, SP_FLAT)
ar_rule_shrinkpos("t_flat", 0.35, SP_FLAT)
ar_rule_shrinkpos("t_edge", 0.1, SP_EDGE)
ar_rule_shrinkpos("t_edge", 0.35, SP_EDGE)
ar_rule_shrinkpos("t_stair", 0.1, SP_STAIR)
ar_rule_shrinkpos("t_stair", 0.3, SP_STAIR)
ar_rule_shrinkpos("t_sliver", 0.1, SP_SLIVER)
ar_rule_shrinkpos("t_sliver", 0.02, SP_SLIVER)

i = 1
while yaws[i] do
	ar_rule({ id = "shrinkwalk_flat_" .. yaws[i], kind = "walk", set = "t_flat", from = { 0, 0, 0 }, yaw = yaws[i], key = 0, frames = 400, radius = 0.1, shrink = TRUE })
	ar_rule({ id = "shrinkwalk_edge_" .. yaws[i], kind = "walk", set = "t_edge", from = { -0.5, 0, 0 }, yaw = yaws[i], key = 0, frames = 300, radius = 0.1, shrink = TRUE })
	ar_rule({ id = "shrinkwalk_sliver_" .. yaws[i], kind = "walk", set = "t_sliver", from = { -1.3, 0, 0 }, yaw = yaws[i], key = 0, frames = 200, radius = 0.1, shrink = TRUE })
	ar_rule({ id = "shrinkwalk_stair_" .. yaws[i], kind = "walk", set = "t_stair", from = { 0, -0.5, 0 }, yaw = yaws[i], key = 0, frames = 250, radius = 0.1, shrink = TRUE })
	ar_rule({ id = "shrinkwalk_wedge_" .. yaws[i], kind = "walk", set = "t_edge", from = { 3, -1, 0 }, yaw = yaws[i], key = 0, frames = 200, radius = 0.1, shrink = TRUE })
	i = i + 1
end

ar_rule_place = function(c)
	c.set_name = c.set
	return ar_nt_place(c)
end

ar_rule_run = function(c)
	local set = ar_rule_place(c)
	if c.kind == "point" then
		local id, name = IsPointInSector(c.from[1], c.from[2], c.from[3], "")
		return tostring(name)
	end
	if c.kind == "shrinkpos" then
		local x, y, z = GetShrinkPos(c.from[1], c.from[2], c.from[3], c.radius)
		if not x then
			return "nil"
		end
		return nil, x, y, z, 0
	end
	if c.radius then
		-- (the boxes shrunk before the walk, given back by the fixture at the end of the case)
		ShrinkBoxes(c.radius)
		AR_NT_SHRUNK = TRUE
	end
	AR_WALK = TRUE
	manny:set_run(c.run)
	-- (steady frames before the first step; the position and heading of the case again after the wait)
	sleep_for(600)
	manny:setpos(c.from[1], c.from[2], ar_nt_goal_z(ar_nav_of(set), c.from[1], c.from[2], c.from[3]))
	manny:setrot(0, c.yaw, 0)
	break_here()
	break_here()
	local k = 0
	while k < c.frames do
		if c.key ~= 0 then
			TurnActor(manny.hActor, c.key)
		end
		manny:walk_forward()
		break_here()
		k = k + 1
	end
	break_here()
	local p = manny:getpos()
	local r = manny:getrot()
	AR_WALK = nil
	return nil, p.x, p.y, p.z, r.y
end

ar_rule_dyaw = function(a, b)
	local d = a - b
	return abs(d - 360 * floor(d / 360 + 0.5))
end

AR_RULES_N = 0
AR_RULES_I = 1
while RULES[AR_RULES_I] do
	local c = RULES[AR_RULES_I]
	if not AR_RULES_ONLY or strfind(c.id, AR_RULES_ONLY, 1, 1) == 1 then
		-- (the set is a name here: the case places by its global)
		local name, x, y, z, yaw = ar_rule_run(c)
		local want = AR_RULES_EXPECT and AR_RULES_EXPECT[c.id]
		local ok = TRUE
		local msg = ""
		if c.kind == "shrinkpos" and name then
			PrintDebug("NAVTEST rules_rec " .. c.id .. " " .. name .. "\n")
			msg = "no place, " .. name
			if want then
				ok = want[1] == name
				msg = msg .. ", the original: " .. tostring(want[1])
			end
		elseif c.kind == "shrinkpos" then
			PrintDebug("NAVTEST rules_rec " .. c.id .. format(" %.4f %.4f %.4f %.1f", x, y, z, yaw) .. "\n")
			msg = format("%.4f %.4f %.4f", x, y, z)
			if want and want[2] then
				local d = sqrt((x - want[1]) * (x - want[1]) + (y - want[2]) * (y - want[2]) + (z - want[3]) * (z - want[3]))
				ok = d <= 0.005
				msg = msg .. format(", the original %.4f %.4f %.4f", want[1], want[2], want[3])
			elseif want then
				ok = nil
				msg = msg .. ", the original: " .. tostring(want[1])
			end
		elseif c.kind == "point" then
			PrintDebug("NAVTEST rules_rec " .. c.id .. " " .. name .. "\n")
			msg = "in " .. name
			if want then
				ok = want[1] == name
				msg = msg .. ", the original: " .. tostring(want[1])
			end
		else
			PrintDebug("NAVTEST rules_rec " .. c.id .. format(" %.4f %.4f %.4f %.1f", x, y, z, yaw) .. "\n")
			msg = format("ended %.4f %.4f %.4f %.1f", x, y, z, yaw)
			if want then
				local d = sqrt((x - want[1]) * (x - want[1]) + (y - want[2]) * (y - want[2]))
				ok = d <= 0.01 and abs(z - want[3]) <= 0.02 and ar_rule_dyaw(yaw, want[4]) <= 0.5
				msg = msg .. format(", the original %.4f %.4f %.4f %.1f", want[1], want[2], want[3], want[4])
			end
		end
		ar_nt_log("rules", c, ok, msg)
	end
	AR_RULES_I = AR_RULES_I + 1
end
ar_fx_close()
PrintDebug("NAVTEST SUMMARY rules " .. AR_NT_PASS.rules .. "/" .. AR_NT_RUN.rules .. "\n")
PrintDebug("NAVTEST SUMMARY leak " .. AR_NT_PASS.leak .. "/" .. AR_NT_RUN.leak .. "\n")
AR_FAILED = AR_NT_PASS.rules < AR_NT_RUN.rules or AR_NT_PASS.leak < AR_NT_RUN.leak
PrintDebug("NAVTEST SUMMARY unit rules done\n")
AR_KEEP_GOING = nil

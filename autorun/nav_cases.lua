-- The cases of the walker tests (ar_nav.lua) on the real sets, and the check of the plan. The same file runs
--   tier A: offline, in the Lua 3.1 of the game (tools/lua31/run.sh), with ar_nt_place from tools/lua31/offline.lua
--   tier B/C: in the game on either engine (test_nav.lua), with its ar_nt_place that puts Manny into the set
-- NAVTEST lines in the log; the same text on both, so that the logs can be diffed.
AR_NT_PASS = { unit = 0, walk = 0 }
AR_NT_RUN = { unit = 0, walk = 0 }

-- id, set (its global), from { x, y, z }, the goal: to { x, y, z } or door (its name in the set's table), and what is checked:
-- link: a kind of link the plan has to use ("c" a cheat box, "s" a stair); level: the height all the way; tol: how near the walk ends;
-- on: sectors switched on first; yaw: the heading at the start; minlinks: (with no goal) how many links the world of the set has
NAVTESTS = {
	-- stairs: the original walks a constrained Manny only along the line of the stair (SetActorConstrain); ch16 and ch20
	{ id = "stairs_into_door", set = "be", from = { 0.00, 0.66, 0 }, door = "bw_door", link = "s" },
	{ id = "stairs_to_point_on_them", set = "be", from = { 0.00, 0.66, 0 }, to = { 0.06, -0.60, 0.19 }, tol = 0.15 },
	{ id = "stairs_start_on_them", set = "be", from = { 0.02, -0.50, 0.13 }, yaw = 180, to = { -0.01, 0.30, 0 } },
	{ id = "stairs_up", set = "be", from = { 0.05, -0.85, 0.26 }, to = { 0.00, 0.66, 0 }, link = "s" },
	-- a long stair (1.5 m down, ch02), walked on to the floor at its foot
	{ id = "stairs_long_down", set = "os", from = { 0.32, 0.40, 0.01 }, to = { 2.81, -1.35, -0.84 }, link = "s" },
	-- a passage 2.5 cm wide (the bottle, between the table and the fridge), and a goal off the floor (the fridge's use point); ch20
	{ id = "thin_passage", set = "si", from = { -0.22, -0.22, 0 }, to = { 1.14, -0.81, 0 }, on = { "bottle", "bottle1" } },
	-- an L-shaped corridor 12 cm wide on a ledge, with floors over and under it; ch05
	{ id = "narrow_corner_ledge", set = "le", climbs = TRUE, from = { -0.05, 2.36, 1.2 }, to = { -1.16, 3.65, 1.2 }, level = 1.2 },
	-- a cheat box over the whole corridor; ch01
	{ id = "cheat_hallway_east", set = "ha", nowalk = TRUE, offline = TRUE, from = { 0.84, 0.12, 0 }, to = { 6.20, 0.60, 0 }, link = "c" },
	{ id = "cheat_hallway_west", set = "ha", nowalk = TRUE, offline = TRUE, from = { 6.20, 0.60, 0 }, to = { 0.84, 0.12, 0 }, link = "c" },
	{ id = "cheat_hallway_from_box_edge", set = "ha", from = { 4.16, 0.60, 0 }, to = { 0.84, 0.12, 0 } },
	-- eight cheat boxes in the garage; ch02, ch03
	{ id = "cheat_garage_across", set = "ga", from = { 0.83, 9.64, 0 }, to = { 17.72, 5.57, 0 }, link = "c" },
	{ id = "cheat_garage_back", set = "ga", from = { 15.62, 0.80, 0 }, to = { 1.42, 9.90, 0 }, link = "c" },
	{ id = "cheat_garage_short", set = "ga", from = { 12.70, 7.20, 0 }, to = { 15.77, 0.22, 0 } },
	-- the alley's cheat box between the street and the rope
	{ id = "cheat_alley", set = "al", from = { 0.08, 1.44, 0 }, to = { -0.36, 7.59, 0 }, link = "c" },
	{ id = "cheat_alley_back", set = "al", from = { -0.31, 7.58, 0 }, to = { 0.08, 1.44, 0 }, link = "c" },
	-- the roof's cheat boxes
	{ id = "cheat_roof", set = "rf", from = { -13.44, 11.05, 3.72 }, to = { -2.31, 4.77, 3.72 }, link = "c", on = { "bird_threshhold" } },
	-- a door (the elevator) whose sector is entered at its edge; ch01
	{ id = "door_elevator_hq", set = "hq", from = { 0.50, 0.00, 0 }, door = "al_door" },
	-- the original, ch13: from the spot by Velasco back to the door of the interior (held up there on the first steps)
	{ id = "re_velasco_to_door", set = "re", from = { 0.585, -4.258, 0 }, door = "ri_door" },
	-- an actor that holds Manny up (learned on the walk, the box of Velasco in ch13): the way goes round it, where the floor is wide
	{ id = "obstacle_none", set = "re", from = { 1.6, -4.0, -3.4 }, to = { 3.4, -4.2, -3.4 } },
	{ id = "obstacle_detour", set = "re", from = { 1.6, -4.0, -3.4 }, to = { 3.4, -4.2, -3.4 }, obst = { { x = 2.5, y = -4.1, r = 0.6 } }, clear = 0.2 },
	{ id = "obstacle_detour_wide", set = "re", from = { 1.6, -4.0, -3.4 }, to = { 3.4, -4.2, -3.4 }, obst = { { x = 2.5, y = -4.1, r = 0.9 } }, clear = 0.3 },
	{ id = "obstacle_start_inside", set = "re", from = { 2.3, -4.1, -3.4 }, to = { 3.4, -4.2, -3.4 }, obst = { { x = 2.5, y = -4.1, r = 0.6 } }, clear = 0.1 },
	{ id = "obstacle_two", set = "re", from = { 1.6, -4.0, -3.4 }, to = { 3.4, -4.2, -3.4 }, obst = { { x = 2.3, y = -3.9, r = 0.5 }, { x = 2.9, y = -4.4, r = 0.5 } }, clear = 0.15 },
	-- a door at the top of a ladder (the sewer hub, ch54): no way over the floor, the follower climbs when the scene of the ladder puts Manny on it
	-- (the game only; the plan has no way, the walk finds the ladder)
	{ id = "ladder_up_to_door", set = "sh", from = { 0.61, -0.05, 0.39 }, door = "te_door", off = { "glottis_gone", "bw_up1", "bw_up2", "bw_up3" }, ingame = TRUE, nounit = TRUE, enter = TRUE, climbs = TRUE },
	-- a goal in the middle of a stair, from the landing below it (a moving target stands there: the walk goes up toward it)
	{ id = "goal_on_stair_mid", set = "ly", from = { 0.14, 0.17, 0.09 }, to = { 0.12, 0.50, 0.09 }, tol = 0.6 },
	{ id = "goal_on_stair_top", set = "ly", from = { 0.14, 0.17, 0.09 }, to = { 0.10, 0.86, 0.09 }, tol = 0.6 },
	-- the stair of the police station down to the morgue door (ch23): the original is held up on it at -3.55 5.78 every time, the run of ScummVM walks it
	{ id = "pc_stair_to_morgue", set = "pc", from = { -3.751, 7.790, 12.596 }, to = { -2.525, 5.440, 11.600 }, tol = 0.3 },
	-- the back stairs of the temple (ch50): the original is held up at -6.98 26.2 a few seconds down them, every time
	{ id = "bs_stair_down", set = "bs", from = { -6.760, 27.555, 12.418 }, door = "td_door", ingame = TRUE, nounit = TRUE },
	-- two stairs one after the other with a landing 8 cm wide between them (ch15)
	{ id = "stairs_two_flights", set = "ev", from = { -0.46, -0.85, 0.05 }, door = "ce_door", link = "ss" },
	-- standing on a stair 25 cm wide, seen from the side (ch15, arriving by the door at its top)
	{ id = "stairs_narrow_side", set = "ev", from = { 0.79, 1.0, 1.1 }, yaw = 0, door = "be_door", link = "ss" },
	{ id = "stairs_narrow_back", set = "ev", from = { 0.79, 1.0, 1.1 }, yaw = 180, door = "be_door", link = "ss" },
	-- arriving by a door leaves Manny off the floor, half a metre from it (ch18)
	{ id = "start_off_floor", set = "cn", from = { 0.93, -0.27, 0 }, door = "ci_door", enter = TRUE },
	-- arriving in the hub from the foreman's office, inside the hot sector of its door, and out of it toward the airlock (ch41): the game took Manny back through the door
	{ id = "fh_from_fo_to_ea", set = "fh", from = { -0.93, -2.86, -1.28 }, door = "ea_door", yaw = 180 },
	{ id = "fh_top_edge_to_ea", set = "fh", from = { -1.10, -2.77, -1.28 }, door = "ea_door", yaw = 65 },
	-- a stair that ends on a landing 8 cm wide, entered from the floor at its foot (ch18)
	{ id = "stairs_to_sliver", set = "ts", from = { 1.13, 0.56, 0 }, door = "tb_door", link = "s" },
	-- the ledge outside the office window (ch02): a goal 3 cm off the floor
	{ id = "ledge_window", set = "le", from = { 0.40, 1.32, 0 }, to = { 0.10, 0.67, 0 } },
	-- along the edge of a diagonal band of floor, to a goal at its wall: the way keeps off the edge (ch04, the tube in the office)
	{ id = "band_to_wall_goal", set = "mo", from = { 1.41, 0.04, 0 }, to = { 0.70, 2.17, 0 }, edge = 0.04 },
	-- the same with the boxes shrunk, as they are with an item in the hand: the edge between two floors is a gap the game does not let
	-- Manny walk square through (ch04, the red balloon)
	{ id = "band_shrunk", set = "mo", shrink = TRUE, from = { 1.41, 0.04, 0 }, to = { 0.70, 2.17, 0 } },
	-- a way of slivers of sectors, 3 to 10 cm wide, 1.9 m long, the only one from the rock of the dam to the beaver room (ch11)
	{ id = "dam_slivers", set = "bd", from = { 3.87, 2.74, -0.10 }, to = { 1.65, 0.56, 0.23 } },
	-- arriving in the garage by the door to the hallway: the pocket there is cut off from the garage by a passage that is off until Manny steps
	-- into the trigger of the door (ch01); the way over it is planned as if it were on
	{ id = "garage_pocket", set = "ga", nowalk = TRUE, from = { 15.63, -0.44, 0 }, to = { 1.42, 9.90, 0 }, tol = 0.15 },
	-- down the long ramp of the cafe to the lower floor (ch17)
	{ id = "cafe_ramp_down", set = "ci", from = { 0.24, 0.56, 0 }, to = { 0.35, 1.75, -1.40 } },
	-- along the extend-o-bridge: its walkways are at different heights and joined by sectors that carry Manny on (ch21): as far as the floor goes
	{ id = "bridge_partial", set = "xb", nowalk = TRUE, from = { 39.79, -12.88, 1.00 }, to = { 36.0, -13.9, 1.5 }, partial = TRUE, tol = 9 },
	-- winding stairs: six flights over each other, and the door of the shuttle in the sector half way up (ch21)
	{ id = "door_on_winding_stairs", set = "gt", from = { -0.56, 6.31, 19.51 }, door = "sl_door", link = "s" },
	-- a stair that ends in a landing 4 cm deep, and the door over it (ch22)
	{ id = "stair_to_sliver_door", set = "sl", from = { -1.06, 0.0, 0 }, door = "gt_door", off = { "carlawalk1", "intro_trigger" } },
	-- a door whose sector lies over the top of a stair that ends in no floor, 3 cm of constrained strip (ch50)
	{ id = "door_over_stair_top", set = "td", from = { 0.67, -2.62, -0.02 }, door = "bs_door", off = { "sigh_box" } },
	-- the door of the workshop is under the upper floor that Manny is on: down the stair first (ch50)
	{ id = "door_below_upper_floor", set = "my", from = { 1.56, 0.41, 0.8 }, door = "mk_door", link = "s" },
	-- a door Manny stands in already: out and in again
	{ id = "door_from_inside", set = "mo", from = "door", door = "ha_door" },
	-- the doors of the beaver lobby that move Manny within the set (lb_cheat1, lb_cheat2), a long way
	{ id = "lobby_long", set = "lb", from = { 0.42, -2.59, 0 }, to = { 11.78, -8.66, 0 } },
	-- the worlds of the sets with cheat boxes: links over every one
	-- the sectors that are off, as the probe sees them: the same list has to come out on both engines and offline
	{ id = "probe_hallway", set = "ha", probe = TRUE },
	{ id = "probe_garage", set = "ga", probe = TRUE },
	{ id = "probe_cafe", set = "ci", probe = TRUE },
	{ id = "probe_ship", set = "si", probe = TRUE, on = { "bottle", "bottle1" } },
	-- the sectors as the set file has them (nav_setfile.lua) against the lists of a ScummVM dump: same corners; in the game only
	{ id = "setfile_hallway", set = "ha", setfile = TRUE },
	{ id = "setfile_garage", set = "ga", setfile = TRUE },
	{ id = "setfile_office_steps", set = "os", setfile = TRUE },
	{ id = "setfile_ship", set = "si", setfile = TRUE },
	{ id = "setfile_ledge", set = "le", setfile = TRUE },
	{ id = "setfile_packing", set = "pk", setfile = TRUE },
	{ id = "setfile_dam", set = "bd", setfile = TRUE },
	{ id = "setfile_lobby", set = "lb", setfile = TRUE },
	{ id = "links_lighthouse", set = "lx", minlinks = 2 },
	{ id = "links_airlock", set = "ea", minlinks = 1 },
	{ id = "links_garage", set = "ga", minlinks = 8 },
	{ id = "links_hallway", set = "ha", minlinks = 1 },
}

ar_nt_log = function(mode, case, ok, msg)
	AR_NT_RUN[mode] = AR_NT_RUN[mode] + 1
	local word = "FAIL"
	if ok then
		AR_NT_PASS[mode] = AR_NT_PASS[mode] + 1
		word = "PASS"
	elseif AR_KNOWN and AR_KNOWN[case.id] then
		-- (a difference between the engines that is known and explained in nav_known.lua: counted as a pass, told as KNOWN)
		AR_NT_PASS[mode] = AR_NT_PASS[mode] + 1
		word = "KNOWN"
		msg = msg .. " [" .. AR_KNOWN[case.id] .. "]"
	end
	local line = "NAVTEST " .. mode .. " " .. case.id .. " " .. word .. " " .. msg
	PrintDebug(line .. "\n")
	if ar_log and not AR_OFFLINE then
		ar_log(line)
	end
end

-- the height of the floor at (x, y) when only one floor is there (a typed goal can have a wrong z), else the given one
ar_nt_goal_z = function(nav, x, y, z)
	local count = ar_nav_count(nav)
	local found = nil
	local n = 0
	local i = 1
	while i <= count do
		if ar_nav_inside(nav, i, x, y) and ar_nav_active(nav, i) then
			n = n + 1
			found = ar_nav_z(nav, i, x, y)
		end
		i = i + 1
	end
	if n == 1 then
		return found
	end
	return z
end

-- the way as text, the same on both engines
ar_nt_way = function(path, n)
	local s = ""
	local i = 1
	while i <= n and i <= 12 do
		s = s .. format("%.2f,%.2f,%.2f,", path[i][1], path[i][2], path[i][3]) .. tostring(path[i][4]) .. ";"
		i = i + 1
	end
	return s
end

-- what the set file gives the planner, as one line of counts and a checksum of the corners: the same text offline (the host reads the
-- archives), on ScummVM and on the original shows that all three read the same sectors
ar_nt_setfile = function(case, set)
	local nav = ar_nav_of(set)
	if not nav then
		ar_nt_log("unit", case, nil, "no set file for " .. tostring(set.name))
		return
	end
	local sum = 0
	local lists = { "p", "hp" }
	local l = 1
	while lists[l] do
		local i = 1
		while nav[lists[l]][i] do
			local m = 1
			while nav[lists[l]][i][m] do
				sum = sum + nav[lists[l]][i][m] * (1 + (m - 3 * floor(m / 3)))
				m = m + 1
			end
			i = i + 1
		end
		l = l + 1
	end
	ar_nt_log("unit", case, ar_nav_len(nav.n) > 0, ar_nav_len(nav.n) .. " walk, " .. ar_nav_len(nav.hn) .. " hot, " .. ar_nav_len(nav.off) .. " off, checksum " .. format("%.2f", sum))
end

-- the plan
ar_nt_unit = function(case)
	local set, nav = ar_nt_place(case)
	if case.setfile then
		ar_nt_setfile(case, set)
		return
	end
	local w = ar_w(nav)
	w.tmp = { }
	-- (actors that hold Manny up, learned on a walk: { x, y, r }; the plan goes round them)
	w.obst = case.obst or { }
	if case.probe then
		local off = ""
		local hot = ar_nav_hotnav(nav)
		local i = 1
		while nav.n[i] do
			if not ar_nav_active(nav, i) then
				off = off .. nav.n[i] .. " "
			end
			i = i + 1
		end
		i = 1
		while hot.n[i] do
			if not ar_nav_active(hot, i) then
				off = off .. hot.n[i] .. " "
			end
			i = i + 1
		end
		local ok = TRUE
		local msg = "off: " .. off
		-- (ScummVM: the exact answer, to check the probe against; development only, never in the run)
		if IsSectorActive then
			local oracle = ""
			i = 1
			while nav.n[i] do
				if not IsSectorActive(nav.n[i]) then
					oracle = oracle .. nav.n[i] .. " "
				end
				i = i + 1
			end
			i = 1
			while hot.n[i] do
				if not IsSectorActive(hot.n[i]) then
					oracle = oracle .. hot.n[i] .. " "
				end
				i = i + 1
			end
			if oracle ~= off then
				ok = nil
				msg = msg .. "| IsSectorActive says: " .. oracle
			end
		end
		ar_nt_log("unit", case, ok, msg)
		return
	end
	if case.minlinks then
		ar_nt_log("unit", case, w.nlinks >= case.minlinks, tostring(w.nlinks) .. " links, at least " .. tostring(case.minlinks) .. " wanted")
		return
	end
	AR_GOAL_REGION = nil
	AR_GOAL_HOT = { }
	local gx = 0
	local gy = 0
	local gz = 0
	if case.door then
		AR_GOAL_HOT = ar_nav_door_hot(nav, set[case.door])
		if not AR_GOAL_HOT then
			AR_GOAL_HOT = { }
			ar_nt_log("unit", case, nil, "the door has no sector that is on")
			return
		end
		AR_GOAL_REGION = TRUE
		gx, gy = ar_nav_centre(ar_nav_hotnav(nav), next(AR_GOAL_HOT, nil))
		gz = manny:getpos().z
	else
		gx = case.to[1]
		gy = case.to[2]
		gz = ar_nt_goal_z(nav, gx, gy, case.to[3])
	end
	AR_NAV_GOAL_X = nil
	AR_ALLOW_PARTIAL = case.partial
	local path = ar_w_plan(nav, w, gx, gy, gz)
	AR_ALLOW_PARTIAL = nil
	if case.nopath then
		-- (a way that must not be there: the floors do not meet)
		local nn = 0
		if path then
			nn = ar_nav_len(path)
		end
		ar_nt_log("unit", case, not path, "no way expected" .. ((path and (", but one of " .. nn .. " points: " .. ar_nt_way(path, nn))) or ""))
		return
	end
	if not path then
		AR_GOAL_REGION = nil
		local mp = manny:getpos()
			ar_nt_log("unit", case, nil, "no way (" .. tostring(AR_SEARCH_STEPS) .. " cells searched) from " .. format("%.3f %.3f %.3f", mp.x, mp.y, mp.z))
		return
	end
	local n = ar_nav_len(path)
	local cum = ar_way_cum(path)
	local why = ""
	local i = 1
	local links = ""
	while path[i] do
		if path[i][4] == "c" or path[i][4] == "s" then
			links = links .. path[i][4]
		end
		if case.level and abs(path[i][3] - case.level) > 0.3 then
			why = why .. format(" point %d is at the height %.2f;", i, path[i][3])
		end
		i = i + 1
	end
	if case.link and not strfind(links, case.link, 1, 1) then
		why = why .. " no link of the kind " .. case.link .. ";"
	end
	if case.door then
		if not ar_w_in_goal_hot(nav, path[n][1], path[n][2]) then
			why = why .. " the way ends outside the sector of the door;"
		end
	else
		local ex = AR_NAV_GOAL_X or gx
		local ey = AR_NAV_GOAL_Y or gy
		local d = sqrt((path[n][1] - ex) * (path[n][1] - ex) + (path[n][2] - ey) * (path[n][2] - ey))
		if d > (case.tol or 0.15) then
			why = why .. format(" the way ends %.2f from the goal;", d)
		end
	end
	if case.clear and case.obst then
		-- (how near to the middle of the actor the way comes, along the lines between its points)
		local near = 1000
		local si = 1
		while si < n do
			local ax = path[si][1]
			local ay = path[si][2]
			local dx = path[si + 1][1] - ax
			local dy = path[si + 1][2] - ay
			local len = sqrt(dx * dx + dy * dy)
			local steps = floor(len / 0.02) + 1
			local st = 0
			while st <= steps do
				local px = ax + dx * st / steps
				local py = ay + dy * st / steps
				local od = sqrt((px - case.obst[1].x) * (px - case.obst[1].x) + (py - case.obst[1].y) * (py - case.obst[1].y))
				if si > 1 or st > steps / 2 then
					if od < near then
						near = od
					end
				end
				st = st + 1
			end
			si = si + 1
		end
		if near < case.clear then
			why = why .. format(" the way comes within %.2f of the actor, %.2f wanted;", near, case.clear)
		end
	end
	if case.len and (cum[1] > case.len * 1.4 + 0.3 or cum[1] < case.len * 0.6 - 0.3) then
		why = why .. format(" the way is %.2f m, it was %.2f m in the run;", cum[1], case.len)
	end
	AR_GOAL_REGION = nil
	AR_GOAL_HOT = { }
	ar_nt_log("unit", case, why == "", format("%d points, %.2f m", n, cum[1]) .. ", links [" .. links .. "], way " .. ar_nt_way(path, n) .. why)
end

-- the walks of a full run (tools/gen_cases.py): added to the cases when the file is there
if AR_RUN_CASES then
	AR_NT_RC = 1
	AR_NT_RN = 0
	while NAVTESTS[AR_NT_RN + 1] do
		AR_NT_RN = AR_NT_RN + 1
	end
	while AR_RUN_CASES[AR_NT_RC] do
		AR_NT_RN = AR_NT_RN + 1
		NAVTESTS[AR_NT_RN] = AR_RUN_CASES[AR_NT_RC]
		AR_NT_RC = AR_NT_RC + 1
	end
end

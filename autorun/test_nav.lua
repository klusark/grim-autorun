-- Tiers B and C: the cases of nav_cases.lua in the game, on either engine. Manny is put straight into the set at the start of each
-- case (the story does not matter here).
--   unit: the plan only (found, over the links it has to take, on the right level, ending where it has to)
--   walk: the walk with the keys, from the same start (arrives, or goes through the door, with no failure, in how long)
-- AR_NT_MODE = "unit" or "walk" runs only one of the two, AR_NT_ONLY = "<id>" one case.
--   ScummVM:  EXTRA=nav_cases.lua sh run_chapter.sh test_nav.lua 900
--   original: sh test_nav_original.sh

-- (a new game: the test needs no save, the intro is over when the game gives the control)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_KEEP_GOING = TRUE

-- AR_NT_WTRACE = TRUE: the position of Manny in every frame of a walk ("NAVTRACE <id> <frame> x y z yaw", the lines tools/compare_trace.py reads)
ar_nt_wtrace = function()
	while TRUE do
		AR_WT_K = AR_WT_K + 1
		local p = manny:getpos()
		PrintDebug("NAVTRACE " .. AR_WT_ID .. " " .. AR_WT_K .. format(" %.6f %.6f %.4f %.1f", p.x, p.y, p.z, manny:getrot().y) .. "\n")
		break_here()
	end
end

-- the walk
ar_nt_walk = function(case)
	if case.minlinks or case.probe or case.nowalk or case.setfile then
		return
	end
	local set, nav = ar_nt_place(case)
	AR_FAILED = nil
	AR_NAV_TIME = 0
	AR_NT_SET = set
	if AR_NT_WTRACE then
		AR_WT_ID = case.id
		AR_WT_K = 0
		AR_WT_TASK = start_script(ar_nt_wtrace)
	end
	local ok = nil
	local msg = ""
	if case.door then
		ar_nav_enter_door(set[case.door], function() return system.currentSet ~= AR_NT_SET end)
		ar_try_wait(function() return system.currentSet ~= AR_NT_SET end, 8000)
		ok = system.currentSet ~= AR_NT_SET and not AR_FAILED
		msg = "now in " .. tostring(system.currentSet.name)
	else
		ar_walk_to(case.to[1], case.to[2], case.to[3])
		local p = manny:getpos()
		local ex = AR_NAV_GOAL_X or case.to[1]
		local ey = AR_NAV_GOAL_Y or case.to[2]
		local d = sqrt((p.x - ex) * (p.x - ex) + (p.y - ey) * (p.y - ey))
		ok = d <= (case.tol or 0.1) and not AR_FAILED and system.currentSet == set
		msg = format("ended %.2f from the goal at %.2f %.2f", d, p.x, p.y)
	end
	if AR_FAILED then
		msg = msg .. ", a failure was logged"
	end
	AR_FAILED = nil
	if AR_WT_TASK then
		stop_script(AR_WT_TASK)
		AR_WT_TASK = nil
	end
	ar_nt_log("walk", case, ok, msg .. format(", %.1f s of walking", (AR_NAV_TIME or 0) / 1000))
end

-- The order of the cases: as listed, or (AR_NT_SHUFFLE = seed) a shuffle from a generator that gives the same order on both engines; a case
-- whose result changes with the order is a case that depends on another.
AR_NT_ORDER = { }
AR_NT_NN = 0
while NAVTESTS[AR_NT_NN + 1] do
	AR_NT_NN = AR_NT_NN + 1
	AR_NT_ORDER[AR_NT_NN] = AR_NT_NN
end
if AR_NT_SHUFFLE then
	local seed = AR_NT_SHUFFLE
	local i = AR_NT_NN
	while i > 1 do
		seed = mod(seed * 16807, 2147483647)
		local j = 1 + mod(seed, i)
		local t = AR_NT_ORDER[i]
		AR_NT_ORDER[i] = AR_NT_ORDER[j]
		AR_NT_ORDER[j] = t
		i = i - 1
	end
	ar_log("NAVTEST order shuffled, seed " .. AR_NT_SHUFFLE)
end
AR_NT_I = 1
while AR_NT_ORDER[AR_NT_I] do
	local case = NAVTESTS[AR_NT_ORDER[AR_NT_I]]
	if (not AR_NT_ONLY or AR_NT_ONLY == case.id) and (not AR_NT_IDS or AR_NT_IDS[case.id]) and not case.offline then
		if AR_NT_MODE ~= "walk" and not case.nounit and ar_nt_tier("unit") then
			ar_nt_unit(case)
		end
		if AR_NT_MODE ~= "unit" and ar_nt_tier("walk") then
			ar_nt_walk(case)
		end
	end
	AR_NT_I = AR_NT_I + 1
end

-- A target that is not where its object was made: an object whose actor rides about (Meche, the agent). The approach has to go to
-- where the actor is, also when it moves while Manny is on the way.
--   moved:  the actor is somewhere else at the start
--   moving: it walks from its place toward `to` (m/s `speed`) while Manny approaches
AR_NT_MOVES = { }
AR_NT_N = 0

-- (the cases: an object, where Manny starts, and where its actor is and goes, at what speed in m/s; speed 0 is an actor that is away
-- from the place of its object and stays; the game puts such an actor back unless something holds it, so the mover holds it)
AR_NT_OBJS = { "meche_obj", "unicycle_man", "charlie_obj" }
AR_NT_STARTS = { { -0.06, 2.07 }, { 1.65, -0.33 }, { 1.35, 0.05 }, { 0.14, 0.17 } }
AR_NT_ROUTES = {
	-- name, from, to, speed
	{ "still_a", { 0.14, 0.17 }, { 0.14, 0.17 }, 0 },
	{ "still_b", { 1.35, 0.05 }, { 1.35, 0.05 }, 0 },
	{ "still_c", { 0.10, 0.86 }, { 0.10, 0.86 }, 0 },
	{ "slow", { 1.35, 0.05 }, { 0.14, 0.17 }, 0.25 },
	{ "walk", { 1.35, 0.05 }, { 0.14, 0.17 }, 0.6 },
	{ "fast", { 1.35, 0.05 }, { 0.14, 0.17 }, 1.2 },
	{ "away", { 0.10, 0.86 }, { 1.65, -0.33 }, 0.5 },
	{ "across", { 0.14, 0.17 }, { 0.10, 0.86 }, 0.5 },
}
AR_NT_A = 1
while AR_NT_OBJS[AR_NT_A] do
	AR_NT_B = 1
	while AR_NT_STARTS[AR_NT_B] do
		AR_NT_C = 1
		while AR_NT_ROUTES[AR_NT_C] do
			local r = AR_NT_ROUTES[AR_NT_C]
			AR_NT_N = AR_NT_N + 1
			AR_NT_MOVES[AR_NT_N] = { id = "target_" .. AR_NT_OBJS[AR_NT_A] .. "_" .. r[1] .. "_from" .. AR_NT_B, set = "ly", obj = AR_NT_OBJS[AR_NT_A], from = AR_NT_STARTS[AR_NT_B], actor = r[2], to = r[3], speed = r[4] }
			AR_NT_C = AR_NT_C + 1
		end
		AR_NT_B = AR_NT_B + 1
	end
	AR_NT_A = AR_NT_A + 1
end

ar_nt_mover = function()
	local c = AR_NT_MOVER
	local a = c.obj.interest_actor
	local start = a:getpos()
	local t = 0
	while AR_NT_MOVER == c and t < 20000 do
		local len = sqrt((c.to[1] - c.actor[1]) * (c.to[1] - c.actor[1]) + (c.to[2] - c.actor[2]) * (c.to[2] - c.actor[2]))
		local f = 1
		if len > 0 and t * c.speed / 1000 < len then
			f = t * c.speed / 1000 / len
		end
		a:setpos(c.actor[1] + (c.to[1] - c.actor[1]) * f, c.actor[2] + (c.to[2] - c.actor[2]) * f, start.z)
		break_here()
		t = t + system.frameTime
	end
end

ar_nt_move_case = function(case)
	local set = ar_nt_place({ id = case.id, set = case.set, from = { case.from[1], case.from[2] } })
	-- (an object and actor of its own, as the real one: the game's scripts put the real actor of the object back where it belongs)
	local base = set[case.obj]
	local obj = Object:create(set, base.name, base.obj_x, base.obj_y, base.obj_z, { range = base.range })
	obj.use_pnt_x = base.use_pnt_x
	obj.use_pnt_y = base.use_pnt_y
	obj.use_pnt_z = base.use_pnt_z
	obj.use_rot_y = base.use_rot_y
	base.touchable = nil
	local a = obj.interest_actor
	local z = a:getpos().z
	a:setpos(case.actor[1], case.actor[2], z)
	AR_NT_MOVER = nil
	case.obj = obj
	AR_NT_MOVER = case
	start_script(ar_nt_mover)
	AR_FAILED = nil
	AR_NAV_TIME = 0
	ar_log("NAVTEST move start: " .. ar_why_not_offered(obj) .. " away " .. tostring(ar_actor_away(obj)))
	AR_START_SET = system.currentSet
	ar_approach(obj)
	ar_log("NAVTEST move end: " .. ar_why_not_offered(obj))
	local near = proximity(manny.hActor, a.hActor)
	AR_NT_MOVER = nil
	local ok = near <= obj.range + 0.15 and not AR_FAILED
	AR_FAILED = nil
	case.obj = nil
	obj.touchable = nil
	parent_object[a.hActor] = nil
	a:set_visibility(FALSE)
	a:put_in_set(nil)
	base.touchable = TRUE
	ar_nt_log("move", { id = case.id }, ok, format("ended %.2f from the actor (range %.2f)", near, obj.range))
end

AR_NT_RUN.move = 0
AR_NT_PASS.move = 0
AR_NT_K = 1
while AR_NT_MOVES[AR_NT_K] do
	if ar_nt_tier("move") and (not AR_NT_ONLY or AR_NT_ONLY == "move" or AR_NT_ONLY == AR_NT_MOVES[AR_NT_K].id) and (not AR_NT_PAT or strfind(AR_NT_MOVES[AR_NT_K].id, AR_NT_PAT)) then
		local c = AR_NT_MOVES[AR_NT_K]
		ar_nt_move_case(c)
	end
	AR_NT_K = AR_NT_K + 1
end
PrintDebug("NAVTEST SUMMARY move " .. AR_NT_PASS.move .. "/" .. AR_NT_RUN.move .. "\n")

-- Turning: SetActorRot on an actor that has no walker (one that never walked, turned or followed boxes) sets the angles as they are asked, as
-- the original does (the tumblers of the safe in vd read the angle back and compare it as a whole number); with a walker the angle that is read
-- is where the walker's frame ended, a few thousandths of a degree off and counted from the angle before.
AR_NT_RUN.turn = 0
AR_NT_PASS.turn = 0
ar_nt_turn_exact = function(a, yaw)
	a:setrot(0, yaw, 0)
	local r = a:getrot()
	local d = abs(r.y - yaw)
	return d < 0.0001, format("asked %.4f got %.6f", yaw, r.y)
end
if ar_nt_tier("turn") and (not AR_NT_ONLY or AR_NT_ONLY == "turn") then
	local set = system.currentSet
	local a = Actor:create(nil, nil, nil, "turntest")
	a:set_costume("tumbler.cos")
	a:put_in_set(set)
	local yaws = { 0, 1, 5, 42, 90, 179, 214, 314, 359 }
	local i = 1
	local all = TRUE
	local msg = ""
	while yaws[i] do
		local ok, m = ar_nt_turn_exact(a, yaws[i])
		if not ok then
			all = nil
			msg = msg .. " " .. m
		end
		i = i + 1
	end
	ar_nt_log("turn", { id = "no_walker_exact" }, all, "angles read back as set" .. msg)
	-- with a walker: within a tenth of a degree of the asked angle (modulo 360)
	SetActorFollowBoxes(a.hActor, TRUE)
	local ok2 = TRUE
	local msg2 = ""
	i = 1
	local lag_ok = TRUE
	local lag_msg = ""
	while yaws[i] do
		local before = a:get_positive_rot()
		a:setrot(0, yaws[i], 0)
		-- (the angle that is read does not change in the frame of the SetActorRot: the heading that is seen follows the walker in the next one)
		local now = a:get_positive_rot()
		if abs(now.y - before.y) > 0.001 then
			lag_ok = nil
			lag_msg = lag_msg .. format(" asked %d: %.3f then %.3f at once", yaws[i], before.y, now.y)
		end
		break_here()
		-- (the visible heading follows the walker, a tenth of the way each frame in the original: it is read when it has stopped moving)
		local still = 0
		local last = a:get_positive_rot().y
		local waited = 0
		while still < 3 and waited < 120 do
			break_here()
			local q = a:get_positive_rot().y
			if abs(q - last) < 0.0005 then
				still = still + 1
			else
				still = 0
			end
			last = q
			waited = waited + 1
		end
		local r = a:get_positive_rot()
		local d = abs(r.y - yaws[i])
		if d > 180 then d = 360 - d end
		if d > 0.1 then
			ok2 = nil
			msg2 = msg2 .. format(" asked %d got %.4f", yaws[i], r.y)
		end
		i = i + 1
	end
	ar_nt_log("turn", { id = "walker_close" }, ok2, "angles with a walker, a frame after" .. msg2)
	ar_nt_log("turn", { id = "walker_lags_a_frame" }, lag_ok, "the angle read in the frame of the SetActorRot" .. lag_msg)
	a:free()
	-- how fast Manny turns with the key (one TurnActor a frame, as the player holding it): the angle after 30 frames and the frame time; only told, the
	-- two engines are to be compared (the follower steers by it)
	local yaw0 = manny:getrot().y
	local frames = 0
	local t0 = system.frameTime
	while frames < 30 do
		TurnActor(manny.hActor, 1)
		break_here()
		frames = frames + 1
	end
	break_here()
	local dyaw = manny:getrot().y - yaw0
	dyaw = dyaw - 360 * floor(dyaw / 360 + 0.5)
	PrintDebug("NAVTEST turn_rate " .. format("%.3f degrees in 30 frames, frame time %d ms, %.3f degrees a frame", dyaw, system.frameTime, dyaw / 30) .. "\n")
end
-- The turn of the key, by the rate that the script sets: Manny walking (the rate 85 of manny:set_run(FALSE)) on the open floor of a hand-made set, 30 presses of
-- the key: the heading turns by rate * frame time a frame (FUN_0048fbd0 / FUN_00491230), and the rate that is read back is the one that was set.
if ar_nt_tier("turn") and (not AR_NT_ONLY or AR_NT_ONLY == "turn") then
	ar_fx_make_sets()
	local tc = { id = "turn_key_rate", set = "t_flat", from = { 0, 0, 0 }, yaw = 0 }
	ar_nt_place(tc)
	manny:set_run(FALSE)
	break_here()
	local rate = GetActorTurnRate(manny.hActor)
	local y0 = manny:getrot().y
	local frames = 0
	local ft = 0
	while frames < 30 do
		TurnActor(manny.hActor, 1)
		break_here()
		ft = ft + system.frameTime
		frames = frames + 1
	end
	break_here()
	local d = manny:getrot().y - y0
	d = d - 360 * floor(d / 360 + 0.5)
	local want = rate * ft / 1000 / 30
	PrintDebug("NAVTEST turn_key " .. format("rate %.2f, %.4f degrees a frame, %.4f wanted, frame time %.2f ms", rate, d / 30, want, ft / 30) .. "\n")
	ar_nt_log("turn", tc, rate == 85 and abs(d / 30 - want) < 0.02, format("rate %.2f, %.4f degrees a frame, rate * frame time %.4f", rate, d / 30, want))
end
-- SetActorRot with the turn flag (Actor_SetRot 0x490900): the pitch and the roll are set at once, only the yaw turns, and it eases (Walker_UpdateYaw
-- 0x491230): step = s + (left - s) * 0.1 with s = rate * frame time, until less than half a degree is left. A SetActorRot without the flag makes the
-- rate negative (GetActorTurnRate reads it so), and the yaw update makes it positive again in the first frame with half a degree or more to turn: a
-- SetActorRot to the angle the actor already has leaves it negative, and the next turn is a jump. SetActorRot also ends a walk to a point.
-- TurnActorTo (0x49fc60): the heading turns by at most rate * frame time, without the time scale; true while a whole step was taken, nil after; at
-- rate 0 it never turns and stays true. The original turns 1.4229 degrees a frame to the right at rate 85 and 17 ms, not the 1.445 of rate * frame
-- time, and answers true 63 times for 90 degrees: its sine table (Math_SinCosTable 0x47bd20) is an entry off for small turns to the right. ScummVM
-- does not copy the table; the two cases accept rate * frame time too.
-- Turn chores (Actor_UpdateMoveChores 0x4913f0): a turn of the body that is not the key's plays the right turn chore whichever way it goes (also one
-- frame for a jump), the key plays its own side; the chore that starts stops the rest chore in the same frame. IsActorTurning (0x499be0) is whether
-- the body still had to turn at the last update; TurnActor (0x48fbd0) is ignored while that angle is more than two steps.
ar_nt_rot_clear = function(h, yaw)
	-- (two jumps of 45 degrees: the yaw update takes the negative rate back each time)
	SetActorRot(h, 0, yaw + 45, 0)
	break_here()
	SetActorRot(h, 0, yaw, 0)
	break_here()
	break_here()
end
ar_nt_chores = function(h)
	local c = manny.base_costume
	return (IsActorChoring(h, ms_swivel_lf, FALSE, c) and 1 or 0), (IsActorChoring(h, ms_swivel_rt, FALSE, c) and 1 or 0), (IsActorChoring(h, ms_rest, FALSE, c) and 1 or 0)
end
-- (in functions: Lua allows 32 locals in one)
ar_nt_turn_setrot = function(h, rate)
	local tc = { id = "setrot_turn_pitch_roll" }
	-- (the original leaves a few hundredths of a degree after the jumps: the angles are counted from where the yaw is)
	local p, y0, r = GetActorRot(h)
	SetActorRot(h, 10, 90, 5, TRUE)
	local y
	p, y, r = GetActorRot(h)
	local turning = IsActorTurning(h)
	ar_nt_log("turn", tc, abs(p - 10) < 0.001 and abs(r - 5) < 0.001 and abs(y - y0) < 0.001, format("in the frame of the SetActorRot: %.4f %.4f %.4f, yaw before %.4f (rate %.2f)", p, y, r, y0, rate))
	ar_nt_log("turn", { id = "setrot_turning_at_once" }, turning, "IsActorTurning in the frame of the SetActorRot")
	local ft = system.frameTime
	break_here()
	local p1, y1, r1 = GetActorRot(h)
	local s = rate * ft / 1000
	local want = s + (90 - y0 - s) * 0.1
	ar_nt_log("turn", { id = "setrot_turn_ease" }, abs((y1 - y0) - want) < 0.02, format("first step %.4f, s + (left - s) * 0.1 = %.4f (rate %.2f, frame %d ms)", y1 - y0, want, rate, ft))
	local k = 0
	local stopped = nil
	while k < 120 do
		if not stopped and not IsActorTurning(h) then
			stopped = k
		end
		break_here()
		k = k + 1
	end
	p, y, r = GetActorRot(h)
	ar_nt_log("turn", { id = "setrot_turn_end" }, abs(y - 90) < 0.5 and abs(p - 10) < 0.001 and abs(r - 5) < 0.001, format("after 120 frames: %.4f %.4f %.4f", p, y, r))
	ar_nt_log("turn", { id = "setrot_turning_ends" }, stopped and stopped > 10 and stopped < 30, format("IsActorTurning false from frame %s", tostring(stopped)))
end
ar_nt_turn_misc = function(h)
	local p, y, r, y0, y1, k
	-- a SetActorRot without the flag to the angle that is there: the rate reads negative and the next turn jumps
	ar_nt_rot_clear(h, 0)
	SetActorRot(h, 0, 0, 0)
	break_here()
	local neg = GetActorTurnRate(h)
	SetActorTurnRate(h, 85)
	local neg2 = GetActorTurnRate(h)
	SetActorRot(h, 0, 90, 0, TRUE)
	break_here()
	p, y, r = GetActorRot(h)
	ar_nt_log("turn", { id = "setrot_snap_pending" }, neg < 0 and neg2 < 0 and abs(y - 90) < 0.1 and GetActorTurnRate(h) > 0, format("rate %.2f after the jump in place, %.2f after SetActorTurnRate(85), yaw %.4f a frame after the turn to 90", neg, neg2, y))
	-- the key is ignored while the body is more than two steps from the heading
	ar_nt_rot_clear(h, 0)
	SetActorRot(h, 0, 90, 0, TRUE)
	k = 0
	while k < 3 do
		TurnActor(h, -1)
		break_here()
		k = k + 1
	end
	k = 0
	while k < 60 do
		break_here()
		k = k + 1
	end
	p, y, r = GetActorRot(h)
	ar_nt_log("turn", { id = "key_ignored_while_easing" }, abs(y - 90) < 0.5, format("ends at %.4f after three right keys during the turn to 90", y))
	-- PointActorAt: the body jumps in the next update
	ar_nt_rot_clear(h, 0)
	p, y0, r = GetActorRot(h)
	PointActorAt(h, AR_NT_O.x + 1, AR_NT_O.y, AR_NT_O.z)
	p, y, r = GetActorRot(h)
	break_here()
	p, y1, r = GetActorRot(h)
	ar_nt_log("turn", { id = "pointat_next_frame" }, abs(y - y0) < 0.001 and abs(y1 + 90) < 0.1, format("%.4f in the frame, %.4f in the next", y, y1))
	-- the puck vector is the heading: it points to the new angle in the frame of a turn, before the body
	ar_nt_rot_clear(h, 0)
	SetActorRot(h, 0, 90, 0, TRUE)
	p, y, r = GetActorRot(h)
	local px, py, pz = GetActorPuckVector(h)
	ar_nt_log("turn", { id = "puck_is_heading" }, abs(y - y0) < 0.1 and abs(px + 1) < 0.01 and abs(py) < 0.01, format("yaw %.4f, puck %.4f %.4f in the frame of the turn to 90", y, px, py))
	k = 0
	while k < 40 do
		break_here()
		k = k + 1
	end
	-- SetActorRot ends a walk to a point
	ar_nt_rot_clear(h, 0)
	WalkActorTo(h, AR_NT_O.x, AR_NT_O.y + 2, AR_NT_O.z)
	k = 0
	while k < 5 do
		break_here()
		k = k + 1
	end
	local wx, wy, wz = GetActorPos(h)
	SetActorRot(h, 0, 0, 0)
	k = 0
	while k < 10 do
		break_here()
		k = k + 1
	end
	local ex, ey, ez = GetActorPos(h)
	ar_nt_log("turn", { id = "setrot_stops_walk" }, wy - AR_NT_O.y > 0.01 and abs(ey - wy) < 0.001, format("y %.4f at the SetActorRot, %.4f ten frames later", wy, ey))
	-- turn chores (Manny in his suit)
	if manny.costume_state == "suit" then
		local lf, rt, rest
		ar_nt_rot_clear(h, 0)
		k = 0
		while k < 6 do
			break_here()
			k = k + 1
		end
		SetActorRot(h, 0, 60, 0, TRUE)
		break_here()
		lf, rt, rest = ar_nt_chores(h)
		ar_nt_log("turn", { id = "chore_eased_left" }, lf == 0 and rt == 1 and rest == 0, format("turn to the left: left %d right %d rest %d in its first frame", lf, rt, rest))
		k = 0
		while k < 40 do
			break_here()
			k = k + 1
		end
		lf, rt, rest = ar_nt_chores(h)
		ar_nt_log("turn", { id = "chore_eased_end" }, lf == 0 and rt == 0 and rest == 1, format("after the turn: left %d right %d rest %d", lf, rt, rest))
		TurnActor(h, 1)
		break_here()
		lf, rt, rest = ar_nt_chores(h)
		ar_nt_log("turn", { id = "chore_key_left" }, lf == 1 and rt == 0 and rest == 0, format("left key: left %d right %d rest %d in its first frame", lf, rt, rest))
		break_here()
		lf, rt, rest = ar_nt_chores(h)
		ar_nt_log("turn", { id = "chore_key_released" }, lf == 0 and rt == 0 and rest == 1, format("key released: left %d right %d rest %d", lf, rt, rest))
		SetActorRot(h, 0, 0, 0)
		break_here()
		lf, rt, rest = ar_nt_chores(h)
		ar_nt_log("turn", { id = "chore_jump" }, lf == 0 and rt == 1 and rest == 0, format("jump: left %d right %d rest %d a frame after", lf, rt, rest))
		-- IsActorResting (0x499da0) is the flag of the rest chore: off from the first frame of a turn, on again in the frame the turn ends
		k = 0
		while k < 5 do
			break_here()
			k = k + 1
		end
		local r0 = IsActorResting(h)
		SetActorRot(h, 0, 60, 0, TRUE)
		local r1 = IsActorResting(h)
		break_here()
		local r2 = IsActorResting(h)
		k = 0
		while k < 40 do
			break_here()
			k = k + 1
		end
		local r3 = IsActorResting(h)
		ar_nt_log("turn", { id = "resting_flag" }, r0 and r1 and not r2 and r3, format("resting %d before, %d in the frame of the turn, %d a frame after, %d at the end", r0 and 1 or 0, r1 and 1 or 0, r2 and 1 or 0, r3 and 1 or 0))
	end
end
ar_nt_turn_turnto = function(h, rate)
	local p, y, r, k
	-- TurnActorTo a point at the right of Manny, 90 degrees away
	ar_nt_rot_clear(h, 0)
	local trues = 0
	local first_nil = nil
	local sum = 0
	local n = 0
	local sumft = 0
	local last_y = 0
	local turning0 = nil
	local turning1 = nil
	k = 0
	while k < 90 do
		local ret = TurnActorTo(h, AR_NT_O.x + 1, AR_NT_O.y, AR_NT_O.z)
		p, y, r = GetActorRot(h)
		if k == 0 then
			turning0 = IsActorTurning(h)
		elseif k == 1 then
			turning1 = IsActorTurning(h)
		end
		if ret then
			if first_nil then
				first_nil = -1
			end
			trues = trues + 1
		elseif not first_nil then
			first_nil = k
		end
		-- (steps in the middle of the turn, read one frame later)
		if k >= 11 and k <= 50 then
			sum = sum + (last_y - y)
			n = n + 1
		end
		if k >= 10 and k <= 49 then
			sumft = sumft + system.frameTime
		end
		last_y = y
		break_here()
		k = k + 1
	end
	p, y, r = GetActorRot(h)
	local ratio = (sum / n) / (rate * sumft / n / 1000)
	local full = floor(90 / (rate * sumft / n / 1000))
	ar_nt_log("turn", { id = "turnto_step_size" }, abs(ratio - 0.9847) < 0.003 or abs(ratio - 1) < 0.003, format("%.4f a frame, %.4f of rate * frame time (the original 0.9847)", sum / n, ratio))
	ar_nt_log("turn", { id = "turnto_true_count" }, first_nil == trues and (trues == full or trues == full + 1), format("true %d times, then nil from call %s (%d whole steps; the original 63 at rate 85, 17 ms)", trues, tostring(first_nil), full))
	ar_nt_log("turn", { id = "turnto_end" }, abs(y + 90) < 0.5, format("ends at %.4f", y))
	ar_nt_log("turn", { id = "turnto_turning" }, not turning0 and turning1, format("IsActorTurning %s in the frame of the first call, %s in the next", turning0 and "true" or "nil", turning1 and "true" or "nil"))
end
ar_nt_turn_turnto2 = function(h, rate)
	local p, y, r, k
	-- the time scale does not change the step of TurnActorTo: steps 4 to 6 at scale 1, 8 to 10 at scale 2
	ar_nt_rot_clear(h, 0)
	-- (each step over rate * the frame time of the call before, as the yaw is read a frame later)
	local steps = { }
	local y0 = 0
	local ft0 = 0
	k = 0
	while k < 11 do
		if k == 7 then
			SetActorTimeScale(h, 2)
		end
		TurnActorTo(h, AR_NT_O.x + 1, AR_NT_O.y, AR_NT_O.z)
		p, y, r = GetActorRot(h)
		if ft0 > 0 then
			steps[k] = (y0 - y) / (rate * ft0 / 1000)
		end
		y0 = y
		ft0 = system.frameTime
		break_here()
		k = k + 1
	end
	SetActorTimeScale(h, 1)
	local s1 = (steps[4] + steps[5] + steps[6]) / 3
	local s2 = (steps[9] + steps[10]) / 2
	ar_nt_log("turn", { id = "turnto_no_timescale" }, abs(s2 - s1) < 0.005, format("step %.4f of rate * frame time at scale 1, %.4f at scale 2", s1, s2))
	-- rate 0: no turn, always true
	ar_nt_rot_clear(h, 0)
	SetActorTurnRate(h, 0)
	break_here()
	local all = TRUE
	k = 0
	while k < 5 do
		if not TurnActorTo(h, AR_NT_O.x + 1, AR_NT_O.y, AR_NT_O.z) then
			all = nil
		end
		break_here()
		k = k + 1
	end
	p, y, r = GetActorRot(h)
	SetActorTurnRate(h, rate)
	ar_nt_log("turn", { id = "turnto_rate0" }, all and abs(y) < 0.05, format("yaw %.4f, %s", y, all and "true every call" or "nil in a call"))
end
-- (the angle of the puck vector, counted like the yaw: 0 along +y, 90 along -x)
ar_nt_puck_yaw = function(h)
	local px, py, pz = GetActorPuckVector(h)
	return atan2(-px, py)
end
ar_nt_turn_more = function(h, rate)
	local p, y, r, k
	local s = rate * system.frameTime / 1000
	-- TurnActor with 0: the key is taken as a right turn once the body is at the heading (Actor_TurnKey: dir > 0 left, else right)
	ar_nt_rot_clear(h, 0)
	TurnActor(h, 0)
	break_here()
	break_here()
	p, y, r = GetActorRot(h)
	ar_nt_log("turn", { id = "key_zero_turns_right" }, y < -0.5 and y > -3 * s, format("yaw %.4f two frames after TurnActor(0) (a step is %.4f)", y, s))
	-- PointActorAt only turns the yaw: the pitch and roll set before stay
	ar_nt_rot_clear(h, 0)
	SetActorRot(h, 10, 0, 5)
	break_here()
	break_here()
	PointActorAt(h, AR_NT_O.x + 1, AR_NT_O.y, AR_NT_O.z)
	k = 0
	while k < 3 do
		break_here()
		k = k + 1
	end
	p, y, r = GetActorRot(h)
	ar_nt_log("turn", { id = "pointat_keeps_pitch_roll" }, abs(p - 10) < 0.001 and abs(r - 5) < 0.001 and abs(y + 90) < 0.1, format("%.4f %.4f %.4f three frames after PointActorAt", p, y, r))
	SetActorRot(h, 0, 0, 0)
	break_here()
	break_here()
end
ar_nt_turn_vector = function(h, rate)
	local p, y, r, k
	local s = rate * system.frameTime / 1000
	local cam = GetCameraActor()
	-- WalkActorVector: which way the camera's forward vector is in this set (the heading Manny ends up walking in)
	ar_nt_rot_clear(h, 0)
	k = 0
	while k < 60 do
		WalkActorVector(h, cam, 0, 0.01, 0)
		break_here()
		k = k + 1
	end
	local fwd = ar_nt_puck_yaw(h)
	-- facing the camera's forward direction: the first call walks
	PutActorAt(h, AR_NT_O.x, AR_NT_O.y, AR_NT_O.z)
	ar_nt_rot_clear(h, fwd)
	local x0, y0, z0 = GetActorPos(h)
	WalkActorVector(h, cam, 0, 0.01, 0)
	break_here()
	local x1, y1, z1 = GetActorPos(h)
	local d1 = sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0))
	ar_nt_log("turn", { id = "vector_front_walks" }, d1 > 0.001, format("moved %.4f in the frame of the first call, facing the direction (yaw %.2f)", d1, fwd))
	-- facing away: the heading turns by two steps a call and the walk starts once the direction is less than 90 degrees from it
	PutActorAt(h, AR_NT_O.x, AR_NT_O.y, AR_NT_O.z)
	ar_nt_rot_clear(h, fwd + 180)
	x0, y0, z0 = GetActorPos(h)
	local h0 = ar_nt_puck_yaw(h)
	WalkActorVector(h, cam, 0, 0.01, 0)
	break_here()
	local turned = ar_nt_puck_yaw(h) - h0
	if turned > 180 then
		turned = turned - 360
	elseif turned < -180 then
		turned = turned + 360
	end
	x1, y1, z1 = GetActorPos(h)
	d1 = sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0))
	ar_nt_log("turn", { id = "vector_back_turn_step" }, abs(abs(turned) - 2 * s) < 0.1 and d1 < 0.0001, format("heading turned %.4f and moved %.4f in the frame of the first call from behind (two steps are %.4f)", turned, d1, 2 * s))
	local moved = nil
	k = 1
	while k < 70 do
		WalkActorVector(h, cam, 0, 0.01, 0)
		break_here()
		x1, y1, z1 = GetActorPos(h)
		if not moved and sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) > 0.0001 then
			moved = k
		end
		k = k + 1
	end
	local want = floor(45 / s) + 1
	ar_nt_log("turn", { id = "vector_back_walks_under_90" }, moved and abs(moved - want) <= 2, format("first move in call %s from 180 degrees away, 45 / step + 1 = %d", tostring(moved), want))
	PutActorAt(h, AR_NT_O.x, AR_NT_O.y, AR_NT_O.z)
	ar_nt_rot_clear(h, 0)
end
if ar_nt_tier("turn") and (not AR_NT_ONLY or AR_NT_ONLY == "turn") then
	ar_fx_make_sets()
	ar_nt_place({ id = "turn_setrot", set = "t_flat", from = { 0, 0, 0 }, yaw = 0 })
	AR_NT_O = { x = 0, y = 0, z = 0 }
	manny:set_run(FALSE)
	ar_nt_rot_clear(manny.hActor, 0)
	local rate = GetActorTurnRate(manny.hActor)
	ar_nt_turn_setrot(manny.hActor, rate)
	ar_nt_turn_turnto(manny.hActor, rate)
	ar_nt_turn_turnto2(manny.hActor, rate)
	ar_nt_turn_misc(manny.hActor)
	ar_nt_turn_more(manny.hActor, rate)
	ar_nt_turn_vector(manny.hActor, rate)
end
PrintDebug("NAVTEST SUMMARY turn " .. AR_NT_PASS.turn .. "/" .. AR_NT_RUN.turn .. "\n")

-- Sliding along an edge: Manny is put just before an edge at an angle, walks forward for 40 frames with a turn key held (right, none, left) and ends where
-- the engine takes him. The original slides along an edge only to the side that the key does not go against (FUN_004a8610), and ends a point of the
-- stair at a corner of the temple back stairs where the autorun was stuck. Expected ends are recorded from the original (nav_slide_expect.lua).
AR_NT_RUN.slide = 0
AR_NT_PASS.slide = 0
AR_NT_SLIDES = {
	{ id = "slide_corner_right", set = "bs", from = { -6.921215, 26.134821, 11.7074 }, yaw = 132.7, key = -1, frames = 40 },
	{ id = "slide_corner_none", set = "bs", from = { -6.921215, 26.134821, 11.7074 }, yaw = 132.7, key = 0, frames = 40 },
	{ id = "slide_corner_left", set = "bs", from = { -6.921215, 26.134821, 11.7074 }, yaw = 132.7, key = 1, frames = 40 },
	{ id = "slide_wall_right", set = "bs", from = { -6.80, 26.40, 11.85 }, yaw = 160, key = -1, frames = 40 },
	{ id = "slide_wall_none", set = "bs", from = { -6.80, 26.40, 11.85 }, yaw = 160, key = 0, frames = 40 },
	{ id = "slide_wall_left", set = "bs", from = { -6.80, 26.40, 11.85 }, yaw = 160, key = 1, frames = 40 },
	{ id = "slide_stairwall_right", set = "ts", from = { 0.092, -0.189, 0.4033 }, yaw = 317, key = -1, frames = 120, trace = TRUE },
	{ id = "slide_stairwall_none", set = "ts", from = { 0.092, -0.189, 0.4033 }, yaw = 317, key = 0, frames = 120, trace = TRUE },
	{ id = "slide_stairwall_left", set = "ts", from = { 0.092, -0.189, 0.4033 }, yaw = 317, key = 1, frames = 120, trace = TRUE },
}
ar_nt_slide = function(case)
	ar_nt_place(case)
	-- (steady frames before the first step: the frames after a change of the scene are long in the original, and the steps are as long as the frames; the
	-- walk of the player, no auto run, and the position and heading of the case again after the wait)
	AR_WALK = TRUE
	manny:set_run(FALSE)
	sleep_for(2500)
	manny:setpos(case.from[1], case.from[2], case.from[3])
	manny:setrot(0, case.yaw, 0)
	break_here()
	break_here()
	local k = 0
	while k < case.frames do
		if case.key ~= 0 then
			TurnActor(manny.hActor, case.key)
		end
		manny:walk_forward()
		break_here()
		k = k + 1
		local q = manny:getpos()
		PrintDebug("NAVTRACE " .. case.id .. " " .. k .. format(" %.6f %.6f %.4f %.1f", q.x, q.y, q.z, manny:getrot().y) .. "\n")
	end
	break_here()
	local p = manny:getpos()
	AR_WALK = nil
	PrintDebug("NAVTEST slide_rec " .. case.id .. format(" %.4f %.4f", p.x, p.y) .. "\n")
	local at = AR_SLIDE_EXPECT and AR_SLIDE_EXPECT[case.id]
	if at then
		local d = sqrt((p.x - at[1]) * (p.x - at[1]) + (p.y - at[2]) * (p.y - at[2]))
		ar_nt_log("slide", case, d <= 0.01, format("ended at %.4f %.4f, the original at %.4f %.4f", p.x, p.y, at[1], at[2]))
	else
		ar_nt_log("slide", case, TRUE, format("recorded %.4f %.4f", p.x, p.y))
	end
end
if ar_nt_tier("slide") and (not AR_NT_ONLY or AR_NT_ONLY == "slide") then
	local i = 1
	while AR_NT_SLIDES[i] do
		if not AR_NT_IDS or AR_NT_IDS[AR_NT_SLIDES[i].id] then
			ar_nt_slide(AR_NT_SLIDES[i])
		end
		i = i + 1
	end
end
PrintDebug("NAVTEST SUMMARY slide " .. AR_NT_PASS.slide .. "/" .. AR_NT_RUN.slide .. "\n")

-- Collision with another actor (COLLISION_BOX or COLLISION_SPHERE): Manny (a sphere) walks at Velasco, who is set up as the game does it
-- (re.setup_velasco_idles2). The expected end points are the ones of the original (nav_coll_expect.lua, recorded from a run of this
-- test on the original: the line "NAVTEST coll_rec <id> x y" of its log); a case without one only records where Manny ends.
--   collision_box_velasco: from the tip of the sliver in the exterior of the Rubamat, the case that held the original up in ch13
--   collision_<box|sphere>_<yaw>_<angle>_<radius>: a ring of starts round the actor in the open floor of the set, walking at it
AR_NT_COLLS = {
	{ id = "collision_box_velasco", set = "re", from = { 0.585, -4.258, -3.4 }, to = { 0.66, -3.86 }, at = { 0.4201, -4.1254 }, tol = 0.04, o = { 0.633072972, -3.98850989 }, yaw = 140.009003, mode = 1 },
}
AR_NT_COLL_N = 1
AR_NT_COLL_MODES = { { "box", 1 }, { "sphere", 2 } }
AR_NT_COLL_YAWS = { 0, 45, 90, 140 }
AR_NT_COLL_RADII = { 0.5, 0.35 }
AR_NT_A = 1
while AR_NT_COLL_MODES[AR_NT_A] do
	AR_NT_B = 1
	while AR_NT_COLL_YAWS[AR_NT_B] do
		-- (a sphere does not turn: one yaw is enough)
		if AR_NT_COLL_MODES[AR_NT_A][2] == 1 or AR_NT_B == 1 then
			AR_NT_C = 1
			while AR_NT_C <= 8 do
				AR_NT_D = 1
				while AR_NT_COLL_RADII[AR_NT_D] do
					local ang = (AR_NT_C - 1) * 45
					local r = AR_NT_COLL_RADII[AR_NT_D]
					AR_NT_COLL_N = AR_NT_COLL_N + 1
					AR_NT_COLLS[AR_NT_COLL_N] = { id = "collision_" .. AR_NT_COLL_MODES[AR_NT_A][1] .. "_" .. AR_NT_COLL_YAWS[AR_NT_B] .. "_" .. ang .. "_" .. floor(r * 100), set = "re", from = { 2.7 + r * cos(ang), -4.2 + r * sin(ang), -3.4 }, to = { 2.7, -4.2 }, o = { 2.7, -4.2 }, yaw = AR_NT_COLL_YAWS[AR_NT_B], mode = AR_NT_COLL_MODES[AR_NT_A][2], tol = 0.05 }
					AR_NT_D = AR_NT_D + 1
				end
				AR_NT_C = AR_NT_C + 1
			end
		end
		AR_NT_B = AR_NT_B + 1
	end
	AR_NT_A = AR_NT_A + 1
end

-- The same starts with a fixed heading and no steering, 40 frames, every frame traced (NAVTRACE lines): the first frame in which two engines
-- differ is the contact, not a result of 120 frames of steering. tools/compare_trace.py reads the traces.
AR_NT_COLL_BASE = AR_NT_COLL_N
AR_NT_E = 1
while AR_NT_E <= AR_NT_COLL_BASE do
	local c = AR_NT_COLLS[AR_NT_E]
	AR_NT_COLL_N = AR_NT_COLL_N + 1
	AR_NT_COLLS[AR_NT_COLL_N] = { id = "collisionS" .. strsub(c.id, 10), set = c.set, from = c.from, to = c.to, o = c.o, yaw = c.yaw, mode = c.mode, tol = 0.03, static = TRUE, frames = 40 }
	AR_NT_E = AR_NT_E + 1
end

ar_nt_coll = function(case)
	local set = getglobal(case.set)
	ar_fx_open(case)
	if system.currentSet ~= set then
		ar_fx_enter_set(set, case)
		ar_wait_for_control()
		ar_nt_settle()
	end
	-- (the scripts of the set put Velasco back at his place by the car when the set is entered, and play his idles; the one that waits
	-- for his walk to the car starts the others when it ends: they are stopped, and he is placed again, until he stays where the case
	-- puts him for 5 frames, on both engines)
	local placed = 0
	local vp = nil
	while placed < 4 do
		if re then
			stop_script(re.setup_velasco_idles)
			stop_script(re.setup_velasco_idles2)
			stop_script(re.vel_look_around)
			stop_script(re.fake_conversation)
			stop_script(velasco.walk_down_to_car)
			stop_script(velasco.walk_and_face)
			stop_script(velasco.new_run_idle)
		end
		velasco:default()
		velasco:put_in_set(set)
		velasco:push_costume("velasco_idles.cos")
		velasco:setpos(case.o[1], case.o[2], -3.4000001)
		-- (no fifth argument: TRUE would make him turn to it over the next frames)
		velasco:setrot(0, case.yaw, 0)
		velasco:set_visibility(TRUE)
		local wf = 0
		while wf < 5 do
			break_here()
			wf = wf + 1
		end
		vp = velasco:getpos()
		if abs(vp.x - case.o[1]) < 0.001 and abs(vp.y - case.o[2]) < 0.001 then
			placed = 10
		else
			placed = placed + 1
			velasco:pop_costume()
		end
	end
	velasco:set_collision_mode(case.mode, 1)
	if placed < 10 then
		ar_log("NAVTEST placement: " .. case.id .. " Velasco is at " .. format("%.4f %.4f", vp.x, vp.y) .. ", not " .. format("%.4f %.4f", case.o[1], case.o[2]))
		if AR_NT_DEBUG then
			print_scripts()
		end
	end
	manny:put_in_set(set)
	manny:set_collision_mode(AR_NT_MANNY_MODE or COLLISION_SPHERE)
	SetActorCollisionScale(manny.hActor, 0.349999994)
	manny:setpos(case.from[1], case.from[2], case.from[3])
	local yawto = GetActorYawToPoint(manny.hActor, case.to[1], case.to[2], case.from[3])
	if AR_NT_DEBUG then
		ar_log(format("NAVTEST yaw before %.6f, to the point %.6f", manny:getrot().y, yawto))
	end
	-- (at once: a fifth argument TRUE makes the actor turn to the heading over the next frames, from the heading the case before left)
	manny:setrot(0, yawto, 0)
	break_here()
	break_here()
	if AR_NT_DEBUG then
		local q0 = manny:getpos()
		ar_log(format("NAVTEST yaw after %.6f at %.7f %.7f", manny:getrot().y, q0.x, q0.y))
	end
	local k = 0
	local frames = case.frames or 150
	while k < frames do
		if not case.static then
			ar_steer(case.to[1], case.to[2], case.from[3], 8)
		end
		manny:walk_forward()
		break_here()
		k = k + 1
		if case.static or AR_NT_TRACE then
			local q = manny:getpos()
			PrintDebug("NAVTRACE " .. case.id .. " " .. k .. format(" %.6f %.6f %.4f %.1f", q.x, q.y, q.z, manny:getrot().y) .. "\n")
		end
	end
	local p = manny:getpos()
	manny:set_collision_mode(COLLISION_OFF)
	SetActorCollisionScale(manny.hActor, 1)
	velasco:set_collision_mode(COLLISION_OFF)
	velasco:pop_costume()
	velasco:put_in_set(nil)
	local at = case.at or (AR_COLL_EXPECT and AR_COLL_EXPECT[case.id])
	AR_NT_RUN.coll = (AR_NT_RUN.coll or 0) + 1
	AR_NT_PASS.coll = AR_NT_PASS.coll or 0
	PrintDebug("NAVTEST coll_rec " .. case.id .. format(" %.4f %.4f", p.x, p.y) .. "\n")
	if at then
		local d = sqrt((p.x - at[1]) * (p.x - at[1]) + (p.y - at[2]) * (p.y - at[2]))
		local note = ""
		if d > case.tol and AR_KNOWN and AR_KNOWN[case.id] then
			-- (a head-on slide goes to the side that the last digits of the floats give, and those depend on the whole history of the angles of the
			-- actors, the original gives either side for the same case: the end on the other side of the line of the approach is as good)
			local ux = case.to[1] - case.from[1]
			local uy = case.to[2] - case.from[2]
			local ul = sqrt(ux * ux + uy * uy)
			ux = ux / ul
			uy = uy / ul
			local rx = at[1] - case.from[1]
			local ry = at[2] - case.from[2]
			local al = rx * ux + ry * uy
			local mx = case.from[1] + 2 * al * ux - rx
			local my = case.from[2] + 2 * al * uy - ry
			local dm = sqrt((p.x - mx) * (p.x - mx) + (p.y - my) * (p.y - my))
			if dm <= case.tol then
				d = dm
				note = " (the other side of the approach)"
			end
		end
		ar_nt_log("coll", case, d <= case.tol, format("ended at %.4f %.4f, the original at %.4f %.4f", p.x, p.y, at[1], at[2]) .. note)
	else
		ar_nt_log("coll", case, TRUE, format("recorded %.4f %.4f", p.x, p.y))
	end
end
AR_NT_RUN.coll = 0
AR_NT_PASS.coll = 0
AR_NT_K = 1
while AR_NT_COLLS[AR_NT_K] do
	if ar_nt_tier("coll") and (not AR_NT_ONLY or AR_NT_ONLY == "coll" or AR_NT_ONLY == AR_NT_COLLS[AR_NT_K].id) and (not AR_NT_IDS or AR_NT_IDS[AR_NT_COLLS[AR_NT_K].id]) then
		ar_nt_coll(AR_NT_COLLS[AR_NT_K])
	end
	AR_NT_K = AR_NT_K + 1
end

ar_fx_close()
PrintDebug("NAVTEST SUMMARY leak " .. AR_NT_PASS.leak .. "/" .. AR_NT_RUN.leak .. "\n")
PrintDebug("NAVTEST SUMMARY unit " .. AR_NT_PASS.unit .. "/" .. AR_NT_RUN.unit .. ", walk " .. AR_NT_PASS.walk .. "/" .. AR_NT_RUN.walk .. "\n")
ar_log("NAVTEST SUMMARY unit " .. AR_NT_PASS.unit .. "/" .. AR_NT_RUN.unit .. ", walk " .. AR_NT_PASS.walk .. "/" .. AR_NT_RUN.walk)
AR_FAILED = AR_NT_PASS.unit < AR_NT_RUN.unit or AR_NT_PASS.walk < AR_NT_RUN.walk or AR_NT_PASS.move < AR_NT_RUN.move or AR_NT_PASS.coll < AR_NT_RUN.coll or AR_NT_PASS.turn < AR_NT_RUN.turn or AR_NT_PASS.slide < AR_NT_RUN.slide or AR_NT_PASS.leak < AR_NT_RUN.leak
-- (the failures were counted, not stopped on: now the run ends and the game closes)
AR_KEEP_GOING = nil

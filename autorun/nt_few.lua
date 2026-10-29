AR_NT_ONLY = "coll"
AR_NT_IDS = { collisionS_box_0_0_35 = 1, collisionS_box_0_180_35 = 1, collisionS_box_0_270_35 = 1, collisionS_box_0_90_35 = 1, collision_box_0_0_35 = 1, collision_box_0_180_35 = 1 }
AR_NT_MODE = "none"
-- Tiers B and C: the cases of nav_cases.lua in the game, on either engine. Manny is put straight into the set at the start of each
-- case (the story does not matter here).
--   unit: the plan only (found, over the links it has to take, on the right level, ending where it has to)
--   walk: the walk with the keys, from the same start (arrives, or goes through the door, with no failure, in how long)
-- AR_NT_MODE = "unit" or "walk" runs only one of the two, AR_NT_ONLY = "<id>" one case.
--   ScummVM:  EXTRA=nav_cases.lua sh run_chapter.sh test_nav.lua 900
--   original: sh test_nav_original.sh

ar_load(19)
AR_KEEP_GOING = TRUE

ar_nt_states = function(set, nav, case)
	-- (the sectors as the set starts: the ones that are off then, and nothing else; then what the case asks for)
	local list = nav.n
	local hot = nav.hn
	local i = 1
	while list[i] do
		MakeSectorActive(list[i], TRUE)
		i = i + 1
	end
	i = 1
	while hot[i] do
		MakeSectorActive(hot[i], TRUE)
		i = i + 1
	end
	i = 1
	-- (the boxes as they are when Manny holds something: shrunk, which leaves gaps at the edges the sectors share)
	if case.shrink then
		ShrinkBoxes(set.shrinkable or 0.1)
		AR_NT_SHRUNK = TRUE
	end
	local offs = nav.off or { }
	while offs[i] do
		MakeSectorActive(offs[i], nil)
		i = i + 1
	end
	i = 1
	while case.on and case.on[i] do
		MakeSectorActive(case.on[i], TRUE)
		i = i + 1
	end
	i = 1
	while case.off and case.off[i] do
		MakeSectorActive(case.off[i], nil)
		i = i + 1
	end
end

-- the set of the case, Manny in it at the start
-- Everything that a case can leave behind, put back before the next one: a case is the same alone, after any other, on either engine.
ar_nt_reset = function()
	manny:set_collision_mode(COLLISION_OFF)
	SetActorCollisionScale(manny.hActor, 1)
	manny:set_run(FALSE)
	if manny.is_holding then
		manny:clear_hands()
	end
	-- the planner and the follower
	AR_OBST = { }
	AR_FOLLOW_RESULT = nil
	AR_WIGGLE = nil
	AR_WIGGLES = 0
	AR_REENTRIES = 0
	AR_IN_CLIMB = nil
	AR_PARTIAL_USED = nil
	AR_ALLOW_PARTIAL = nil
	AR_GOAL_REGION = nil
	AR_GOAL_HOT = { }
	AR_FAILED = nil
	AR_TELE_SEEN = AR_TELE_COUNT
	AR_STEER_TURNED = nil
	AR_STEER_TURNED2 = nil
	AR_TURN_STALL = 0
end

-- The scripts of a set that was just entered, and of a door that was just gone through, run for a frame or two: wait until no cutscene, no
-- sentence, and Manny has not moved for 3 frames (cap 3 s)
ar_nt_settle = function()
	local still = 0
	local waited = 0
	local lx = 1000
	local ly = 1000
	while still < 3 and waited < 3000 do
		local p = manny:getpos()
		if cutSceneLevel == 0 and not find_script(Sentence) and abs(p.x - lx) < 0.0005 and abs(p.y - ly) < 0.0005 then
			still = still + 1
		else
			still = 0
		end
		lx = p.x
		ly = p.y
		break_here()
		waited = waited + system.frameTime
	end
end

ar_nt_place = function(case)
	local set = getglobal(case.set)
	ar_nt_reset()
	-- (the boxes are given back in the set that shrank them, before it is left: the original walks the sectors it keeps of that set when
	-- they are given back, and crashes in another one)
	if AR_NT_SHRUNK then
		UnShrinkBoxes()
		AR_NT_SHRUNK = nil
	end
	-- (the scripts of the door the case before went through can still be running, and switch to their own set after: wait them out)
	local tries = 0
	while system.currentSet ~= set and system.currentSet.setFile ~= set.setFile and tries < 4 do
		ar_wait_for(function() return cutSceneLevel == 0 and not find_script(Sentence) end, 30000)
		set:switch_to_set()
		ar_wait_for_control()
		ar_nt_settle()
		tries = tries + 1
	end
	if system.currentSet ~= set and system.currentSet.setFile ~= set.setFile then
		ar_log("NAVTEST placement: could not enter " .. tostring(case.set) .. ", in " .. tostring(system.currentSet.setFile) .. " not " .. tostring(set.setFile))
	end
	-- (a case must not start on a ladder: the climbing state is checked, logged and cleared)
	if manny.is_climbing then
		ar_log("NAVTEST placement: Manny was climbing, state cleared")
		manny.is_climbing = nil
		manny:stop_chore()
	end
	manny:put_in_set(set)
	local nav = ar_nav_of(set)
	ar_nt_states(set, nav, case)
	local x = 0
	local y = 0
	local z = 0
	if case.from == "door" then
		x, y, z = ar_nav_hot_point(set[case.door])
	elseif case.from then
		x = case.from[1]
		y = case.from[2]
		z = ar_nt_goal_z(nav, case.from[1], case.from[2], case.from[3])
	else
		x, y = ar_nav_centre(nav, 1)
		z = nav.p[1][3]
	end
	manny:setpos(x, y, z)
	-- (facing the goal, as a player who walks there does, unless the case says; the line of a stair is made from the heading)
	local yaw = case.yaw
	if not yaw and case.to then
		yaw = GetActorYawToPoint(manny.hActor, case.to[1], case.to[2], z)
	elseif not yaw then
		-- (the same heading for every case that does not say: not what the case before left, the line of a stair depends on it)
		yaw = 0
	end
	manny:setrot(0, yaw or manny:getrot().y, 0)
	-- (the line a stair walks Manny along is made once, when he steps on it, from the way he faces: a placement is a step on it)
	stop_script(stairman)
	stop_script(curbman)
	SetActorConstrain(manny.hActor, nil)
	start_script(stairman)
	start_script(curbman)
	break_here()
	break_here()
	ar_wait_for_control()
	-- (the scripts of the set that was just entered settle the sectors in their first frames: after them the states are the case's)
	ar_nt_settle()
	ar_nt_states(set, nav, case)
	-- (Manny is where the case asked: a placement that the game moves is told, it is not a result of the planner)
	local at = manny:getpos()
	if abs(at.x - x) > 0.3 or abs(at.y - y) > 0.3 then
		ar_log("NAVTEST placement: " .. case.id .. " asked for " .. format("%.2f %.2f %.2f", x, y, z) .. ", Manny is at " .. format("%.2f %.2f %.2f", at.x, at.y, at.z))
	end
	return set, nav
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
		if AR_NT_MODE ~= "walk" and not case.nounit then
			ar_nt_unit(case)
		end
		if AR_NT_MODE ~= "unit" then
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
	if (not AR_NT_ONLY or AR_NT_ONLY == "move" or AR_NT_ONLY == AR_NT_MOVES[AR_NT_K].id) and (not AR_NT_PAT or strfind(AR_NT_MOVES[AR_NT_K].id, AR_NT_PAT)) then
		local c = AR_NT_MOVES[AR_NT_K]
		ar_nt_move_case(c)
	end
	AR_NT_K = AR_NT_K + 1
end
PrintDebug("NAVTEST SUMMARY move " .. AR_NT_PASS.move .. "/" .. AR_NT_RUN.move .. "\n")

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
	if system.currentSet ~= set then
		set:switch_to_set()
		ar_wait_for_control()
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
	manny:set_collision_mode(COLLISION_SPHERE)
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
	velasco:set_collision_mode(COLLISION_OFF)
	velasco:pop_costume()
	velasco:put_in_set(nil)
	local at = case.at or (AR_COLL_EXPECT and AR_COLL_EXPECT[case.id])
	AR_NT_RUN.coll = (AR_NT_RUN.coll or 0) + 1
	AR_NT_PASS.coll = AR_NT_PASS.coll or 0
	PrintDebug("NAVTEST coll_rec " .. case.id .. format(" %.4f %.4f", p.x, p.y) .. "\n")
	if at then
		local d = sqrt((p.x - at[1]) * (p.x - at[1]) + (p.y - at[2]) * (p.y - at[2]))
		ar_nt_log("coll", case, d <= case.tol, format("ended at %.4f %.4f, the original at %.4f %.4f", p.x, p.y, at[1], at[2]))
	else
		ar_nt_log("coll", case, TRUE, format("recorded %.4f %.4f", p.x, p.y))
	end
end
AR_NT_RUN.coll = 0
AR_NT_PASS.coll = 0
AR_NT_K = 1
while AR_NT_COLLS[AR_NT_K] do
	if (not AR_NT_ONLY or AR_NT_ONLY == "coll" or AR_NT_ONLY == AR_NT_COLLS[AR_NT_K].id) and (not AR_NT_IDS or AR_NT_IDS[AR_NT_COLLS[AR_NT_K].id]) then
		ar_nt_coll(AR_NT_COLLS[AR_NT_K])
	end
	AR_NT_K = AR_NT_K + 1
end

PrintDebug("NAVTEST SUMMARY unit " .. AR_NT_PASS.unit .. "/" .. AR_NT_RUN.unit .. ", walk " .. AR_NT_PASS.walk .. "/" .. AR_NT_RUN.walk .. "\n")
ar_log("NAVTEST SUMMARY unit " .. AR_NT_PASS.unit .. "/" .. AR_NT_RUN.unit .. ", walk " .. AR_NT_PASS.walk .. "/" .. AR_NT_RUN.walk)
AR_FAILED = AR_NT_PASS.unit < AR_NT_RUN.unit or AR_NT_PASS.walk < AR_NT_RUN.walk or AR_NT_PASS.move < AR_NT_RUN.move or AR_NT_PASS.coll < AR_NT_RUN.coll
-- (the failures were counted, not stopped on: now the run ends and the game closes)
AR_KEEP_GOING = nil

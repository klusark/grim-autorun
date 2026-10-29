-- The placement of a case for the in-game tests (test_nav.lua, test_rules.lua): the sectors as the case wants them, Manny in the set at the start.
-- Loaded after ar_fixture.lua, on both engines.

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
	AR_GOAL_LINKS = nil
	AR_GOAL_LINK_OF = nil
	AR_GOAL_CELLS = nil
	AR_GOAL_K = nil
	AR_OPTIMISTIC = nil
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
	ar_fx_open(case)
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
		ar_fx_enter_set(set, case)
		ar_wait_for_control()
		ar_nt_settle()
		tries = tries + 1
	end
	if system.currentSet ~= set and system.currentSet.setFile ~= set.setFile then
		ar_log("NAVTEST placement: could not enter " .. tostring(case.set) .. ", in " .. tostring(system.currentSet.setFile) .. " not " .. tostring(set.setFile))
	end
	-- (a case must not start on a ladder: the climbing state is checked, logged and cleared)
	if manny.is_climbing then
		ar_log("NAVTEST placement: Manny was climbing, the ladder left as the game leaves it")
		-- (the game's own end of a climb: the climbing scripts and chores stopped, the ladder costume popped, the boxes followed again; clearing the
		-- flag only left him in the costume of the ladder and the animations of the next case wrong)
		manny:stop_climb_ladder()
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
	-- (the original stops with an error on a script that does not exist)
	if stairman then
		stop_script(stairman)
	end
	if curbman then
		stop_script(curbman)
	end
	SetActorConstrain(manny.hActor, nil)
	start_script(stairman)
	start_script(curbman)
	break_here()
	break_here()
	ar_wait_for_control()
	-- (the scripts of the set that was just entered settle the sectors in their first frames: after them the states are the case's)
	ar_nt_settle()
	-- (a script of the set that was left, in its last frame, can have set a collision mode: the case starts from the fixture's own)
	ar_fx_defaults()
	AR_FX_BASE = ar_fx_snapshot()
	if AR_FX_DUMP then
		ar_fx_dump(case)
	end
	ar_nt_states(set, nav, case)
	-- (the world of the planner was made for the sector states of an earlier case: it is made again, as tier A does at each placement)
	nav.w = nil
	-- (Manny is where the case asked: a placement that the game moves is told, it is not a result of the planner)
	local at = manny:getpos()
	if abs(at.x - x) > 0.3 or abs(at.y - y) > 0.3 then
		ar_log("NAVTEST placement: " .. case.id .. " asked for " .. format("%.2f %.2f %.2f", x, y, z) .. ", Manny is at " .. format("%.2f %.2f %.2f", at.x, at.y, at.z))
	end
	return set, nav
end


-- AR_NT_TIERS = { unit = 1, coll = 1 }: only these tiers (a process for each, side by side); none given: all
ar_nt_tier = function(name)
	return not AR_NT_TIERS or AR_NT_TIERS[name]
end

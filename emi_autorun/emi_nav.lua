-- The Grim planner in EMI: generated/emi_nav_planner.lua is autorun/ar_nav.lua with its calls into the game renamed (emi_nav_gen.py);
-- this file is those calls, for Guybrush, and the sectors of the sets (emi_nav_data.lua, gen_nav.py, from the set files).
--
-- The planner works in Grim's axes and metres: the floor is x/y and z is up. EMI's floor is x/z with y up, and its unit is about
-- AR_NAV_S times smaller than a metre (Guybrush runs about 4 units a second, Manny 1.6 m): a point of EMI (x, y, z) is the planner's
-- (x / S, z / S, y / S). Its distances (cells of 8 cm, an arrival within 2.5 cm, the 35 cm a floor may step) then mean to Guybrush
-- what they mean to Manny.
-- Guybrush walks with the keys: a frame of the follower that steps holds the forward key, one that does not lets it go; the turn keys
-- and the run key as in emi_lib.lua's ar_step and ar_steer.
-- Lua 3.1: no closures over locals, no for loops, no break.

AR_NAV_S = AR_NAV_S or 2.5
-- (EMI's sectors named stair are not constrained: stairman only changes the walk chore)
AR_NAV_CONS = nil
-- (no way: not tried again (Grim waits up to 18 s for a way to open); the grid planner of emi_lib.lua walks instead)
AR_NAV_TRIES = 0
-- (cells searched in a frame: the whole of Lucre town, 80,000 cells, in 20 frames instead of 267. Monkey4.exe kills a script only after
-- 10 million instructions in one function without a break_here)
AR_SLICE_N = 4000
-- (the box of a door or trigger that is not the goal: Doorman sends Guybrush through any door whose box he steps into (on the island
-- maps the roads run through the boxes of the places), so the way keeps out of them where there is any other)
AR_HOT_COST = 100
-- (turns: Grim's follower walks on while it turns up to 75 degrees off the way, and at the start of every walk. Guybrush swings wide
-- in a turn while he walks: from the foot of Mêlée town's porch he swung into porch_trigger, 0.12 m away, and the game walked him up
-- the steps. Turned standing at the start, and walking on only within 30 degrees, as emi_lib.lua's walker did)
AR_NO_START_WALK = TRUE
AR_TURN_LIM = 30
-- (a goal off the floor, however far: the walk ends at the nearest floor (the place of a door can be 10 units from it))
AR_GOAL_OFF_MAX = 1000000

-- where Guybrush is, in the planner's axes
ar_np = function()
	local p = manny:getpos()
	return { x = p.x / AR_NAV_S, y = p.z / AR_NAV_S, z = p.y / AR_NAV_S }
end

-- where another actor is, in the planner's axes
ar_nap = function(h)
	local x, y, z = GetActorPos(h)
	if not x then
		-- (an actor that has been freed, whose handle the collision hook still holds: GetActorPos gives nothing (Monkey4.exe 0x4161a0).
		-- Far away, so that it is in no one's way: the obstacle list of the planner does not ask)
		return 1000000, 1000000, 1000000
	end
	return x / AR_NAV_S, z / AR_NAV_S, y / AR_NAV_S
end

-- the heading from Guybrush toward the planner's point (x, y, z), as Grim's GetActorYawToPoint gives it: his yaw and the turn that
-- Monkey4's builtin gives (see ar_want_yaw)
ar_nyaw = function(h, x, y, z)
	return manny:getrot().y + GetActorYawToPoint(h, x * AR_NAV_S, z * AR_NAV_S, y * AR_NAV_S)
end

-- the turn keys toward the planner's point; the follower holds or lets go the forward key itself
ar_nsteer = function(x, y, z, thr)
	AR_NSTEER = TRUE
	local r = ar_steer(x * AR_NAV_S, z * AR_NAV_S, y * AR_NAV_S, thr)
	AR_NSTEER = nil
	return r
end

-- a step: the forward key held for this frame. The game's walk starts when the key goes down (SampleButtonHandler -> move_actor);
-- held for 20 frames with Guybrush not moving (a cutscene ended that walk while the key was down), it is let go for a frame and pressed
-- again, as a player does
ar_nstep = function()
	AR_NSTEPPED = TRUE
	if AR_DRIVE.MOVE_FORWARD and not manny:is_moving() then
		AR_NSTILL = (AR_NSTILL or 0) + 1
		if AR_NSTILL >= 20 then
			AR_NSTILL = 0
			ar_drive_key("MOVE_FORWARD", nil)
			return
		end
	else
		AR_NSTILL = 0
	end
	ar_step(manny)
end

-- run (the run key) or walk
ar_nrun = function(on)
	if on then
		AR_NAV_SLOW = nil
	else
		AR_NAV_SLOW = TRUE
	end
end

ar_nconstrain = function(h, on)
end

-- a frame of the follower that did not step lets the forward key go (Grim's walk_forward walks for one frame; a held key walks on)
-- (wrapped once for each load of the planner: a save brings back the functions of the run that made it, and this file is loaded again
-- after it, with or without the planner)
if ar_follow_frame ~= AR_NFF_W then
	AR_NFF = ar_follow_frame
	AR_NFF_W = function(nav, w, path, n, cum, i)
		AR_NSTEPPED = nil
		local r = AR_NFF(nav, w, path, n, cum, i)
		if not AR_NSTEPPED then
			ar_drive_key("MOVE_FORWARD", nil)
		end
		return r
	end
	ar_follow_frame = AR_NFF_W
end
-- (each walk along a way starts and ends with every key let go: one held from before a cutscene would not start the game's walk)
if ar_follow ~= AR_NFOL_W then
	AR_NFOL = ar_follow
	AR_NFOL_W = function(nav, w, path, stop_when, budget)
		ar_drive_stop()
		AR_NSTILL = 0
		local p0 = manny:getpos()
		local r = AR_NFOL(nav, w, path, stop_when, budget)
		ar_drive_stop()
		-- (held up without having moved at all: Guybrush cannot walk here (the wedding ship holds him at the cannon, with no button
		-- handler). The walk ends, as the grid planner's did after 3.6 s; seven plans more were 35 s, and the coal in his hand went cold)
		local p1 = manny:getpos()
		if r == "replan" and system.currentSet == AR_FOLLOW_SET and abs(p1.x - p0.x) + abs(p1.z - p0.z) < 0.02 then
			ar_log("nav: Guybrush has not moved at all on this way, the walk ends here")
			AR_GNAV_NOMOVE = TRUE
			r = "done"
		end
		return r
	end
	ar_follow = AR_NFOL_W
end
-- (the planner's report of why there is no way reads the search's lists, which a goal that is given up before the search does not
-- make)
if ar_nav_why ~= AR_NWHY_W then
	AR_NWHY = ar_nav_why
	AR_NWHY_W = function(nav, w, mp, x, y, z)
		AR_CLOSED = AR_CLOSED or { }
		AR_G = AR_G or { }
		return AR_NWHY(nav, w, mp, x, y, z)
	end
	ar_nav_why = AR_NWHY_W
end

-- is sector i on: Monkey4's own IsSectorActive, by its name
ar_nav_active = function(nav, i)
	if AR_OPTIMISTIC and not nav.hot then
		return TRUE
	end
	return IsSectorActive(nav.n[i])
end

-- the planner's lists of a set: from emi_nav_data.lua, scaled into the planner's units; kept by the set file
ar_nav_emi_list = function(src, names, polys)
	local i = 1
	while src[i] do
		local s = src[i]
		names[i] = s[1]
		local p = { }
		local k = 2
		while s[k] do
			p[k - 1] = s[k] / AR_NAV_S
			k = k + 1
		end
		polys[i] = p
		i = i + 1
	end
end

ar_nav_of = function(set)
	if not set or not set.setFile then
		return nil
	end
	local nav = AR_NAV[set.setFile]
	if nav then
		return nav
	end
	local key = strlower(set.setFile)
	local dot = strfind(key, ".", 1, 1)
	if dot then
		key = strsub(key, 1, dot - 1)
	end
	local d = AR_NAV_EMI and AR_NAV_EMI[key]
	if not d then
		return nil
	end
	d = d()
	nav ={ n = { }, p = { }, hn = { }, hp = { }, off = { }, adj = { } }
	ar_nav_emi_list(d.w, nav.n, nav.p)
	ar_nav_emi_list(d.h, nav.hn, nav.hp)
	AR_NAV[set.setFile] = nav
	ar_log("nav: " .. tostring(set.setFile) .. " read, " .. ar_nav_len(nav.n) .. " walk sectors, " .. ar_nav_len(nav.hn) .. " hot")
	return nav
end

-- Walks Guybrush to EMI's point (x, y, z) with the Grim planner. Returns TRUE when the walk is over, nil when the planner has no way
-- (or no sectors for the set), and the caller's own planner walks instead.
ar_gnav_walk = function(x, y, z, stop_when)
	if not system.currentSet or not ar_nav_of(system.currentSet) then
		return nil
	end
	ar_wait_for_control()
	local set = system.currentSet
	-- (the planner's give-ups, which end a Grim run, end only the planner's walk: the log says why, and the grid planner goes on)
	AR_NAV_FAILED = nil
	AR_GNAV_NOMOVE = nil
	AR_GNAV_FAIL = ar_fail
	ar_fail = function(msg)
		ar_log("NAVFALLBACK " .. msg)
		AR_NAV_FAILED = TRUE
	end
	AR_NAV_SLOW = nil
	-- (the point of a walk is mostly the use point of an object, which the floor need not reach (ch23's first one in Lucre town is on
	-- sector18, a floor of its own 0.3 units from the rest): as near as the floor goes, as the grid planner did)
	AR_ALLOW_PARTIAL = TRUE
	local r = ar_nav_walk(x / AR_NAV_S, z / AR_NAV_S, y / AR_NAV_S, stop_when)
	AR_ALLOW_PARTIAL = nil
	ar_fail = AR_GNAV_FAIL
	AR_NAV_SLOW = nil
	ar_drive_stop()
	AR_STEER_TURNED = nil
	if AR_NAV_FAILED or not r then
		if not AR_NAV_FAILED then
			ar_log("NAVFALLBACK no way in " .. ar_set_name())
		end
		return nil
	end
	return TRUE
end

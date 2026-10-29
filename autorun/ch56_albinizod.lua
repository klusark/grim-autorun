-- Chapter 56 (Year 4): the men's room of the Le Mans lobby turns Manny into a gentleman (manny.fancy), then
-- back through the theater sewer to the sewer hub. The grinder with the arm in it makes baby's breath grow
-- wherever it is used on the floor where Bowlsley the bird once walked: first in the sewer hub, then in the
-- sewer maze along the whole trail to the spot where Albinizod is found. Checkpoint in slot 72.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 300000
ar_load(56)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()

-- the men's room is a hot sector, walked into
ar_walk_to(1.96, 4.2, 0.9, function() return cutSceneLevel > 0 end)
ar_wait_for(function() return manny.fancy end, 30000)
ar_wait_for_control()
ar_check(manny.fancy, "Manny is dressed up")

-- out by the service door, down to the sewer hub
ar_go(ly.service_door, te)
ar_wait_for_control()
ar_walk_to(0.0, 0.3, 0)
ar_go(te.sh_door, sh)
ar_wait_for_control()
ar_climb(nil, function() return not manny.is_climbing end, 40000)
ar_wait_for_control()
ar_expect_set(sh, "in the sewer hub")

-- the first flowers: the grinder on the strip toward the sewer maze (the game then grinds a few more)
ar_hold(th.grinder)
ar_walk_to(3.05, -0.9, 0)
while TurnActorTo(manny.hActor, 3.2, 0.5, 0) do
	break_here()
end
ar_press("use")
ar_wait_for(function() return exclaimed_tears end, 20000)
ar_wait_for_control()
ar_check(exclaimed_tears, "baby's breath grows where the grinder was used")
ar_go(sh.zw_door, zw)
ar_wait_for_control()
-- the game grinds a few more flowers by itself on arriving
ar_wait_for(function() return zw.talked_flowers end, 20000)
sleep_for(3000)
ar_wait_for_control()

-- the trail: Manny steps along it and uses the grinder every 40 cm, facing the way on
-- a short hop with the stick: first turn to the point, then walk straight at it
ar_hop = function(x, y)
	-- (already there, or a few centimeters past it: no turning back for that)
	if ar_dist2d(x, y) < 0.2 then
		return
	end
	local frames = 0
	local last = manny:getpos()
	local stuck = 0
	manny:set_run(FALSE)
	while ar_dist2d(x, y) > 0.06 and frames < 1500 and stuck < 100 do
		-- turn toward the point, and walk on once he faces it
		-- (within 15 cm the way to the point changes with every step: straight on from there)
		if ar_dist2d(x, y) > 0.15 then
			TurnActorTo(manny.hActor, x, y, 0)
		end
		if not manny:is_turning() then
			manny:walk_forward()
		end
		break_here()
		frames = frames + 1
		local p = manny:getpos()
		if abs(p.x - last.x) + abs(p.y - last.y) < 0.0005 then
			stuck = stuck + 1
		else
			stuck = 0
		end
		last = p
	end
end

ar_trail = function(pts)
	local i = 1
	while pts[i + 1] and not uncovered_trail do
		local a = pts[i]
		local b = pts[i + 1]
		local dx = b[1] - a[1]
		local dy = b[2] - a[2]
		local len = sqrt(dx * dx + dy * dy)
		local steps = floor(len / 0.43)
		if steps < 1 then
			steps = 1
		end
		local k = 0
		while k < steps and not uncovered_trail do
			ar_hop(a[1] + dx * k / steps, a[2] + dy * k / steps)
			if manny.is_holding ~= th.grinder then
				ar_hold(th.grinder)
			end
			AR_TURN_T = 0
			while TurnActorTo(manny.hActor, b[1], b[2], 0) and AR_TURN_T < 3000 do
				break_here()
				AR_TURN_T = AR_TURN_T + system.frameTime
			end
			ar_press("use")
			sleep_for(300)
			ar_wait_for_control()
			ar_wait_for(function() return not inventory_disabled end, 10000)
			k = k + 1
		end
		i = i + 1
	end
end
ar_trail({ {-0.89, 4.6}, {-1.14, 2.61}, {-1.15, 1.5}, {-1.17, 0.9}, {-1.21, 0.78}, {-1.58, -1.76}, {-0.98, -2.0}, {-0.59, -1.95}, {0.17, -1.5}, {0.34, -0.7}, {2.34, 0.88}, {2.67, 1.15} })
ar_wait_for(function() return uncovered_trail end, 60000)
ar_wait_for_control()
ar_check(uncovered_trail, "the trail leads to Albinizod")
ar_expect_set(at, "in the albinizod tunnel")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 56")
ar_checkpoint(57)

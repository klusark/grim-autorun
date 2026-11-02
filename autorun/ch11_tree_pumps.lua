-- Chapter 11 (Year 2): the tree pump room. The tree's four pumps beat out of step; pushing the
-- wheelbarrow over the hoses pinches them and sets a hose's beat when it is released, and the
-- tree shakes when the pumps pair up (1 with 2, 3 with 4, the two pairs apart). Sweep the
-- barrow over the hoses until they do, put the lever down so Glottis climbs the tree to
-- fasten a weight, and put it up again while he is up there: the tree shakes the shocks loose.
-- The shocks loose, the Bone Wagon takes the bumpy road (it leads to the beaver room once the signpost is set in the navigation room). Checkpoint in slot 27.

ar_load(10)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- The lever first: down, so that Glottis climbs the tree (and fastens his weight), and up again at once. Glottis stays in the tree
-- with the lever up, and from then on the game itself, the moment the pumps are in step, drops the barrow and runs the cutscene that
-- shakes the shocks loose: nothing is left to do after the barrow.
ar_do("use", tr.switch)
ar_wait_for(function() return tr.tree.has_glottis end, 120000)
ar_check(tr.tree.has_glottis, "Glottis is in the tree")
ar_wait_for_control()
ar_do("use", tr.switch)
ar_wait_for_control()
ar_do("use", tr.wheelbarrow)
ar_wait_for(function() return manny.holding_wheelbarrow end, 60000)
ar_wait_for_control()
ar_check(manny.holding_wheelbarrow, "Manny pushes the wheelbarrow")

-- (Fallback) Sweep the hoses forward and back, stopping and waiting a random moment in the gaps between
-- them: the barrow is pushed along one line, over the hoses of pumps 1, 2, 3 and 4 in that
-- order (barrow x about 2.85, 3.07, 3.31 and 3.60). Each hose gets its beat when the barrow
-- leaves it, so the waits decide the beats, and some sweep pairs the pumps up.
AR_GAPS = { 2.96, 3.19, 3.45, 3.69 }

ar_barrow_x = function()
	return tr.barrow:getpos().x
end

-- Pushes the barrow forward to x, or pulls it back to x
ar_barrow_idle = function()
	return not find_script(tr.push_barrow) and not find_script(tr.pull_barrow)
end

-- Waits until the barrow is at x (AR_X), or has stopped for a while: it has reached the end of its travel, which is
-- not the same place in the two engines
ar_wait_barrow = function(forward)
	local t = 0
	local still = 0
	local last = ar_barrow_x()
	while t < 15000 do
		local bx = ar_barrow_x()
		if (forward and bx >= AR_X) or (not forward and bx <= AR_X) then
			return TRUE
		end
		if abs(bx - last) < 0.002 then
			still = still + 100
		else
			still = 0
		end
		last = bx
		if still >= 1500 and t >= 1500 then
			return TRUE
		end
		sleep_for(100)
		t = t + 100
	end
	return ar_fail("timed out after 15000 ms waiting for the barrow to get to x " .. tostring(AR_X))
end

ar_barrow_to = function(x, forward)
	AR_X = x
	-- a key pressed while the barrow still finishes its last step does nothing
	ar_wait_for(ar_barrow_idle, 8000)
	if forward then
		ar_key_down("MOVE_FORWARD")
		ar_wait_barrow(TRUE)
		ar_key_up("MOVE_FORWARD")
	else
		ar_key_down("MOVE_BACKWARD")
		ar_wait_barrow(FALSE)
		ar_key_up("MOVE_BACKWARD")
	end
	sleep_for(150)
end

-- Pulls the barrow back until the limit stops it: Manny stands in the pull limit and the
-- barrow is just in the hose of pump 1
ar_barrow_to_the_end = function()
	ar_wait_for(ar_barrow_idle, 8000)
	ar_key_down("MOVE_BACKWARD")
	ar_wait_for(function() return manny:find_sector_name("wb_pull_lim") end, 15000)
	ar_key_up("MOVE_BACKWARD")
	sleep_for(150)
end

-- The pumps start on beats 3 1 2 4 (a beat is a tick of 500 ms, 1 to 4, and a pump takes the beat of the tick on which the barrow
-- leaves its hose) and the tree shakes when pump 1 = pump 2, pump 3 = pump 4 and the two pairs differ. So only the middle two hoses
-- are needed: pump 2 takes the beat of pump 1 and pump 3 that of pump 4, and the outer two stay as they are. The barrow stands just past
-- the hose of pump 2; it is run into a hose, held there (the pump's beat is 0 while it is in the hose) until the tick that makes the
-- exit land on the beat wanted, and run out. A start tick that lands on another beat is moved by the difference and tried again.
-- (the old sweeping over all four hoses, below, is what is left to do if the beats are not as they start)
ar_set_hose = function(pump, want, inx, outx, tick0)
	local tick = tick0 or want
	while tick > 4 do
		tick = tick - 4
	end
	local tries = 0
	while pump.beat ~= want and tries < 12 do
		tries = tries + 1
		-- (into the hose from the side the barrow is on)
		ar_barrow_to(inx, ar_barrow_x() < inx)
		-- (the barrow is still, then the push starts on the edge of the tick, and goes on until the hose lets go: every frame counted,
		-- so that the same start tick gives the same beat)
		local w = 0
		while not ar_barrow_idle() and w < 600 do
			break_here()
			w = w + 1
		end
		w = 0
		while tr.beat ~= tick and w < 400 do
			break_here()
			w = w + 1
		end
		ar_key_down("MOVE_FORWARD")
		w = 0
		while pump.beat == 0 and w < 300 do
			break_here()
			w = w + 1
		end
		ar_key_up("MOVE_FORWARD")
		w = 0
		while not ar_barrow_idle() and w < 600 do
			break_here()
			w = w + 1
		end
		ar_log("hose: pump beat " .. tostring(pump.beat) .. ", wanted " .. want .. ", started on tick " .. tick)
		if pump.beat ~= want then
			tick = tick + want - pump.beat
			while tick < 1 do
				tick = tick + 4
			end
			while tick > 4 do
				tick = tick - 4
			end
		end
	end
	return pump.beat == want
end
if tr.pump1.beat >= 1 and tr.pump4.beat >= 1 and tr.pump1.beat ~= tr.pump4.beat and ar_barrow_x() > 3.1 and ar_barrow_x() < 3.2 then
	ar_log("the middle two hoses: pump 2 to beat " .. tr.pump1.beat .. ", pump 3 to beat " .. tr.pump4.beat)
	if ar_set_hose(tr.pump2, tr.pump1.beat, 3.07, 3.13, tr.pump1.beat - 1) then
		ar_set_hose(tr.pump3, tr.pump4.beat, 3.34, 3.43, tr.pump4.beat + 1)
	end
	ar_wait_for(function() return tr.tree.synched or mod_solved end, 3000)
end

AR_SWEEPS = 0
AR_FWD = TRUE
while not tr.tree.synched and AR_SWEEPS < 500 do
	AR_SWEEPS = AR_SWEEPS + 1
	local i
	if AR_FWD then
		i = 1
		while i <= 4 and not tr.tree.synched do
			ar_barrow_to(AR_GAPS[i] - 0.03, TRUE)
			sleep_for(rndint(0, 600))
			i = i + 1
		end
	else
		i = 4
		while i >= 1 and not tr.tree.synched do
			ar_barrow_to(AR_GAPS[i] + 0.03, FALSE)
			sleep_for(rndint(0, 600))
			i = i - 1
		end
		ar_barrow_to_the_end()
		sleep_for(rndint(0, 600))
	end
	if AR_FWD then
		AR_FWD = FALSE
	else
		AR_FWD = TRUE
	end
	ar_log("sweep " .. AR_SWEEPS .. ": beats " .. tr.pump1.beat .. " " .. tr.pump2.beat .. " " .. tr.pump3.beat .. " " .. tr.pump4.beat .. " synched " .. (tr.tree.synched and "yes" or "no"))
end
ar_keys_up()
-- (the pumps in step: the game drops the barrow and shakes the shocks loose by itself)
ar_check(tr.tree.synched or mod_solved, "the pumps are out of step")
ar_wait_for(function() return mod_solved end, 240000)
ar_check(mod_solved, "the shocks are loose (puzzle state 17)")
ar_wait_for_control()
-- The bumpy road at the east end of the signpost fork (the wagon stands by the trail to the tree): along the vehicle sectors, through the door box.
if not manny.is_driving then
	ar_do("use", sg.bone_wagon)
	ar_wait_for(function() return manny.is_driving end, 120000)
	ar_wait_for_control()
end
AR_ROAD = {
	{ 7.00, -4.60 },
	{ 6.70, -3.20 },
	{ 6.30, -1.80 },
	{ 6.30, -0.30 },
	{ 7.10, 0.90 },
	{ 8.20, 2.00 },
	{ 9.30, 3.00 },
	{ 10.50, 4.00 },
	{ 11.55, 4.50 },
	{ 12.00, 4.80 },
}
AR_ROAD_I = 1
while AR_ROAD[AR_ROAD_I] and system.currentSet == sg do
	ar_drive_to(AR_ROAD[AR_ROAD_I][1], AR_ROAD[AR_ROAD_I][2], 0, 0.8, 20000, function() return system.currentSet ~= sg end)
	AR_ROAD_I = AR_ROAD_I + 1
end
ar_wait_for(function() return system.currentSet == bv end, 60000)
ar_expect_set(bv, "in the beaver room")
ar_wait_for_control()
ar_state("end of chapter 11")
ar_checkpoint(11)

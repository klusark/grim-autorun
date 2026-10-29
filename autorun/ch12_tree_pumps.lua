-- Chapter 12 (Year 2): the tree pump room. The tree's four pumps beat out of step; pushing the
-- wheelbarrow over the hoses pinches them and sets a hose's beat when it is released, and the
-- tree shakes when the pumps pair up (1 with 2, 3 with 4, the two pairs apart). Sweep the
-- barrow over the hoses until they do, put the lever down so Glottis climbs the tree to
-- fasten a weight, and put it up again while he is up there: the tree shakes the shocks loose.
-- With the beavers gone and the padlock open the Bone Wagon then leaves the forest, and
-- Year 2 ends. Checkpoint in slot 28.

ar_load(11)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_do("use", tr.wheelbarrow)
ar_wait_for(function() return manny.holding_wheelbarrow end, 60000)
ar_wait_for_control()
ar_check(manny.holding_wheelbarrow, "Manny pushes the wheelbarrow")

-- Sweep the hoses forward and back, stopping and waiting a random moment in the gaps between
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
ar_check(tr.tree.synched, "the pumps are out of step")

-- let go of the wheelbarrow
AR_TRIES = 0
while manny.holding_wheelbarrow and AR_TRIES < 8 do
	AR_TRIES = AR_TRIES + 1
	ar_wait_for_control()
	ar_press("use")
	sleep_for(1500)
	ar_wait_for(function() return not find_script(tr.drop_wheelbarrow) end, 20000)
end
ar_check(not manny.holding_wheelbarrow, "Manny has put the wheelbarrow down")
ar_wait_for_control()

-- the lever down: Glottis climbs the tree, the lever up again while he is in it
ar_do("use", tr.switch)
ar_wait_for(function() return tr.tree.has_glottis end, 120000)
ar_check(tr.tree.has_glottis, "Glottis is in the tree")
ar_wait_for_control()
ar_do("use", tr.switch)
ar_wait_for(function() return mod_solved end, 240000)
ar_check(mod_solved, "the shocks are loose (puzzle state 17)")
ar_wait_for_control()
ar_state("end of chapter 12")
ar_checkpoint(12)

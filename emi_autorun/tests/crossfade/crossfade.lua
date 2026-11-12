-- Two chores of the same priority at full weight on one character: Guybrush's pickup_high and pickup_low (both priority 4).
-- The original averages the two rotations of each joint into a quaternion that it does not normalize; the matrix of a short
-- quaternion is not a rotation. Each pose is held still 0.6 s in (time scale 0.001): A = high alone, B = low alone, C = both.
ar_log("=== crossfade test ===")
ar_wait_for_control()
dofile("_jumpscripts.lua")
start_script(jump_script, "200")
ar_dlg("el15")
sleep_for(2000)
ar_exhaust("el15", nil, 20)
ar_dlg_done("el15")
ar_wait_for_control()
sleep_for(2000)
xf_pose = function(tag, a, b)
	local ha = guybrush:play_chore_looping(a)
	local hb = nil
	if b then hb = guybrush:play_chore_looping(b) end
	sleep_for(600)
	guybrush:set_time_scale(0.001)
	sleep_for(300)
	ar_log("POSE " .. tag)
	sleep_for(4000)
	guybrush:set_time_scale(1)
	StopChore(ha)
	if hb then StopChore(hb) end
	sleep_for(1500)
end
xf_pose("A", "pickup_high")
xf_pose("B", "pickup_low")
xf_pose("C", "pickup_high", "pickup_low")
ar_log("POSES DONE")

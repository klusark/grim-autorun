-- Act 3 chapter 10: the gold mine: Timmy and a banana in the vent, the lever, the tube and the weed whipper (banana picker)
ar_log("=== ACT3 ch10 mine ===")
ar_wait_for_control()
a3_goto("monkey beach")
a3_feed_timmy(mib.timmy_obj)
a3_goto("canyon")
ar_log("timmy obj in canyon " .. tostring(can.timmy_obj))
a3_feed_timmy(can.timmy_obj)
ar_log("timmy following " .. tostring(glob.timmy_following))
a3_mt = 0
while system.currentSet ~= gom and a3_mt < 4 do
	a3_mt = a3_mt + 1
	-- (the walk to the mine shaft can cross the door to the map: then back to the canyon and again)
	if system.currentSet ~= can then
		a3_goto("canyon")
	end
	ar_do("use", can.gom_door)
	ar_wait_for_control()
	sleep_for(1000)
end
ar_state("mine")
-- (the tunnel to the vent is half a unit wide: Timmy, who follows Guybrush, can wander into it ahead of him and stand there; then there is
-- no way past. As a player does: back out of the tunnel's mouth and let him come over, then go in with him behind)
a3_timmy_in_tunnel = function()
	if not timmy or timmy.in_set ~= system.currentSet then
		return nil
	end
	local t = timmy:getpos()
	return t.z > 1.5 and abs(t.x) < 1.5
end
-- (he can also wander in while Guybrush walks: the walk to the vent is tried again after backing out, up to three times)
local a3_tt = 0
local a3_vent_done = nil
while not a3_vent_done and a3_tt < 4 do
	a3_tt = a3_tt + 1
	if a3_timmy_in_tunnel() then
		ar_log("Timmy is in the tunnel: out of its mouth, waiting for him")
		ar_walk_to(0.8, 0, -3)
		ar_try_wait(function() return not a3_timmy_in_tunnel() end, 15000)
	end
	AR_KEEP_GOING = a3_tt < 4
	a3_vent_done = ar_do("use", gom.vent)
	AR_KEEP_GOING = FALSE
	if not a3_vent_done then
		AR_FAILED = FALSE
		ar_log("the vent was not reached (try " .. a3_tt .. ")")
	end
end
ar_log("vent open " .. tostring(glob.vent_open) .. " timmy in set " .. tostring(timmy.in_set == system.currentSet))
ar_do("use", gom.vent, props.bananas)
ar_log("monkey in vent " .. tostring(glob.monkey_in_vent))
ar_do("use", gom.vent)
ar_log("vent open " .. tostring(glob.vent_open))
ar_do("use", gom.door_portal, props.bananas)
ar_log("door opened " .. tostring(glob.opened_gom_door))
ar_do("use", gom.mrb_door)
ar_state("tube")
ar_do("use", mrb.weed_whipper, props.banana_picker)
ar_state("whipper")
ar_do("use", mrb.big_tube)
ar_wait_for_control()
ar_do("use", gom.can_door)
ar_wait_for_control()
ar_state("back in the canyon")
ar_check(props.weed_whipper.state ~= PROP_INITIAL, "the weed whipper")
ar_checkpoint(310)

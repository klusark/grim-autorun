-- DEV: does pushing north in the pocket of the garage (floor ends at the trigger of the elevator door) enter the trigger, on both engines
ar_load(19)
ga:switch_to_set()
ar_wait_for_control()
manny:put_in_set(ga)
MakeSectorActive("ga_elevator_psg", nil)
MakeSectorActive("ha_door_trigger", TRUE)
manny:setpos(15.64, -0.45, 0)
manny:setrot(0, 0, 0)
sleep_for(1500)
ar_wait_for_control()
tp_t = 0
while tp_t < 4000 do
	manny:walk_forward()
	break_here()
	tp_t = tp_t + system.frameTime
	if tp_t - 500 * floor(tp_t / 500) < system.frameTime then
		local p = manny:getpos()
		local hid, hname = manny:find_sector_type(HOT)
		PrintDebug(format("TRIGPROBE t %d at %.4f %.4f hot %s flag %s psg %s sentence %s", tp_t, p.x, p.y, tostring(hname), tostring(doorman_in_hot_box), tostring(ar_sector_on("ga_elevator_psg")), tostring(find_script(Sentence))) .. "\n")
	end
end
PrintDebug("TRIGPROBE DONE\n")

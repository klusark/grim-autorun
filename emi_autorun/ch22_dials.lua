ar_has_directions = function() return props.pegnose_map.state == PROP_INV end
-- EMI chapter 22: the dials of Deadeye's file retrieval system: Pegnose's file ("directions") is retrieved with the combination the game keeps
ar_load(121)
ar_log("=== EMI ch22 dials ===")
ar_dial_press = function(name)
	ar_press_key(ar_real_key(name))
	ar_release_key(ar_real_key(name))
	sleep_for(700)
	ar_try_wait(ar_dial_idle, 30000)
end
ar_dial_idle = function()
	return not find_script(pop.file_controls.buttonDelay) and not find_script(pop.file_controls.roll_roller) and not pop.arm_moving
end
ar_in_file_controls = function()
	return system.buttonHandler == pop.file_controls.buttonHandler
end
ar_wait_for_control()
ar_dial_target = { glob.pegnose_first_i, glob.pegnose_mid_i, glob.pegnose_last_i }
ar_log("combination " .. tostring(ar_dial_target[1]) .. tostring(ar_dial_target[2]) .. tostring(ar_dial_target[3]))
-- (the verb runs until the dials are left, and Guybrush is out of the set meanwhile: started, not waited for)
ar_put_away()
AR_START_SET = system.currentSet
AR_CODE = pop.file_controls.use
ar_approach(pop.file_controls)
ar_send_verb("use", pop.file_controls, "use the file controls")
ar_try_wait(ar_in_file_controls, 30000)
ar_log("in controls: " .. tostring(ar_in_file_controls()) .. " handler=" .. tostring(system.buttonHandler) .. " cut=" .. tostring(cutSceneLevel) .. " target=" .. tostring(pop.file_controls.current_target) .. " key=" .. tostring(ar_real_key("TURN_RIGHT")))
sleep_for(500)
ar_dial_i = 1
while ar_dial_i <= 3 do
	local guard = 0
	while pop.file_controls.current_target ~= ar_dial_i and guard < 8 do
		ar_dial_press("TURN_RIGHT")
		guard = guard + 1
	end
	guard = 0
	while pop["fc_roll" .. ar_dial_i].value ~= ar_dial_target[ar_dial_i] and guard < 8 do
		ar_dial_press("USE")
		guard = guard + 1
	end
	ar_log("dial " .. ar_dial_i .. " = " .. tostring(pop["fc_roll" .. ar_dial_i].value))
	ar_dial_i = ar_dial_i + 1
end
ar_dial_press("MOVE_BACKWARD")
ar_log("target now " .. tostring(pop.file_controls.current_target))
ar_press_key(ar_real_key("USE"))
ar_wait_for(ar_has_directions, 60000, "the directions")
-- (reading the map: a "press any key" screen; the skipper does not always see it in a long chain)
ar_pak = 0
while ar_pak < 30 and (system.press_any_key or cutSceneLevel > 0) do
	if system.press_any_key then
		ar_log("pressing a key for the map")
		ar_press_key(ar_real_key("USE"))
		ar_release_key(ar_real_key("USE"))
	end
	sleep_for(700)
	ar_pak = ar_pak + 1
end
ar_wait_for_control()
ar_check(props.pegnose_map.state == PROP_INV, "Pegnose's directions are Guybrush's")
ar_checkpoint(22)

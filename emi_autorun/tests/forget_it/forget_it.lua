-- ScummVM #11783: after Escape in Deadeye's file retrieval controls (pop.file_controls), Guybrush's "Ah, forget it" is placed below the
-- verb line. ch22 from its checkpoint (121) into the controls, FI READY (10 s for the capture), the Escape key, held.
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
ar_log("FI READY")
sleep_for(10000)
ar_log("FI ESC")
ar_press_key(ar_real_key("OVERRIDE"))
ar_release_key(ar_real_key("OVERRIDE"))
sleep_for(15000)
ar_log("FI done")

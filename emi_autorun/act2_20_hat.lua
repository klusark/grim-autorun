-- Act 2 chapter 20: the puppets argue under the right rock; the cannon fire digs up the bronze hat
ar_load(219)
ar_log("=== ACT2 ch20 hat ===")
ar_wait_for_control()
ar_put_away()
-- (taking the puppets in hand in front of the right rock starts their show: a task of its own, the conversation blocks the key)
AR_KEEP_GOING = TRUE
A2_HOLD_DONE = nil
a2_hold_task = function()
	ar_hold(props.puppets)
	A2_HOLD_DONE = TRUE
end
start_script(a2_hold_task)
ar_dlg("gp1")
sleep_for(6000)
ar_exhaust("gp1", nil, 12)
ar_wait_for(function() return not (gp1 and gp1.running) end, 120000, "the puppet show to end")
sleep_for(3000)
ar_wait_for_control()
AR_KEEP_GOING = FALSE
ar_state("after the puppets")
ar_check(props.bronzehat.state == PROP_INV, "bronze hat")
ar_checkpoint(220)

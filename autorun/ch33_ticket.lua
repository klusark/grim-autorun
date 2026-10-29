-- Chapter 33: Charlie's ticket printer. The photo finish only develops for the winning ticket:
-- race 6, day 2, week 2, which the printer's buttons are set to (the keys move between the
-- fields and change them) and printed. Checkpoint in slot 49.

ar_load(32)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_do("use", cn.printer)
ar_wait_for(function() return system.buttonHandler == tpButtonHandler end, 60000)
ar_check(system.buttonHandler == tpButtonHandler, "the printer is open")
local tap = function(control)
	ar_key_down(control)
	sleep_for(150)
	ar_key_up(control)
	sleep_for(300)
	ar_wait_for_control()
end
local i = 0
-- race: 1 up to 6
while i < 5 do
	tap("MOVE_FORWARD")
	i = i + 1
end
tap("TURN_LEFT")
tap("MOVE_FORWARD")
tap("TURN_LEFT")
tap("MOVE_FORWARD")
ar_log("printer: race " .. tostring(tp.race) .. " day " .. tostring(tp.day) .. " week " .. tostring(tp.week))
ar_check(tp.race == 6 and tp.day == 2 and tp.week == 2, "the printer shows race 6, day 2, week 2")
tap("TURN_LEFT")
ar_check(tp.current_button == tp.PRINT, "on the print button")
tap("MOVE_FORWARD")
ar_wait_for(function() return cn.ticket.owner == manny end, 60000)
ar_wait_for_control()
ar_check(cn.ticket.owner == manny, "Manny has the ticket")
ar_state("end of chapter 33")
ar_checkpoint(33)

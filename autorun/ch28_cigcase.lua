-- Chapter 28: Nick Virago in the lounge. Having seen him kiss Lola, Manny talks to him; he drops
-- his key and his cigarette case, which Manny takes. Checkpoint in slot 44.

ar_load(27)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_hh_elevator()
ar_go(hh.hl_door, hl)
ar_wait_for_control()
ar_describe()
ar_do("use", hl.virago_obj)
ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
ar_check(vi1 and system.buttonHandler == vi1, "Nick talks")
-- he refuses to help (a first round of questions), then the kiss is thrown at him
ar_pick(vi1, 100)
-- (a good question: with Terry arrested the first one is on the screen and hides the others, any of them leads to the good node)
if ar_line_shown(vi1, vi1[110]) then
	ar_pick(vi1, 110)
else
	ar_pick(vi1, 150)
end
ar_pick(vi1, 170)
ar_pick(vi1, 190)
ar_pick(vi1, 200)
ar_wait_for_control()
ar_do("use", hl.virago_obj)
ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
ar_pick(vi1, 240)
ar_pick(vi1, 280)
ar_wait_for(function() return hl.nick_gone end, 300000)
ar_wait_for_control()
ar_check(hl.nick_gone, "Nick has left")
ar_describe()
ar_do("pickUp", hl.case)
ar_wait_for(function() return hl.case.owner == manny end, 120000)
ar_wait_for_control()
ar_check(hl.case.owner == manny, "Manny has the cigarette case")
ar_state("end of chapter 28")
ar_checkpoint(28)

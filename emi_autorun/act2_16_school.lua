-- Act 2 chapter 16: the Pirate Transmogrification Academy: the class, every answer the worst: the dunce cap
ar_load(215)
ar_log("=== ACT2 ch16 school ===")
ar_wait_for_control()
ar_put_away()
-- (the cheat boxes of this town belong to the puppet show: they are no stairs)
AR_NO_CHEAT = TRUE
AR_CELL_SET = nil
ar_talk(cpt.teacher_obj)
AR_NO_CHEAT = nil
AR_CELL_SET = nil
ar_dlg("tc1")
a2_ready("tc1", 3000)
ar_lines("tc1")
ar_say("tc1", 70)
a2_ready("tc1", 15000)
ar_lines("tc1")
ar_say("tc1", 72)
ar_wait_for(function() return ar_set_name() == "pirate transmogrification academy" end, 60000, "the school")
-- the quiz
local worst = { 130, 210, 300, 430, 500, 610, 730, 820, 930 }
local q = 1
local guard = 0
-- (the class can be over before the 9th answer: the dunce cap is his, he is back in town; the loop looked for questions 400 s more)
while q <= 9 and guard < 400 and props.dunce_cap.state ~= PROP_INV and not (guard > 5 and ar_set_name() ~= "pirate transmogrification academy" and cutSceneLevel == 0) do
	sleep_for(1000)
	guard = guard + 1
	local d = getglobal("pt1")
	if d and d.running and d.node and ar_dialog_ready(d, 100) then
		local k = a2_pick_any("pt1", worst)
		if k then
			ar_log("quiz answer " .. k)
			q = q + 1
			sleep_for(4000)
		end
	end
end
ar_state("quiz done")
ar_wait_for_control()
ar_log("dunce cap state " .. tostring(props.dunce_cap.state) .. " taken_class " .. tostring(glob.taken_class) .. " set " .. ar_set_name())
ar_check(props.dunce_cap.state == PROP_INV, "dunce cap")
ar_checkpoint(216)

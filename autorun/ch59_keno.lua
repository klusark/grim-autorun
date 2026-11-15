-- Chapter 59 (Year 4): the Le Mans lobby, Charlie gone: the men's room turns Manny into a gentleman (manny.fancy). With the gun in his pocket Manny can
-- talk to Brennis the elevator demon: asked which keno number came up last, Manny picks the number the board
-- shows, with the dialog keys (puzzle state 57). The elevator opens to Hector's foyer (hf).
-- Checkpoint in slot 75.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 300000
ar_load(59)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the men's room is a hot sector, walked into
ar_walk_to(1.96, 4.2, 0.9, function() return cutSceneLevel > 0 end)
ar_wait_for(function() return manny.fancy end, 30000)
ar_wait_for_control()
ar_check(manny.fancy, "Manny is dressed up")
-- (the keno board draws a number every 15 s and clears after its tenth, ly.keno_actor.game; the dialog stops the draws but not the clock, so a question asked
-- on the tenth number has its board cleared under it, current_number nil, and no answer is right. On the tenth the board's clear is waited for: the
-- dialog's intro then draws a new number at once, dlg_brennis2.lua)
if ly.keno_actor.game_index and ly.keno_actor.game_index >= 10 then
	ar_log("keno: the board is on its last number, waiting for it to clear")
	ar_wait_for(function() return ly.keno_actor.game_index < 10 end, 20000)
end
ar_do("use", ly.brennis_obj)
ar_wait_for(function() return br2 and system.buttonHandler == br2 and br2.num_choices end, 120000)
sleep_for(500)
ar_check(br2 and system.buttonHandler == br2, "Brennis asks his keno question")
-- the board shows the number; the list is moved to the line of that number, one key tap each. The number is looked at again before every tap (the dialog can
-- draw a new one, ly.keno_actor:choose_number, after it was first read: a list moved to 22 for a board that showed 22 was answered wrong)
ar_log("the keno board shows " .. tostring(ly.keno_actor.current_number))
local taps = 0
-- (each tap until the list has moved, at most the 330 ms that a tap took)
-- (the board clears now and then, current_number nil, before it shows a new one: then a frame is waited)
while br2.current_line ~= ly.keno_actor.current_number and taps < 200 do
	local num = ly.keno_actor.current_number
	if num then
		AR_KENO_LINE = br2.current_line
		local key = "DIALOG_DOWN"
		if br2.current_line > num then
			key = "DIALOG_UP"
		end
		ar_key_down(key)
		ar_try_wait(function() return br2.current_line ~= AR_KENO_LINE end, 330)
		ar_key_up(key)
	end
	break_here()
	taps = taps + 1
end
ar_log("keno: line " .. tostring(br2.current_line) .. " of " .. tostring(br2.num_choices) .. ", the board " .. tostring(ly.keno_actor.current_number) .. ", " .. taps .. " taps")
ar_press_key(ar_real_key("DIALOG_CHOOSE"))
ar_wait_for(function() return cur_puzzle_state[57] end, 60000)
ar_wait_for(function() return system.currentSet == hf end, 60000)
ar_wait_for_control()
ar_check(cur_puzzle_state[57], "Brennis opens the elevator (puzzle state 57)")
ar_expect_set(hf, "in Hector's foyer")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 59")
ar_checkpoint(60)

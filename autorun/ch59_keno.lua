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
ar_do("use", ly.brennis_obj)
ar_wait_for(function() return br2 and system.buttonHandler == br2 and br2.num_choices end, 120000)
sleep_for(500)
ar_check(br2 and system.buttonHandler == br2, "Brennis asks his keno question")
-- the board shows the number; the list is moved down to the line of that number, one key tap each
local target = ly.keno_actor.current_number
ar_log("the keno board shows " .. tostring(target))
local taps = 0
-- (each tap until the list has moved, at most the 330 ms that a tap took)
while br2.current_line < target and taps < 80 do
	AR_KENO_LINE = br2.current_line
	ar_key_down("DIALOG_DOWN")
	ar_try_wait(function() return br2.current_line ~= AR_KENO_LINE end, 330)
	ar_key_up("DIALOG_DOWN")
	break_here()
	taps = taps + 1
end
ar_press_key(ar_real_key("DIALOG_CHOOSE"))
ar_wait_for(function() return cur_puzzle_state[57] end, 60000)
ar_wait_for(function() return system.currentSet == hf end, 60000)
ar_wait_for_control()
ar_check(cur_puzzle_state[57], "Brennis opens the elevator (puzzle state 57)")
ar_expect_set(hf, "in Hector's foyer")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 59")
ar_checkpoint(60)

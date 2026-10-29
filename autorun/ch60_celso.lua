-- Chapter 60 (Year 4): Hector's foyer (hf). Celso and his lady are talked into buying the ticket: the pitch line, then
-- the line about the problems, then the last one (puzzle state ... Celso sells). Then Manny crosses the
-- foyer to the trigger by Hector's door and the old job is on (puzzle state 58). Checkpoint in slot 76.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 300000
ar_load(60)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_do("use", hf.couple)
ar_wait_for(function() return ar_dialog_ready(ce2) end, 60000)
ar_pick(ce2, 110)
ar_wait_for(function() return ar_dialog_ready(ce2) end, 60000)
ar_pick(ce2, 170)
ar_wait_for(function() return ar_dialog_ready(ce2) end, 60000)
ar_pick(ce2, 200)
ar_wait_for(function() return celso.sold end, 120000)
ar_wait_for_control()
ar_check(celso.sold, "Celso buys the ticket")
-- the trigger by Hector's door: walking from Celso's corner across the foyer
ar_walk_to(0.2, -0.6, 0, function() return cutSceneLevel > 0 end)
ar_wait_for(function() return cur_puzzle_state[58] end, 60000)
ar_wait_for_control()
ar_check(cur_puzzle_state[58], "Hector sends Manny on the old job (puzzle state 58)")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 60")
ar_checkpoint(61)

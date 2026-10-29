-- Chapter 49 (Year 3): aboard the Lamancha's sub Domino fights Manny with... Manny puts the scythe into the
-- octopus' eye (Bloodeye). The cutscene ends Year 3 and starts Year 4. Checkpoint in slot 65.

AR_NEW = TRUE
ar_load(49)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
AR_CONTROL_TIMEOUT = 600000
ar_do("use", lu.eye, mo.scythe)
ar_wait_for(function() return cur_puzzle_state[46] end, 120000)
ar_check(cur_puzzle_state[46], "the scythe hits the octopus' eye (puzzle state 46)")
ar_wait_for(function() return system.currentSet == bs end, 600000)
ar_wait_for_control()
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 49")
ar_checkpoint(50)

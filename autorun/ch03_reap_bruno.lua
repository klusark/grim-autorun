-- Chapter 3: in the Land of the Living, reap Bruno's cocoon with the scythe. The cutscene
-- ends back in the hallway of the Department of Death. Checkpoint in slot 12.

ar_load(2)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_do("use", lr.cocoon, mo.scythe)
ar_wait_for(function() return reaped_bruno and system.currentSet == ha end, 120000)
ar_check(reaped_bruno, "Bruno has been reaped")
ar_check(cur_puzzle_state[3], "puzzle state 3 set")
ar_wait_for_control()
ar_state("end of chapter 3")
ar_checkpoint(3)

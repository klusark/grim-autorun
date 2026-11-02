-- Chapter 9 (Year 2): through the trapdoor to the lobby of the beaver room and the key that hangs
-- from the sign (the padlock of the beaver room needs it at the end of the year). Checkpoint in slot 24.

ar_load(8)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(na.trapdoor, lb)
ar_do("use", lb.sign)
ar_wait_for(function() return lb.key.owner == manny end, 120000)
ar_check(lb.key.owner == manny, "Manny has the key")
ar_state("end of chapter 9")
ar_checkpoint(9)

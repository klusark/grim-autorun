-- Chapter 9 (Year 2): through the trapdoor to the lobby of the beaver room, the key that hangs
-- from the sign, and on to the beaver room. Checkpoint in slot 24.

ar_load(8)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(na.trapdoor, lb)
ar_do("use", lb.sign)
ar_wait_for(function() return lb.key.owner == manny end, 120000)
ar_check(lb.key.owner == manny, "Manny has the key")
ar_go(lb.bd_door, bv)
ar_state("end of chapter 9")
ar_checkpoint(9)

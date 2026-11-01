-- Chapter 3: in the Land of the Living, reap Bruno's cocoon with the scythe. The cutscene
-- ends back in the hallway of the Department of Death. Checkpoint in slot 12.

ar_load(2)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- No planner: the scythe in hand, steered at the body with the forward key held until the game offers it, as a player does. The verb is then given from there and
-- the scene begins at once: it walks Manny to its own place at the body (0.61 0.365); the walk to the use point on the west side, 190 frames, is not done at all
ar_hold(mo.scythe)
AR_OBJ = lr.cocoon
ar_walk_stick(lr.cocoon.obj_x, lr.cocoon.obj_y, 0, ar_offered, 5000)
ar_do("use", lr.cocoon, mo.scythe)
ar_wait_for(function() return reaped_bruno and system.currentSet == ha end, 120000)
ar_check(reaped_bruno, "Bruno has been reaped")
ar_check(cur_puzzle_state[3], "puzzle state 3 set")
ar_wait_for_control()
ar_state("end of chapter 3")
ar_checkpoint(3)

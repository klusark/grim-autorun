-- Chapter 29: the cigarette case is a bomb. Carla, still sobbing in the security hall, is asked to
-- watch it for a moment; it blows the safe open and Manny fishes out the skeleton key.
-- Checkpoint in slot 45.

ar_load(28)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- (from the hall in front of the lounge elevator, where chapter 27 ends: Nick was talked to in chapter 19, so the lounge is not entered)
ar_go(hh.tb_door, tb)
ar_wait_for_control()
ar_go(tb.gt_door, gt)
ar_wait_for_control()
ar_go(gt.sl_door, sl)
ar_wait_for_control()
ar_do("use", sl.carla_obj, hl.case)
ar_wait_for(function() return bo1 and system.buttonHandler == bo1 end, 120000)
ar_check(bo1 and system.buttonHandler == bo1, "Manny talks to Carla about the case")
ar_pick(bo1, 300)
ar_pick(bo1, 400)
ar_wait_for(function() return sl.bomb_detonated end, 300000)
ar_wait_for(function() return sl.key.owner == manny end, 300000)
ar_wait_for_control()
ar_check(sl.key.owner == manny, "Manny has the skeleton key")
ar_state("end of chapter 29")
ar_checkpoint(29)

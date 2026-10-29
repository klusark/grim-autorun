-- Chapter 21: Carla at the security lobby. Manny drinks the gold flake liqueur just outside (it only
-- lasts a few seconds), is searched at the metal detector and charms Carla, who throws the metal
-- detector into the cat box. Checkpoint in slot 37.

ar_load(20)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(si.ladder, se)
ar_go(se.sd_door, xb)
-- back along the extend-o-bridge, the stick follows its camera boxes
ar_bridge_west()
ar_go(xb.tx_door, tx)
ar_go(tx.ts_door, ts)
ar_go(ts.tb_door, tb)
ar_wait_for_control()
ar_go(tb.gt_door, gt)
ar_wait_for_control()
ar_state("in the security lobby")
-- down the stairs into the security hall (Carla greets Manny when he steps off them)
ar_go(gt.sl_door, sl)
ar_state("in the security hall")
ar_walk_to(-0.67, -0.92, 0)
ar_wait_for_control()
-- the liqueur wears off in ten seconds: drink it here, just short of the detector, and walk through
ar_hold(ci.liqueur)
ar_press("use")
ar_wait_for(function() return manny.golden end, 20000)
ar_check(manny.golden, "Manny is golden")
ar_wait_for_control()
-- through the metal detector: Carla searches Manny and, charmed, tells her troubles
ar_walk_to(0.17, -0.35, 0)
ar_wait_for(function() return ca2 and system.buttonHandler == ca2 end, 120000)
ar_check(ca2 and system.buttonHandler == ca2, "Carla talks")
-- the babble goes on until the detector line is offered
ar_wait_for(function() return ca2[30].text ~= nil and ca2[30].text ~= "" and system.buttonHandler == ca2 end, 300000)
ar_pick(ca2, 30)
ar_wait_for(function() return ca2.node == "detector" end, 30000)
ar_pick(ca2, 100)
ar_wait_for(function() return sl.detector.in_catbox end, 60000)
ar_check(sl.detector.in_catbox, "the detector is in the cat box")
ar_wait_for(function() return sl.carla_scorned end, 120000)
ar_wait_for_control()
ar_state("end of chapter 21")
ar_describe()
ar_checkpoint(21)

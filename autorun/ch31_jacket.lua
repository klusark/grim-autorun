-- Chapter 31: the card for Lupe at the coat check, who hands Manny the jacket of the man the card
-- belongs to; the pocket holds a slip of paper. Checkpoint in slot 47.

ar_load(30)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(lx.dd_door, dd)
ar_go(dd.bw_door, bw)
ar_go(bw.ev_door, ev, -2.49, -2.35, 0.2)
ar_go(ev.ce_door, ce, -0.5, -0.85, 0.05)
ar_go(ce.cc_door, cc)
-- Lupe, who has something to tell Manny about the kiss, grabs him on arrival
sleep_for(3000)
ar_wait_for_control()
ar_do("use", cc.lupe_obj, lx.lengua)
ar_wait_for(function() return cc.jacket.owner == manny end, 300000)
ar_wait_for_control()
ar_check(cc.jacket.owner == manny, "Manny has the jacket")
ar_do("use", cc.jacket)
ar_wait_for(function() return cc.anchor_paper.owner == manny end, 300000)
ar_wait_for_control()
ar_check(cc.anchor_paper.owner == manny, "Manny has the slip of paper")
ar_do("use", cc.lupe_obj, cc.jacket)
ar_wait_for(function() return cc.jacket.owner ~= manny end, 120000)
ar_wait_for_control()
ar_state("end of chapter 31")
ar_checkpoint(31)

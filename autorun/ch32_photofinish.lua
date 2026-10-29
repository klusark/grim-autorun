-- Chapter 32: back to the ship. With the sailor out cold, the slip of paper (Manny's "autograph
-- from the anchor") gets Toto to hand over the photo finish picture. Checkpoint in slot 48.

ar_load(31)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(cc.ce_door, ce)
ar_go(ce.ev_door, ev)
ar_go(ev.be_door, bw)
ar_go(bw.hb_door, hb)
ar_go(hb.xb_door, xb)
ar_bridge_east()
ar_go(se.si_door, si)
ar_wait_for_control()
ar_do("use", si.toto_obj, cc.anchor_paper)
ar_wait_for(function() return si.photofinish.owner == manny end, 600000)
ar_wait_for_control()
ar_check(si.photofinish.owner == manny, "Manny has the photo finish")
ar_state("end of chapter 32")
ar_checkpoint(32)

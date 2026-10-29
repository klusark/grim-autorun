-- Chapter 24: the V.I.P. pass to Glottis at the piano, who runs off to gamble in the high roller
-- lounge. Checkpoint in slot 40.

ar_load(23)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(pc.ev_door, ev)
ar_go(ev.ce_door, ce, -0.5, -0.85, 0.05)
ar_go(ce.cc_door, cc)
ar_go(cc.ci_door, ci)
ar_wait_for_control()
ar_do("use", ci.glottis_obj, cn.pass)
ar_wait_for(function() return hl.glottis_gambling end, 600000)
ar_wait_for_control()
ar_check(hl.glottis_gambling, "Glottis gambles")
ar_state("end of chapter 24")
ar_checkpoint(24)

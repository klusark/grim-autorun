-- Chapter 43: stockings for Chepito's gun. Checkpoint in slot 59.

ar_load(42)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(ar.vd_door, vd)
ar_go(vd.fh_door, fh)
ar_go(fh.ea_door, ea)
ar_go(ea.mn_door, mn)
ar_wait_for_control()
ar_do("use", mn.chepito_obj, ar.stockings)
ar_wait_for(function() return mn.gun.owner == manny end, 300000)
ar_wait_for_control()
ar_check(mn.gun.owner == manny, "Manny has the gun")
ar_state("end of chapter 43")
ar_checkpoint(43)

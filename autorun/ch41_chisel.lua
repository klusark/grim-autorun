-- Chapter 41: the miners' foreman Chepito wants a hammer for his chisel: tools swapped.
-- Checkpoint in slot 57.

ar_load(40)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(fo.fh_door, fh)
ar_go(fh.ea_door, ea)
ar_go(ea.mn_door, mn)
ar_wait_for_control()
ar_describe()
ar_do("use", mn.chepito_obj, fo.hammer)
ar_wait_for(function() return mn.chisel.owner == manny end, 300000)
ar_wait_for_control()
ar_check(mn.chisel.owner == manny, "Manny has the chisel")
ar_state("end of chapter 41")
ar_checkpoint(41)

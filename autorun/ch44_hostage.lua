-- Chapter 44: the gun for Meche in the ashtray room: she is taken hostage (cutscene) and locked up
-- in the vault by Domino. Checkpoint in slot 60.

ar_load(43)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(mn.ea_door, ea)
ar_go(ea.fh_door, fh)
ar_go(fh.vd_door, vd)
ar_go(vd.ar_door, ar)
ar_wait_for_control()
ar_wait_for(function() return not find_script(ar.greet_manny) and cutSceneLevel == 0 end, 300000)
ar_do("use", ar.meche_obj, mn.gun)
ar_wait_for(function() return meche.locked_up end, 300000)
ar_wait_for(function() return not find_script(cut_scene.hostage) and cutSceneLevel == 0 end, 900000)
ar_wait_for_control()
ar_state("end of chapter 44")
ar_checkpoint(44)

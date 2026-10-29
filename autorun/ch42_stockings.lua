-- Chapter 42: Meche's ashtray room. Twisting the ashtray while Meche flicks her ash sets her stockings
-- alight; they are thrown into the wastebasket and Manny takes the remains. Checkpoint in slot 58.

ar_load(41)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(mn.ea_door, ea)
ar_go(ea.fh_door, fh)
ar_go(fh.vd_door, vd)
ar_go(vd.ar_door, ar)
ar_wait_for_control()
ar_wait_for(function() return ar.greeted and not find_script(ar.greet_manny) and cutSceneLevel == 0 end, 300000)
ar_wait_for_control()
local tries = 0
while not ar.stockings_tossed and tries < 40 do
	ar_do("use", ar.ashtray)
	ar_wait_for_control()
	sleep_for(1500)
	tries = tries + 1
end
ar_check(ar.stockings_tossed, "Meche's stockings went up in flames")
ar_wait_for(function() return not find_script(cut_scene.leg) and cutSceneLevel == 0 end, 300000)
ar_wait_for_control()
ar_do("lookAt", ar.wastebasket)
ar_wait_for(function() return ar.stockings.owner == manny end, 120000)
ar_wait_for_control()
ar_check(ar.stockings.owner == manny, "Manny has the stockings")
ar_state("end of chapter 42")
ar_checkpoint(42)

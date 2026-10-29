-- Chapter 53 (Year 4): Meche's plan in the New Headquarters (nq), then down the ladder into the sewer (lw) and
-- on to the sewer hub (sh), where Glottis in the Bone Wagon gives Manny the remote control. Checkpoint in
-- slot 69.

AR_NEW = TRUE
ar_load(53)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_do("use", nq.meche_obj)
ar_wait_for_control()
ar_go(nq.lw_door, lw)
ar_wait_for_control()
ar_go(lw.sh_door, sh)
ar_wait_for_control()
ar_check(sh.remote.owner == manny, "Manny has the remote control")
ar_state("end of chapter 53")
ar_checkpoint(54)

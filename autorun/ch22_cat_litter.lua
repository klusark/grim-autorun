-- Chapter 22: the can opener (used in chapter 19 already) and the metal detector were taken from the cat stables in chapter 18, nothing is left to do here but check it. Checkpoint in slot 38.

ar_load(21)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_check(sl.detector.owner == manny, "Manny has the metal detector")
ar_state("end of chapter 22")
ar_checkpoint(22)

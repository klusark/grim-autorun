-- Chapter 23: the morgue (the detector to the coroner, the dog tags on the corpse) is on the way to Velasco now, at the start of chapter 35, where the strike
-- cutscene leaves Manny in front of it. Checkpoint in slot 39.

ar_load(22)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_state("end of chapter 23")
ar_checkpoint(23)

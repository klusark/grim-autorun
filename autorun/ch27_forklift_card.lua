-- Chapter 27: the wine cellar forklift and the union card were in chapter 19 now; nothing is left to do here but check it. Checkpoint in slot 43.

ar_load(26)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_check(hh.union_card.owner == manny, "Manny has the union card")
ar_state("end of chapter 27")
ar_checkpoint(27)

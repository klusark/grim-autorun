-- Chapter 26: the cask (Raoul trapped, the can opener, Manny climbs in) was in chapter 19 now; nothing is left to do here but check it. Checkpoint 42.

ar_load(25)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_check(hk.raoul_quit, "Raoul has quit")
ar_state("end of chapter 26")
ar_checkpoint(26)

-- Chapter 24: Glottis has the V.I.P. pass since chapter 17 and gambles in the high roller lounge; this chapter has nothing left to do but
-- check it. Checkpoint in slot 40.

ar_load(23)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_check(hl.glottis_gambling, "Glottis gambles")
ar_state("end of chapter 24")
ar_checkpoint(24)

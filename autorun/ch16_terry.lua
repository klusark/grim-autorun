-- Chapter 16: the revolutionaries' book to the dock workers' foreman Terry at the dry dock: he is
-- arrested (cutscene). Checkpoint in slot 32.

ar_load(15)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(bi.be_door, be)
ar_go(be.bw_door, bw)
ar_go(bw.dd_door, dd)
ar_wait_for_control()
ar_describe()
ar_do("use", dd.barrel_bees, bi.book)
ar_wait_for(function() return dd.terry_arrested end, 120000)
ar_check(dd.terry_arrested, "Terry is arrested")
ar_wait_for_control()
ar_state("end of chapter 16")
ar_checkpoint(16)

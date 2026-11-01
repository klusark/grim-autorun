-- Chapter 28: Nick Virago was talked to in chapter 19 at the first visit to the lounge (he dropped his key and his cigarette case, which Manny took); nothing
-- is left to do here but check it. Checkpoint in slot 44.

ar_load(27)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- (Nick was talked to and the cigarette case taken at the first visit to the lounge, in chapter 19)
ar_check(hl.nick_gone, "Nick has left")
ar_check(hl.case.owner == manny, "Manny has the cigarette case")
ar_state("end of chapter 28")
ar_checkpoint(28)

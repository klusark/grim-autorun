-- EMI chapter 15: out of the Hall o' Justice
ar_load(14)
ar_log("=== EMI ch15 out ===")
ar_wait_for_control()
ar_do("use", hoj.luc_door)
ar_wait_for_control()
ar_state("out")
ar_checkpoint(15)

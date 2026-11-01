-- Chapter 26: Raoul is trapped in the pantry since chapter 19 (Manny waited by it with the scythe in hand and, the moment Raoul was inside, put the
-- scythe into the door handles), the cask is empty: the can opener opens its lid and Manny climbs in. Checkpoint 42.

ar_load(25)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- (Raoul was trapped in the pantry with the scythe at the first visit to the kitchen, in chapter 19)
ar_check(hk.raoul_trapped, "Raoul is trapped in the pantry")
ar_check(hk.cask_empty, "the cask is empty")
-- the cask: opener, then Manny climbs in
ar_do("use", hk.upper_cask, ks.opener)
ar_wait_for(function() return hk.upper_cask:is_open() end, 60000)
ar_wait_for_control()
ar_do("use", hk.upper_cask)
ar_wait_for(function() return hk.raoul_quit end, 600000)
ar_wait_for_control()
ar_state("in the wine cellar")
ar_describe()
ar_checkpoint(26)

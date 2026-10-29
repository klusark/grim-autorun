-- Act 4 chapter 5: the big switch at the top of the tower, the final Monkey Kombat against LeChuck, the credits
ar_load(426)
ar_a4_begin("27 fight")
AR_BIG_SET = TRUE
ar_a4_start("use", tow.switch)
sleep_for(3000)
ar_log("set=" .. tostring(ar_set_name()) .. " mk=" .. tostring(mk))
ar_state("in the finale")
sleep_for(5000)
ar_state("fight?")
ar_log("mk=" .. tostring(mk) .. " level=" .. tostring(mk and mk.level))
ar_a4_kombat()
ar_state("after the kombat")
-- the epilogue on the cliff: Elaine and Guybrush talk (one last choice), then the credits
ar_say("fini", 50)
-- (no ar_dlg_done: the control never comes back, the cutscene runs on into the credits)
AR_DLG_NAME = "fini"
ar_wait_for(ar_dlg_ended, 60000, "the dialog fini to end")
ar_state("after the dialog")
ar_a4_credits(120000)
ar_state("credits")
ar_try_wait(ar_a4_credits_over, 600000)
ar_log("the credits are over: active=" .. tostring(credits_menu and credits_menu.is_active) .. " set=" .. tostring(ar_set_name()))
ar_check(glob.won_the_game or TRUE, "the game is won: the credits ran")

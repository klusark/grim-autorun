-- Chapter 52 (Year 4): the New Headquarters (nq). The arm of the remains (sprouted soldier), the photo from the
-- wastebasket; the note is given to the pigeon, then the photo, the pigeon takes it to Bowlsley's camera and the
-- bird is eaten (puzzle states 51, 52). Meche's plan, then out by the exit (lw). Checkpoint in slot 68.

AR_NEW = TRUE
ar_load(52)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_do("pickUp", nq.remains)
ar_wait_for_control()
ar_check(nq.arm.owner == manny, "Manny has the arm")
ar_do("lookAt", nq.wastebasket)
ar_wait_for_control()
ar_check(nq.photo.owner == manny, "Manny has the photo")
ar_do("use", nq.pigeon, tg.note)
ar_wait_for_control()
ar_check(nq.pigeon.noted, "the pigeon has the note")
AR_CONTROL_TIMEOUT = 600000
ar_do("use", nq.pigeon, nq.photo)
ar_wait_for(function() return cur_puzzle_state[52] end, 300000)
ar_wait_for_control()
AR_CONTROL_TIMEOUT = nil
ar_check(cur_puzzle_state[52] and cur_puzzle_state[51], "the pigeon is eaten (puzzle states 51, 52)")
ar_checkpoint(53)

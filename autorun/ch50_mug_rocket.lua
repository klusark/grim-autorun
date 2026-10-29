-- Chapter 50 (Year 4): the mug from Bruno's casket in the truck depot (td), the note from the gate keeper
-- (tg) when leaving, then the mechanics' kitchen: the mug on the rack, a rag from the drawer, dipped in the
-- oil drum of the workshop, burnt in the toaster. The fire sets the mug rack off as a rocket
-- (puzzle states 47, 48). Checkpoint in slot 66.

AR_NEW = TRUE
ar_load(50)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(bs.td_door, td)
ar_wait_for_control()
ar_do("use", td.coffin)
ar_wait_for(function() return td.mug.owner == manny end, 120000)
ar_wait_for_control()
ar_check(td.mug.owner == manny, "Manny has the mug")
-- (the first way down to the back stairs plays the hell train cutscene, which ends in the temple gate)
if not seen_hell_train then
	ar_go(td.bs_door, tg)
	ar_wait_for_control()
	ar_go(tg.bs_door, bs)
else
	ar_go(td.bs_door, bs)
end
ar_wait_for_control()
ar_go(bs.tg_door, tg)
ar_wait_for_control()
ar_go(tg.bs_door, bs)
ar_wait_for_control()
ar_check(tg.note.owner == manny, "the gate keeper gave Manny a note")
ar_go(bs.my_door, my)
ar_wait_for_control()
ar_go(my.mk_door, mk)
ar_wait_for_control()
ar_do("use", mk.mug_rack, td.mug)
ar_wait_for_control()
ar_check(mk.mug_rack.has_mug, "the mug hangs on the rack")
ar_do("use", mk.drawers)
ar_wait_for_control()
ar_do("use", mk.drawers)
ar_wait_for_control()
ar_check(mk.rag.owner == manny, "Manny has a rag")
ar_go(mk.my_door, my)
ar_wait_for_control()
ar_do("use", my.oil_drum, mk.rag)
ar_wait_for_control()
ar_check(my.oily_rag.owner == manny, "the rag is oily")
ar_go(my.mk_door, mk)
ar_wait_for_control()
AR_CONTROL_TIMEOUT = 600000
ar_do("use", mk.toaster, my.oily_rag)
ar_wait_for(function() return cur_puzzle_state[48] end, 120000)
ar_wait_for_control()
ar_check(cur_puzzle_state[47] and cur_puzzle_state[48], "the toaster fire sets the mug rack off (puzzle states 47, 48)")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 50")
ar_checkpoint(51)

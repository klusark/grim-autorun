-- Chapter 15: the letters from the cafe's drawer (taken in chapter 14) befriend the revolutionaries in the Blue
-- Casket, who give away their book; the book is for the dock workers' foreman. Checkpoint in slot 31.

ar_load(14)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- Limbo Dock to the Blue Casket (the letters were taken in the cafe office in chapter 14)
ar_go(lm.hb_door, hb)
ar_go(hb.bw_door, bw)
ar_go(bw.be_door, be)
ar_go(be.bi_door, bi)
ar_wait_for_control()
ar_state("in the Blue Casket")
-- the letters win over the revolutionaries, who then let go of their book
ar_do("use", bi.commies, cf.letters)
ar_wait_for_control()
ar_check(bi.commies.befriended, "the revolutionaries are friends")
ar_do("use", bi.book)
ar_wait_for_control()
ar_check(bi.book.owner == manny, "Manny has the book")
-- the first time in the Blue Casket the way goes on to the back, for the kiss cutscene (the camera changes on the way to the kitchen door) and the talk
-- with Olivia, which chapters 28 onward want seen
-- on the way to the kitchen door the camera changes: Nick and Lola kiss in the kitchen door, Manny
-- is there with the camera and the photographer talks (Olivia)
ar_walk_to(-0.4, -1.4, 0.15, function() return bi.seen_kiss end)
ar_wait_for(function() return bi.seen_kiss end, 60000)
ar_check(bi.seen_kiss, "Manny saw the kiss")
ar_wait_for_control()
-- (after the skipped cutscene the original leaves Manny by Olivia without the talk: a player speaks to her)
if not ar_try_wait(function() return ol1 and system.buttonHandler == ol1 end, 8000) then
	ar_do("use", bi.olivia_obj)
end
ar_wait_for(function() return ol1 and system.buttonHandler == ol1 end, 120000)
ar_pick_exit(ol1)
ar_wait_for_control()
ar_state("after the kiss")
ar_state("end of chapter 15")
ar_checkpoint(15)

-- Chapter 15: the letters from the cafe's drawer befriend the revolutionaries in the Blue
-- Casket, who give away their book; the book is for the dock workers' foreman. Checkpoint in slot 31.

ar_load(14)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- Limbo Dock to the cafe
ar_go(lm.hb_door, hb)
ar_go(hb.bw_door, bw)
ar_go(bw.ev_door, ev, -2.49, -2.35, 0.2)
ar_go(ev.ce_door, ce, -0.5, -0.85, 0.05)
ar_go(ce.cc_door, cc)
-- the ramp to the office is a strip five centimetres wide; it is entered through a gap of the same size at its east end
ar_walk_to(-0.325, 1.0, 0)
ar_walk_stick(-0.335, 1.175, 0.0)
ar_walk_stick(-0.40, 1.185, 0.0)
ar_go(cc.cf_door, cf)
ar_do("pickUp", cf.letters)
ar_check(cf.letters.owner == manny, "Manny has the letters")
ar_go(cf.cc_door, cc)
-- and left through the gap again
ar_walk_stick(-0.40, 1.185, 0.0)
ar_walk_stick(-0.335, 1.175, 0.0)
ar_walk_stick(-0.325, 1.05, 0.0)
ar_go(cc.ce_door, ce)
ar_go(ce.ev_door, ev)
ar_go(ev.be_door, bw)
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
ar_state("end of chapter 15")
ar_checkpoint(15)

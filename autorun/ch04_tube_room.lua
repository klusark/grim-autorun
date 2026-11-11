-- Chapter 4: the tube room puzzle. The punched card (chapter 1: cards from the office, the hole punch
-- in the hallway); two balloons from the balloon man at the festival (chapter 2), filled at the packing
-- room with the two chemicals and sent down the office tube to jam the tube switcher;
-- in the tube room lock the dead bolt, leave so Brennis goes, turn the wheel and send the
-- punched card down the red tube. That reaps Meche. Checkpoint in slot 13.

ar_load(3)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- (the cards were taken and a card punched in chapter 1)
ar_check(ar_has(mo.one_card), "Manny has a card")
ar_check(mo.one_card.punched, "the card is punched")
ar_state("end of chapter 4a")

ar_log("next step, now in " .. ar_set_name())
ar_wait_for_control()
-- (the two empty balloons, the dead worms, came from the clown in chapter 2)
ar_check(ar_find_owned(fe.balloons), "Manny has the empty balloons")
ar_state("end of chapter 4b")

ar_log("next step, now in " .. ar_set_name())
ar_wait_for_control()
ar_go(ha.lo_door, lo)
ar_go(lo.pk_door, pk)

ar_do("use", pk.nozzle_1, ar_find_owned(fe.balloons))
ar_check(ar_find_owned(pk.balloons), "the first balloon is filled")
ar_do("use", pk.nozzle_2, ar_find_owned(fe.balloons))
ar_state("balloons filled")

ar_go(pk.lo_door, lo)
ar_go(lo.ha_door, ha)
-- (100% modes: Domino is in his office only now, between Bruno and Meche; the trip looks around, talks to him and comes back)
ar_side_trip(ha.do_door, dom, dom.ha_door)
ar_go(ha.mo_door, mo)

ar_do("use", mo.tube, ar_find_owned(pk.balloons))
ar_do("use", mo.tube, ar_find_owned(pk.balloons))
ar_check(tu.chem_state == "both chem", "the switcher is jammed (both chemicals)")
ar_wait_for_control()
ar_state("end of chapter 4c")

ar_log("next step, now in " .. ar_set_name())
ar_wait_for_control()
ar_go(mo.ha_door, ha)
ar_go(ha.lo_door, lo)
ar_go(lo.tu_door, tu)
ar_state("in the tube room, chem=" .. tu.chem_state .. " door=" .. tu.door_state)

ar_do("use", tu.open_bolt)
ar_check(tu.open_bolt:is_locked(), "the dead bolt is locked")
ar_go(tu.lo_door, lo)
ar_log("after leaving: chem=" .. tu.chem_state .. " door=" .. tu.door_state)
ar_go(lo.tu_door, tu)
ar_log("back in: chem=" .. tu.chem_state .. " door=" .. tu.door_state)
ar_do("use", tu.door_wheel)
ar_check(tu.door_state == "open", "the switcher door is open")
ar_do("use", tu.red_tube, mo.one_card)
ar_wait_for(function() return reaped_meche end, 120000)
ar_check(reaped_meche, "Meche has been reaped")
ar_check(cur_puzzle_state[6], "puzzle state 6 set")
ar_wait_for_control()
ar_state("end of chapter 4d")
ar_checkpoint(4)

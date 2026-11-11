-- Chapter 6: the rest of Year 1. Out of the headquarters by the elevator to the alley, up the
-- rope to the ledge and in through Domino's window: punch the speed bag three times so the
-- mouthpiece falls, take it and the coral from the drawer. (The cat balloon and a piece of
-- bread came from the festival in chapter 2; once the hook is thrown the alley rope's landing is no longer
-- walkable, so everything is fetched first.) Tie the coral to the rope and throw the hook at
-- the ladder, climb to the roof, put the balloon and the bread in the dish so the pigeons
-- leave, take the eggs. Down to the shop for the bondo, fit the mouthpiece, wave the eggs at
-- the eye in the alley to go down to the headquarters, the eggs to Salvador and the mouthpiece
-- to Eva. Checkpoints in slots 15 to 18.

ar_load(5)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(hq.al_door, al)
ar_do("use", al.rope)
ar_expect_set(le, "on the ledge")
ar_do("use", le.dom_door)
ar_expect_set(dom, "in Domino's office")

ar_do("use", dom.bag)
ar_do("use", dom.bag)
ar_do("use", dom.bag)
ar_do("pickUp", dom.mouthpiece)
ar_check(ar_has(dom.mouthpiece), "Manny has the mouthpiece")
ar_do("use", dom.drawer_object)
ar_do("use", dom.drawer_object)
ar_check(ar_has(dom.coral), "Manny has the coral")

-- (a 100% run looks over the office before it leaves: the window is a use, not a door of ar_go, which sweeps by itself)
ar_sweep()
ar_do("use", dom.window)
ar_expect_set(le, "back on the ledge")
ar_state("end of chapter 5a")

ar_log("next step, now in " .. ar_set_name())
ar_wait_for_control()
-- (the cat balloon and the bread were fetched in chapter 2, on the first trip outside: Manny stays on the ledge)
ar_check(fe.balloon_cat.owner == manny, "Manny has the cat balloon")
ar_check(ar_find_owned(fe.breads), "Manny has a piece of bread")
ar_state("end of chapter 5c")

ar_log("next step, now in " .. ar_set_name())
ar_wait_for_control()
ar_do("use", le.loose_end, dom.coral)
ar_wait_for(function() return le.grappling_hook.touchable end, 30000)
ar_check(le.grappling_hook.touchable, "the coral is tied to the rope")
ar_do("use", le.grappling_hook)
ar_wait_for(function() return le.manny_holding_rope end, 30000)
ar_check(le.manny_holding_rope, "Manny holds the rope")
-- holding the rope, USE throws it
ar_press("use")
ar_wait_for(function() return le.rope_up.touchable end, 60000)
ar_check(le.rope_up.touchable, "the hook caught, the rope hangs from the ladder")
ar_check(cur_puzzle_state[8], "puzzle state 8 set")
ar_wait_for_control()
ar_state("end of chapter 5b")

-- up the hooked rope, then the ladder: walking into its foot starts the climb, and then the
-- player holds "up", which runs climb_up over and over until the top and the roof
ar_do("use", le.rope_up)
ar_wait_for_control()
AR_WALK = TRUE
manny:set_run(FALSE)
-- (the walk to the foot of the ladder is sometimes cut short, then again, as a player does)
-- (the way west to the ladder passes a gap in the ledge that is a few centimetres wide: the original's walk boxes are not the
-- ones of ScummVM there, and a walk that aims at the foot of the ladder from below runs into the edge of the gap and is turned
-- away again and again. Up the side to the height of the gap first, then through the middle of it)
AR_LADDER_TRIES = 0
while not manny.is_climbing and AR_LADDER_TRIES < 6 do
	if AR_LADDER_TRIES > 0 then
		-- (the climb starts when the foot of the ladder is stepped into: out of it and in again)
		ar_walk_to(le.ladder_to_roof.base.use_pnt_x + 0.45, le.ladder_to_roof.base.use_pnt_y, le.ladder_to_roof.base.use_pnt_z, function() return manny.is_climbing end)
	end
	ar_walk_to(le.ladder_to_roof.base.use_pnt_x, le.ladder_to_roof.base.use_pnt_y, le.ladder_to_roof.base.use_pnt_z, function() return manny.is_climbing end)
	ar_try_wait(function() return manny.is_climbing end, 10000)
	AR_LADDER_TRIES = AR_LADDER_TRIES + 1
end
ar_wait_for(function() return manny.is_climbing end, 1000)
ar_check(manny.is_climbing, "Manny is on the ladder")
-- (the forward key held, as a player climbs: the game's own climbing task runs while it is down)
local climbs = 0
ar_key_down("MOVE_FORWARD")
while system.currentSet ~= rf and climbs < 400 do
	sleep_for(100)
	climbs = climbs + 1
end
ar_key_up("MOVE_FORWARD")
ar_expect_set(rf, "on the roof")
AR_WALK = nil

ar_do("use", rf.dish, fe.balloon_cat)
ar_check(rf.dish.contains == fe.balloon_cat, "the cat balloon is in the dish")
ar_do("use", rf.dish, ar_find_owned(fe.breads))
ar_wait_for(function() return rf.pigeons_gone end, 180000)
ar_check(rf.pigeons_gone, "the pigeons are gone")
ar_check(cur_puzzle_state[9], "puzzle state 9 set")
ar_wait_for_control()

ar_do("pickUp", rf.nest)
ar_check(ar_has(rf.eggs), "Manny has the eggs")
ar_state("end of chapter 5d")

ar_wait_for_control()
ar_go(rf.ladder_object, le)
ar_state("back on the ledge")
ar_do("use", le.rope_down)
ar_expect_set(al, "in the alley")
ar_go(al.ga_door, ga)
ar_state("in the garage")
ar_go(ga.gs_door, gs)
ar_do("use", gs.bondo_machine, dom.mouthpiece)
ar_check(dom.mouthpiece.bonded, "the mouthpiece is filled with bondo")
ar_do("use", dom.mouthpiece)
ar_check(dom.mouthpiece.molded, "the mouthpiece is fitted")
ar_check(cur_puzzle_state[10], "puzzle state 10 set")

-- the shop is a cell no more: out to the garage and the big door to the alley, wave the
-- eggs at the eye
ar_go(gs.ga_door, ga)
ar_go(ga.al_door, al)
ar_do("use", al.lens)
ar_expect_set(hq, "in the headquarters")

-- the eggs go to Salvador, the fitted mouthpiece to Eva: Salvador then sends Manny off
ar_do("use", hq.salvador_obj, rf.eggs)
ar_check(salvador.got_eggs, "Salvador has the eggs")
ar_do("use", hq.eva_obj, dom.mouthpiece)
ar_check(eva.got_teeth, "Eva has the mouthpiece")
ar_wait_for(function() return cut_scene.stump_started or mo.cards.owner == IN_LIMBO end, 300000)
ar_check(mo.cards.owner == IN_LIMBO, "Year 1 is over, the stump cutscene started")
ar_wait_for_control()
ar_state("end of Year 1")
ar_checkpoint(6)

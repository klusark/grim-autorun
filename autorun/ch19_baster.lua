-- Chapter 19: the first time in the high roller lounge, Nick (the case), and Raoul (trapped in the pantry), the turkey baster from the kitchen, the cask and the
-- wine cellar, out by the forklift with the union card, then to the Blue Casket with the baster, filled with dishwater at the Blue
-- Casket's kitchen sink. On the way past the track betting hall Carla's bomb gives the skeleton key. Checkpoint 35.

ar_load(18)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- the first time in the lounge: Nick right away (Manny has seen him kiss Lola), and Raoul in the kitchen
ar_describe()
ar_do("use", hl.virago_obj)
ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
ar_check(vi1 and system.buttonHandler == vi1, "Nick talks")
-- he refuses to help (a first round of questions), then the kiss is thrown at him
ar_pick(vi1, 100)
-- (a good question: with Terry arrested the first one is on the screen and hides the others, any of them leads to the good node)
if ar_line_shown(vi1, vi1[110]) then
	ar_pick(vi1, 110)
else
	ar_pick(vi1, 150)
end
ar_pick(vi1, 170)
ar_pick(vi1, 190)
ar_pick(vi1, 200)
ar_wait_for_control()
ar_do("use", hl.virago_obj)
ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
ar_pick(vi1, 240)
ar_pick(vi1, 280)
ar_wait_for(function() return hl.nick_gone end, 300000)
ar_wait_for_control()
ar_check(hl.nick_gone, "Nick has left")
ar_describe()
ar_do("pickUp", hl.case)
ar_wait_for(function() return hl.case.owner == manny end, 120000)
ar_wait_for_control()
ar_check(hl.case.owner == manny, "Manny has the cigarette case")
ar_go(hl.hk_door, hk)
ar_wait_for_control()
-- Raoul, who keeps going into the pantry now that Glottis gambles, is trapped there with the scythe (the dig for the detector, the only use of the scythe
-- before it comes back at the end of chapter 26, is done)
ar_hold(mo.scythe)
-- wait for the moment Raoul is away, then wait by the pantry
local waited = 0
while hk.raoul_in_kitchen and waited < 120000 do
	sleep_for(50)
	waited = waited + 50
end
ar_walk_to(-0.45, -0.28, 0.01)
-- the moment he has gone into the pantry, turn to it and scythe the door
waited = 0
while not (hk.raoul_in_pantry and cutSceneLevel == 0) and waited < 300000 do
	sleep_for(50)
	waited = waited + 50
end
ar_check(hk.raoul_in_pantry, "Raoul is in the pantry")
ar_face(hk.pantry)
ar_check(ar_gaze_at(hk.pantry), "the pantry is offered")
ar_press("use")
ar_wait_for(function() return hk.raoul_trapped end, 120000)
ar_wait_for_control()
ar_check(hk.raoul_trapped, "Raoul is trapped in the pantry")
ar_check(hk.cask_empty, "the cask is empty")
ar_do("pickUp", hk.turkey_baster)
ar_check(hk.turkey_baster.owner == manny, "Manny has the turkey baster")
-- the cask, the way to the wine cellar (chapter 26 was this) and out of it by the forklift to the hidden hall and the union card (chapter 27 was this)
-- the cask: opener, then Manny climbs in
ar_do("use", hk.upper_cask, ks.opener)
ar_wait_for(function() return hk.upper_cask:is_open() end, 60000)
ar_wait_for_control()
ar_do("use", hk.upper_cask)
ar_wait_for(function() return hk.raoul_quit end, 600000)
ar_wait_for_control()
ar_state("in the wine cellar")
ar_describe()
-- round the north side of the forklift: the walk sectors run straight through it
ar_walk_to(0.8, -1.2, 0)
ar_walk_to(1.7, -1.9, 0)
ar_walk_to(1.42, -2.3, 0)
ar_do("use", wc.forklift)
ar_check(manny.is_driving, "Manny drives the forklift")
ar_drive_to(1.4, -0.3, 0, 0.3, 40000, function() return system.currentSet == de end, de.forklift_actor)
ar_drive_to(1.45, 0.95, 0, 0.3, 40000, function() return system.currentSet == de end, de.forklift_actor)
ar_wait_for_control()
ar_check(system.currentSet == de, "the forklift is in the elevator")
-- parked by the north wall, facing the heading the jam needs, close enough to get out
ar_drive_to(-0.5, -0.05, 0, 0.1, 30000, nil, de.forklift_actor)
ar_turn_vehicle(de.forklift_actor, 90, 2, 20000)
ar_press("use")
ar_wait_for(function() return not manny.is_driving end, 30000)
ar_wait_for_control()
ar_check(not manny.is_driving, "Manny got off the forklift")
-- the car goes up, Manny jumps on and drives into the trigger
ar_do("use", de.button)
-- (the car is on its way up: no time for the walk and the waits of ar_do, the forklift is a step away from the button)
ar_face(de.forklift)
ar_press("use")
ar_wait_for(function() return manny.is_driving end, 20000)
ar_check(manny.is_driving, "Manny is on the forklift again")
AR_TV = ar_turn_vehicle(de.forklift_actor, 90, 2, 10000)
AR_FP = de.forklift_actor:getpos()
ar_log("FORK turned " .. tostring(AR_TV) .. ": " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " shaft z " .. de.shaft:getpos().z .. " floor " .. tostring(de.shaft.floor))
ar_key_down("MOVE_FORWARD")
sleep_for(3000)
AR_FP = de.forklift_actor:getpos()
ar_log("FORK after 3 s: " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " shaft z " .. de.shaft:getpos().z .. " floor " .. tostring(de.shaft.floor))
AR_N = 0
while AR_N < 15 and not de.shaft.stuck do
	ar_try_wait(function() return de.shaft.stuck end, 4000)
	AR_FP = de.forklift_actor:getpos()
	ar_log("FORK at " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " shaft z " .. de.shaft:getpos().z .. " floor " .. tostring(de.shaft.floor) .. " fb4 " .. tostring(ar_sector_on("fork_box4")) .. " st " .. tostring(ar_sector_on("fork_stuck_trig")) .. " in " .. tostring(de.forklift_actor:find_sector_name("fork_stuck_trig")))
	AR_N = AR_N + 1
end
ar_keys_up()
ar_check(de.shaft.stuck, "the elevator is jammed")
ar_press("use")
ar_wait_for(function() return not manny.is_driving end, 30000)
ar_wait_for_control()
-- the forklift stands between Manny and the lever: go round its tail
ar_walk_to(0.7, 0.2, 0)
ar_walk_to(0.7, -0.9, 0)
ar_walk_to(-0.5, -0.9, 0)
AR_FP = de.forklift_actor:getpos()
ar_log("PRE forklift " .. AR_FP.x .. " " .. AR_FP.y .. " rot " .. de.forklift_actor:getrot().y .. " lever " .. de.lever.obj_x .. " " .. de.lever.obj_y .. " use " .. de.lever.use_pnt_x .. " " .. de.lever.use_pnt_y)
ar_do("use", de.lever)
ar_wait_for(function() return de.shaft.floor == "secret_hallway" end, 60000)
ar_wait_for_control()
ar_check(de.shaft.floor == "secret_hallway", "the grating is open on the hidden hall")
-- the forklift slides back off the blades by itself (a cutscene) and shoves what is in its way: a player waits for it
sleep_for(1500)
ar_wait_for(function() return not find_script(de.forklift_actor.slide_out) end, 30000)
ar_wait_for_control()
-- Manny stands at the lever inside the forklift's collision box: his first step throws him along its side to the far end,
-- by the open grating. From there it is south and then east, into the grating
AR_N = 0
while AR_N < 120 and system.currentSet == de do
	if not ar_steer(-0.95, -0.9, 0, 4) then
		manny:walk_forward()
	end
	break_here()
	AR_N = AR_N + 1
end
if system.currentSet == de then
	-- (the forklift boxes Manny in at the corner: he tries the eight ways in turn, east first, until one takes him into the grating)
	AR_H = 90
	while AR_H < 90 + 720 and system.currentSet == de do
		AR_P1 = manny:getpos()
		AR_N = 0
		while system.currentSet == de and ar_steer(AR_P1.x + 0.5 * cos(AR_H + 90), AR_P1.y + 0.5 * cos(AR_H), 0, 3) and AR_N < 200 do
			break_here()
			AR_N = AR_N + 1
		end
		AR_N = 0
		while AR_N < 6 and system.currentSet == de do
			manny:walk_forward()
			break_here()
			AR_N = AR_N + 1
		end
		AR_P2 = manny:getpos()
		AR_H = AR_H + 45
	end
end
ar_expect_set(dh, "Manny walks out through the grating")
ar_wait_for_control()
ar_do("use", dh.suitcase)
ar_wait_for(function() return hh.union_card.owner == manny end, 600000)
ar_wait_for_control()
ar_check(hh.union_card.owner == manny, "Manny has the union card")
-- (out of the hidden hall into the hall of the lounge, in front of the elevator)
ar_wait_for_control()
ar_go(hh.tb_door, tb)
ar_wait_for_control()
ar_tw_exit()
-- Carla in the security hall, a step from here (chapter 29 was this): the cigarette case is a bomb for her safe, and the skeleton key is in it. The lighthouse, the coat
-- check and the ship follow from the Blue Casket in one trip, so the key is wanted before it
ar_go(tb.gt_door, gt)
ar_wait_for_control()
ar_go(gt.sl_door, sl)
ar_wait_for_control()
ar_do("use", sl.carla_obj, hl.case)
ar_wait_for(function() return bo1 and system.buttonHandler == bo1 end, 120000)
ar_check(bo1 and system.buttonHandler == bo1, "Manny talks to Carla about the case")
ar_pick(bo1, 300)
ar_pick(bo1, 400)
ar_wait_for(function() return sl.bomb_detonated end, 300000)
ar_wait_for(function() return sl.key.owner == manny end, 300000)
ar_wait_for_control()
ar_check(sl.key.owner == manny, "Manny has the skeleton key")
-- (the game puts Manny out into the lol gate hall after the key)
ar_go(gt.tb_door, tb)
ar_wait_for_control()
ar_go(tb.ts_door, ts)
ar_go(ts.tx_door, tx)
ar_go(tx.xb_door, xb)
ar_go(xb.hb_door, hb)
ar_go(hb.bw_door, bw)
ar_go(bw.be_door, be)
ar_go(be.bi_door, bi)
ar_wait_for_control()
ar_state("in the Blue Casket")
-- (the kiss and the talk with Olivia were in chapter 15, on the first visit to the Blue Casket)
ar_go(bi.bk_door, bk)
ar_wait_for_control()
ar_wait_for(function() return bk.seen_water end, 60000)
ar_wait_for_control()
ar_do("use", bk.sink, hk.turkey_baster)
ar_wait_for(function() return hk.turkey_baster.full end, 60000)
ar_wait_for_control()
ar_check(hk.turkey_baster.full, "the baster is full of dishwater")
ar_state("end of chapter 19")
ar_checkpoint(19)

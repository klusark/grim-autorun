-- Chapter 19: the first time in the high roller lounge, Nick (the case), and Raoul (trapped in the pantry), the turkey baster from the kitchen, the cask and the
-- wine cellar, out by the forklift with the union card, then to the Blue Casket with the baster, filled with dishwater at the Blue
-- Casket's kitchen sink. On the way past the track betting hall Carla's bomb gives the skeleton key. Checkpoint 35.

ar_load(18)
-- (100% modes) the talk with Nick in the trouble node ended there, then Nick talked to again while he has lines left
ar_nick_threats = function()
	if ar_dialog_ready(vi1, 20000) then
		ar_talk_before(vi1, nil, TRUE)
	end
end
ar_nick_rounds = function()
	if ar_dialog_ready(vi1, 20000) then
		ar_talk_before(vi1, nil, TRUE)
	end
	ar_wait_for_control()
	AR_TALK_OBJ = hl.virago_obj
	ar_talk_one()
end
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- (100% modes: Maximino in his office, mx1, through the door at the back of the lounge, which lets Manny in until Nick has gone)
ar_side_trip(hl.mx_door, mx, mx.hl_door)
-- the first time in the lounge: Nick right away (Manny has seen him kiss Lola), and Raoul in the kitchen
ar_describe()
ar_do("use", hl.virago_obj)
ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
ar_check(vi1 and system.buttonHandler == vi1, "Nick talks")
-- he refuses to help (a first round of questions), then the kiss is thrown at him
ar_pick(vi1, 100)
-- (100% modes: Nick is talked through first. His trouble, good, excellent, best and threats nodes have no way back, so each talk ends in one of
-- them, by a line that ends it, and he is talked to again while there are lines left; 240 takes the talk back into trouble_node until he has
-- refused (200). The lines this chapter picks are kept for it (ar_picked_later): 110 or 150 into good_node, 170, 190 and 200)
if AR_FULL then
	ar_extra_run("talk Nick through", ar_nick_rounds)
	ar_wait_for_control()
	ar_do("use", hl.virago_obj)
	ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
	ar_pick(vi1, 240)
end
-- (a good question: with Terry arrested the first one is on the screen and hides the others, any of them leads to the good node)
-- (100% modes: with one line left in trouble_node, the game says it by itself when the talk comes back by 240, the node's abort, and the talk is
-- in good_node already)
ar_dialog_ready(vi1, 20000)
if vi1.node ~= "trouble_node" then
	ar_log("the game said the line into good_node itself")
elseif ar_line_shown(vi1, vi1[110]) then
	ar_pick(vi1, 110)
else
	ar_pick(vi1, 150)
end
ar_pick(vi1, 170)
ar_pick(vi1, 190)
ar_pick(vi1, 200)
ar_wait_for_control()
-- (100% modes: his threats node once more before the kiss is thrown at him, for the lines there and the one that ends the talk, 290)
-- (240 goes to threats_node now that he has refused; the talk takes it only where every node it may go to can be ended, and trouble_node is empty)
if AR_FULL then
	ar_do("use", hl.virago_obj)
	ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
	ar_pick(vi1, 240)
	ar_extra_run("talk to Nick before the kiss", ar_nick_threats)
	ar_wait_for_control()
end
ar_do("use", hl.virago_obj)
ar_wait_for(function() return vi1 and system.buttonHandler == vi1 end, 120000)
ar_pick(vi1, 240)
-- (100% modes: with 280 the only line left in threats_node the game says it by itself, the node's abort)
ar_wait_for(function() return system.buttonHandler == vi1 or vi1[280].said end, 60000)
if not vi1[280].said then
	ar_pick(vi1, 280)
end
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
-- (100% modes: Aitor asleep in the high roller elevator, ai1, through the kitchen's elevator door. The first time in the kitchen he brings up the new cask
-- and is downstairs after it (hk.put_up_new_cask); he is back in the elevator when Manny comes into the kitchen again from the lounge, until Raoul quits)
if AR_FULL then
	ar_go(hk.hl_door, hl)
	ar_go(hl.hk_door, hk)
	ar_wait_for_control()
	ar_side_trip(hk.he_door, he, he.hk_door)
end
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
-- (the first 3 s of the drive, or until the elevator jams)
ar_try_wait(function() return de.shaft.stuck end, 3000)
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
-- (its script starts a moment after the grating opens: until it has begun, at most the 1.5 s that were waited)
ar_try_wait(function() return find_script(de.forklift_actor.slide_out) end, 1500)
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

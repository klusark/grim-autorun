-- Chapter 19: the first time in the high roller lounge, Nick (the case), and Raoul (trapped in the pantry), then the turkey baster from the kitchen, filled with dishwater at the Blue
-- Casket's kitchen sink. Checkpoint 35.

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
ar_go(hk.hl_door, hl)
ar_hl_elevator()
ar_go(hl.hh_door, hh)
ar_go(hh.tb_door, tb)
ar_wait_for_control()
ar_tw_exit()
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

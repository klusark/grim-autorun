-- Chapter 26: Raoul keeps going into the pantry. With Glottis gambling, Manny waits by the pantry
-- with the scythe in hand; the moment Raoul is inside, the scythe goes into the door handles. Raoul
-- trapped, the cask is empty: the can opener opens its lid and Manny climbs in. Checkpoint 42.

ar_load(25)
AR_NEW = TRUE
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
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
-- the cask: opener, then Manny climbs in
ar_do("use", hk.upper_cask, ks.opener)
ar_wait_for(function() return hk.upper_cask:is_open() end, 60000)
ar_wait_for_control()
ar_do("use", hk.upper_cask)
ar_wait_for(function() return hk.raoul_quit end, 600000)
ar_wait_for_control()
ar_state("in the wine cellar")
ar_describe()
ar_checkpoint(26)

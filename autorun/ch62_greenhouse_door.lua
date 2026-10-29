-- Chapter 62 (Year 4): the meadow (me). Olivia keeps Manny away from Salvador, so he walks up the hill to the greenhouse
-- door; Hector shoots him (Meadow Flowers, mf) and the liquid nitrogen freezes the wound (hotkey 3 takes it
-- out, the use key uses it). Manny is back in the meadow, healed. Checkpoint in slot 78.

AR_NEW = TRUE
AR_CONTROL_TIMEOUT = 600000
ar_load(62)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
-- a long walk, in one go to the foot of the greenhouse, then the door
ar_walk_to(me.door.use_pnt_x, me.door.use_pnt_y + 0.5, me.door.use_pnt_z)
ar_do("use", me.door)
ar_wait_for(function() return system.currentSet == mf end, 300000)
ar_wait_for_control()
ar_expect_set(mf, "shot in the flower meadow")
-- the inventory of a dying Manny: hotkey 3 is the nitrogen (scythe, grinder, nitrogen), the use key leaves the
-- inventory with it in hand, the next use key uses it
local pressed = 0
while manny.is_holding ~= si.nitrogen and pressed < 5 do
	ar_press_key(KEY3)
	sleep_for(4000)
	ar_wait_for_control()
	ar_press("use")
	sleep_for(3000)
	ar_wait_for_control()
	pressed = pressed + 1
end
ar_check(manny.is_holding == si.nitrogen, "Manny holds the liquid nitrogen")
local tries = 0
while not manny.healed and tries < 4 do
	ar_press("use")
	sleep_for(6000)
	ar_wait_for_control()
	tries = tries + 1
end
ar_wait_for(function() return system.currentSet == me end, 120000)
ar_wait_for_control()
ar_check(manny.healed, "the nitrogen froze the wound, Manny is healed")
ar_expect_set(me, "back in the meadow")
AR_CONTROL_TIMEOUT = nil
ar_state("end of chapter 62")
ar_checkpoint(63)

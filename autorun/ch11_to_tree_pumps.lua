-- Chapter 11 (Year 2): with the beavers gone the key opens the padlock in the beaver room. Back
-- on foot to the Bone Wagon (lobby, navigation room, forest), Manny gets in and drives to the
-- trail of the tree pump room. Checkpoint in slot 26.

ar_load(10)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
ar_go(bd.bv_door, bv)
ar_wait_for_control()
ar_do("use", bv.padlock)
ar_wait_for(function() return bv.padlock.unlocked end, 120000)
ar_check(bv.padlock.unlocked, "the padlock is open")
ar_wait_for_control()
ar_go(bv.sg_door, lb)
-- the way on from the spot in front of the door leads through the door's own trigger box, which
-- sends Manny back into the beaver room; walked with the doorman off (cameraman_disabled)
cameraman_disabled = TRUE
ar_walk_to(0.45, -2.6, -0.1)
cameraman_disabled = FALSE
-- the way past the rocks in the lobby (collision spheres): along the west side, then between the last two
ar_walk_route({
	{ -0.08, -1.48, -0.07 },
	{ -0.48, -1.05, -0.05 },
	{ -0.53, 1.70, -0.44 },
	{ -0.48, 1.95, -0.46 },
	{ 0.85, 3.30, -0.19 },
	{ 2.88, 3.38, 0.03 },
	{ 5.55, 0.73, -0.24 },
	{ 6.60, -1.15, -0.33 },
	{ 8.60, -6.62, -0.82 },
	{ 10.30, -8.33, -0.83 },
})
ar_go(lb.na_door, na)
ar_go(na.sg_door, sg)
ar_do("use", sg.bone_wagon)
ar_wait_for(function() return manny.is_driving end, 120000)
ar_wait_for_control()
ar_check(manny.is_driving, "Manny drives the Bone Wagon")
ar_state("driving")
-- The wagon stops dead at the edge of the road and the straight line to the door leads it into a dead end by the signpost:
-- drive along the road (plan_drive.py).
AR_DRIVE_ROUTE = {
	{ -3.30, -1.80 },
	{ -1.60, -0.20 },
	{ 0.40, -0.20 },
	{ 2.10, -1.00 },
	{ 3.60, -2.50 },
	{ 5.00, -4.00 },
	{ 6.50, -5.50 },
	{ 7.00, -6.30 },
}
-- the cutscene before leaves the wagon beside the road, in front of the edge of the floor it can drive on: back out first
ar_key_down("MOVE_BACKWARD")
AR_BACKED = 0
while AR_BACKED < 1500 do
	break_here()
	AR_BACKED = AR_BACKED + system.frameTime
end
ar_keys_up()
AR_DRIVE_I = 1
while AR_DRIVE_ROUTE[AR_DRIVE_I] and system.currentSet ~= tr do
	ar_drive_to(AR_DRIVE_ROUTE[AR_DRIVE_I][1], AR_DRIVE_ROUTE[AR_DRIVE_I][2], 0, 1.2, 30000, function() return system.currentSet == tr end)
	AR_DRIVE_I = AR_DRIVE_I + 1
end
ar_expect_set(tr, "in the tree pump room")
ar_state("end of chapter 11")
ar_checkpoint(11)

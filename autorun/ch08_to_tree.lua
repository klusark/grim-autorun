-- Chapter 8 (Year 2): Glottis has his heart and backs the Bone Wagon into the signpost; Manny is still at the wheel and drives on to the trail of the
-- tree pump room. (As the speed run guides go: the tree pumps come first, then the signpost, the navigation room and the key, and from the lobby of the
-- beaver room a door leads into the beaver room on foot. The old order walked back from the lobby to the wagon and drove the bumpy road.) Checkpoint in slot 23.

ar_load(7)
ar_log("start in " .. ar_set_name())
ar_wait_for_control()
if not manny.is_driving then
	ar_do("use", sg.bone_wagon)
	ar_wait_for(function() return manny.is_driving end, 120000)
	ar_wait_for_control()
end
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
-- the wagon stands beside the road, in front of the edge of the floor it can drive on: back out first
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
ar_state("end of chapter 8")
ar_checkpoint(8)

-- EMI's walking (Actor::walkForward's EMI branches, walkTo without a path, IsActorTurning after TurnActorTo): actors
-- without a costume in Grim's sets turned over (a Grim point (x, y, z) is the EMI point (x, z, y)); the floor is x-z

awk_e_actor = function(set, x, z, yaw, nofollow)
	MakeCurrentSet(set)
	local a = LoadActor("awk_eprobe")
	PutActorInSet(a, set)
	PutActorAt(a, x, 0, z)
	SetActorRot(a, 0, yaw, 0)
	if not nofollow then
		SetActorFollowBoxes(a, TRUE)
	end
	return a
end

awk_e_pos = function(key, a)
	local x, y, z = GetActorPos(a)
	cr_log(key, x, y, z)
end

-- WalkActorForward for n frames, the position every 10 frames and at the end, the yaw at the end
awk_e_forward = function(key, a, n)
	local i = 0
	while i < n do
		WalkActorForward(a)
		if mod(i, 10) == 0 then
			awk_e_pos(key .. i, a)
		end
		break_here()
		i = i + 1
	end
	awk_e_pos(key .. "end", a)
	local p, y, r = GetActorRot(a)
	cr_log(key .. "yaw", y)
end

-- (not following the boxes: straight on and past the edge of the floor)
cr_t_awk_e_fwd_nofollow = function()
	local a = awk_e_actor("cr_flat.set", 1, 0, 90, TRUE)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	awk_e_forward("f", a, 40)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_e_fwd_nofollow", "WalkActorForward moves in its own frame on ScummVM, a frame later on the original") cr_test("awk_e_fwd_nofollow", cr_t_awk_e_fwd_nofollow)

-- (following the boxes, with the floor of cr_flat switched off: no sector)
cr_t_awk_e_fwd_nosector = function()
	local a = awk_e_actor("cr_flat.set", 0, 0, 45)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	MakeSectorActive("floor", FALSE)
	awk_e_forward("f", a, 20)
	MakeSectorActive("floor", TRUE)
	cr_frames(1)
	awk_e_pos("floor_on", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_e_fwd_nosector", "without an active sector the original does not move the actor that follows the boxes; ScummVM walks on (actor.cpp:849-866)") cr_test("awk_e_fwd_nosector", cr_t_awk_e_fwd_nosector)

-- (from one arm of the L into the next floor (ell_a to ell_b), and into the edge of cr_flat at 30 degrees from its normal)
cr_t_awk_e_fwd_cross = function()
	local a = awk_e_actor("cr_ell.set", -1, -1, 90)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	awk_e_forward("cross", a, 40)
	cr_log("cross_sector", GetActorSector(a, 4096))
	PutActorInSet(a, nil)
	a = awk_e_actor("cr_flat.set", 1.5, 0, 60)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	awk_e_forward("edge", a, 40)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_e_fwd_cross", "WalkActorForward a frame early; at the edge the original slides along it (yaw -90), ScummVM stops in the corner") cr_test("awk_e_fwd_cross", cr_t_awk_e_fwd_cross)

-- (to the floor e_gap of cr_edge, 2e-5 m from the others: no path)
cr_t_awk_e_no_path = function()
	local a = awk_e_actor("cr_edge.set", -1, 0, 0)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	WalkActorTo(a, -1, 0, 3)
	cr_log("moving", IsActorMoving(a))
	break_here()
	cr_log("moving_next", IsActorMoving(a))
	cr_frames(20)
	awk_e_pos("after_20", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_e_no_path", "the original walks towards a point it has no path to; ScummVM does not walk (actor.cpp:746-749)") cr_test("awk_e_no_path", cr_t_awk_e_no_path)

-- (IsActorTurning in the frame of a TurnActorTo that has not reached its yaw)
cr_t_awk_e_turning = function()
	local a = awk_e_actor("cr_flat.set", 0, 0, 0)
	SetActorTurnRate(a, 30)
	cr_frames(1)
	cr_log("turn_to", TurnActorTo(a, 1, 0, 0))
	cr_log("turning", IsActorTurning(a))
	local p, y, r = GetActorRot(a)
	cr_log("yaw", y)
	break_here()
	cr_log("turning_next", IsActorTurning(a))
	ActorStopMoving(a)
	cr_log("turning_stopped", IsActorTurning(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_e_turning", "TurnActorTo does not turn on the original and IsActorTurning is nil") cr_test("awk_e_turning", cr_t_awk_e_turning)

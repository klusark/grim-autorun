-- EMI's actors without a costume: placing, turning, walking, sectors, the overworld (y up, the floor is x-z)  -- games: emi

cr_ea_actor = function(set, nofollow)
	MakeCurrentSet(set)
	local a = LoadActor("cr_probe")
	PutActorInSet(a, set)
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	if not nofollow then
		SetActorFollowBoxes(a, TRUE)
	end
	return a
end

cr_ea_pos = function(key, a)
	local x, y, z = GetActorPos(a)
	cr_log(key, x, y, z)
end

cr_ea_rot = function(key, a)
	local p, y, r = GetActorRot(a)
	cr_log(key, p, y, r)
end

-- follows a walk, the position every 10 frames, until it stops or 300 frames
cr_ea_follow = function(a, key)
	local f = 0
	while IsActorMoving(a) and f < 300 do
		if mod(f, 10) == 0 then
			cr_ea_pos(key .. f, a)
		end
		break_here()
		f = f + 1
	end
	cr_log(key .. "frames", f)
	cr_ea_pos(key .. "end", a)
end

cr_t_ea_place = function()
	local a = cr_ea_actor("cr_flat.set")
	cr_log("type", type(a))
	cr_frames(1)
	cr_ea_pos("start", a)
	PutActorAt(a, 1.25, 0, -0.5)
	cr_ea_pos("put", a)
	PutActorAt(a, 1, 0.5, 1)
	cr_ea_pos("put_above", a)
	PutActorAt(a, 3, 0, 3)
	cr_ea_pos("put_outside", a)
	cr_log("world_pos", GetActorWorldPos(a))
	SetActorRot(a, 0, 45, 0)
	cr_ea_rot("rot", a)
	SetActorRot(a, 0, 400, 0)
	cr_ea_rot("rot_wrap", a)
	SetActorRot(a, 0, -30, 0)
	cr_ea_rot("rot_neg", a)
	SetActorRot(a, 10, 20, 30)
	cr_ea_rot("rot_all", a)
	cr_log("walk_rate", GetActorWalkRate(a))
	cr_log("turn_rate", GetActorTurnRate(a))
	cr_log("moving", IsActorMoving(a))
	cr_log("turning", IsActorTurning(a))
end
cr_test("ea_place", cr_t_ea_place)

cr_t_ea_sector = function()
	local a = cr_ea_actor("cr_edge.set")
	PutActorAt(a, -1, 0, 0)
	cr_log("left", GetActorSector(a, 4096))
	cr_log("in_left", IsActorInSector(a, "e_left"))
	cr_log("in_right", IsActorInSector(a, "e_right"))
	PutActorAt(a, 1, 0, 0)
	cr_log("right", GetActorSector(a, 4096))
	PutActorAt(a, 3, 0, -1)
	cr_log("wedge", GetActorSector(a, 4096))
	PutActorAt(a, 9, 0, 9)
	cr_log("outside", GetActorSector(a, 4096))
end
cr_test("ea_sector", cr_t_ea_sector)

cr_t_ea_yaw_to = function()
	local a = cr_ea_actor("cr_flat.set")
	PutActorAt(a, 0, 0, 0)
	cr_log("plus_x", GetActorYawToPoint(a, { x = 1, y = 0, z = 0 }))
	cr_log("plus_z", GetActorYawToPoint(a, { x = 0, y = 0, z = 1 }))
	cr_log("minus_x", GetActorYawToPoint(a, { x = -1, y = 0, z = 0 }))
	cr_log("diagonal", GetActorYawToPoint(a, { x = 1, y = 0, z = 1 }))
	cr_log("up", GetActorYawToPoint(a, { x = 0, y = 1, z = 0 }))
	SetActorRot(a, 0, 90, 0)
	cr_log("turned_plus_x", GetActorYawToPoint(a, { x = 1, y = 0, z = 0 }))
end
cr_test("ea_yaw_to", cr_t_ea_yaw_to)

cr_t_ea_walk = function()
	local a = cr_ea_actor("cr_flat.set")
	SetActorWalkRate(a, 1)
	cr_frames(1)
	WalkActorTo(a, 1.5, 0, 1)
	cr_log("moving_at_once", IsActorMoving(a))
	break_here()
	cr_log("moving_next_frame", IsActorMoving(a))
	cr_ea_follow(a, "w")
	cr_ea_rot("rot_end", a)
end
cr_test("ea_walk", cr_t_ea_walk)

cr_t_ea_walk_outside = function()
	local a = cr_ea_actor("cr_flat.set")
	SetActorWalkRate(a, 2)
	cr_frames(1)
	WalkActorTo(a, 5, 0, 0)
	cr_log("moving", IsActorMoving(a))
	cr_ea_follow(a, "w")
end
cr_test("ea_walk_outside", cr_t_ea_walk_outside)

cr_t_ea_walk_nofollow = function()
	local a = cr_ea_actor("cr_flat.set", TRUE)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	WalkActorTo(a, 3, 0, 0)
	cr_log("moving", IsActorMoving(a))
	cr_ea_follow(a, "w")
end
cr_test("ea_walk_nofollow", cr_t_ea_walk_nofollow)

-- around the corner of the L: the straight line leaves the floor
cr_t_ea_walk_ell = function()
	local a = cr_ea_actor("cr_ell.set")
	PutActorAt(a, -1, 0, -1)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	WalkActorTo(a, 1, 0, 1)
	cr_ea_follow(a, "w")
	cr_log("sector", GetActorSector(a, 4096))
end
cr_test("ea_walk_ell", cr_t_ea_walk_ell)

cr_t_ea_walk_stop = function()
	local a = cr_ea_actor("cr_flat.set")
	SetActorWalkRate(a, 1)
	cr_frames(1)
	WalkActorTo(a, 1.8, 0, 0)
	cr_frames(20)
	cr_ea_pos("before_stop", a)
	ActorStopMoving(a)
	cr_log("moving_after_stop", IsActorMoving(a))
	cr_frames(5)
	cr_ea_pos("after_stop", a)
end
cr_test("ea_walk_stop", cr_t_ea_walk_stop)

cr_t_ea_walk_forward = function()
	local a = cr_ea_actor("cr_flat.set")
	SetActorWalkRate(a, 1)
	SetActorRot(a, 0, 90, 0)
	cr_frames(1)
	local i = 0
	while i < 30 do
		WalkActorForward(a)
		if mod(i, 10) == 0 then
			cr_ea_pos("f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_ea_pos("end", a)
end
cr_test("ea_walk_forward", cr_t_ea_walk_forward)

cr_t_ea_turn = function()
	local a = cr_ea_actor("cr_flat.set")
	SetActorTurnRate(a, 90)
	cr_log("turn_rate", GetActorTurnRate(a))
	cr_frames(1)
	TurnActorTo(a, 1, 0, 0)
	cr_log("turning_at_once", IsActorTurning(a))
	local f = 0
	while IsActorTurning(a) and f < 300 do
		if mod(f, 10) == 0 then
			cr_ea_rot("f" .. f, a)
		end
		break_here()
		f = f + 1
	end
	cr_log("frames", f)
	cr_ea_rot("end", a)
	PointActorAt(a, 0, 0, -1)
	cr_ea_rot("point_at", a)
end
cr_test("ea_turn", cr_t_ea_turn)

cr_t_ea_overworld = function()
	local a = cr_ea_actor("cr_flat.set")
	PutActorAt(a, 1, 0, 1)
	PutActorInOverworld(a)
	cr_ea_pos("in_overworld", a)
	cr_log("sector", GetActorSector(a, 4096))
	cr_frames(1)
	RemoveActorFromOverworld(a)
	cr_ea_pos("removed", a)
	cr_log("sector_removed", GetActorSector(a, 4096))
end
cr_test("ea_overworld", cr_t_ea_overworld)

-- an actor's handle after UnloadActor: the original takes it out of a set or puts it in one without trouble
cr_t_ea_unloaded_out = function()
	local a = cr_ea_actor("cr_flat.set")
	UnloadActor(a)
	cr_log("r", PutActorInSet(a, nil))
end
cr_test("ea_unloaded_out", cr_t_ea_unloaded_out)

cr_t_ea_unloaded_in = function()
	local a = cr_ea_actor("cr_flat.set")
	UnloadActor(a)
	cr_log("r", PutActorInSet(a, "cr_flat.set"))
end
cr_test("ea_unloaded_in", cr_t_ea_unloaded_in)

-- Actors without a costume: placing, turning, walking, sectors
-- (the original walks an actor with WalkActorTo only when it follows the boxes, which the game's scripts always switch on;
-- SetSelectedActor on an actor without a costume crashes the original)

cr_actor = function(set, nofollow)
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

cr_pos = function(key, a)
	local x, y, z = GetActorPos(a)
	cr_log(key, x, y, z)
end

cr_t_actor_place = function()
	local a = cr_actor("cr_flat.set")
	cr_frames(1)
	cr_pos("start", a)
	PutActorAt(a, 1.25, -0.5, 0)
	cr_pos("put", a)
	SetActorRot(a, 0, 45, 0)
	local p, y, r = GetActorRot(a)
	cr_log("rot", p, y, r)
	SetActorRot(a, 0, 400, 0)
	p, y, r = GetActorRot(a)
	cr_log("rot_wrap", p, y, r)
	SetActorRot(a, 0, -30, 0)
	p, y, r = GetActorRot(a)
	cr_log("rot_neg", p, y, r)
	cr_log("yaw_to", GetActorYawToPoint(a, { x = 2, y = 1, z = 0 }))
	cr_log("sector", GetActorSector(a, 4096))
	cr_log("walk_rate", GetActorWalkRate(a))
end
cr_scummvm_differs("actor_place") cr_test("actor_place", cr_t_actor_place)

cr_t_actor_walk = function()
	local a = cr_actor("cr_flat.set")
	SetActorWalkRate(a, 1)
	cr_frames(1)
	WalkActorTo(a, 1.5, 1, 0)
	cr_log("moving_at_once", IsActorMoving(a))
	break_here()
	cr_log("moving_next_frame", IsActorMoving(a))
	local f = 1
	while IsActorMoving(a) and f < 300 do
		if mod(f, 10) == 0 then
			cr_pos("f" .. f, a)
		end
		break_here()
		f = f + 1
	end
	cr_log("frames", f)
	cr_pos("end", a)
	local p, y, r = GetActorRot(a)
	cr_log("end_rot", p, y, r)
end
cr_scummvm_differs("actor_walk") cr_test("actor_walk", cr_t_actor_walk)

cr_t_actor_walk_nofollow = function()
	local a = cr_actor("cr_flat.set", TRUE)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	WalkActorTo(a, 1.5, 1, 0)
	cr_frames(10)
	cr_pos("after_10", a)
	cr_log("moving", IsActorMoving(a))
end
cr_scummvm_differs("actor_walk_nofollow") cr_test("actor_walk_nofollow", cr_t_actor_walk_nofollow)

cr_t_actor_turn = function()
	local a = cr_actor("cr_flat.set")
	SetActorTurnRate(a, 90)
	cr_frames(1)
	local f = 0
	local p, y, r
	while TurnActorTo(a, 1, 0, 0) and f < 300 do
		p, y, r = GetActorRot(a)
		if f < 12 then
			cr_log("f" .. f, y)
		end
		break_here()
		f = f + 1
	end
	cr_log("frames", f)
	p, y, r = GetActorRot(a)
	cr_log("end", y)
end
cr_scummvm_differs("actor_turn") cr_test("actor_turn", cr_t_actor_turn)

cr_t_actor_forward_wall = function()
	local a = cr_actor("cr_flat.set")
	SetActorWalkRate(a, 2)
	PutActorAt(a, 1, 0, 0)
	SetActorRot(a, 0, 300, 0)
	cr_frames(1)
	local f = 0
	while f < 90 do
		WalkActorForward(a)
		if mod(f, 15) == 0 then
			cr_pos("f" .. f, a)
		end
		break_here()
		f = f + 1
	end
	cr_pos("end", a)
end
cr_scummvm_differs("actor_forward_wall") cr_test("actor_forward_wall", cr_t_actor_forward_wall)

cr_t_actor_stair = function()
	local a = cr_actor("cr_stair.set")
	SetActorWalkRate(a, 1)
	PutActorAt(a, 0, -1, 0)
	cr_frames(1)
	WalkActorTo(a, 0, 2, 0.5)
	break_here()
	local f = 1
	while IsActorMoving(a) and f < 300 do
		if mod(f, 15) == 0 then
			cr_pos("f" .. f, a)
		end
		break_here()
		f = f + 1
	end
	cr_log("frames", f)
	cr_pos("end", a)
	cr_log("sector", GetActorSector(a, 4096))
end
cr_scummvm_differs("actor_stair") cr_test("actor_stair", cr_t_actor_stair)

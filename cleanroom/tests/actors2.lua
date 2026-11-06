-- More actor rules: pointing, turning by key, the puck vector, the walk vector, two actors colliding

cr_t_point_and_angles = function()
	local a = cr_actor("cr_flat.set")
	local b = LoadActor("cr_other")
	PutActorInSet(b, "cr_flat.set")
	PutActorAt(b, 1, 1, 0)
	cr_frames(1)
	-- (GetAngleBetweenActors uses the walker's heading of the first actor (walker+0x1b4): with an actor that does not follow the
	-- boxes first, the original crashes)
	cr_log("between", GetAngleBetweenActors(a, b))
	PointActorAt(a, 1, 1, 0)
	local p, y, r = GetActorRot(a)
	cr_log("pointed", p, y, r)
	PointActorAt(a, -1, 0.5, 0)
	p, y, r = GetActorRot(a)
	cr_log("pointed2", p, y, r)
	cr_log("between_after", GetAngleBetweenActors(a, b))
	cr_log("yaw_to_b", GetActorYawToPoint(a, { x = 1, y = 1, z = 0 }))
	cr_log("yaw_to_self", GetActorYawToPoint(a, { x = 0, y = 0, z = 0 }))
	cr_log("yaw_to_above", GetActorYawToPoint(a, { x = 0, y = 0, z = 1 }))
	PutActorInSet(b, nil)
end
cr_scummvm_differs("point_and_angles") cr_test("point_and_angles", cr_t_point_and_angles)

-- (TurnActor: the turn keys, one call a frame)
cr_t_turn_key = function()
	local a = cr_actor("cr_flat.set")
	SetActorTurnRate(a, 85)
	cr_frames(1)
	local s = ""
	local i = 0
	local p, y, r
	while i < 20 do
		TurnActor(a, 1)
		p, y, r = GetActorRot(a)
		s = s .. format("%.4f", y) .. " "
		break_here()
		i = i + 1
	end
	cr_log("left", s)
	s = ""
	i = 0
	while i < 10 do
		TurnActor(a, -1)
		p, y, r = GetActorRot(a)
		s = s .. format("%.4f", y) .. " "
		break_here()
		i = i + 1
	end
	cr_log("right", s)
	p, y, r = GetActorRot(a)
	cr_log("end", y, IsActorTurning(a))
end
cr_scummvm_differs("turn_key") cr_test("turn_key", cr_t_turn_key)

cr_t_puck = function()
	local a = cr_actor("cr_stair.set")
	cr_frames(1)
	PutActorAt(a, 0, -1, 0)
	local x, y, z = GetActorPuckVector(a)
	cr_log("flat", x, y, z)
	PutActorAt(a, 0, 0.5, 0.25)
	SetActorRot(a, 0, 0, 0)
	x, y, z = GetActorPuckVector(a)
	cr_log("ramp_up", x, y, z)
	SetActorRot(a, 0, 90, 0)
	x, y, z = GetActorPuckVector(a)
	cr_log("ramp_side", x, y, z)
	x, y, z = GetActorPuckVector(a, TRUE)
	cr_log("ramp_side_add", x, y, z)
end
cr_scummvm_differs("puck") cr_test("puck", cr_t_puck)

-- (WalkActorVector: the stick, relative to the camera of the setup)
cr_t_walk_vector = function()
	local a = cr_actor("cr_flat.set")
	SetActorWalkRate(a, 1)
	cr_frames(1)
	local cam = GetCameraActor()
	local i = 0
	while i < 30 do
		WalkActorVector(a, cam, 1, 0, nil, nil)
		break_here()
		i = i + 1
	end
	cr_pos("right30", a)
	local p, y, r = GetActorRot(a)
	cr_log("right30_rot", y)
	i = 0
	while i < 30 do
		WalkActorVector(a, cam, 0, 1, nil, nil)
		break_here()
		i = i + 1
	end
	cr_pos("up30", a)
	p, y, r = GetActorRot(a)
	cr_log("up30_rot", y)
end
cr_scummvm_differs("walk_vector") cr_test("walk_vector", cr_t_walk_vector)

-- (an actor walks forward into another; both collide as spheres; actors without a costume have no model to size the sphere)
cr_t_collide = function()
	local a = cr_actor("cr_flat.set")
	local b = LoadActor("cr_block")
	PutActorInSet(b, "cr_flat.set")
	PutActorAt(b, 0, 1, 0)
	SetActorCollisionMode(a, 2)
	SetActorCollisionMode(b, 2)
	SetActorCollisionScale(a, 0.3)
	SetActorCollisionScale(b, 0.3)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	local i = 0
	while i < 60 do
		WalkActorForward(a)
		if mod(i, 10) == 0 then
			cr_pos("f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos("end", a)
	cr_pos("block", b)
	SetActorCollisionMode(a, 0)
	SetActorCollisionMode(b, 0)
	PutActorInSet(b, nil)
end
cr_scummvm_differs("collide") cr_test("collide", cr_t_collide)

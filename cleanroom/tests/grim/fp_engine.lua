-- The engine's own math to the last bit (cr_fp_exact of common/fp_x87.lua): vectors, angles, an actor's place and turn.
-- The original computes in floats on x87 (its precision as the game set it), ScummVM in floats and doubles on SSE; the
-- other tests log 6 decimals, which hide a difference in the last bits.

cr_fp_vec = function(key, v)
	if v == nil then
		cr_log(key, nil)
	else
		cr_log(key, cr_fp_exact(v.x), cr_fp_exact(v.y), cr_fp_exact(v.z))
	end
end

cr_t_fp_rotate_vector = function()
	cr_fp_vec("yaw30", RotateVector({ x = 1, y = 0, z = 0 }, { x = 0, y = 30, z = 0 }))
	cr_fp_vec("yaw90", RotateVector({ x = 1, y = 0, z = 0 }, { x = 0, y = 90, z = 0 }))
	cr_fp_vec("yaw180", RotateVector({ x = 1, y = 0, z = 0 }, { x = 0, y = 180, z = 0 }))
	cr_fp_vec("pitch_tenth", RotateVector({ x = 0, y = 1, z = 0 }, { x = 0.1, y = 0, z = 0 }))
	cr_fp_vec("roll_odd", RotateVector({ x = 0.3, y = 0.7, z = 1.1 }, { x = 0, y = 0, z = 33.3 }))
	cr_fp_vec("all", RotateVector({ x = 1.1, y = 2.2, z = 3.3 }, { x = 12.5, y = 77.7, z = -45.25 }))
	cr_fp_vec("big", RotateVector({ x = 1000.5, y = -250.25, z = 3 }, { x = 0, y = 359.9, z = 0 }))
	cr_fp_vec("tiny", RotateVector({ x = 0.0001, y = 0.0002, z = 0 }, { x = 0, y = 45, z = 0 }))
end
cr_scummvm_differs("fp_rotate_vector", "the original's RotateVector is less precise (cos 30 is 0.86584, 2e-4 off), ScummVM's is right to the float; and ScummVM's (float)pi leaves -2.7e-8 where the original has 0") cr_test("fp_rotate_vector", cr_t_fp_rotate_vector)

cr_t_fp_angle_between = function()
	cr_fp("right", GetAngleBetweenVectors({ x = 1, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }))
	cr_fp("thirty", GetAngleBetweenVectors({ x = 1, y = 0, z = 0 }, { x = 0.8660254, y = 0.5, z = 0 }))
	cr_fp("near_same", GetAngleBetweenVectors({ x = 1, y = 0, z = 0 }, { x = 1, y = 0.0001, z = 0 }))
	cr_fp("near_opposite", GetAngleBetweenVectors({ x = 1, y = 0, z = 0 }, { x = -1, y = 0.0001, z = 0 }))
	cr_fp("skew", GetAngleBetweenVectors({ x = 1.1, y = 2.2, z = 3.3 }, { x = -2.5, y = 0.5, z = 1.25 }))
	cr_fp("long", GetAngleBetweenVectors({ x = 1000, y = 1, z = 0 }, { x = 1, y = 1000, z = 0 }))
end
cr_scummvm_differs("fp_angle_between", "the last bits; thirty: 30.0057 on the original, 30 on ScummVM") cr_test("fp_angle_between", cr_t_fp_angle_between)

cr_t_fp_actor_place = function()
	local a = cr_actor("cr_flat.set")
	PutActorAt(a, 0.1, 0.2, 0.3)
	local x, y, z = GetActorPos(a)
	cr_log("tenths", cr_fp_exact(x), cr_fp_exact(y), cr_fp_exact(z))
	PutActorAt(a, 1 / 3, -2 / 3, 1e-7)
	x, y, z = GetActorPos(a)
	cr_log("thirds", cr_fp_exact(x), cr_fp_exact(y), cr_fp_exact(z))
	PutActorAt(a, 16777217, 1e10, -1e-40)
	x, y, z = GetActorPos(a)
	cr_log("edges", cr_fp_exact(x), cr_fp_exact(y), cr_fp_exact(z))
	PutActorAt(a, 0, 0, 0)
end
cr_scummvm_differs("fp_actor_place", "an actor put outside the set's sectors: the original and ScummVM move it to different points; ScummVM puts 1e-7 on the floor (0)") cr_test("fp_actor_place", cr_t_fp_actor_place)

cr_t_fp_actor_rot = function()
	local a = cr_actor("cr_flat.set")
	cr_frames(1)
	local yaws = { 0.1, 33.3, 359.9, 360, 400.1, 720.5, -0.1, -180, -359.9, 1e6, 123456.7 }
	local i = 1
	while yaws[i] do
		SetActorRot(a, 0, yaws[i], 0)
		cr_frames(1)
		local p, y, r = GetActorRot(a)
		cr_log("yaw" .. i, cr_fp_exact(y))
		i = i + 1
	end
	SetActorRot(a, 12.3, 45.6, 78.9)
	cr_frames(1)
	local p, y, r = GetActorRot(a)
	cr_log("all", cr_fp_exact(p), cr_fp_exact(y), cr_fp_exact(r))
	SetActorRot(a, 0, 0, 0)
end
cr_scummvm_differs("fp_actor_rot", "the original turns to a SetActorRot yaw over the frames after it (actors.lua's actor_place), ScummVM sets it at once") cr_test("fp_actor_rot", cr_t_fp_actor_rot)

cr_t_fp_yaw_to_point = function()
	local a = cr_actor("cr_flat.set")
	cr_frames(1)
	PutActorAt(a, 0.1, 0.2, 0)
	SetActorRot(a, 0, 17.5, 0)
	cr_fp("ahead", GetActorYawToPoint(a, { x = 0.1, y = 5, z = 0 }))
	cr_fp("side", GetActorYawToPoint(a, { x = 3.3, y = 0.2, z = 0 }))
	cr_fp("behind", GetActorYawToPoint(a, { x = -1.7, y = -2.9, z = 0 }))
	cr_fp("near", GetActorYawToPoint(a, { x = 0.1001, y = 0.2001, z = 0 }))
	cr_fp("far", GetActorYawToPoint(a, { x = 1000.25, y = -999.75, z = 0 }))
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
end
cr_scummvm_differs("fp_yaw_to_point", "the last bits of the angle (atan2 in floats on the original, ScummVM's in doubles)") cr_test("fp_yaw_to_point", cr_t_fp_yaw_to_point)

-- a walk: each frame's step is the walk rate times the frame's time, added to the position (an error that grows)
cr_t_fp_walk_steps = function()
	local a = cr_actor("cr_flat.set")
	SetActorWalkRate(a, 0.37)
	PutActorAt(a, 0.05, 0.05, 0)
	SetActorRot(a, 0, 30, 0)
	cr_frames(1)
	WalkActorTo(a, 1.3, 0.9, 0)
	local f = 1
	while IsActorMoving(a) and f < 300 do
		if mod(f, 5) == 0 then
			local x, y, z = GetActorPos(a)
			cr_log("f" .. f, cr_fp_exact(x), cr_fp_exact(y))
		end
		break_here()
		f = f + 1
	end
	local x, y, z = GetActorPos(a)
	cr_log("end", cr_fp_exact(x), cr_fp_exact(y), cr_fp_exact(z))
	local p, yaw, r = GetActorRot(a)
	cr_log("end_yaw", cr_fp_exact(yaw))
	cr_log("frames", f)
end
cr_scummvm_differs("fp_walk_steps", "each frame's step a few bits apart, the error growing along the walk") cr_test("fp_walk_steps", cr_t_fp_walk_steps)

-- a turn at a rate: the yaw each frame, toward a point on each side (from yaw 0, as actors.lua's actor_turn)
cr_fp_turn = function(rate, x, y)
	local a = cr_actor("cr_flat.set")
	SetActorTurnRate(a, rate)
	cr_frames(1)
	local f = 0
	while TurnActorTo(a, x, y, 0) and f < 200 do
		if f < 8 then
			local p, yaw, r = GetActorRot(a)
			cr_log("f" .. f, cr_fp_exact(yaw))
		end
		break_here()
		f = f + 1
	end
	local p, yaw, r = GetActorRot(a)
	cr_log("end", cr_fp_exact(yaw))
	cr_log("frames", f)
end

cr_scummvm_differs("fp_turn_right", "the original turns from a SetActorRot yaw, at another rate and to another end, than ScummVM") cr_test("fp_turn_right", function() cr_fp_turn(73.3, 1, 0.3) end)
cr_scummvm_differs("fp_turn_left", "the original does not turn left toward (-1, 0.3) in 200 frames; ScummVM does") cr_test("fp_turn_left", function() cr_fp_turn(73.3, -1, 0.3) end)
cr_scummvm_differs("fp_turn_back", "the original turns a few degrees, ScummVM all the way") cr_test("fp_turn_back", function() cr_fp_turn(41.7, -0.2, -1) end)

cr_t_fp_colors = function()
	local vals = { 0.4, 0.5, 0.6, 1.5, 2.5, 127.5, 128.5, 254.5, 254.9, 255.4, -0.4, -0.6 }
	local i = 1
	while vals[i] do
		local r, g, b = GetColorComponents(MakeColor(vals[i], vals[i], vals[i]))
		cr_log("v" .. i, r)
		i = i + 1
	end
end
cr_test("fp_colors", cr_t_fp_colors)

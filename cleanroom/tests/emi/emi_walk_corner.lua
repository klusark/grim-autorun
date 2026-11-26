-- EMI's walker in a sharp corner (ewc_corner.set: Melee Town's sector1, its vertex 2 at 17.8278008, 3.15728998). A cutscene
-- walk took Guybrush up the east edge into that corner; when a step started exactly on the edge that blocked it, ScummVM's
-- walker found no exit and no turn and stopped there for good. WalkActorForward for n frames (ScummVM moves in the frame of
-- the call, the original a frame later, so only the place two frames after the last call is logged), then the yaw once the
-- turn has settled (30 frames on), in 0..360 (the original gives -180..180, ScummVM 0..360).

ewc_actor = function(x, z, yaw, rate)
	MakeCurrentSet("ewc_corner.set")
	local a = LoadActor("ewc_probe")
	PutActorInSet(a, "ewc_corner.set")
	PutActorAt(a, x, 0.58, z)
	SetActorRot(a, 0, yaw, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, rate)
	return a
end

ewc_walk = function(a, n)
	cr_frames(1)
	local i = 0
	while i < n do
		WalkActorForward(a)
		break_here()
		i = i + 1
	end
	cr_frames(2)
	local x, y, z = GetActorPos(a)
	cr_log("end", x, y, z)
	cr_frames(30)
	local p, yaw, r = GetActorRot(a)
	cr_log("yaw", mod(yaw + 720, 360))
	PutActorInSet(a, nil)
end

-- the cutscene's last free step: 4 cm from the corner, heading 2.093 degrees (up the east edge), walk rate 1.5 (8.4 cm a frame)
cr_t_ewc_melee = function()
	ewc_walk(ewc_actor(17.8259068, 3.1163645, 2.093, 1.5), 30)
end
cr_scummvm_differs("ewc_melee", "master's walker stops in the corner facing 1.3 degrees; the original turns 180.2 - angle and walks back down the edge") cr_test("ewc_melee", cr_t_ewc_melee)

-- from 60 cm down the east edge, heading into it at 2.093 degrees: slides up the edge into the corner
cr_t_ewc_slide = function()
	ewc_walk(ewc_actor(17.79, 2.55, 2.093, 1.5), 40)
end
cr_scummvm_differs("ewc_slide", "master's walker stops in the corner as the original does but keeps facing up the edge (1.3 degrees); the original turns along the north edge (81.1)") cr_test("ewc_slide", cr_t_ewc_slide)

-- the same at walk rate 1 (5.6 cm a frame)
cr_t_ewc_slide_slow = function()
	ewc_walk(ewc_actor(17.79, 2.55, 2.093, 1), 60)
end
cr_scummvm_differs("ewc_slide_slow", "master's walker stops in the corner as the original does but keeps facing up the edge (1.3 degrees); the original turns along the north edge (81.1)") cr_test("ewc_slide_slow", cr_t_ewc_slide_slow)

-- put exactly on the corner vertex, heading out of the floor: up the east edge, east (across it), and north-east
cr_t_ewc_on_corner_north = function()
	ewc_walk(ewc_actor(17.8278008, 3.15728998, 2.093, 1.5), 20)
end
cr_scummvm_differs("ewc_on_corner_north", "master's walker does not move off the corner vertex; the original turns and walks back down the east edge") cr_test("ewc_on_corner_north", cr_t_ewc_on_corner_north)

cr_t_ewc_on_corner_east = function()
	ewc_walk(ewc_actor(17.8278008, 3.15728998, 90, 1.5), 20)
end
cr_test("ewc_on_corner_east", cr_t_ewc_on_corner_east)

cr_t_ewc_on_corner_ne = function()
	ewc_walk(ewc_actor(17.8278008, 3.15728998, 45, 1.5), 20)
end
cr_scummvm_differs("ewc_on_corner_ne", "master's walker does not move off the corner vertex; the original turns and walks back down the east edge") cr_test("ewc_on_corner_ne", cr_t_ewc_on_corner_ne)

-- on the corner vertex heading back into the floor (south-west): walks off the corner
cr_t_ewc_on_corner_back = function()
	ewc_walk(ewc_actor(17.8278008, 3.15728998, 200, 1.5), 20)
end
cr_scummvm_differs("ewc_on_corner_back", "master's walker turns at the west edge 0.9 degrees further and stops 8 mm away from where the original does") cr_test("ewc_on_corner_back", cr_t_ewc_on_corner_back)

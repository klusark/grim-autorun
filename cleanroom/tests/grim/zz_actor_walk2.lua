-- Walking and turning (Actor::walkForward, walkTo's path search, the turn chores, calculateOrientation, the puck vector):
-- WalkActorForward without the boxes, at a rate of 0 and backwards, without an active sector and into the edges and the
-- corner of a floor; a path whose first guess is not the shortest (awk_grid); the turn and rest chores of a turning actor
-- (awk_turn.cos); the walk chore changed during a walk; an actor that follows the slope of a ramp (ActorPuckOrient).
-- (the sets and the costume: assets_extra_awk.py)

-- an actor in a set, at (x, y, 0) facing yaw, following the boxes unless nofollow
awk_actor = function(set, x, y, yaw, nofollow)
	MakeCurrentSet(set)
	local a = LoadActor("awk_probe")
	PutActorInSet(a, set)
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, yaw, 0)
	if not nofollow then
		SetActorFollowBoxes(a, TRUE)
	end
	AWK_A = a
	CR_A = a
	return a
end

awk_rot = function(key, a)
	local p, y, r = GetActorRot(a)
	cr_log(key, p, y, r)
end

-- WalkActorForward for n frames, the position every `every` frames (key .. frame) and at the end
awk_forward = function(key, a, n, every)
	local i = 0
	while i < n do
		WalkActorForward(a)
		if every and mod(i, every) == 0 then
			cr_pos(key .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos(key .. "end", a)
	local p, y, r = GetActorRot(a)
	cr_log(key .. "yaw", y)
	cr_log(key .. "moving", IsActorMoving(a))
end

-- (not following the boxes: straight on, off the floor too, and with a negative rate straight back)
cr_t_awk_fwd_nofollow = function()
	local a = awk_actor("awk_one.set", 0, 0, 30, TRUE)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	awk_forward("fwd", a, 20, 5)
	SetActorWalkRate(a, -1)
	awk_forward("back", a, 20, 5)
	-- (on past the edge of the floor)
	SetActorWalkRate(a, 2)
	PutActorAt(a, 1.5, 0, 0)
	SetActorRot(a, 0, 270, 0)
	awk_forward("off", a, 30, 10)
	cr_log("off_sector", GetActorSector(a, 4096))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_fwd_nofollow", "WalkActorForward moves in its own frame on ScummVM, a frame later on the original, and IsActorMoving is nil after it there; past the floor's edge the original turns the actor that does not follow the boxes") cr_test("awk_fwd_nofollow", cr_t_awk_fwd_nofollow)

-- (a walk rate of 0: the actor walks without moving; the walk chore keeps playing)
cr_t_awk_fwd_rate0 = function()
	local a = awk_actor("awk_one.set", 0, 0, 0)
	SetActorCostume(a, "awk_turn.cos")
	SetActorWalkChore(a, 1, "awk_turn.cos")
	SetActorRestChore(a, 0, "awk_turn.cos")
	SetActorWalkRate(a, 0)
	cr_frames(2)
	AWK_WALK = 0
	local s = ""
	local i = 0
	while i < 12 do
		WalkActorForward(a)
		break_here()
		s = s .. tostring(AWK_WALK) .. "/" .. tostring(IsActorMoving(a)) .. " "
		i = i + 1
	end
	cr_log("trace", s)
	cr_pos("end", a)
	cr_log("walk_chore", IsActorChoring(a, 1, FALSE, "awk_turn.cos"))
	cr_frames(3)
	cr_log("walk_chore_after", IsActorChoring(a, 1, FALSE, "awk_turn.cos"), IsActorMoving(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_fwd_rate0", "IsActorMoving after WalkActorForward is nil on the original; the walk chore's keys") cr_test("awk_fwd_rate0", cr_t_awk_fwd_rate0)

-- (a negative walk rate, following the boxes: backwards, then backwards into the edge of the floor, slid along it)
cr_t_awk_fwd_back = function()
	local a = awk_actor("awk_one.set", 0, 0, 0)
	SetActorWalkRate(a, -1)
	cr_frames(1)
	awk_forward("back", a, 30, 10)
	PutActorAt(a, 0.5, -1.5, 0)
	SetActorRot(a, 0, 20, 0)
	SetActorWalkRate(a, -2)
	awk_forward("wall", a, 60, 10)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_fwd_back", "WalkActorForward a frame early; walking backwards into the edge the original turns the actor away from it (yaw 189) where ScummVM slides along it") cr_test("awk_fwd_back", cr_t_awk_fwd_back)

-- (following the boxes in a set whose only floor is switched off: no sector at all, forwards and backwards; the puck
-- vector there)
cr_t_awk_fwd_nosector = function()
	local a = awk_actor("awk_one.set", 0, 0, 45)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	MakeSectorActive("awk_floor", FALSE)
	cr_log("sector", GetActorSector(a, 4096))
	local x, y, z = GetActorPuckVector(a)
	cr_log("puck", x, y, z)
	awk_forward("fwd", a, 20, 5)
	SetActorWalkRate(a, -1)
	awk_forward("back", a, 10, 5)
	MakeSectorActive("awk_floor", TRUE)
	cr_frames(1)
	cr_pos("floor_on", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_fwd_nosector", "WalkActorForward a frame early; the original's puck vector at yaw 45 is -0.7075 0.7067") cr_test("awk_fwd_nosector", cr_t_awk_fwd_nosector)

-- (into the right edge (x = 2, its edge going up) from below the normal (yaw 240: more than 90 degrees to the edge) and
-- from above it (yaw 300), steeply (yaw 260, 10 degrees off the normal) and with a reflection angle of 20 (the walk stops at
-- the edge), and into the top right corner)
awk_edge = function(key, x, y, yaw, refl, n)
	local a = awk_actor("awk_one.set", x, y, yaw)
	SetActorWalkRate(a, 2)
	if refl then
		SetActorReflection(a, refl)
	end
	cr_frames(1)
	awk_forward(key, a, n or 40, 10)
	PutActorInSet(a, nil)
end

cr_t_awk_fwd_edges = function()
	awk_edge("e240_", 1.5, 0, 240)
	awk_edge("e300_", 1.5, 0, 300)
	awk_edge("e260_", 1.5, 0, 260)
	awk_edge("r20_", 1.5, 0, 300, 20)
	awk_edge("r20b_", 1.5, 0, 240, 20)
	awk_edge("r80_", 1.5, 0, 300, 80)
	awk_edge("r89_", 1.5, 0, 300, 89)
end
cr_scummvm_differs("awk_fwd_edges", "into an edge the original stops (and turns a few degrees only with a reflection angle of 80 or 89 set); ScummVM slides along it (actor.cpp:924-939)") cr_test("awk_fwd_edges", cr_t_awk_fwd_edges)

cr_t_awk_fwd_corner = function()
	awk_edge("c315_", 1.7, 1.7, 315, nil, 30)
	awk_edge("c300_", 1.7, 1.7, 300, nil, 30)
	awk_edge("c330_", 1.7, 1.7, 330, nil, 30)
	awk_edge("c315r_", 1.7, 1.7, 315, 50, 30)
end
cr_scummvm_differs("awk_fwd_corner", "into the corner the original turns differently (yaw 217) and moves back along the edge; ScummVM stays in the corner") cr_test("awk_fwd_corner", cr_t_awk_fwd_corner)

-- (the puck vector of an actor that does not follow the boxes, off the floor and on it)
cr_t_awk_puck_off = function()
	local a = awk_actor("awk_one.set", 5, 5, 30, TRUE)
	cr_frames(1)
	cr_pos("pos", a)
	local x, y, z = GetActorPuckVector(a)
	cr_log("off", x, y, z)
	x, y, z = GetActorPuckVector(a, TRUE)
	cr_log("off_add", x, y, z)
	PutActorAt(a, 1, 1, 0)
	x, y, z = GetActorPuckVector(a)
	cr_log("on", x, y, z)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_puck_off", "GetActorPuckVector is nil on the original for an actor that does not follow the boxes (lua_v1_actor.cpp:521)") cr_test("awk_puck_off", cr_t_awk_puck_off)

-- (a path over the grid: the path search reaches the top middle floor first through the left column, then more cheaply
-- through the middle; the walk and where it goes)
awk_grid_walk = function(key, x0, y0, x1, y1)
	local a = awk_actor("awk_grid.set", x0, y0, 0)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	WalkActorTo(a, x1, y1, 0)
	local i = 0
	while i < 8 do
		cr_frames(5)
		cr_pos(key .. "_f" .. (i + 1) * 5, a)
		i = i + 1
	end
	local f = cr_until(cr_not_moving_a, 300)
	cr_log(key .. "_frames", f)
	cr_pos(key .. "_end", a)
	cr_log(key .. "_sector", GetActorSector(a, 4096))
	PutActorInSet(a, nil)
end

cr_t_awk_path_grid = function()
	awk_grid_walk("bl_tr", -1.5, -1.5, 1, 1.5)
	awk_grid_walk("tl_br", -1.5, 1.5, 1, -1.5)
	awk_grid_walk("ml_tl", -0.25, 0.25, -1.5, 1)
end
cr_scummvm_differs("awk_path_grid", "the original's walk over the grid of floors takes another way and ends 0.02 m past the target") cr_test("awk_path_grid", cr_t_awk_path_grid)

-- (the turn chores of awk_turn.cos (left 2, right 3) with its rest chore (0): a turn by SetActorRot's turn flag to the
-- left and back to the right; the rest chore stops while a turn chore plays and starts again after it; IsActorTurning in
-- the frame after the turn)
awk_chores = function()
	return tostring(AWK_REST) .. "/" .. tostring(AWK_LEFT) .. "/" .. tostring(AWK_RIGHT) .. "/" ..
		tostring(IsActorChoring(AWK_A, 0, FALSE, "awk_turn.cos")) .. "/" ..
		tostring(IsActorChoring(AWK_A, 2, FALSE, "awk_turn.cos")) .. "/" ..
		tostring(IsActorChoring(AWK_A, 3, FALSE, "awk_turn.cos")) .. "/" .. tostring(IsActorTurning(AWK_A))
end

-- every frame for n frames: the chores and the yaw
awk_turn_trace = function(key, n)
	local s = ""
	local i = 0
	local p, y, r
	while i < n do
		break_here()
		p, y, r = GetActorRot(AWK_A)
		s = s .. awk_chores() .. "/" .. format("%.1f", y) .. " "
		i = i + 1
	end
	cr_log(key, s)
end

awk_turn_actor = function(name)
	local a = awk_actor("awk_one.set", 0, 0, 0)
	SetActorCostume(a, "awk_turn.cos")
	SetActorRestChore(a, 0, "awk_turn.cos")
	SetActorTurnChores(a, 2, 3, "awk_turn.cos")
	SetActorTurnRate(a, 30)
	AWK_REST = 0
	AWK_LEFT = 0
	AWK_RIGHT = 0
	cr_frames(3)
	return a
end

cr_t_awk_turn_rot = function()
	local a = awk_turn_actor()
	cr_log("before", awk_chores())
	SetActorRot(a, 0, 60, 0, TRUE)
	cr_log("at_once", awk_chores())
	awk_turn_trace("left", 24)
	SetActorRot(a, 0, 0, 0, TRUE)
	awk_turn_trace("right", 24)
	awk_rot("end", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_turn_rot", "the original eases into SetActorRot's turn and plays the right turn chore both ways; its Lua Variable component sets the global to nil when the chore stops") cr_test("awk_turn_rot", cr_t_awk_turn_rot)

-- (TurnActor a few frames each way, then nothing: the turn chore stops and the rest chore comes back)
cr_t_awk_turn_key = function()
	local a = awk_turn_actor()
	local s = ""
	local i = 0
	while i < 6 do
		TurnActor(a, 1)
		break_here()
		s = s .. awk_chores() .. " "
		i = i + 1
	end
	cr_log("left", s)
	awk_turn_trace("left_after", 4)
	s = ""
	i = 0
	while i < 6 do
		TurnActor(a, -1)
		break_here()
		s = s .. awk_chores() .. " "
		i = i + 1
	end
	cr_log("right", s)
	awk_turn_trace("right_after", 4)
	awk_rot("end", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_turn_key", "the rest chore stops a frame earlier on the original, its Lua Variable global is nil when stopped, and TurnActor's yaw differs") cr_test("awk_turn_key", cr_t_awk_turn_key)

-- (a walk that turns, with the turn chores and the walk chore 1: the turn chores do not play while the actor walks)
cr_t_awk_turn_walk = function()
	local a = awk_turn_actor()
	SetActorWalkChore(a, 1, "awk_turn.cos")
	SetActorWalkRate(a, 1)
	AWK_WALK = 0
	WalkActorTo(a, 1, -1, 0)
	local s = ""
	local i = 0
	while i < 30 do
		break_here()
		if mod(i, 3) == 0 then
			s = s .. awk_chores() .. "/" .. tostring(AWK_WALK) .. " "
		end
		i = i + 1
	end
	cr_log("trace", s)
	cr_until(cr_not_moving_a, 200)
	cr_pos("end", a)
	cr_log("after", awk_chores(), AWK_WALK)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_turn_walk", "the original's Lua Variable global is nil when its chore stops (the rest and walk chores)") cr_test("awk_turn_walk", cr_t_awk_turn_walk)

-- (the walk chore changed in the middle of a walk, from chore 1 to chore 4: the old one stops, the rest chore starts)
cr_t_awk_walk_chore_change = function()
	local a = awk_actor("awk_one.set", -1, 0, 270)
	SetActorCostume(a, "awk_turn.cos")
	SetActorRestChore(a, 0, "awk_turn.cos")
	SetActorWalkChore(a, 1, "awk_turn.cos")
	SetActorWalkRate(a, 0.5)
	cr_frames(2)
	WalkActorTo(a, 1.5, 0, 0)
	cr_frames(8)
	cr_log("walking", IsActorChoring(a, 1, FALSE, "awk_turn.cos"), IsActorChoring(a, 0, FALSE, "awk_turn.cos"))
	SetActorWalkChore(a, 4, "awk_turn.cos")
	cr_log("changed", IsActorChoring(a, 1, FALSE, "awk_turn.cos"), IsActorChoring(a, 4, FALSE, "awk_turn.cos"),
		IsActorChoring(a, 0, FALSE, "awk_turn.cos"))
	local s = ""
	local i = 0
	while i < 8 do
		break_here()
		s = s .. tostring(IsActorChoring(a, 1, FALSE, "awk_turn.cos")) .. "/" ..
			tostring(IsActorChoring(a, 4, FALSE, "awk_turn.cos")) .. "/" ..
			tostring(IsActorChoring(a, 0, FALSE, "awk_turn.cos")) .. " "
		i = i + 1
	end
	cr_log("trace", s)
	cr_pos("pos", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_walk_chore_change", "SetActorWalkChore during a walk: the original plays the new walk chore at once; ScummVM stops the old one and starts the rest chore (actor.cpp:1012-1017)") cr_test("awk_walk_chore_change", cr_t_awk_walk_chore_change)

-- (ActorPuckOrient: an actor on the ramp of cr_stair pointed up and across it, and walking up it; the rotation it takes)
cr_t_awk_puck_orient = function()
	local a = awk_actor("cr_stair.set", 0, -1, 0)
	PutActorAt(a, 0, 0.5, 0.25)
	ActorPuckOrient(a, TRUE)
	cr_frames(1)
	PointActorAt(a, 0, 2, 0.5)
	awk_rot("up", a)
	PointActorAt(a, 2, 0.5, 0.25)
	awk_rot("across", a)
	cr_frames(2)
	awk_rot("across_later", a)
	PutActorAt(a, 0, -1, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorWalkRate(a, 1)
	WalkActorTo(a, 0, 2, 0.5)
	local i = 0
	while i < 5 do
		cr_frames(10)
		cr_pos("walk" .. i, a)
		awk_rot("walk_rot" .. i, a)
		i = i + 1
	end
	ActorPuckOrient(a, FALSE)
	PointActorAt(a, 0, -1, 0)
	awk_rot("off", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("awk_puck_orient", "ActorPuckOrient on a ramp: other pitch and roll (ScummVM: setPuckOrient not implemented, actor.cpp:981)") cr_test("awk_puck_orient", cr_t_awk_puck_orient)

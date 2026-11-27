-- What an actor sees and where it looks: GetVisibleThings (the actors of its set it can see: ahead of it, within its field
-- of view), ActorLookAt with a point, an actor and nil, TurnActorTo and PointActorAt. The actors have the drawn box
-- (draw.lua), which has the nodes of BOX_MODEL (a head node at 1.7 m).

cr_sg_actor = function(name, x, y, yaw)
	local a = LoadActor(name)
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, yaw or 0, 0)
	SetActorCostume(a, "cr_dbox.cos")
	return a
end

-- (the names of the actors of a table, in the order of the actors given)
cr_sg_seen = function(key, t, actors, names)
	local i = 1
	local s = ""
	while actors[i] do
		local found = nil
		local k, v = next(t, nil)
		while k do
			if k == actors[i] or v == actors[i] then
				found = 1
			end
			k, v = next(t, k)
		end
		if found then
			s = s .. names[i] .. " "
		end
		i = i + 1
	end
	cr_log(key, s)
end

cr_t_sight_visible = function()
	MakeCurrentSet("cr_open.set")
	local a = cr_sg_actor("cr_sg_obs", 0, 0, 0)
	local front = cr_sg_actor("cr_sg_front", 0, 1.5, 0)
	local behind = cr_sg_actor("cr_sg_behind", 0, -1.5, 0)
	local side = cr_sg_actor("cr_sg_side", 1.5, 0.2, 0)
	local wide = cr_sg_actor("cr_sg_wide", 1.2, 1.2, 0)
	cr_frames(2)
	local all = { front, behind, side, wide }
	local names = { "front", "behind", "side", "wide" }
	cr_sg_seen("ahead", GetVisibleThings(a), all, names)
	SetActorRot(a, 0, 180, 0)
	cr_frames(2)
	cr_sg_seen("turned", GetVisibleThings(a), all, names)
	SetActorRot(a, 0, -90, 0)
	cr_frames(2)
	cr_sg_seen("right", GetVisibleThings(a), all, names)
	PutActorInSet(front, nil)
	PutActorInSet(behind, nil)
	PutActorInSet(side, nil)
	PutActorInSet(wide, nil)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("sight_visible") cr_test("sight_visible", cr_t_sight_visible)

cr_t_sight_look = function()
	MakeCurrentSet("cr_open.set")
	local a = cr_sg_actor("cr_sg_looker", 0, 0, 0)
	local b = cr_sg_actor("cr_sg_target", 1, 1, 0)
	cr_frames(2)
	ActorLookAt(a, 1, 2, 1.7, 100)
	cr_frames(10)
	cr_log("point_ret", 1)
	local x, y, z = GetActorNodeLocation(a, 2)
	cr_log("point_head", x, y, z)
	ActorLookAt(a, b, 100)
	cr_frames(10)
	x, y, z = GetActorNodeLocation(a, 2)
	cr_log("actor_head", x, y, z)
	ActorLookAt(a, nil)
	cr_frames(10)
	x, y, z = GetActorNodeLocation(a, 2)
	cr_log("nil_head", x, y, z)
	ActorLookAt(a, 2, 0, 0)
	cr_frames(10)
	PutActorInSet(b, nil)
	PutActorInSet(a, nil)
end
cr_test("sight_look", cr_t_sight_look)

cr_sg_rot = function(key, a)
	local p, y, r = GetActorRot(a)
	cr_log(key, p, y, r)
end

cr_t_sight_turn = function()
	MakeCurrentSet("cr_open.set")
	local a = cr_sg_actor("cr_sg_turner", 0, 0, 0)
	local b = cr_sg_actor("cr_sg_target", -1, 1, 0)
	SetActorTurnRate(a, 90)
	cr_frames(2)
	local f = 0
	local r = TurnActorTo(a, 1, 1, 0)
	cr_log("turn_first", r)
	while r and f < 200 do
		break_here()
		r = TurnActorTo(a, 1, 1, 0)
		f = f + 1
	end
	cr_log("turn_frames", f)
	cr_sg_rot("turn_rot", a)
	f = 0
	r = TurnActorTo(a, b)
	while r and f < 200 do
		break_here()
		r = TurnActorTo(a, b)
		f = f + 1
	end
	cr_log("turn_actor_frames", f)
	cr_sg_rot("turn_actor_rot", a)
	PointActorAt(a, 0, -1, 0)
	cr_frames(1)
	cr_sg_rot("point_rot", a)
	PointActorAt(a, b)
	cr_frames(1)
	cr_sg_rot("point_actor_rot", a)
	cr_log("yaw_to_point", GetActorYawToPoint(a, 1, 0, 0))
	PutActorInSet(b, nil)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("sight_turn") cr_test("sight_turn", cr_t_sight_turn)

-- What an actor with a head sees (sputActor_CanActorSeePoint 0x48fa60): the way from its first head joint to the other
-- actor, on the floor, against the way it faces, within cos(|maxRoll| / 2) (SetActorHead 0x48f9d0). The viewer is
-- cr_dbox.cos (BOX_MODEL's nodes: 2 the head, 1.7 m above the root; 3 the arm, at (0.3, 0.1, 1.2)); the targets have no
-- costume. A ring of targets 2 m away at angles from the way the viewer faces (+ to its right).
CR_SR_ANGLES = { 0, 45, 80, 85, 100, 180, -45, -80, -85, -100 }
CR_SR_NAMES = { "a0", "a45", "a80", "a85", "a100", "a180", "m45", "m80", "m85", "m100" }

-- (the ring around (x, y) for a viewer turned by yaw; the actors are made once and moved)
cr_sr_ring = function(x, y, yaw, set)
	if not CR_SR_RING then
		CR_SR_RING = { }
		local i = 1
		while CR_SR_ANGLES[i] do
			CR_SR_RING[i] = LoadActor("cr_sr_t" .. i)
			i = i + 1
		end
	end
	local i = 1
	while CR_SR_ANGLES[i] do
		local t = CR_SR_RING[i]
		local ang = CR_SR_ANGLES[i] - (yaw or 0)
		PutActorInSet(t, set or "cr_open.set")
		PutActorAt(t, x + 2 * sin(ang), y + 2 * cos(ang), 0)
		i = i + 1
	end
end

cr_sr_ring_off = function()
	local i = 1
	while CR_SR_RING[i] do
		PutActorInSet(CR_SR_RING[i], nil)
		i = i + 1
	end
end

cr_sr_log = function(key, a)
	cr_frames(1)
	cr_sg_seen(key, GetVisibleThings(a), CR_SR_RING, CR_SR_NAMES)
end

cr_sr_test = function(name, fn)
	cr_test("sight_head_" .. name, function()
		MakeCurrentSet("cr_open.set")
		local a = cr_sg_actor("cr_sr_viewer", 0, 0, 0)
		cr_sr_ring(0, 0, 0)
		cr_frames(2)
		%fn(a)
		cr_sr_ring_off()
		PutActorInSet(a, nil)
	end)
end

-- the half angle of the field of view from maxRoll; the other limits do not count
cr_sr_test("roll", function(a)
	cr_sr_log("no_head", a)
	SetActorHead(a, 2, 2, 2, 165, 28, 80)
	cr_sr_log("r165", a)
	SetActorHead(a, 2, 2, 2, 90, 28, 80)
	cr_sr_log("r90", a)
	SetActorHead(a, 2, 2, 2, -165, 28, 80)
	cr_sr_log("r_neg165", a)
	SetActorHead(a, 2, 2, 2, 200, 28, 80)
	cr_sr_log("r200", a)
	SetActorHead(a, 2, 2, 2, 360, 28, 80)
	cr_sr_log("r360", a)
	SetActorHead(a, 2, 2, 2, 165, 0, 0)
	cr_sr_log("r165_no_pitch_yaw", a)
end)

-- turned and moved: the ring turns and moves with it
cr_sr_test("turned", function(a)
	SetActorHead(a, 2, 2, 2, 165, 28, 80)
	SetActorRot(a, 0, 90, 0)
	cr_sr_ring(0, 0, 90)
	cr_sr_log("yaw90", a)
	SetActorRot(a, 0, -135, 0)
	cr_sr_ring(0, 0, -135)
	cr_sr_log("yaw_m135", a)
	PutActorAt(a, 1, -2, 0)
	SetActorRot(a, 0, 30, 0)
	cr_sr_ring(1, -2, 30)
	cr_sr_log("moved", a)
end)

-- from the joint, not the root: the arm (node 3) is 0.3 m to the right and 0.1 m ahead. A target at (0.5, 0.12) is 76.5
-- degrees right of the root's way but 84.3 from the arm; one at (0.5, 0.15) 73.3 and 76
cr_sr_test("joint", function(a)
	cr_sr_ring_off()
	local near = LoadActor("cr_sr_near")
	local far = LoadActor("cr_sr_far")
	PutActorInSet(near, "cr_open.set")
	PutActorInSet(far, "cr_open.set")
	PutActorAt(near, 0.5, 0.15, 0)
	PutActorAt(far, 0.5, 0.12, 0)
	SetActorHead(a, 2, 2, 2, 165, 28, 80)
	cr_frames(1)
	cr_sg_seen("from_head", GetVisibleThings(a), { near, far }, { "near", "far" })
	SetActorHead(a, 3, 3, 3, 165, 28, 80)
	cr_frames(1)
	cr_sg_seen("from_arm", GetVisibleThings(a), { near, far }, { "near", "far" })
	-- (turned: the arm turns with the actor)
	SetActorRot(a, 0, 90, 0)
	PutActorAt(near, -0.15, 0.5, 0)
	PutActorAt(far, -0.12, 0.5, 0)
	cr_frames(1)
	cr_sg_seen("from_arm_turned", GetVisibleThings(a), { near, far }, { "near", "far" })
	SetActorHead(a, 1, 1, 1, 165, 28, 80)
	cr_frames(1)
	cr_sg_seen("from_body", GetVisibleThings(a), { near, far }, { "near", "far" })
	PutActorInSet(near, nil)
	PutActorInSet(far, nil)
end)

-- pitched or rolled: the way it faces is the actor's forward axis with its height dropped, not made one long again
cr_sr_test("pitch_roll", function(a)
	SetActorHead(a, 2, 2, 2, 165, 28, 80)
	SetActorRot(a, 60, 0, 0)
	cr_sr_log("pitch60", a)
	SetActorRot(a, -60, 0, 0)
	cr_sr_log("pitch_m60", a)
	SetActorRot(a, 0, 0, 60)
	cr_sr_log("roll60", a)
	SetActorRot(a, 85, 0, 0)
	cr_sr_log("pitch85", a)
	SetActorRot(a, 120, 0, 0)
	cr_sr_log("pitch120", a)
end)

-- the costumes: a pushed costume with the same model has the head of the costume below it (sputCostume_PushCostume
-- 0x494e80); one with another model has none, until it is given one; popping it gives back the one below
cr_sr_test("costumes", function(a)
	SetActorHead(a, 2, 2, 2, 165, 28, 80)
	PushActorCostume(a, "cr_cm_white.cos")
	cr_sr_log("pushed_same_model", a)
	SetActorHead(a, 2, 2, 2, 90, 28, 80)
	cr_sr_log("pushed_own_head", a)
	PushActorCostume(a, "cr_gbox.cos")
	cr_sr_log("pushed_other_model", a)
	SetActorHead(a, 2, 2, 2, 360, 28, 80)
	cr_sr_log("other_model_own_head", a)
	PopActorCostume(a)
	cr_sr_log("popped_once", a)
	PopActorCostume(a)
	cr_sr_log("popped_twice", a)
	SetActorCostume(a, "cr_cm_white.cos")
	cr_sr_log("set_costume", a)
	SetActorCostume(a, nil)
	cr_sr_log("no_costume", a)
end)

-- the set: the other actor must be in the viewer's set (its name compared without the case); the viewer need not be in
-- the current set
cr_sr_test("sets", function(a)
	SetActorHead(a, 2, 2, 2, 165, 28, 80)
	cr_sr_ring(0, 0, 0, "cr_flat.set")
	cr_sr_log("ring_elsewhere", a)
	cr_sr_ring(0, 0, 0, "CR_OPEN.SET")
	cr_sr_log("ring_upper_case", a)
	cr_sr_ring(0, 0, 0)
	MakeCurrentSet("cr_flat.set")
	cr_sr_log("viewer_not_current", a)
	MakeCurrentSet("cr_open.set")
	PutActorInSet(a, nil)
	cr_sr_log("viewer_out", a)
	PutActorInSet(a, "cr_open.set")
	SetSelectedActor(a)
	cr_frames(1)
	cr_sg_seen("selected_nil_arg", GetVisibleThings(), CR_SR_RING, CR_SR_NAMES)
end)

-- the height does not count: targets high above or right over the head
cr_sr_test("height", function(a)
	cr_sr_ring_off()
	local high = LoadActor("cr_sr_high")
	local over = LoadActor("cr_sr_over")
	PutActorInSet(high, "cr_open.set")
	PutActorInSet(over, "cr_open.set")
	PutActorAt(high, 0.3, 1, 5)
	PutActorAt(over, 0, 0, 3)
	SetActorHead(a, 2, 2, 2, 165, 28, 80)
	cr_frames(1)
	cr_sg_seen("r165", GetVisibleThings(a), { high, over }, { "high", "over" })
	SetActorHead(a, 2, 2, 2, 360, 28, 80)
	cr_frames(1)
	cr_sg_seen("r360", GetVisibleThings(a), { high, over }, { "high", "over" })
	PutActorInSet(high, nil)
	PutActorInSet(over, nil)
end)

-- (ScummVM before Actor::canSee: a 90 degree half angle from the root whatever the head, the actor itself seen)
cr_scummvm_differs("sight_head_roll")
cr_scummvm_differs("sight_head_joint")
cr_scummvm_differs("sight_head_pitch_roll")
cr_scummvm_differs("sight_head_costumes")
cr_scummvm_differs("sight_head_sets")
cr_scummvm_differs("sight_head_height")

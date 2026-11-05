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
cr_test("sight_visible", cr_t_sight_visible)

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
cr_test("sight_turn", cr_t_sight_turn)

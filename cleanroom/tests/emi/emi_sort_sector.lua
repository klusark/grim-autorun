-- The sort order of an actor that follows the boxes: the sort plane of its walk sector for the current setup (bug 11816,
-- an actor drawn in front of the building it walks behind on Lucre). The original (Actor_GetEffectiveSortOrder 0x4257b0)
-- asks on demand: before the actor's first walk, the first active walk sector that holds its position exactly (within the
-- sector's height, 0.005 for a height of 0); once its walker has a heading frame, the sector the walker is in (kept from
-- step to step, handed on at an edge to the sector past it), whatever the position. A setup past the sector's planes reads 0.
-- ScummVM looks for the closest visible walk sector within 1 cm of the position, once a frame in Actor::update.
-- Sets in assets_emi_extra_ess.py: ess_over (o_mid over the shared edge of o_left and o_right, o_neg, o_door off), ess_ramp,
-- ess_tall. Every actor's own order is 99, so 99 means "no sector".

ess_actor = function(set, x, z, nofollow)
	MakeCurrentSet(set)
	local a = LoadActor("ess_probe")
	PutActorInSet(a, set)
	PutActorAt(a, x, 0, z)
	SetActorRot(a, 0, 0, 0)
	SetActorSortOrder(a, 99)
	if not nofollow then
		SetActorFollowBoxes(a, TRUE)
	end
	return a
end

ess_pos = function(key, a)
	local x, y, z = GetActorPos(a)
	cr_log(key, x, y, z)
end

-- the sort order in each of ess_over's three setups (back in setup 0 afterwards)
ess_setups = function(key, a)
	MakeCurrentSetup(0)
	local s0 = GetActorSortOrder(a)
	MakeCurrentSetup(1)
	local s1 = GetActorSortOrder(a)
	MakeCurrentSetup(2)
	local s2 = GetActorSortOrder(a)
	MakeCurrentSetup(0)
	cr_log(key, s0, s1, s2)
end

-- the sort orders an actor goes through, one frame after another while it moves (at most maxf frames), as a string
ess_seq = function(a, maxf)
	local last = GetActorSortOrder(a)
	local seq = format("%d", last)
	local f = 0
	local s = 0
	local moving = IsActorMoving(a)
	while moving and f < maxf do
		break_here()
		f = f + 1
		s = GetActorSortOrder(a)
		if s ~= last then
			seq = seq .. " " .. format("%d", s)
			last = s
		end
		moving = IsActorMoving(a)
	end
	return seq
end

ess_walk = function(key, a, x, y, z, maxf)
	WalkActorTo(a, x, y, z)
	cr_log(key .. "_seq", ess_seq(a, maxf))
	ess_pos(key .. "_end", a)
end

-- placed (no walk yet): in one sector, in two (o_mid first), on o_left/o_right's shared edge, at o_mid's edge, in o_neg,
-- just outside and far outside the floor; the order at once and a frame later, in the three setups
ess_place_points = { { "left", -3, 0 }, { "mid_left", -0.5, 0 }, { "mid_right", 0.5, 0 }, { "right", 3, 0 },
	{ "edge_lr", 0, 1.5 }, { "mid_edge", -1, 0 }, { "neg", 0, 3 }, { "out_near", -4.003, 0 }, { "out_far", -6, 0 },
	{ "door_off", 4.5, 0 } }
cr_t_ess_place = function()
	local a = ess_actor("ess_over.set", -3, 0)
	cr_frames(1)
	local i = 1
	local p = nil
	while ess_place_points[i] do
		p = ess_place_points[i]
		PutActorAt(a, p[2], 0, p[3])
		cr_log(p[1] .. "_now", GetActorSortOrder(a))
		cr_frames(1)
		ess_setups(p[1], a)
		ess_pos(p[1] .. "_pos", a)
		i = i + 1
	end
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_place", "ScummVM works the sector's plane out in Actor::update with the setup of that frame: right after PutActorAt or MakeCurrentSetup GetActorSortOrder gives the old value; the original asks when called")
cr_test("ess_place", cr_t_ess_place)

-- following the boxes switched off and on again while standing in o_left; an actor that never followed them
cr_t_ess_follow = function()
	local a = ess_actor("ess_over.set", -3, 0, TRUE)
	cr_frames(1)
	cr_log("never", GetActorSortOrder(a))
	SetActorFollowBoxes(a, TRUE)
	cr_log("on_now", GetActorSortOrder(a))
	cr_frames(1)
	cr_log("on", GetActorSortOrder(a))
	SetActorFollowBoxes(a, FALSE)
	cr_log("off_now", GetActorSortOrder(a))
	cr_frames(1)
	cr_log("off", GetActorSortOrder(a))
	SetActorFollowBoxes(a, TRUE)
	cr_frames(1)
	SetActorSortOrder(a, 7)
	cr_log("own_set_following", GetActorSortOrder(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_follow", "ScummVM works the sector's plane out in Actor::update with the setup of that frame: right after PutActorAt or MakeCurrentSetup GetActorSortOrder gives the old value; the original asks when called (also right after SetActorFollowBoxes)")
cr_test("ess_follow", cr_t_ess_follow)

-- placed above and below the floor of o_left (no walk yet): within 0.005, within 1 cm, past both
ess_heights = { { "up3mm", 0.003 }, { "up8mm", 0.008 }, { "up2cm", 0.02 }, { "down3mm", -0.003 }, { "down2cm", -0.02 } }
cr_t_ess_height = function()
	local a = ess_actor("ess_over.set", -3, 0)
	cr_frames(1)
	local i = 1
	local h = nil
	while ess_heights[i] do
		h = ess_heights[i]
		PutActorAt(a, -3, h[2], 0)
		cr_log(h[1] .. "_now", GetActorSortOrder(a))
		cr_frames(1)
		cr_log(h[1], GetActorSortOrder(a))
		ess_pos(h[1] .. "_pos", a)
		i = i + 1
	end
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_height", "ScummVM snaps an actor that is 3 mm off the floor onto it (Actor::update findClosestSector); the original keeps it within the sector's height")
cr_test("ess_height", cr_t_ess_height)

-- ess_tall: 5 cm above t_tall (height 0.1) and above t_flat (height 0, the original's 0.005)
cr_t_ess_tall = function()
	local a = ess_actor("ess_tall.set", -1, 0)
	cr_frames(1)
	cr_log("tall_floor", GetActorSortOrder(a))
	PutActorAt(a, -1, 0.05, 0)
	cr_log("tall_5cm_now", GetActorSortOrder(a))
	cr_frames(1)
	cr_log("tall_5cm", GetActorSortOrder(a))
	ess_pos("tall_5cm_pos", a)
	PutActorAt(a, 1, 0.05, 0)
	cr_log("flat_5cm_now", GetActorSortOrder(a))
	cr_frames(1)
	cr_log("flat_5cm", GetActorSortOrder(a))
	ess_pos("flat_5cm_pos", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_tall", "ScummVM ignores the sector's height (its sort lookup takes the closest sector within 1 cm and snaps); the original keeps an actor 5 cm up in a sector of height 0.1")
cr_test("ess_tall", cr_t_ess_tall)

-- walks across ess_over: through o_mid (over the edge of o_left and o_right), past it on the shared edge, into o_mid and
-- stopping there, back out of it
cr_t_ess_walk_mid = function()
	local a = ess_actor("ess_over.set", -3, 0)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	ess_walk("through_mid", a, 3, 0, 0, 200)
	ess_setups("after_through", a)
	PutActorAt(a, -3, 0, 1.5)
	cr_frames(1)
	ess_walk("past_mid", a, 3, 0, 1.5, 200)
	ess_setups("after_past", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_walk_mid", "ScummVM works the sector's plane out in Actor::update with the setup of that frame: right after PutActorAt or MakeCurrentSetup GetActorSortOrder gives the old value; the original asks when called")
cr_test("ess_walk_mid", cr_t_ess_walk_mid)

cr_t_ess_walk_into = function()
	local a = ess_actor("ess_over.set", -3, 0)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	ess_walk("into_mid", a, -0.5, 0, 0, 200)
	ess_setups("stopped", a)
	cr_frames(5)
	ess_setups("stopped_5", a)
	ess_walk("out_left", a, -3, 0, 0, 200)
	ess_setups("back_left", a)
	ess_walk("into_mid_right", a, 0.5, 0, 0, 200)
	ess_setups("stopped_right", a)
	ess_walk("to_right", a, 3, 0, 0, 200)
	ess_setups("in_right", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_walk_into", "ScummVM works the sector's plane out in Actor::update with the setup of that frame: right after PutActorAt or MakeCurrentSetup GetActorSortOrder gives the old value; the original asks when called")
cr_test("ess_walk_into", cr_t_ess_walk_into)

-- after a walk in o_left: put elsewhere with PutActorAt (the walker's sector is not moved with it?)
cr_t_ess_put_after_walk = function()
	local a = ess_actor("ess_over.set", -3, 0)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	ess_walk("short", a, -2, 0, 0, 200)
	cr_log("walked", GetActorSortOrder(a))
	PutActorAt(a, 3, 0, 0)
	cr_log("put_right_now", GetActorSortOrder(a))
	cr_frames(2)
	ess_setups("put_right", a)
	PutActorAt(a, 0.5, 0, 0)
	cr_frames(2)
	ess_setups("put_mid", a)
	PutActorAt(a, 0, 0, 3)
	cr_frames(2)
	ess_setups("put_neg", a)
	PutActorAt(a, -6, 0, 0)
	cr_frames(2)
	ess_setups("put_out", a)
	ess_pos("put_out_pos", a)
	ess_walk("from_out", a, -3, 0, 0, 200)
	ess_setups("after_walk_back", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_put_after_walk", "ScummVM works the sector's plane out in Actor::update with the setup of that frame: right after PutActorAt or MakeCurrentSetup GetActorSortOrder gives the old value; the original asks when called")
cr_test("ess_put_after_walk", cr_t_ess_put_after_walk)

-- a sector switched off under an actor: before any walk, and after a walk in it; on again
cr_t_ess_box_off = function()
	local a = ess_actor("ess_over.set", -3, 0)
	cr_frames(1)
	MakeSectorActive("o_left", FALSE)
	cr_log("nowalk_off_now", GetActorSortOrder(a))
	cr_frames(1)
	cr_log("nowalk_off", GetActorSortOrder(a))
	ess_pos("nowalk_off_pos", a)
	MakeSectorActive("o_left", TRUE)
	cr_frames(1)
	cr_log("nowalk_on", GetActorSortOrder(a))
	ess_pos("nowalk_on_pos", a)
	PutActorAt(a, -3, 0, 0)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	ess_walk("walk", a, -2, 0, 0, 200)
	MakeSectorActive("o_left", FALSE)
	cr_log("walked_off_now", GetActorSortOrder(a))
	cr_frames(1)
	cr_log("walked_off", GetActorSortOrder(a))
	ess_pos("walked_off_pos", a)
	MakeSectorActive("o_left", TRUE)
	cr_frames(1)
	cr_log("walked_on", GetActorSortOrder(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_box_off", "a sector switched off under a standing actor: the original keeps the actor and its walker's sector plane; ScummVM snaps it to the closest visible sector (moves it) and takes that plane")
cr_test("ess_box_off", cr_t_ess_box_off)

-- the Lucre tourists' start (luc.start_walk): a box switched on, the actor put in it and walked out, the box switched off
cr_t_ess_door = function()
	MakeCurrentSet("ess_over.set")
	MakeSectorActive("o_door", TRUE)
	local a = LoadActor("ess_probe")
	PutActorInSet(a, "ess_over.set")
	PutActorAt(a, 4.5, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorSortOrder(a, 99)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 2)
	cr_log("in_door_now", GetActorSortOrder(a))
	cr_frames(1)
	ess_setups("in_door", a)
	WalkActorTo(a, -3, 0, 0)
	local seq = ess_seq(a, 10)
	MakeSectorActive("o_door", FALSE)
	cr_log("door_off_now", GetActorSortOrder(a))
	cr_log("seq", seq .. " | " .. ess_seq(a, 200))
	ess_pos("end", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_door", "ScummVM works the sector's plane out in Actor::update with the setup of that frame: right after PutActorAt or MakeCurrentSetup GetActorSortOrder gives the old value; the original asks when called")
cr_test("ess_door", cr_t_ess_door)

-- up the ramp of ess_ramp and down again: the orders on the way, the height off the floor's plane at its worst
ess_floor_y = function(z)
	if z <= 0 then
		return 0
	elseif z >= 1 then
		return 0.5
	end
	return z * 0.5
end
ess_ramp_walk = function(key, a, x, y, z)
	WalkActorTo(a, x, y, z)
	local last = GetActorSortOrder(a)
	local seq = format("%d", last)
	local worst = 0
	local f = 0
	local s = 0
	local px = 0
	local py = 0
	local pz = 0
	local moving = IsActorMoving(a)
	while moving and f < 300 do
		break_here()
		f = f + 1
		s = GetActorSortOrder(a)
		if s ~= last then
			seq = seq .. " " .. format("%d", s)
			last = s
		end
		px, py, pz = GetActorPos(a)
		if abs(py - ess_floor_y(pz)) > worst then
			worst = abs(py - ess_floor_y(pz))
		end
		moving = IsActorMoving(a)
	end
	cr_log(key .. "_seq", seq)
	if worst > 0.001 then
		cr_log(key .. "_off_plane", "over 1 mm")
	else
		cr_log(key .. "_off_plane", "within 1 mm")
	end
	ess_pos(key .. "_end", a)
end
cr_t_ess_ramp = function()
	local a = ess_actor("ess_ramp.set", 0, -2)
	SetActorWalkRate(a, 1)
	cr_frames(1)
	cr_log("start", GetActorSortOrder(a))
	ess_ramp_walk("up", a, 0, 0.5, 2)
	ess_ramp_walk("down", a, 1, 0, -2)
	ess_ramp_walk("onto_ramp", a, -1, 0.25, 0.5)
	PutActorInSet(a, nil)
end
cr_test("ess_ramp", cr_t_ess_ramp)

-- a walk whose straight way crosses a hot box (Lucre's long_cheatbox, bug 11816): the original's path planner
-- (WalkPlaneCollection_BuildPath 0x445980) knows walk sectors only and goes round by the bridge h_b; an actor outside every
-- walk sector has its own order (99 here, 0 for the game's tourists: drawn over every layer)
ess_walk_track = function(key, a, x, y, z)
	WalkActorTo(a, x, y, z)
	local last = GetActorSortOrder(a)
	local seq = format("%d", last)
	local north = 0
	local f = 0
	local s = 0
	local px = 0
	local py = 0
	local pz = 0
	local moving = IsActorMoving(a)
	while moving and f < 300 do
		break_here()
		f = f + 1
		s = GetActorSortOrder(a)
		if s ~= last then
			seq = seq .. " " .. format("%d", s)
			last = s
		end
		px, py, pz = GetActorPos(a)
		if pz > north then
			north = pz
		end
		moving = IsActorMoving(a)
	end
	cr_log(key .. "_seq", seq)
	if north > 0.5 then
		cr_log(key .. "_route", "by the bridge")
	else
		cr_log(key .. "_route", "straight")
	end
	ess_pos(key .. "_end", a)
end
cr_t_ess_hot_path = function()
	local a = ess_actor("ess_hot.set", -2, -2)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	cr_log("start", GetActorSortOrder(a))
	ess_walk_track("across", a, 2, 0, -2)
	ess_walk_track("back", a, -2, 0, -2)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_hot_path", "bug 11816: ScummVM's Actor::walkTo plans through hot sectors (the straight way, no walk sector: own order); the original plans over walk sectors only (fixed on grim-11816)")
cr_test("ess_hot_path", cr_t_ess_hot_path)

-- put inside the hot box (no walk sector there); a walk to a point inside the hot box
cr_t_ess_hot_put = function()
	local a = ess_actor("ess_hot.set", -2, -2)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	PutActorAt(a, -0.5, 0, -2)
	cr_log("in_hot_now", GetActorSortOrder(a))
	cr_frames(1)
	cr_log("in_hot", GetActorSortOrder(a))
	ess_pos("in_hot_pos", a)
	PutActorAt(a, -2, 0, -2)
	cr_frames(1)
	ess_walk_track("to_hot", a, 0, 0, -2)
	PutActorInSet(a, nil)
end
cr_test("ess_hot_put", cr_t_ess_hot_put)

-- across a walk sector of type 0x1200 (the game's stair sectors)
cr_t_ess_stair_type = function()
	local a = ess_actor("ess_stairs.set", -2, 0)
	SetActorWalkRate(a, 2)
	cr_frames(1)
	cr_log("start", GetActorSortOrder(a))
	ess_walk_track("across", a, 2, 0, 0)
	PutActorAt(a, 0, 0, 2)
	cr_frames(1)
	cr_log("on_mid", GetActorSortOrder(a))
	ess_pos("on_mid_pos", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_stair_type", "ScummVM's Actor::walkTo plans only over sectors whose type is exactly walk, hot or funnel: a 0x1200 walk sector (Lucre's stairs) has no path; the original plans over every sector with the walk bit (fixed on grim-11816)")
cr_test("ess_stair_type", cr_t_ess_stair_type)

-- ess_apart: two floors 12 m apart that do not touch (Lucre's sector213 and sector143). The original finds no path and does
-- not walk; ScummVM's getBridgesTo gave the far floor a bridge on the near floor's west edge, and the actor walked over the
-- gap outside every walk sector (own order 99 here; 0 in Lucre: drawn over the port authority building, bug 11816)
cr_t_ess_apart = function()
	local a = ess_actor("ess_apart.set", -8, 6)
	SetActorWalkRate(a, 4)
	cr_frames(1)
	cr_log("start", GetActorSortOrder(a))
	WalkActorTo(a, 15, 0, -12.8)
	cr_log("moving", IsActorMoving(a))
	cr_log("seq", ess_seq(a, 600))
	ess_pos("end", a)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("ess_apart", "bug 11816: Sector::getBridgesTo clipped at the other sector's edge segments, not their lines, and gave two floors that do not touch a bridge; ScummVM walks over the gap outside every walk sector (fixed on grim-11816)")
cr_test("ess_apart", cr_t_ess_apart)

-- ess_lift: a walk from l_a to l_b with collision spheres on, past another actor (cr_ebox.cos, collision scale 2) that
-- stands 3.5 m to the side, off the floor. The original walks straight on the floor (WalkActorTo moves no path point round
-- other actors: Actor_WalkTo passes no actor to avoid). ScummVM's getTangentPos took the other actor's sphere in the x-y
-- plane, a side view in EMI: the bridge point went 0.7 m down, the walker left the floor (own order)
ess_lift_moving = function()
	return not IsActorMoving(ESS_LW)
end
cr_t_ess_lift = function()
	MakeCurrentSet("ess_lift.set")
	local w = LoadActor("ess_lwalker")
	ESS_LW = w
	PutActorInSet(w, "ess_lift.set")
	PutActorAt(w, -3, 0, 0)
	SetActorSortOrder(w, 99)
	SetActorFollowBoxes(w, TRUE)
	PlayActorChore(w, "wear_default", "cr_ebox.cos")
	SetActorWalkRate(w, 2)
	local o = LoadActor("ess_lother")
	PutActorInSet(o, "ess_lift.set")
	PutActorAt(o, 0, 0, 3.5)
	PlayActorChore(o, "wear_default", "cr_ebox.cos")
	cr_frames(2)
	SetActorCollisionMode(w, 2)
	SetActorCollisionScale(w, 0.3)
	SetActorCollisionMode(o, 2)
	SetActorCollisionScale(o, 2)
	cr_frames(1)
	WalkActorTo(w, 3, 0, 0)
	local last = GetActorSortOrder(w)
	local seq = format("%d", last)
	local worst = 0
	local f = 0
	local s = 0
	local px = 0
	local py = 0
	local pz = 0
	while IsActorMoving(w) and f < 300 do
		break_here()
		f = f + 1
		s = GetActorSortOrder(w)
		if s ~= last then
			seq = seq .. " " .. format("%d", s)
			last = s
		end
		px, py, pz = GetActorPos(w)
		if abs(py) > worst then
			worst = abs(py)
		end
	end
	cr_log("seq", seq)
	if worst > 0.001 then
		cr_log("height", "off the floor")
	else
		cr_log("height", "on the floor")
	end
	ess_pos("end", w)
	ess_pos("other", o)
	SetActorCollisionMode(w, 0)
	SetActorCollisionMode(o, 0)
	SetActorCollisionScale(w, 1)
	SetActorCollisionScale(o, 1)
	StopActorChores(w)
	StopActorChores(o)
	cr_frames(1)
	PutActorInSet(w, nil)
	PutActorInSet(o, nil)
end
cr_scummvm_differs("ess_lift", "bug 11816: ScummVM's Actor::getTangentPos moved a path point round another actor in the x-y plane, a side view in EMI: the point went 0.7 m under the floor and the walker left every walk sector (fixed on grim-11816)")
cr_test("ess_lift", cr_t_ess_lift)

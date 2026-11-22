-- Walks between floors that do not touch (assets_extra_fkl.py: fkl_low below y = 0, the triangle fkl_tri 1 m above it, the
-- way round by fkl_west and fkl_top). ScummVM's Sector::getBridgesTo gave fkl_low a bridge to fkl_tri (a cut only where
-- the bridge crossed an edge segment of the other floor, not the edge's line), and the path search took it: the walk went
-- straight over the gap, off every floor. The original goes round.

fkl_actor = function(x, y)
	MakeCurrentSet("fkl_fake.set")
	local a = LoadActor("fkl_probe")
	FKL_A = a
	PutActorInSet(a, "fkl_fake.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 2)
	return a
end

-- a walk to (x, y): which way it went (mode "west": west of x = 0.5 is round by fkl_west; mode "north": north of y = 0.5
-- is round by the bridge fkl_hb), whether it was ever off every floor, where it ended (to 0.1 m: the original stops a few
-- cm short, paths.lua) and in which floor
fkl_walk = function(key, a, x, y, mode)
	WalkActorTo(a, x, y, 0)
	local west = 100
	local north = -100
	local off = 0
	local f = 0
	local px = 0
	local py = 0
	local pz = 0
	local id = nil
	local moving = 1
	while moving and f < 1200 do
		break_here()
		f = f + 1
		px, py, pz = GetActorPos(a)
		if px < west then
			west = px
		end
		if py > north then
			north = py
		end
		id = GetPointSector(px, py, pz)
		if not id then
			off = off + 1
		end
		moving = IsActorMoving(a)
	end
	if mode == "north" then
		if north > 0.5 then
			cr_log(key .. "_route", "round by the bridge")
		else
			cr_log(key .. "_route", "straight")
		end
	elseif west < 0.5 then
		cr_log(key .. "_route", "round by the west")
	else
		cr_log(key .. "_route", "straight")
	end
	if off > 0 then
		cr_log(key .. "_floor", "off every floor")
	else
		cr_log(key .. "_floor", "on the floors")
	end
	px, py, pz = GetActorPos(a)
	cr_log(key .. "_end", format("%.1f %.1f", px, py))
	local sid, sname = GetPointSector(px, py, pz)
	cr_log(key .. "_sector", sname)
end

-- from the middle of fkl_low to the middle of fkl_tri, and back
cr_t_fkl_across = function()
	cr_allow_frames(3000)
	local a = fkl_actor(5, -1)
	cr_frames(1)
	fkl_walk("up", a, 5, 2.5)
	fkl_walk("down", a, 5, -1)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("fkl_across", "Sector::getBridgesTo bridges fkl_low to fkl_tri (cut at edge segments, not lines): the walk up goes straight over the gap (fixed on grim-11816)")
cr_test("fkl_across", cr_t_fkl_across)

-- from the east end of fkl_low to fkl_tri's west corner
cr_t_fkl_corner = function()
	cr_allow_frames(1500)
	local a = fkl_actor(9, -1.5)
	cr_frames(1)
	fkl_walk("to_corner", a, 3.5, 2.8)
	PutActorInSet(a, nil)
end
cr_scummvm_differs("fkl_corner", "Sector::getBridgesTo bridges fkl_low to fkl_tri (cut at edge segments, not lines): the walk goes straight over the gap (fixed on grim-11816)")
cr_test("fkl_corner", cr_t_fkl_corner)

-- fkl_hot: from the west column to the east one and back. The straight way crosses the chernobyl sector fkl_hhot (no walk
-- floor under it); the original's planner knows walk planes only (BuildPath 0x4a9430: WalkPlane_PlaneAt(.., 0x1000),
-- FindExitPoints: dwType & 0x1000) and goes round by the bridge fkl_hb
fkl_hot_actor = function(x, y)
	MakeCurrentSet("fkl_hot.set")
	local a = LoadActor("fkl_hprobe")
	PutActorInSet(a, "fkl_hot.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 2)
	return a
end
cr_t_fkl_hot_path = function()
	cr_allow_frames(2000)
	local a = fkl_hot_actor(-2, -2)
	cr_frames(1)
	fkl_walk("across", a, 2, -2, "north")
	fkl_walk("back", a, -2, -2, "north")
	PutActorInSet(a, nil)
end
cr_scummvm_differs("fkl_hot_path", "ScummVM's Actor::walkTo plans through Grim's hot (chernobyl) sectors: the walk goes straight through fkl_hhot, off every floor; the original plans over walk planes only (fixed on grim-11816)")
cr_test("fkl_hot_path", cr_t_fkl_hot_path)

-- the same walk with the chernobyl sector switched off: the control (both engines go round)
cr_t_fkl_hot_off = function()
	cr_allow_frames(2000)
	local a = fkl_hot_actor(-2, -2)
	MakeSectorActive("fkl_hhot", FALSE)
	cr_frames(1)
	fkl_walk("across", a, 2, -2, "north")
	MakeSectorActive("fkl_hhot", TRUE)
	PutActorInSet(a, nil)
end
cr_test("fkl_hot_off", cr_t_fkl_hot_off)

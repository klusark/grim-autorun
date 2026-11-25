-- What an actor sees (GetVisibleThings 0x415c80, 0x428070, 0x427eb0): the other actors of its set whose way from the
-- actor's position, on the x-z floor, is within cos(fov / 2) of the way it faces (SetActorFOV; 120 degrees at start).
-- A ring of targets 2 m away at angles from the way the viewer faces; no costumes.
CR_ES_ANGLES = { 0, 45, 55, 65, 80, 100, 180, -45, -55, -65 }
CR_ES_NAMES = { "a0", "a45", "a55", "a65", "a80", "a100", "a180", "m45", "m55", "m65" }

-- (the ring around (x, z) for a viewer turned by yaw; made once and moved)
cr_es_ring = function(x, z, yaw, set)
	if not CR_ES_RING then
		CR_ES_RING = { }
		local i = 1
		while CR_ES_ANGLES[i] do
			CR_ES_RING[i] = LoadActor("cr_es_t" .. i)
			i = i + 1
		end
	end
	local i = 1
	while CR_ES_ANGLES[i] do
		local t = CR_ES_RING[i]
		local ang = CR_ES_ANGLES[i] + (yaw or 0)
		PutActorInSet(t, set or "cr_flat.set")
		PutActorAt(t, x + 2 * sin(ang), 0, z + 2 * cos(ang))
		i = i + 1
	end
end

cr_es_ring_off = function()
	local i = 1
	while CR_ES_RING[i] do
		PutActorInSet(CR_ES_RING[i], nil)
		i = i + 1
	end
end

-- (the names of the actors of a table, in the order of the actors given)
cr_es_seen = function(key, t, actors, names)
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

cr_es_log = function(key, a)
	cr_frames(1)
	local t = GetVisibleThings(a)
	cr_log(key .. "_type", type(t))
	if type(t) == "table" then
		cr_es_seen(key, t, CR_ES_RING, CR_ES_NAMES)
	end
end

cr_es_test = function(name, fn)
	cr_test("es_" .. name, function()
		MakeCurrentSet("cr_flat.set")
		local a = LoadActor("cr_es_viewer")
		PutActorInSet(a, "cr_flat.set")
		PutActorAt(a, 0, 0, 0)
		SetActorRot(a, 0, 0, 0)
		cr_es_ring(0, 0, 0)
		cr_frames(2)
		%fn(a)
		cr_es_ring_off()
		PutActorInSet(a, nil)
	end)
end

-- An actor sees nothing until it has a walker (0x427eb0 tests +0x1a0): SetActorFOV makes one (0x412ff0), and so do
-- SetActorTurnRate, a heading, a line, following the boxes, IsActorResting, IsActorTurning, GetActorYawToPoint, a walk
-- (Actor_CreateWalker 0x425740). (GetActorFOV is nil without a walker: ee_rates.)
cr_es_test("no_walker", function(a)
	cr_es_log("default", a)
	SetActorTurnRate(a, 90)
	cr_es_log("turn_rate", a)
end)

cr_es_test("fov", function(a)
	SetActorFOV(a, 120)
	cr_es_log("fov120", a)
	SetActorFOV(a, 160)
	cr_es_log("fov160", a)
	SetActorFOV(a, 90)
	cr_es_log("fov90", a)
	SetActorFOV(a, 360)
	cr_es_log("fov360", a)
	SetActorFOV(a, 0)
	cr_es_log("fov0", a)
end)

cr_es_test("turned", function(a)
	SetActorFOV(a, 120)
	SetActorRot(a, 0, 90, 0)
	cr_es_ring(0, 0, 90)
	cr_es_log("yaw90", a)
	PutActorAt(a, 1, 0, -2)
	SetActorRot(a, 0, -135, 0)
	cr_es_ring(1, -2, -135)
	cr_es_log("moved", a)
end)

cr_es_test("sets", function(a)
	SetActorFOV(a, 120)
	cr_es_ring(0, 0, 0, "cr_two.set")
	cr_es_log("ring_elsewhere", a)
	cr_es_ring(0, 0, 0)
	MakeCurrentSet("cr_two.set")
	cr_es_log("viewer_not_current", a)
	MakeCurrentSet("cr_flat.set")
	PutActorInSet(a, nil)
	cr_es_log("viewer_out", a)
end)

-- the height does not count
cr_es_test("height", function(a)
	cr_es_ring_off()
	local high = LoadActor("cr_es_high")
	local over = LoadActor("cr_es_over")
	PutActorInSet(high, "cr_flat.set")
	PutActorInSet(over, "cr_flat.set")
	PutActorAt(high, 0.3, 5, 1)
	PutActorAt(over, 0, 3, 0)
	SetActorFOV(a, 120)
	cr_frames(1)
	cr_es_seen("fov120", GetVisibleThings(a), { high, over }, { "high", "over" })
	SetActorFOV(a, 360)
	cr_frames(1)
	cr_es_seen("fov360", GetVisibleThings(a), { high, over }, { "high", "over" })
	PutActorInSet(high, nil)
	PutActorInSet(over, nil)
end)

-- (ScummVM has no walker: an actor sees without one)
cr_scummvm_differs("es_no_walker", "no walker in ScummVM", "emi")
-- (ScummVM before Actor::canSee: only a viewer in the current set saw anything)
cr_scummvm_differs("es_sets", "", "emi")

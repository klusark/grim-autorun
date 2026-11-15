-- The engine core: sets of other layouts (assets_extra_gco.py sets()), sounds placed in a set, the set's lights moved and
-- dimmed by Lua, shrunk sectors that stop being convex, object states with a z-buffer and a missing bitmap, saved and loaded.

gco_pt = function(key, x, y, z)
	local id, name, typ = GetPointSector(x, y, z)
	cr_log(key, id, name, typ)
end

-- a set of only colormaps and setups (no lights, no sectors)
cr_t_gco_set_nolight = function()
	MakeCurrentSet("gco_nolight.set")
	cr_frames(2)
	cr_log("setup", GetCurrentSetup("gco_nolight.set"))
	gco_pt("centre", 0, 0, 0)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_test("gco_set_nolight", cr_t_gco_set_nolight)

-- a set whose sectors section is empty
cr_t_gco_set_nosect = function()
	MakeCurrentSet("gco_nosect.set")
	cr_frames(2)
	cr_log("setup", GetCurrentSetup("gco_nosect.set"))
	gco_pt("centre", 0, 0, 0)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_test("gco_set_nosect", cr_t_gco_set_nosect)

-- an object states section before the setups
cr_t_gco_set_objs = function()
	MakeCurrentSet("gco_objs.set")
	cr_frames(2)
	cr_log("setup", GetCurrentSetup("gco_objs.set"))
	gco_pt("centre", 0, 0, 0)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_test("gco_set_objs", cr_t_gco_set_objs)

-- a funnel sector, a sector without a name, a light without a name
cr_t_gco_set_kinds = function()
	MakeCurrentSet("gco_kinds.set")
	cr_frames(2)
	gco_pt("floor", -1.5, -1.5, 0)
	gco_pt("funnel", 0, 0, 0)
	gco_pt("nameless", 3.5, 0, 0)
	gco_pt("thin", 0, 3.5, 0)
	MakeCurrentSetup(1)
	cr_frames(1)
	cr_log("setup", GetCurrentSetup("gco_kinds.set"))
	MakeCurrentSetup(0)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_scummvm_differs("gco_set_kinds", "the original finds the funnel sector (as id 2) and not the sector without a name; ScummVM reads the nameless sector (sector.cpp:124-129) and gives the floor at the funnel") cr_test("gco_set_kinds", cr_t_gco_set_kinds)

-- the lights of the set dimmed and moved, by number and by name (no getter: the calls only must not fail; the picture of
-- a lit box, as zz_lit.lua's)
cr_t_gco_set_lights = function()
	MakeCurrentSet("gco_kinds.set")
	cr_frames(1)
	SetLightIntensity(0, 0.5)
	SetLightIntensity("gco_spot", 0.25)
	SetLightIntensity(2, "x")
	SetLightPosition(0, 1, 1, 2)
	SetLightPosition("gco_spot", -1, 0, 2)
	SetLightPosition(1, 0, 0)
	cr_frames(2)
	cr_log("done", 1)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_test("gco_set_lights", cr_t_gco_set_lights)

-- the thin floor (4 x 1 m) shrunk by 0.2 (still convex) and by 1 (turned inside out: not convex, left as it was)
cr_t_gco_set_shrink = function()
	MakeCurrentSet("gco_kinds.set")
	cr_frames(1)
	ShrinkBoxes(0.2)
	gco_pt("s02_thin_mid", 0, 3.5, 0)
	gco_pt("s02_thin_end", 1.9, 3.5, 0)
	gco_pt("s02_floor_edge", 1.9, 0, 0)
	ShrinkBoxes(1)
	gco_pt("s1_thin_mid", 0, 3.5, 0)
	gco_pt("s1_thin_end", 1.9, 3.5, 0)
	gco_pt("s1_floor_mid", 0.5, 0, 0)
	gco_pt("s1_floor_edge", 1.5, 0, 0)
	UnShrinkBoxes()
	gco_pt("un_thin_end", 1.9, 3.5, 0)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end
cr_test("gco_set_shrink", cr_t_gco_set_shrink)

-- a sound placed in the set (SetSoundPosition with the least and most volume and the distance): its volume and pan
-- by where it is
GCO_SP_VOL = 1536
GCO_SP_PAN = 1792
gco_sp = function(key, x, y, z, minv, maxv, dist)
	SetSoundPosition("cr_long.wav", x, y, z, minv, maxv, dist)
	cr_frames(1)
	cr_log(key, ImGetParam("cr_long.wav", GCO_SP_VOL), ImGetParam("cr_long.wav", GCO_SP_PAN))
end

cr_t_gco_set_sound_pos = function()
	ImStopAllSounds()
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	ImStartSound("cr_long.wav", 64, 1)
	cr_frames(2)
	cr_log("start", ImGetParam("cr_long.wav", GCO_SP_VOL), ImGetParam("cr_long.wav", GCO_SP_PAN))
	gco_sp("centre", 0, 0, 0, 10, 120, 10)
	gco_sp("right", 2, 0, 0, 10, 120, 10)
	gco_sp("left", -2, 0, 0, 10, 120, 10)
	gco_sp("far", 0, 30, 0, 10, 120, 10)
	gco_sp("far_right", 30, 0, 0, 10, 120, 10)
	gco_sp("camera", 0, -0.5, 6, 10, 120, 10)
	gco_sp("no_dist", 1, 0, 0, 10, 120, 0)
	gco_sp("max_below_min", 1, 0, 0, 100, 20, 10)
	gco_sp("over_127", 1, 0, 0, 200, 300, 10)
	gco_sp("neg_dist", 1, 0, 0, 10, 120, -5)
	-- (by number: the sound's id is not a number the scripts know; a stopped sound)
	ImStopSound("cr_long.wav")
	cr_frames(2)
	gco_sp("stopped", 1, 0, 0, 10, 120, 10)
	ImStopAllSounds()
	cr_frames(2)
end
cr_scummvm_differs("gco_set_sound_pos", "a sound far beyond its distance and one at the camera: the original sets the most volume (and pan 0 at the camera), ScummVM other volumes (set.cpp:1121-1172)") cr_test("gco_set_sound_pos", cr_t_gco_set_sound_pos)

-- a sound placed by an actor (SetSoundPosition(name, actor))
cr_t_gco_set_sound_actor = function()
	ImStopAllSounds()
	local a = cr_actor("cr_flat.set")
	PutActorAt(a, 1.5, 0, 0)
	cr_frames(2)
	ImStartSound("cr_long.wav", 64, 1)
	cr_frames(2)
	SetSoundPosition("cr_long.wav", a)
	cr_frames(1)
	cr_log("by_actor", ImGetParam("cr_long.wav", GCO_SP_VOL), ImGetParam("cr_long.wav", GCO_SP_PAN))
	-- (another set while it plays, then back)
	MakeCurrentSet("cr_edge.set")
	cr_frames(2)
	cr_log("other_set", ImGetParam("cr_long.wav", GCO_SP_VOL), ImGetParam("cr_long.wav", GCO_SP_PAN))
	MakeCurrentSet("cr_flat.set")
	cr_frames(2)
	cr_log("back", ImGetParam("cr_long.wav", GCO_SP_VOL), ImGetParam("cr_long.wav", GCO_SP_PAN))
	ImStopAllSounds()
	PutActorInSet(a, nil)
	cr_frames(2)
end
cr_test("gco_set_sound_actor", cr_t_gco_set_sound_actor)

-- object states: a bitmap that is not there, one of another case than the file's, one compressed with short copies
cr_t_gco_set_states = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	local o = NewObjectState(0, 1, "gco_none.bm", nil, TRUE)
	cr_log("missing", type(o))
	local n = NewObjectState(0, 1, "gco_noise.bm", nil, TRUE)
	cr_log("noise", type(n))
	cr_frames(2)
	cr_snap("noise_snap", "count")
	if n then
		FreeObjectState(n)
	end
	cr_frames(1)
end
cr_scummvm_differs("gco_set_states", "an object state of a bitmap that is not there: the original gives one, ScummVM nil (set.cpp:1248, lua_v1_set.cpp:407)") cr_test("gco_set_states", cr_t_gco_set_states)

-- saved and loaded: shrunk sectors, an object state with a z-buffer of two images (save.lua's cr_t_save_case)
gco_save_test = function(name, setup, look, change, after)
	if not CR_SAVE_CASES then
		CR_SAVE_CASES = { }
	end
	CR_SAVE_CASES["gco_save_" .. name] = { setup = setup, look = look, change = change, after = after }
	if name == "shrunk" then
		cr_scummvm_differs("gco_save_shrunk", "after a load the original has the sectors unshrunk, ScummVM keeps them shrunk (sector.cpp:65-71, 97-104)")
	end
	cr_test("gco_save_" .. name, cr_t_save_case)
end

gco_save_test("shrunk", function()
	MakeCurrentSet("gco_kinds.set")
	ShrinkBoxes(0.2)
end, function()
	local l = { }
	local id, name = GetPointSector(1.9, 3.5, 0)
	l.thin_end = tostring(id) .. " " .. tostring(name)
	id, name = GetPointSector(0, 3.5, 0)
	l.thin_mid = tostring(id) .. " " .. tostring(name)
	return l
end, function()
	UnShrinkBoxes()
end, function()
	UnShrinkBoxes()
	MakeCurrentSet("cr_flat.set")
end)

gco_save_test("zstate", function()
	MakeCurrentSet("cr_flat.set")
	GCO_ZS = NewObjectState(0, 1, "gco_two.bm", "gco_two.zbm", TRUE)
end, function()
	local l = { }
	l.state = type(GCO_ZS)
	return l
end, function()
	SendObjectToBack(GCO_ZS)
end, function()
	if GCO_ZS then
		FreeObjectState(GCO_ZS)
	end
end)

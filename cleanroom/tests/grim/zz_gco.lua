-- The engine core: costume components the other tests do not use (assets_extra_gco.py). Sounds in a costume (imls, imss),
-- a model on a mesh of another model (MODL under MESH, with a mesh, a material and a keyframe of its own), keyframes with
-- priorities and the pause, fade and stop keys, keyframes of other layouts, a bitmap component of a bitmap of two images.
-- Seen through the sound's iMUSE params (sound.lua's CR_IM_*), the chores' state, the nodes' places and cr_snap.

GCO_IM_PLAY = 256
GCO_IM_GROUP = 1024
GCO_IM_PRIO = 1280
GCO_IM_VOL = 1536
GCO_IM_PAN = 1792

gco_im = function(name)
	return tostring(ImGetParam(name, GCO_IM_PLAY)) .. " " .. tostring(ImGetParam(name, GCO_IM_GROUP)) .. " " ..
		tostring(ImGetParam(name, GCO_IM_PRIO)) .. " " .. tostring(ImGetParam(name, GCO_IM_VOL)) .. " " ..
		tostring(ImGetParam(name, GCO_IM_PAN))
end

-- (an actor with costume cos in set, at x, y)
gco_actor = function(cos, set, x, y)
	MakeCurrentSet(set)
	local a = LoadActor("gco_a")
	PutActorInSet(a, set)
	PutActorAt(a, x or 0, y or 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, cos)
	GCO_LV = 0
	cr_frames(2)
	return a
end

gco_done = function(a)
	StopActorChore(a)
	cr_frames(1)
	PutActorInSet(a, nil)
	ImStopAllSounds()
	cr_frames(2)
end

-- (plays chore n of cos and logs, after `frames` frames, whether it plays and the params of the sound)
gco_chore = function(key, a, n, cos, sound, frames)
	PlayActorChore(a, n, cos)
	cr_frames(frames or 3)
	cr_log(key .. "_choring", IsActorChoring(a, n, FALSE, cos))
	if sound then
		cr_log(key .. "_sound", gco_im(sound))
	end
	cr_log(key .. "_lv", GCO_LV)
end

-- a sound component: play, stop, the loop hook off, a key it does not know, the sound with no params
cr_t_gco_cos_sound = function()
	ImStopAllSounds()
	cr_frames(2)
	local a = gco_actor("gco_snd.cos", "cr_flat.set")
	cr_log("before", gco_im("cr_long.wav"))
	gco_chore("play", a, 0, "gco_snd.cos", "cr_long.wav")
	gco_chore("unloop", a, 2, "gco_snd.cos", "cr_long.wav")
	gco_chore("stop", a, 1, "gco_snd.cos", "cr_long.wav")
	gco_chore("tone", a, 3, "gco_snd.cos", "cr_tone.wav")
	gco_chore("bad_key", a, 4, "gco_snd.cos", "cr_tone.wav")
	cr_frames(40)
	cr_log("tone_after", gco_im("cr_tone.wav"))
	gco_done(a)
end
cr_scummvm_differs("gco_cos_sound", "a sound component with parameters: the original plays it at full volume in the middle, ScummVM places it by the actor with its most volume (sound_component.cpp:66-75)") cr_test("gco_cos_sound", cr_t_gco_cos_sound)

-- the sound of an actor to the side of the camera: its pan and volume (the set's sound position)
cr_t_gco_cos_sound_side = function()
	ImStopAllSounds()
	cr_frames(2)
	local a = gco_actor("gco_snd.cos", "cr_flat.set", 1.8, 0)
	gco_chore("right", a, 0, "gco_snd.cos", "cr_long.wav")
	PlayActorChore(a, 1, "gco_snd.cos")
	cr_frames(2)
	PutActorAt(a, -1.8, 1.5, 0)
	cr_frames(1)
	gco_chore("left", a, 0, "gco_snd.cos", "cr_long.wav")
	gco_done(a)
end
cr_scummvm_differs("gco_cos_sound_side", "a sound component with parameters: the original plays it at full volume in the middle, ScummVM places it by the actor with its most volume (sound_component.cpp:66-75)") cr_test("gco_cos_sound_side", cr_t_gco_cos_sound_side)

-- a chore of 300 ms that starts the sound: does the sound go on when the chore ends, and when the costume goes?
cr_t_gco_cos_sound_end = function()
	ImStopAllSounds()
	cr_frames(2)
	local a = gco_actor("gco_snd.cos", "cr_flat.set")
	gco_chore("start", a, 5, "gco_snd.cos", "cr_long.wav", 2)
	cr_frames(30)
	cr_log("chore_done", IsActorChoring(a, 5, FALSE, "gco_snd.cos"), GCO_LV)
	cr_log("sound_after_chore", gco_im("cr_long.wav"))
	PlayActorChore(a, 0, "gco_snd.cos")
	cr_frames(3)
	SetActorCostume(a, "cr_box.cos")
	cr_frames(3)
	cr_log("sound_after_costume", gco_im("cr_long.wav"))
	gco_done(a)
end
cr_scummvm_differs("gco_cos_sound_end", "a sound component with parameters: the original plays it at full volume in the middle, ScummVM places it by the actor with its most volume (sound_component.cpp:66-75)") cr_test("gco_cos_sound_end", cr_t_gco_cos_sound_end)

-- the streamed sound component (imss)
cr_t_gco_cos_stream = function()
	ImStopAllSounds()
	cr_frames(2)
	local a = gco_actor("gco_stream.cos", "cr_flat.set")
	cr_log("costume", GetActorCostume(a))
	gco_chore("play", a, 0, "gco_stream.cos", "cr_long.wav")
	gco_chore("stop", a, 1, "gco_stream.cos", "cr_long.wav")
	gco_done(a)
end
cr_scummvm_differs("gco_cos_stream") cr_test("gco_cos_stream", cr_t_gco_cos_stream)

-- a model on the left mesh of cr_two.3do (gco_att.cos): the node places and the pictures with the mesh and the hat shown
-- and hidden
gco_att_nodes = function(key, a)
	local i = 0
	while i < 3 do
		local x, y, z = GetActorNodeLocation(a, i)
		cr_log(key .. "_node" .. i, x, y, z)
		i = i + 1
	end
end

cr_t_gco_att = function()
	local a = gco_actor("gco_att.cos", "cr_open.set")
	cr_log("costume", GetActorCostume(a))
	gco_att_nodes("rest", a)
	cr_snap("rest_snap")
	gco_chore("left_off", a, 0, "gco_att.cos")
	cr_snap("left_off_snap")
	gco_chore("hat_off", a, 2, "gco_att.cos")
	cr_snap("both_off_snap")
	gco_chore("left_on", a, 1, "gco_att.cos")
	cr_snap("hat_off_snap")
	gco_chore("hat_on", a, 3, "gco_att.cos")
	cr_snap("hat_on_snap")
	gco_chore("hat_mesh_off", a, 6, "gco_att.cos")
	cr_snap("hat_mesh_off_snap")
	gco_done(a)
end
cr_scummvm_differs("gco_att", "a mesh component of the model on a mesh: ScummVM hides that mesh, the original does not (mesh_component.cpp:39-44, 61); the boxes a pixel apart (as draw.lua's)") cr_test("gco_att", cr_t_gco_att)

-- the main model hidden by a chore of 200 ms, then the chore ends (reset); the keyframe on the hat
cr_t_gco_att_chores = function()
	local a = gco_actor("gco_att.cos", "cr_open.set")
	gco_chore("main_off", a, 4, "gco_att.cos", nil, 2)
	cr_snap("main_off_snap")
	cr_frames(20)
	cr_log("main_after", IsActorChoring(a, 4, FALSE, "gco_att.cos"), GCO_LV)
	cr_snap("main_after_snap")
	PlayActorChore(a, 5, "gco_att.cos")
	cr_frames(15)
	gco_att_nodes("hat_slide", a)
	cr_snap("hat_slide_snap")
	cr_frames(20)
	cr_log("hat_slide_done", IsActorChoring(a, 5, FALSE, "gco_att.cos"))
	-- (another costume in the place of this one: the hat comes off its parent)
	SetActorCostume(a, "cr_dbox.cos")
	cr_frames(2)
	cr_log("swapped", GetActorCostume(a))
	gco_done(a)
end
cr_scummvm_differs("gco_att_chores") cr_test("gco_att_chores", cr_t_gco_att_chores)

-- keyframes: the nodes of the drawn box (the body node 1, the head 2) under each chore of gco_kf.cos
gco_kf_nodes = function(key, a)
	local x, y, z = GetActorNodeLocation(a, 1)
	cr_log(key .. "_body", x, y, z)
end

gco_kf_run = function(key, a, chores, step, n)
	local i = 1
	while chores[i] do
		PlayActorChore(a, chores[i], "gco_kfa.cos")
		i = i + 1
	end
	i = 0
	while i < n do
		cr_frames(step)
		gco_kf_nodes(key .. "_" .. (i + 1) * step, a)
		i = i + 1
	end
end

gco_kf_test = function(name, fn)
	if name ~= "bad_key" then
		cr_scummvm_differs("gco_kf_" .. name, "the original's GetActorNodeLocation does not follow keyframes (as keyframe.lua's kf_*)")
	end
	cr_test("gco_kf_" .. name, function()
		local a = gco_actor("gco_kfa.cos", "cr_open.set", -1, 0)
		cr_log(%name .. "_costume", GetActorCostume(a))
		%fn(%name, a)
		PlayActorChore(a, 15, "gco_kfa.cos")
		cr_frames(2)
		gco_done(a)
	end)
end

-- two keyframes at one priority (their weights shared), two at different ones (the higher wins)
gco_kf_test("same_priority", function(k, a)
	gco_kf_run(k, a, { 1 }, 10, 3)
end)
gco_kf_test("other_priority", function(k, a)
	gco_kf_run(k, a, { 2 }, 10, 3)
end)

-- pause and unpause
gco_kf_test("pause", function(k, a)
	gco_kf_run(k, a, { 0 }, 10, 1)
	PlayActorChore(a, 3, "gco_kfa.cos")
	cr_frames(2)
	gco_kf_nodes(k .. "_paused", a)
	cr_frames(15)
	gco_kf_nodes(k .. "_paused_later", a)
	PlayActorChore(a, 4, "gco_kfa.cos")
	cr_frames(15)
	gco_kf_nodes(k .. "_unpaused", a)
end)

-- the fades in (1, 0.5, 0.25, 0.125 s) of a keyframe that does not play, and the fades out of one that plays
local gco_i = 0
while gco_i < 4 do
	gco_kf_test("fade_in_" .. gco_i, function(k, a)
		gco_kf_run(k, a, { 5 + %gco_i }, 5, 4)
	end)
	gco_kf_test("fade_out_" .. gco_i, function(k, a)
		gco_kf_run(k, a, { 0 }, 10, 1)
		gco_kf_run(k, a, { 9 + %gco_i }, 5, 4)
	end)
	gco_i = gco_i + 1
end

-- a key the component does not know
gco_kf_test("bad_key", function(k, a)
	gco_kf_run(k, a, { 13 }, 5, 1)
end)

-- a keyframe without markers, one with fewer joints than the model (its first record without a name, the second twice),
-- one with a joint number past its count
gco_kf_test("nomark", function(k, a)
	gco_kf_run(k, a, { 14 }, 10, 3)
	cr_log(k .. "_choring", IsActorChoring(a, 14, FALSE, "gco_kfa.cos"))
end)

-- (the binary keyframes of other layouts, each alone in a costume: gco_kfs.cos, gco_kfb.cos)
gco_kf_alone = function(k, cos)
	local a = gco_actor(cos, "cr_open.set", -1, 0)
	cr_log(k .. "_costume", GetActorCostume(a))
	PlayActorChore(a, 0, cos)
	local i = 0
	while i < 3 do
		cr_frames(10)
		gco_kf_nodes(k .. "_" .. (i + 1) * 10, a)
		i = i + 1
	end
	gco_done(a)
end
cr_scummvm_differs("gco_kf_alone_x", "the original's GetActorNodeLocation does not follow keyframes (as keyframe.lua's kf_*)") cr_test("gco_kf_alone_x", function() gco_kf_alone("x", "gco_kfx.cos") end)
cr_scummvm_differs("gco_kf_alone_y", "the original's GetActorNodeLocation does not follow keyframes (as keyframe.lua's kf_*)") cr_test("gco_kf_alone_y", function() gco_kf_alone("y", "gco_kfy.cos") end)
-- (gco_kf_short, gco_kfs.cos: a keyframe with fewer joints than the model and a joint number used twice, and gco_kf_badj,
-- gco_kfb.cos: a joint number past the joint count, are not run: in the whole run they corrupt the original's heap, and
-- later tests crash at Lua.dll+0x93A2 reading text as a pointer (0x5F6F636B), a different test each run. Found 2026-11-10
-- by full runs with these two left out: the crashes went. ScummVM loads both costumes.)

-- the parts of gco_att.cos one by one (which ones the costume loads with)
cr_t_gco_att_parts = function()
	MakeCurrentSet("cr_open.set")
	local a = LoadActor("gco_a")
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, 0, 0, 0)
	local p = { "a", "b", "c", "d", "e", "f" }
	local i = 1
	while p[i] do
		SetActorCostume(a, "gco_att" .. p[i] .. ".cos")
		cr_frames(1)
		cr_log(p[i], GetActorCostume(a))
		SetActorCostume(a, nil)
		i = i + 1
	end
	PutActorInSet(a, nil)
end
cr_scummvm_differs("gco_att_parts", "a colormap component without a parent: the original does not load the costume, ScummVM only warns (colormap_component.cpp:39-41)") cr_test("gco_att_parts", cr_t_gco_att_parts)

-- a bitmap component of a bitmap of two images (gco_two.bm with gco_two.zbm): image 1, image 2, hidden; a bitmap
-- component of a bitmap no object state has
cr_t_gco_cos_bitmap = function()
	local a = gco_actor("gco_bmp.cos", "cr_flat.set")
	cr_log("costume", GetActorCostume(a))
	local o = NewObjectState(0, 1, "gco_two.bm", "gco_two.zbm", TRUE)
	cr_log("state", type(o))
	cr_frames(2)
	cr_snap("state_snap", "count")
	gco_chore("image1", a, 0, "gco_bmp.cos")
	cr_snap("image1_snap", "count")
	gco_chore("image2", a, 1, "gco_bmp.cos")
	cr_snap("image2_snap", "count")
	gco_chore("hide", a, 2, "gco_bmp.cos")
	cr_snap("hide_snap", "count")
	if o then
		FreeObjectState(o)
	end
	gco_done(a)
	a = gco_actor("gco_bmpx.cos", "cr_flat.set")
	cr_log("missing_costume", GetActorCostume(a))
	gco_chore("missing", a, 0, "gco_bmpx.cos")
	gco_done(a)
end
cr_scummvm_differs("gco_cos_bitmap", "a bitmap component of a file that is not there: the original does not load the costume, ScummVM does (bitmap_component.cpp:46 only warns)") cr_test("gco_cos_bitmap", cr_t_gco_cos_bitmap)

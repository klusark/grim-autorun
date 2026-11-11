-- EMI's models and costumes (assets_emi_extra_emd.py): the animation component (its keys: play, stop, pause, loop, no
-- loop, the fades; animations blended on one joint, priorities, keys that end before the animation, a joint the skeleton
-- lacks), the texture component (texi: the texture of a .sur), the Lua code component (luac), the tracks ScummVM skips,
-- two wear chores on two skeletons, a costume worn on top of another, the head, a set with every kind of light, the
-- layers (NewLayer) and a save with all of it. The original's EMI gives no picture in the clean room: what is seen is
-- EMD_LV (the costumes' Lua Variable tracks), the chore builtins and a rider attached to a joint of the skeleton
-- (GetActorWorldPos follows the joint).

-- (an actor in cr_flat.set wearing emd_anim.cos, and a rider 0.5 m to its right at the joint emd_body)
emd_pair = function(joint)
	MakeCurrentSet("cr_flat.set")
	EMD_LV = 0
	local a = LoadActor("emd_carrier")
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	EMD_W = PlayActorChore(a, "wear", "emd_anim.cos")
	local r = LoadActor("emd_rider")
	PutActorInSet(r, "cr_flat.set")
	PutActorAt(r, 0.5, 0, 0)
	SetActorRot(r, 0, 0, 0)
	cr_frames(2)
	AttachActor(r, a, joint or "emd_body")
	cr_frames(1)
	return a, r
end

emd_done = function(a, r)
	EMD_POS = nil
	if r then
		DetachActor(r)
		PutActorInSet(r, nil)
	end
	StopActorChores(a)
	PutActorInSet(a, nil)
	cr_frames(1)
end

-- (the rider's world position, in the tests that set EMD_POS: on the original the rider does not follow what an
-- animation does to its joint, on ScummVM it does; elsewhere "-")
emd_wp = function(r)
	if not EMD_POS then
		return "-"
	end
	local x, y, z = GetActorWorldPos(r)
	if not z then
		return tostring(x) .. " " .. tostring(y) .. " " .. tostring(z)
	end
	return format("%.3f %.3f %.3f", x, y, z)
end

-- (the rider's position every step frames, n times, and EMD_LV and whether chore c plays)
emd_trace = function(r, c, n, step)
	local s = ""
	local i = 0
	while i < n do
		s = s .. emd_wp(r) .. "/" .. tostring(EMD_LV) .. "/" .. tostring(IsChorePlaying(c)) .. "; "
		-- (a line in the log now and then, so that a long trace does not look like a hang)
		PrintDebug("emd trace\n")
		cr_frames(step)
		i = i + 1
	end
	return s
end

-- one translation of emd_body (1 m up in 1 s) in a chore of 1.5 s: the animation ends before its chore
cr_scummvm_differs("emd_up", "the rider attached to emd_body follows the animated joint on ScummVM (Actor::getFinalMatrix, actor.cpp:2372, uses the joint's _finalMatrix), not on the original") cr_test("emd_up", function()
	EMD_POS = 1
	local a, r = emd_pair()
	cr_log("rest", emd_wp(r))
	local c = PlayActorChore(a, "up", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 11, 10))
	cr_log("after", emd_wp(r), IsChorePlaying(c), IsChorePlaying(EMD_W))
	-- (played again: the animation already has its skeleton)
	c = PlayActorChore(a, "up", "emd_anim.cos")
	cr_frames(30)
	cr_log("again", emd_wp(r), IsChorePlaying(c))
	emd_done(a, r)
end)

-- two translations of emd_body at the same priority (their weights add up to 2), then two rotations of emd_root
cr_scummvm_differs("emd_blend", "the rider attached to emd_body follows the animated joint on ScummVM (Actor::getFinalMatrix, actor.cpp:2372, uses the joint's _finalMatrix), not on the original") cr_test("emd_blend", function()
	EMD_POS = 1
	local a, r = emd_pair()
	local c = PlayActorChore(a, "up", "emd_anim.cos")
	PlayActorChore(a, "side", "emd_anim.cos")
	cr_log("trans", emd_trace(r, c, 6, 10))
	cr_frames(40)
	c = PlayActorChore(a, "turn", "emd_anim.cos")
	PlayActorChore(a, "tilt", "emd_anim.cos")
	cr_log("rot", emd_trace(r, c, 6, 10))
	cr_frames(40)
	c = PlayActorChore(a, "turn", "emd_anim.cos")
	cr_log("turn_alone", emd_trace(r, c, 4, 15))
	emd_done(a, r)
end)

-- a rotation and a translation of emd_body at priority 3 over the translation of "up" at priority 1
cr_scummvm_differs("emd_priority", "the rider attached to emd_body follows the animated joint on ScummVM (Actor::getFinalMatrix, actor.cpp:2372, uses the joint's _finalMatrix), not on the original") cr_test("emd_priority", function()
	EMD_POS = 1
	local a, r = emd_pair()
	local c = PlayActorChore(a, "hi", "emd_anim.cos")
	PlayActorChore(a, "up", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 6, 10))
	emd_done(a, r)
end)

-- an animation of 2 s whose keys end at 1 s, and one with a joint the skeleton lacks
cr_scummvm_differs("emd_hold", "the rider attached to emd_body follows the animated joint on ScummVM (Actor::getFinalMatrix, actor.cpp:2372, uses the joint's _finalMatrix), not on the original") cr_test("emd_hold", function()
	EMD_POS = 1
	local a, r = emd_pair()
	local c = PlayActorChore(a, "hold", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 8, 15))
	cr_frames(30)
	c = PlayActorChore(a, "ghost", "emd_anim.cos")
	cr_log("ghost", emd_trace(r, c, 6, 10))
	emd_done(a, r)
end)

-- the loop key (3) and, at 2.2 s, no loop (4) in a chore of 3 s
cr_test("emd_loopkey", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "loopkey", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 12, 15))
	emd_done(a, r)
end)

-- the chore "up" (1.5 s) played looping (PlayActorChore's fourth argument): past its end it starts again
cr_test("emd_chore_loop", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "up", "emd_anim.cos", 1)
	cr_log("trace", emd_trace(r, c, 12, 15))
	cr_log("looping", IsChoreLooping(c))
	emd_done(a, r)
end)

-- play, pause at 0.3 s, play at 0.6, stop at 1.0, play at 1.2; then play and pause at the same time
cr_test("emd_pausekey", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "pausekey", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 14, 9))
	cr_frames(20)
	c = PlayActorChore(a, "frozen", "emd_anim.cos")
	cr_log("frozen", emd_trace(r, c, 4, 10))
	emd_done(a, r)
end)

-- the fade keys: in over 1 s; in over 3/4, 1/2, 1/4, 1/8 s
cr_test("emd_fadein", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "fadein1", "emd_anim.cos")
	cr_log("in1", emd_trace(r, c, 10, 10))
	cr_frames(10)
	c = PlayActorChore(a, "fadeins", "emd_anim.cos")
	cr_log("ins", emd_trace(r, c, 13, 10))
	emd_done(a, r)
end)

-- out over 1 s (looping); out over 3/4, 1/2, 1/4, 1/8 s, each played again; out and played again when it has ended
cr_test("emd_fadeout", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "fadeout1", "emd_anim.cos")
	cr_log("out1", emd_trace(r, c, 12, 10))
	cr_frames(10)
	c = PlayActorChore(a, "fadeouts", "emd_anim.cos")
	cr_log("outs", emd_trace(r, c, 18, 10))
	cr_frames(10)
	c = PlayActorChore(a, "replay", "emd_anim.cos")
	cr_log("replay", emd_trace(r, c, 12, 10))
	emd_done(a, r)
end)

-- a key the animation component does not know (15)
cr_test("emd_badkey", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "badkey", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 7, 10))
	emd_done(a, r)
end)

-- the chore's own fades: PlayActorChore with a fade time (in), StopChore with one (out); PauseChore, PlayChore and
-- AdvanceChore
cr_scummvm_differs("emd_chore_fade", "AdvanceChore of a chore that has ended plays it again on ScummVM (lua_v2_actor.cpp:384), not on the original") cr_test("emd_chore_fade", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "up", "emd_anim.cos", nil, 0.5)
	cr_log("fade_in", emd_trace(r, c, 5, 6))
	StopChore(c, 0.3)
	cr_log("fade_out", emd_trace(r, c, 5, 6))
	cr_frames(30)
	c = PlayActorChore(a, "up", "emd_anim.cos")
	cr_frames(10)
	PauseChore(c)
	cr_log("paused", emd_trace(r, c, 3, 10))
	PlayChore(c)
	cr_log("unpaused", emd_trace(r, c, 2, 10))
	AdvanceChore(c, 0.4)
	cr_frames(1)
	cr_log("advanced", emd_wp(r), IsChorePlaying(c))
	cr_frames(60)
	-- (a chore that has ended, advanced)
	AdvanceChore(c, 0.2)
	cr_frames(1)
	cr_log("advanced_stopped", emd_wp(r), IsChorePlaying(c))
	cr_frames(60)
	emd_done(a, r)
end)

-- an animation track of a file that is not there
cr_test("emd_noanim", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "noanim", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 4, 10))
	emd_done(a, r)
end)

-- the texi track: the textures 0, 1, 2 of emd_eyes.sur, then 5 and 3 (it has three), then 1; a texi of a material the
-- actor has not loaded
cr_test("emd_texi", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "eyes", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 8, 5))
	cr_log("after", EMD_LV, IsChorePlaying(c))
	emd_done(a, r)
	-- (again where the box is seen, so that its faces are drawn with the texture of the moment)
	MakeCurrentSet("emd_lights.set")
	a = LoadActor("emd_eyed")
	PutActorInSet(a, "emd_lights.set")
	PutActorAt(a, 0, 0, 0)
	PlayActorChore(a, "wear", "emd_anim.cos")
	c = PlayActorChore(a, "eyes", "emd_anim.cos")
	cr_frames(40)
	cr_log("seen", EMD_LV, IsChorePlaying(c))
	emd_done(a)
	MakeCurrentSet("cr_flat.set")
end)

-- the Lua code track (luac): its name is run as code at each key
cr_test("emd_luac", function()
	local a, r = emd_pair()
	EMD_LC = 0
	EMD_LS = nil
	local c = PlayActorChore(a, "code", "emd_anim.cos")
	local s = ""
	local i = 0
	while i < 30 do
		s = s .. tostring(EMD_LC) .. " "
		break_here()
		i = i + 1
	end
	cr_log("trace", s)
	cr_log("after", EMD_LC, EMD_LS, IsChorePlaying(c))
	emd_done(a, r)
end)

-- the tracks shad and awgt, each between two Lua Variable keys (a snd2 track, "!snd2emd.snd", hangs Monkey4.exe: left out)
cr_test("emd_skip_shad", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "skip_shad", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 6, 5))
	emd_done(a, r)
end)

cr_test("emd_skip_awgt", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "skip_awgt", "emd_anim.cos")
	cr_log("trace", emd_trace(r, c, 6, 5))
	emd_done(a, r)
end)


-- a second wear chore on the other skeleton (emd_tall, its body 1.5 m up) while an animation plays; the first worn again,
-- looping; the wear chore stopped while another chore of the costume plays
cr_test("emd_wear2", function()
	local a, r = emd_pair()
	local c = PlayActorChore(a, "loopkey", "emd_anim.cos")
	cr_frames(20)
	cr_log("first", emd_wp(r))
	local t = PlayActorChore(a, "wear_tall", "emd_anim.cos")
	cr_frames(20)
	cr_log("tall", emd_wp(r), IsChorePlaying(t), IsChorePlaying(EMD_W))
	local w = PlayActorChore(a, "wear", "emd_anim.cos", 1)
	cr_frames(20)
	cr_log("back", emd_wp(r), IsChoreLooping(w), IsChorePlaying(c))
	StopChore(c)
	local i = PlayActorChore(a, "idle", "emd_anim.cos")
	StopChore(w)
	StopChore(t)
	cr_frames(5)
	cr_log("stopped", emd_wp(r), IsChorePlaying(w), IsChorePlaying(i), EMD_LV)
	emd_done(a, r)
end)

-- a costume worn over emd_anim.cos (its tracks without a parent take the first costume's first component)
cr_test("emd_over", function()
	local a, r = emd_pair()
	local o = PlayActorChore(a, "over", "emd_over.cos")
	cr_log("trace", emd_trace(r, o, 5, 5))
	local o2 = PlayActorChore(a, "over2", "emd_over.cos")
	cr_frames(2)
	local t = GetActorChores(a)
	cr_log("chores", type(t), t and t.count, EMD_LV, IsChorePlaying(o2))
	emd_done(a, r)
end)

-- two meshes, the second a child of the first; a mesh file that is not there (in a set where the box is seen, lit by one
-- omni light and no ambient one)
cr_test("emd_meshes", function()
	MakeCurrentSet("emd_dark.set")
	EMD_LV = 0
	local a = LoadActor("emd_twin")
	PutActorInSet(a, "emd_dark.set")
	PutActorAt(a, 0, 0, 0)
	local c = PlayActorChore(a, "wear", "emd_twin.cos")
	cr_frames(20)
	cr_log("twin", EMD_LV, IsChorePlaying(c))
	StopActorChores(a)
	cr_frames(1)
	c = PlayActorChore(a, "wear", "emd_nomesh.cos")
	cr_frames(20)
	cr_log("nomesh", EMD_LV, IsChorePlaying(c))
	emd_done(a)
	MakeCurrentSet("cr_flat.set")
end)

-- the head on emd_head with a rider at its side: looking straight up, straight down, behind, to the side, back; a head on
-- a joint the skeleton lacks
cr_test("emd_head", function()
	local a, r = emd_pair("emd_head")
	SetActorHead(a, "emd_head", 0, 0, 0)
	SetActorHeadLimits(a, 180, 80, 80)
	SetActorLookRate(a, 360)
	ActorLookAt(a, 0, 10, 0)
	cr_frames(30)
	cr_log("up", emd_wp(r))
	ActorLookAt(a, 0, -10, 0)
	cr_frames(30)
	cr_log("down", emd_wp(r))
	ActorLookAt(a, 0, 1.4, -5)
	cr_frames(30)
	cr_log("behind", emd_wp(r))
	ActorLookAt(a, 5, 1.4, 0.5)
	cr_frames(30)
	cr_log("side", emd_wp(r))
	ActorLookAt(a, -5, 1.4, 0.5)
	cr_frames(30)
	cr_log("other_side", emd_wp(r))
	ActorLookAt(a, 3, -2, -3)
	cr_frames(30)
	cr_log("behind_low", emd_wp(r))
	ActorLookAt(a, -3, 4, -3)
	cr_frames(30)
	cr_log("behind_high", emd_wp(r))
	ActorLookAt(a, 0.2, 1.4, 5)
	cr_frames(30)
	cr_log("front", emd_wp(r))
	ActorLookAt(a, nil)
	cr_frames(30)
	cr_log("none", emd_wp(r))
	SetActorHead(a, "emd_nojoint", 0, 0, 0)
	ActorLookAt(a, 2, 1, 2)
	cr_frames(10)
	cr_log("nojoint", emd_wp(r))
	ActorLookAt(a, nil)
	cr_frames(2)
	emd_done(a, r)
end)

-- the box in a set with every kind of light (emd_lights.set), in each light mode (SetActorLighting 0 static, 1 fast, 2
-- normal, 3 none), moving
cr_test("emd_lights", function()
	MakeCurrentSet("emd_lights.set")
	EMD_LV = 0
	local a = LoadActor("emd_lit")
	PutActorInSet(a, "emd_lights.set")
	PutActorAt(a, 0, 0, 0)
	local w = PlayActorChore(a, "wear", "emd_anim.cos")
	cr_frames(3)
	local m = 0
	while m < 4 do
		SetActorLighting(a, m)
		cr_frames(2)
		PutActorAt(a, 0.5, 0, 0.5)
		cr_frames(2)
		PutActorAt(a, 2.8, 0.5, 2.8)
		cr_frames(2)
		PutActorAt(a, 0, 0, 0)
		m = m + 1
	end
	SetActorLighting(a, 1)
	cr_log("lit", EMD_LV, IsChorePlaying(w))
	StopActorChores(a)
	PutActorInSet(a, nil)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
end)

-- a layer of three frames (emd_layers.til): frames set, past the end, advanced past the end; its sort order; freed
cr_test("emd_layer", function()
	MakeCurrentSet("cr_flat.set")
	local l = NewLayer("emd_layers.til", 3, 0)
	cr_log("type", type(l))
	cr_frames(1)
	SetLayerFrame(l, 2)
	cr_frames(1)
	SetLayerFrame(l, 3)
	SetLayerFrame(l, -1)
	cr_frames(1)
	AdvanceLayerFrame(l, 2)
	cr_frames(1)
	SetLayerSortOrder(l, 20)
	local l2 = NewLayer("emd_layers.til", 1, 0)
	cr_frames(1)
	SetLayerSortOrder(l2, 30)
	cr_frames(1)
	FreeLayer(l2)
	FreeLayer(l)
	cr_frames(1)
	cr_log("ok", 1)
end)

-- the frames and sort order that GetLayerFrame and GetLayerSortOrder give (ScummVM has neither)
cr_scummvm_differs("emd_layer_get", "ScummVM has no GetLayerFrame or GetLayerSortOrder")
cr_test("emd_layer_get", function()
	MakeCurrentSet("cr_flat.set")
	local l = NewLayer("emd_layers.til", 3, 0)
	if not GetLayerFrame then
		cr_log("missing", 1)
		FreeLayer(l)
		return
	end
	SetLayerFrame(l, 2)
	cr_log("set_2", GetLayerFrame(l))
	SetLayerFrame(l, 3)
	cr_log("set_3", GetLayerFrame(l))
	SetLayerFrame(l, -1)
	cr_log("set_minus", GetLayerFrame(l))
	AdvanceLayerFrame(l, 2)
	cr_log("advanced_2", GetLayerFrame(l))
	AdvanceLayerFrame(l, 1)
	cr_log("advanced_1", GetLayerFrame(l))
	SetLayerSortOrder(l, 20)
	cr_log("sort", GetLayerSortOrder(l))
	FreeLayer(l)
end)

-- a save with an animation fading in and a chore fading out, the head looking at a point, and Load (the test
-- runs on after the Save twice: after the save and after the Load; JustLoaded tells them apart)
cr_t_emd_save = function()
	MakeCurrentSet("cr_flat.set")
	EMD_LV = 0
	EMD_SA = LoadActor("emd_saver")
	PutActorInSet(EMD_SA, "cr_flat.set")
	PutActorAt(EMD_SA, 0, 0, 0)
	SetActorRot(EMD_SA, 0, 0, 0)
	EMD_SW = PlayActorChore(EMD_SA, "wear", "emd_anim.cos")
	EMD_SO = PlayActorChore(EMD_SA, "over", "emd_over.cos")
	EMD_SR = LoadActor("emd_srider")
	PutActorInSet(EMD_SR, "cr_flat.set")
	PutActorAt(EMD_SR, 0.5, 0, 0)
	cr_frames(2)
	AttachActor(EMD_SR, EMD_SA, "emd_body")
	EMD_SC = PlayActorChore(EMD_SA, "loopkey", "emd_anim.cos", nil, 0.5)
	EMD_SI = PlayActorChore(EMD_SA, "idle", "emd_anim.cos")
	SetActorHead(EMD_SA, "emd_head", 0, 0, 0)
	ActorLookAt(EMD_SA, 2, 1, 2)
	cr_frames(10)
	StopChore(EMD_SI, 0.4)
	cr_frames(2)
	cr_log("just_loaded_before", JustLoaded())
	EMD_SVERSION = system.version
	system.version = "cr 1.0"
	EMD_SPOS = emd_wp(EMD_SR)
	Save("cremd_save.gsv")
	cr_frames(3)
	if not JustLoaded() then
		StopChore(EMD_SC)
		cr_frames(30)
		Load("cremd_save.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		cr_log("pass", "loaded")
		cr_log("chores", IsChorePlaying(EMD_SW), IsChorePlaying(EMD_SC), IsChorePlaying(EMD_SO), IsChorePlaying(EMD_SI))
		cr_log("trace", emd_trace(EMD_SR, EMD_SC, 5, 10))
	end
	system.version = EMD_SVERSION
	ActorLookAt(EMD_SA, nil)
	DetachActor(EMD_SR)
	PutActorInSet(EMD_SR, nil)
	StopActorChores(EMD_SA)
	PutActorInSet(EMD_SA, nil)
	cr_frames(1)
end
cr_test("emd_save", cr_t_emd_save)

-- a save with a layer (freed before the Load: the Load makes it again)
cr_t_emd_save_layer = function()
	MakeCurrentSet("cr_flat.set")
	EMD_SL = NewLayer("emd_layers.til", 4, 0)
	SetLayerFrame(EMD_SL, 1)
	cr_frames(2)
	EMD_SVERSION = system.version
	system.version = "cr 1.0"
	Save("cremd_layer.gsv")
	cr_frames(3)
	if not JustLoaded() then
		FreeLayer(EMD_SL)
		cr_frames(2)
		Load("cremd_layer.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		cr_log("pass", "loaded")
		SetLayerFrame(EMD_SL, 2)
		AdvanceLayerFrame(EMD_SL, 1)
		cr_frames(1)
		FreeLayer(EMD_SL)
	end
	system.version = EMD_SVERSION
	cr_frames(1)
end
cr_scummvm_differs("emd_save_layer", "the software renderer crashes after the Load: TinyGL blits the bitmap of the layer freed before it (crossBlit from tglBlitOpaque in presentBufferDirtyRects)") cr_test("emd_save_layer", cr_t_emd_save_layer)

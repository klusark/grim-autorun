-- Saving and loading actors (Actor::saveState / restoreState): an actor that talks when the game is saved (with a lip
-- sync file and without one), shadow planes (of the current set and of another one), a stack of three costumes with a
-- chore playing on the one at the bottom. As save.lua's cr_save_test: setup() makes the state, look() returns what can be
-- seen of it ({ key = string }), change() changes it after the save, Load brings the save back and "kept_<key>" is 1
-- when the loaded value is the saved one; after() looks on from there and cleans up. The registry (not in a save) tells
-- the two passes apart. (The functions are globals and the test one function without upvalues: the original's Load
-- crashed in Lua.dll when the task that saved ran a closure with upvalues.)

ASV_CASES = { }
asv_save_test = function(name, setup, look, change, after)
	ASV_CASES["asv_" .. name] = { setup = setup, look = look, change = change, after = after }
	cr_test("asv_" .. name, cr_t_asv_case)
end

cr_t_asv_case = function()
	local c = ASV_CASES[CR_CUR]
	local file = "cr" .. CR_CUR .. ".gsv"
	cr_save_clean()
	c.setup()
	cr_frames(2)
	ASV_LOOK = c.look()
	WriteRegistryValue("CrSavePass", "saving")
	cr_save(file)
	-- (here twice: after the save, and after the Load)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		c.change()
		cr_frames(2)
		local after = c.look()
		cr_log("changed", cr_save_diff(ASV_LOOK, after))
		-- (the changed values, to see what change() did)
		local ks = cr_keys(ASV_LOOK)
		local j = 1
		while ks[j] do
			local k = ks[j]
			local v = ASV_LOOK[k]
			if after[k] ~= v then
				cr_log("now_" .. k, after[k])
			end
			j = j + 1
		end
		Load(file)
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		cr_log("pass", ReadRegistryValue("CrSavePass"))
		WriteRegistryValue("CrSavePass", "done")
		cr_frames(1)
		local now = c.look()
		local ks = cr_keys(ASV_LOOK)
		local j = 1
		while ks[j] do
			local k = ks[j]
			local v = ASV_LOOK[k]
			if now[k] == v then
				cr_log("kept_" .. k, 1)
			else
				cr_log("kept_" .. k, v, now[k])
			end
			j = j + 1
		end
		c.after()
	end
end

-- (what is seen of a talking actor)
asv_talk_look = function()
	local l = { }
	l.lv = tostring(CR_LV)
	l.going = tostring(IsMessageGoing())
	l.actor_going = tostring(IsMessageGoing(ASV_A))
	l.pos = cr_s(GetActorPos(ASV_A))
	return l
end

asv_talk_change = function()
	ShutUpActor(ASV_A)
	PutActorAt(ASV_A, 0.5, 0.5, 0)
end

-- (after the load: still talking a few frames on? then shut up)
asv_talk_after = function()
	cr_frames(3)
	cr_log("after_3", CR_LV, IsMessageGoing(), IsMessageGoing(ASV_A))
	ShutUpActor(ASV_A)
	cr_frames(2)
	cr_log("shut_up", CR_LV, IsMessageGoing(), IsMessageGoing(ASV_A))
	PutActorInSet(ASV_A, nil)
	ExpireText()
	cr_frames(1)
end

-- an actor saying a line with a voice and a lip sync file (crtv01: the first phoneme is shape 2)
asv_save_test("talk_lip", function()
	ASV_A = cr_talker()
	SayLine(ASV_A, "/crtv01/", { x = 100, y = 100 })
end, asv_talk_look, asv_talk_change, asv_talk_after)

-- a voice without a lip sync file (crtv02: the mumble)
asv_save_test("talk_mumble", function()
	ASV_A = cr_talker()
	SayLine(ASV_A, "/crtv02/", { x = 100, y = 100 })
end, asv_talk_look, asv_talk_change, asv_talk_after)

-- a lip sync file without a voice (crtv03)
asv_save_test("talk_no_voice", function()
	ASV_A = cr_talker()
	SayLine(ASV_A, "/crtv03/", { x = 100, y = 100 })
end, asv_talk_look, asv_talk_change, asv_talk_after)

-- (the shadow actor of shadow.lua: the white box in cr_open)
asv_shadow_actor = function()
	MakeCurrentSet("cr_open.set")
	ASV_A = LoadActor("cr_asv_sh")
	PutActorInSet(ASV_A, "cr_open.set")
	PutActorAt(ASV_A, 0, 0, 0)
	SetActorRot(ASV_A, 0, 0, 0)
	SetActorCostume(ASV_A, "cr_dbox.cos")
	cr_frames(2)
	cr_sh_setup(ASV_A, -4, 0, 3)
	ActivateActorShadow(ASV_A, TRUE, 0)
end

asv_shadow_look = function()
	local l = { }
	l.pos = cr_s(GetActorPos(ASV_A))
	l.costume = tostring(GetActorCostume(ASV_A))
	return l
end

asv_shadow_end = function()
	KillActorShadows(ASV_A)
	cr_frames(2)
	PutActorInSet(ASV_A, nil)
end

-- a shadow on a plane of the current set: after the load (the shadows killed after the save), is it drawn again?
asv_save_test("shadow", function()
	asv_shadow_actor()
	cr_frames(3)
	cr_snap("saved_dark", "dark")
end, asv_shadow_look, function()
	KillActorShadows(ASV_A)
	cr_frames(3)
	cr_snap("killed_dark", "dark")
end, function()
	cr_frames(3)
	cr_snap("loaded_dark", "dark")
	asv_shadow_end()
end)

-- a shadow in a second slot and a plane name that is no sector (nothing added)
asv_save_test("shadow_slot", function()
	asv_shadow_actor()
	SetActiveShadow(ASV_A, 1)
	SetActorShadowPoint(ASV_A, 4, 0, 3)
	SetActorShadowPlane(ASV_A, "shadow1")
	AddShadowPlane(ASV_A, "shadow1")
	AddShadowPlane(ASV_A, "no_such_sector")
	ActivateActorShadow(ASV_A, TRUE, 1)
	ActivateActorShadow(ASV_A, FALSE, 0)
	cr_frames(3)
	cr_snap("saved_dark", "dark")
end, asv_shadow_look, function()
	KillActorShadows(ASV_A)
	cr_frames(3)
end, function()
	cr_frames(3)
	cr_snap("loaded_dark", "dark")
	asv_shadow_end()
end)

-- the plane is of cr_open, but the current set is cr_flat when the game is saved; after the load, cr_open again
asv_save_test("shadow_other_set", function()
	asv_shadow_actor()
	cr_frames(3)
	MakeCurrentSet("cr_flat.set")
end, function()
	local l = asv_shadow_look()
	l.set = tostring(GetActorSector(ASV_A, 4096))
	return l
end, function()
	MakeCurrentSet("cr_open.set")
	KillActorShadows(ASV_A)
	cr_frames(2)
	MakeCurrentSet("cr_flat.set")
end, function()
	MakeCurrentSet("cr_open.set")
	cr_frames(3)
	cr_snap("loaded_dark", "dark")
	asv_shadow_end()
end)

-- three costumes on a stack, a chore playing on the bottom one (cr_luav.cos sets CR_LV at its keys), and the stack read
-- with GetActorCostume(actor, n) (n from the top)
cr_scummvm_differs("asv_costume_stack", "GetActorCostume(a, n) is nil (not done); the original plays no key of a chore on a costume under the top one") asv_save_test("costume_stack", function()
	MakeCurrentSet("cr_flat.set")
	ASV_A = LoadActor("cr_asv_stack")
	PutActorInSet(ASV_A, "cr_flat.set")
	PutActorAt(ASV_A, 0.25, -0.5, 0)
	SetActorCostume(ASV_A, "cr_luav.cos")
	PushActorCostume(ASV_A, "cr_box.cos")
	PushActorCostume(ASV_A, "cr_talk.cos")
	CR_LV = 0
	PlayActorChore(ASV_A, 0, "cr_luav.cos")
	cr_frames(3)
	cr_log("lv_3", CR_LV)
	cr_frames(5)
	cr_log("lv_8", CR_LV)
end, function()
	local l = { }
	l.depth = tostring(GetActorCostumeDepth(ASV_A))
	l.top = tostring(GetActorCostume(ASV_A))
	l.c0 = tostring(GetActorCostume(ASV_A, 0))
	l.c1 = tostring(GetActorCostume(ASV_A, 1))
	l.c2 = tostring(GetActorCostume(ASV_A, 2))
	l.c3 = tostring(GetActorCostume(ASV_A, 3))
	l.choring = tostring(IsActorChoring(ASV_A, 0, FALSE, "cr_luav.cos"))
	l.lv = tostring(CR_LV)
	l.pos = cr_s(GetActorPos(ASV_A))
	return l
end, function()
	StopActorChore(ASV_A, 0, "cr_luav.cos")
	PopActorCostume(ASV_A)
	PopActorCostume(ASV_A)
	CR_LV = -1
end, function()
	cr_follow_chore(ASV_A, 0, 60, "after")
	cr_log("pop1", PopActorCostume(ASV_A), GetActorCostumeDepth(ASV_A))
	cr_log("pop2", PopActorCostume(ASV_A), GetActorCostumeDepth(ASV_A))
	cr_log("pop3", PopActorCostume(ASV_A), GetActorCostumeDepth(ASV_A))
	PutActorInSet(ASV_A, nil)
end)

-- the same costumes with cr_luav.cos on top, the chore playing on it (the stack seen through the pops)
asv_save_test("costume_stack_top", function()
	MakeCurrentSet("cr_flat.set")
	ASV_A = LoadActor("cr_asv_stack")
	PutActorInSet(ASV_A, "cr_flat.set")
	PutActorAt(ASV_A, 0.25, -0.5, 0)
	SetActorCostume(ASV_A, "cr_box.cos")
	PushActorCostume(ASV_A, "cr_talk.cos")
	PushActorCostume(ASV_A, "cr_luav.cos")
	CR_LV = 0
	PlayActorChore(ASV_A, 0, "cr_luav.cos")
	cr_frames(3)
	cr_log("lv_3", CR_LV)
	cr_frames(5)
	cr_log("lv_8", CR_LV)
end, function()
	local l = { }
	l.depth = tostring(GetActorCostumeDepth(ASV_A))
	l.top = tostring(GetActorCostume(ASV_A))
	l.choring = tostring(IsActorChoring(ASV_A, 0, FALSE, "cr_luav.cos"))
	l.lv = tostring(CR_LV)
	return l
end, function()
	StopActorChore(ASV_A, 0, "cr_luav.cos")
	PopActorCostume(ASV_A)
	CR_LV = -1
end, function()
	cr_follow_chore(ASV_A, 0, 60, "after")
	cr_log("pop1", PopActorCostume(ASV_A), GetActorCostumeDepth(ASV_A))
	cr_log("pop2", PopActorCostume(ASV_A), GetActorCostumeDepth(ASV_A))
	cr_log("pop3", PopActorCostume(ASV_A), GetActorCostumeDepth(ASV_A))
	PutActorInSet(ASV_A, nil)
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("asv_shadow")

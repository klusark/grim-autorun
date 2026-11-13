-- Saving and loading: Save(file) and Load(file) (the engine does them between frames), system.saveGameCallback with
-- SubmitSaveGameData, GetSaveGameData(file). Load brings back the Lua state of the save, the tasks with it: the test goes
-- on after the Save a second time. The registry is not in a save (CrSavePass tells the two passes apart).
-- Each cr_save_test: setup() makes the state, look() returns what can be seen of it ({ key = string }); after the save,
-- change() changes it and Load brings the save back. "kept_<key>" is 1 when the loaded value is the saved one (and both
-- values when not), "changed" counts the keys change() changed, so that a test that changes nothing is seen.
-- The game saves from its menu, in RenderModeUser(TRUE), and a load leaves the original in that mode (Engine_LoadGame sets
-- mode 4: no actor moves) until RenderModeUser(nil); cr_save does the same (save_mode is the load without it).

-- (as the menu does it: the game is saved in RenderModeUser, and goes on with RenderModeUser(nil), after the save and after
-- a load of it)
-- (no text object of an earlier test in the save. This file runs before text.lua: after SetEmergencyFont (its
-- blast_print) every Load crashed the original when it drew a text object, TextObject_Draw 0x48ca13 with no font;
-- zy_save_emergency.lua, after the others, is that)
cr_save_clean = function()
	PurgeText()
	cr_frames(1)
end

cr_save = function(file)
	RenderModeUser(TRUE)
	Save(file)
	cr_frames(3)
	RenderModeUser(nil)
end

-- (the values as one string)
cr_s = function(a, b, c, d, e)
	return tostring(a) .. " " .. tostring(b) .. " " .. tostring(c) .. " " .. tostring(d) .. " " .. tostring(e)
end

-- (how many keys of two looks differ)
cr_save_diff = function(a, b)
	local n = 0
	local k, v = next(a, nil)
	while k do
		if b[k] ~= v then
			n = n + 1
		end
		k, v = next(a, k)
	end
	return n
end

-- (the cases by test name; the test is one function without upvalues: the original's Load crashed in Lua.dll when the task
-- that saved runs a closure with upvalues)
CR_SAVE_CASES = { }
cr_save_test = function(name, setup, look, change, after)
	CR_SAVE_CASES["save_" .. name] = { setup = setup, look = look, change = change, after = after }
	cr_test("save_" .. name, cr_t_save_case)
end

cr_t_save_case = function()
	local c = CR_SAVE_CASES[CR_CUR]
	local file = "cr" .. CR_CUR .. ".gsv"
	cr_save_clean()
	c.setup()
	cr_frames(2)
	-- (a global: in the save, so the Load brings it back)
	CR_SAVE_LOOK = c.look()
	WriteRegistryValue("CrSavePass", "saving")
	cr_save(file)
	-- (here twice: after the save, and after the Load)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		c.change()
		cr_frames(2)
		cr_log("changed", cr_save_diff(CR_SAVE_LOOK, c.look()))
		Load(file)
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		cr_log("pass", ReadRegistryValue("CrSavePass"))
		WriteRegistryValue("CrSavePass", "done")
		cr_frames(1)
		local now = c.look()
		local ks = cr_keys(CR_SAVE_LOOK)
		local j = 1
		while ks[j] do
			local k = ks[j]
			local v = CR_SAVE_LOOK[k]
			if now[k] == v then
				cr_log("kept_" .. k, 1)
			else
				cr_log("kept_" .. k, v, now[k])
			end
			j = j + 1
		end
		if c.after then
			c.after()
		end
	end
end

-- an actor, a global, a text object and the strings of the save (SubmitSaveGameData from system.saveGameCallback)
cr_t_save_load = function()
	cr_save_clean()
	local a = cr_costume_actor()
	PutActorAt(a, 0.5, -0.25, 0)
	SetActorRot(a, 0, 30, 0)
	CR_SAVE_G = "before"
	local t = MakeTextObject("Saved", { font = LockFont("cr_font.laf"), fgcolor = MakeColor(255, 255, 255), x = 300, y = 200 })
	cr_frames(2)
	system.saveGameCallback = function()
		CR_SAVE_CALLED = 1
		-- (the original reads the strings from index 0 and stops at the first nil)
		local d = { }
		d[0] = "cr one"
		d[1] = "cr two"
		SubmitSaveGameData(d)
	end
	WriteRegistryValue("CrSavePass", "saving")
	cr_save("crsave.gsv")
	-- (here twice: after the save, and after the Load)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		cr_log("callback", CR_SAVE_CALLED)
		local d = GetSaveGameData("crsave.gsv")
		cr_log("data", type(d))
		if d then
			cr_log("data_items", tostring(d[0]), tostring(d[1]), tostring(d[2]))
		end
		PutActorAt(a, -1, 1, 0)
		CR_SAVE_G = "changed"
		cr_pos("changed_pos", a)
		cr_snap("changed_snap")
		Load("crsave.gsv")
		cr_frames(10)
		cr_log("no_load", 1)
	else
		cr_log("pass", ReadRegistryValue("CrSavePass"))
		WriteRegistryValue("CrSavePass", "done")
		cr_pos("loaded_pos", a)
		local p, yaw, r = GetActorRot(a)
		cr_log("loaded_rot", p, yaw, r)
		cr_log("loaded_costume", GetActorCostume(a))
		cr_log("loaded_global", CR_SAVE_G)
		cr_frames(2)
		cr_snap("loaded_snap")
	end
	system.saveGameCallback = nil
	if t then
		KillTextObject(t)
	end
end
cr_scummvm_differs("save_load") cr_test("save_load", cr_t_save_load)

-- the saved strings: no callback (the original writes none and GetSaveGameData gives an empty table), an empty list, three
cr_t_save_data_none = function()
	MakeCurrentSet("cr_flat.set")
	system.saveGameCallback = nil
	cr_save("crsave_none.gsv")
	local d = GetSaveGameData("crsave_none.gsv")
	cr_log("data", type(d), d and tostring(d[0]))
end
cr_scummvm_differs("save_data_none") cr_test("save_data_none", cr_t_save_data_none)

cr_t_save_data_empty = function()
	MakeCurrentSet("cr_flat.set")
	system.saveGameCallback = function()
		SubmitSaveGameData({ })
	end
	cr_save("crsave_empty.gsv")
	system.saveGameCallback = nil
	local d = GetSaveGameData("crsave_empty.gsv")
	cr_log("data", type(d), d and tostring(d[0]))
end
cr_test("save_data_empty", cr_t_save_data_empty)

cr_t_save_data_three = function()
	MakeCurrentSet("cr_flat.set")
	system.saveGameCallback = function()
		local d = { }
		d[0] = "a"
		d[1] = ""
		d[2] = "a much longer string than the others, to see that the lengths are kept"
		SubmitSaveGameData(d)
	end
	cr_save("crsave_three.gsv")
	system.saveGameCallback = nil
	local d = GetSaveGameData("crsave_three.gsv")
	cr_log("data", d and tostring(d[0]), d and tostring(d[1]), d and tostring(d[2]), d and tostring(d[3]))
end
cr_test("save_data_three", cr_t_save_data_three)

cr_t_save_data_missing = function()
	cr_log("data", type(GetSaveGameData("no_such_save.gsv")))
end
cr_scummvm_differs("save_data_missing") cr_test("save_data_missing", cr_t_save_data_missing)

-- a load without the menu's RenderModeUser: does the world go on at once (the actor walking), or only after
-- RenderModeUser(nil)?
cr_t_save_mode = function()
	cr_save_clean()
	-- (RenderModeUser(nil) goes back to the mode RenderModeUser(TRUE) left: the normal one)
	RenderModeUser(TRUE)
	RenderModeUser(nil)
	CR_SA = cr_actor("cr_flat.set")
	WalkActorTo(CR_SA, 1.5, 1.5, 0)
	cr_frames(2)
	WriteRegistryValue("CrSavePass", "saving")
	Save("crsave_mode.gsv")
	cr_frames(3)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		Load("crsave_mode.gsv")
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		WriteRegistryValue("CrSavePass", "done")
		local x0, y0 = GetActorPos(CR_SA)
		cr_frames(5)
		local x1, y1 = GetActorPos(CR_SA)
		cr_log("moves_after_load", x1 ~= x0)
		RenderModeUser(nil)
		cr_frames(5)
		local x2, y2 = GetActorPos(CR_SA)
		cr_log("moves_after_mode", x2 ~= x1)
	end
	PutActorInSet(CR_SA, nil)
end
cr_scummvm_differs("save_mode") cr_test("save_mode", cr_t_save_mode)

-- an actor's attributes
cr_save_test("actor_attrs", function()
	CR_SA = cr_attr_actor("cr_save1")
	PutActorAt(CR_SA, 0.75, 0.5, 0)
	SetActorRot(CR_SA, 5, 40, -3)
	SetActorScale(CR_SA, 1.5)
	SetActorTimeScale(CR_SA, 0.75)
	SetActorWalkRate(CR_SA, 0.6)
	SetActorTurnRate(CR_SA, 200)
	SetActorLookRate(CR_SA, 150)
	SetActorTalkColor(CR_SA, MakeColor(10, 200, 30))
	SetActorVisibility(CR_SA, FALSE)
	SetActorConstrain(CR_SA, TRUE)
	SetActorCollisionMode(CR_SA, 1)
	SetActorCollisionScale(CR_SA, 0.5)
	PushActorCostume(CR_SA, "cr_luav.cos")
end, function()
	local l = { }
	local x, y, z = GetActorPos(CR_SA)
	l.pos = cr_s(x, y, z)
	local p, yaw, r = GetActorRot(CR_SA)
	l.rot = cr_s(p, yaw, r)
	l.timescale = tostring(GetActorTimeScale(CR_SA))
	l.walk_rate = tostring(GetActorWalkRate(CR_SA))
	l.look_rate = tostring(GetActorLookRate(CR_SA))
	l.talk_color = cr_s(GetColorComponents(GetActorTalkColor(CR_SA)))
	l.costume = cr_s(GetActorCostume(CR_SA), GetActorCostumeDepth(CR_SA), GetActorCostume(CR_SA, 0))
	l.sector = cr_s(GetActorSector(CR_SA, 4096))
	return l
end, function()
	PutActorAt(CR_SA, -0.5, -0.5, 0)
	SetActorRot(CR_SA, 0, 0, 0)
	SetActorTimeScale(CR_SA, 1)
	SetActorWalkRate(CR_SA, 1)
	SetActorLookRate(CR_SA, 10)
	SetActorTalkColor(CR_SA, MakeColor(1, 2, 3))
	PopActorCostume(CR_SA)
end)

-- an actor walking when the game is saved: does it walk on from where it was?
cr_save_test("walking", function()
	CR_SA = cr_actor("cr_flat.set")
	WalkActorTo(CR_SA, 1.5, 1.5, 0)
	cr_frames(5)
	cr_pos("saved_pos", CR_SA)
end, function()
	local l = { }
	l.moving = tostring(IsActorMoving(CR_SA))
	return l
end, function()
	PutActorAt(CR_SA, -1, -1, 0)
	SetActorWalkRate(CR_SA, 2)
	WalkActorTo(CR_SA, -1.5, 1.5, 0)
end, function()
	local f = 0
	while f < 120 and IsActorMoving(CR_SA) do
		break_here()
		f = f + 1
	end
	cr_log("walked_frames", f < 120)
	cr_pos("walked_to", CR_SA)
end)

-- a chore playing when the game is saved (cr_luav.cos sets CR_LV at its keys)
cr_save_test("chore", function()
	CR_SA = cr_costume_actor()
	PlayActorChore(CR_SA, 0, "cr_luav.cos")
	cr_frames(3)
end, function()
	local l = { }
	l.choring = tostring(IsActorChoring(CR_SA, 0, FALSE, "cr_luav.cos"))
	l.lv = tostring(CR_LV)
	return l
end, function()
	StopActorChore(CR_SA, 0, "cr_luav.cos")
	CR_LV = -1
end, function()
	cr_follow_chore(CR_SA, 0, 60, "after")
end)

-- a set, its setup, its lights and its sectors
cr_save_test("set", function()
	MakeCurrentSet("cr_edge.set")
	MakeSectorActive("e_off", TRUE)
	MakeSectorActive("e_left", FALSE)
	SetLightIntensity("cr_light", 0.25)
	SetLightPosition("cr_light", 1, -2, 3)
	TurnLightOn("cr_light", FALSE)
	SetAmbientLight(1)
end, function()
	local l = { }
	l.setup = tostring(GetCurrentSetup("cr_edge.set"))
	l.off = cr_s(GetPointSector(0, -3, 0))
	l.left = cr_s(GetPointSector(-1, 0, 0))
	l.right = cr_s(GetPointSector(1, 0, 0))
	l.active = cr_s(IsSectorActive ~= nil and IsSectorActive("e_off"), IsSectorActive ~= nil and IsSectorActive("e_left"))
	return l
end, function()
	MakeSectorActive("e_off", FALSE)
	MakeSectorActive("e_left", TRUE)
	MakeCurrentSet("cr_flat.set")
end)

-- a set with several setups, the second one current
cr_save_test("setup", function()
	MakeCurrentSet("cr_cams.set")
	MakeCurrentSetup(1)
end, function()
	local l = { }
	l.setup = tostring(GetCurrentSetup("cr_cams.set"))
	l.fov = tostring(GetCameraFOV())
	l.screen = cr_s(WorldToScreen(0, 0, 0))
	return l
end, function()
	MakeCurrentSetup(0)
end, function()
	MakeCurrentSetup(0)
end)

-- text objects and the text settings
cr_save_test("text", function()
	MakeCurrentSet("cr_flat.set")
	local f = LockFont("cr_font.laf")
	CR_ST1 = MakeTextObject("First", { font = f, fgcolor = MakeColor(255, 255, 255), x = 100, y = 100 })
	CR_ST2 = MakeTextObject("Second line", { font = f, fgcolor = MakeColor(200, 200, 255), x = 320, y = 300, center = TRUE })
	CR_ST3 = MakeTextObject("Third", { font = f, fgcolor = MakeColor(255, 255, 255), x = 500, y = 50, ljustify = TRUE })
	ChangeTextObject(CR_ST3, "Third, changed", { x = 450 })
	SetTextSpeed(4)
	SetSayLineDefaults({ x = 10, y = 20, fgcolor = MakeColor(1, 2, 3) })
end, function()
	local l = { }
	l.d1 = cr_s(GetTextObjectDimensions(CR_ST1))
	l.d2 = cr_s(GetTextObjectDimensions(CR_ST2))
	l.d3 = cr_s(GetTextObjectDimensions(CR_ST3))
	l.speed = tostring(GetTextSpeed())
	return l
end, function()
	-- (not killed: GetTextObjectDimensions of a killed one is text_dims_killed)
	ChangeTextObject(CR_ST2, "Other words")
	ChangeTextObject(CR_ST3, "x")
	SetTextSpeed(7)
end, function()
	cr_frames(3)
	cr_snap("loaded_snap", "count")
	KillTextObject(CR_ST1)
	KillTextObject(CR_ST2)
	KillTextObject(CR_ST3)
	SetTextSpeed(7)
end)

-- 2D primitives
cr_save_test("primitives", function()
	MakeCurrentSet("cr_flat.set")
	local w = MakeColor(255, 255, 255)
	CR_SP1 = DrawRectangle(100, 100, 199, 149, { color = w, filled = TRUE })
	CR_SP2 = DrawLine(300, 300, 400, 300, { color = w })
	CR_SP3 = DrawRectangle(450, 50, 500, 90, { color = w })
end, function()
	local l = { }
	return l
end, function()
	KillPrimitive(CR_SP1)
	ChangePrimitive(CR_SP2, { x = 10, y = 10 })
end, function()
	cr_frames(3)
	cr_snap("loaded_snap", "count")
	KillPrimitive(CR_SP1)
	KillPrimitive(CR_SP2)
	KillPrimitive(CR_SP3)
	cr_frames(1)
	cr_snap("killed_snap", "count")
end)

-- an object state of the set
cr_save_test("object_state", function()
	MakeCurrentSet("cr_flat.set")
	CR_SO = NewObjectState(0, 1, "cr_obj.bm", nil, TRUE)
	SetObjectType(CR_SO, 2)
end, function()
	local l = { }
	l.state = type(CR_SO)
	return l
end, function()
	SendObjectToBack(CR_SO)
end, function()
	FreeObjectState(CR_SO)
end)

-- Lua values of every kind and a task that counts frames: the task goes on after the Load
cr_save_test("lua", function()
	CR_SL = { n = 1.5, s = "str", t = { 1, 2, { deep = "yes" } }, b = nil }
	CR_SL.self = CR_SL
	CR_SL.f = function(x) return x * 2 end
	CR_SL_COUNT = 0
	CR_SL_TASK = start_script(function()
		while 1 do
			CR_SL_COUNT = CR_SL_COUNT + 1
			break_here()
		end
	end)
end, function()
	local l = { }
	l.n = tostring(CR_SL.n)
	l.s = CR_SL.s
	l.deep = CR_SL.t[3].deep
	l.self = tostring(CR_SL.self == CR_SL)
	l.f = tostring(CR_SL.f(21))
	l.task = tostring(find_script(CR_SL_TASK) ~= nil)
	return l
end, function()
	CR_SL.n = 0
	CR_SL.t[3].deep = "no"
	stop_script(CR_SL_TASK)
end, function()
	local c = CR_SL_COUNT
	cr_frames(3)
	cr_log("task_counts", CR_SL_COUNT > c)
	stop_script(CR_SL_TASK)
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("save_actor_attrs")
cr_scummvm_differs("save_primitives")
cr_scummvm_differs("save_set")
cr_scummvm_differs("save_setup")
cr_scummvm_differs("save_text")
cr_scummvm_differs("save_walking")
cr_scummvm_differs("save_chore")

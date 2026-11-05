-- Builtins the argument probe calls but no other test used: with valid arguments here (the original-only ones through
-- cr_fn, so that their absence on ScummVM is a difference and not a Lua error)

cr_t_localize = function()
	cr_log("one", LocalizeString("/crt001/"))
	cr_log("two", LocalizeString("/crt002/"))
	cr_log("short", LocalizeString("/crt003/"))
	cr_log("missing", LocalizeString("/nosuchid/"))
	cr_log("plain", LocalizeString("no slashes"))
end
cr_test("localize", cr_t_localize)

cr_t_screen_effects = function()
	DimScreen()
	cr_frames(1)
	DimRegion(10, 10, 100, 100, 0.5)
	cr_frames(1)
	CleanBuffer()
	ForceRefresh()
	PreRender(TRUE, TRUE)
	Display()
	ResetTextures()
	cr_frames(1)
	cr_log("ok", 1)
end
cr_test("screen_effects", cr_t_screen_effects)

cr_t_set_locks = function()
	LockSet("cr_edge.set")
	UnLockSet("cr_edge.set")
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
	cr_log("sector_active", IsSectorActive("e_left"), IsSectorActive("e_off"), IsSectorActive("no_such"))
	local f = cr_fn("GetSectorVertices")
	if f then
		local v = f("e_left")
		cr_log("vertices_type", type(v))
	end
	MakeCurrentSet("cr_flat.set")
end
cr_test("set_locks", cr_t_set_locks)

cr_t_actor_extras = function()
	local a = cr_attr_actor("cr_extra1")
	SetActorColormap(a, "cr_pal.cmp")
	SetActorTalkChore(a, 1, 0, "cr_box.cos")
	SetActorMumblechore(a, 1, "cr_box.cos")
	ActorToClean(a)
	PrintActorCostumes(a)
	local f = cr_fn("SetActorOffsetYaw")
	if f then
		f(a, 30)
		local p, y, r = GetActorRot(a)
		cr_log("offset_yaw_rot", y)
	end
	local g = cr_fn("SetWalkSystemFadeTime")
	if g then
		g(100)
	end
	cr_frames(1)
	cr_log("ok", 1)
	PutActorInSet(a, nil)
end
cr_test("actor_extras", cr_t_actor_extras)

cr_t_actor_sees = function()
	local a = cr_attr_actor("cr_extra2")
	local b = cr_attr_actor("cr_extra3")
	PutActorAt(b, 0, 1, 0)
	cr_frames(1)
	local f = cr_fn("CanActorSee")
	if f then
		cr_log("sees_ahead", f(a, b))
		PutActorAt(b, 0, -1, 0)
		cr_log("sees_behind", f(a, b))
	end
	local g = cr_fn("WalkActorToInterest")
	if g then
		g(a)
		cr_frames(5)
		cr_pos("to_interest", a)
	end
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end
cr_test("actor_sees", cr_t_actor_sees)

cr_t_screen_to_world = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	local f = cr_fn("ScreenToWorld")
	if f then
		cr_log("centre", f(320, 240))
		cr_log("corner", f(0, 0))
	end
	local g = cr_fn("GetClippedPos")
	if g then
		cr_log("clipped", g(3, 0, 0))
	end
end
cr_test("screen_to_world", cr_t_screen_to_world)

cr_t_light_details = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	local names = { "GetLightType", "GetLightAngles", "GetLightRotation" }
	local i = 1
	local f
	while i <= 3 do
		f = cr_fn(names[i])
		if f then
			cr_log(names[i], f("cr_light"))
		end
		i = i + 1
	end
	LightMgrStartup()
	cr_log("ok", 1)
end
cr_test("light_details", cr_t_light_details)

cr_t_sound_details = function()
	ImFadeParam("no_such.imu", 1, 0, 100)
	local f = cr_fn("ImGetMasterVol")
	if f then
		cr_log("master", f())
	end
	local g = cr_fn("ImSetMasterVol")
	if g then
		g(64)
		if f then
			cr_log("master_set", f())
		end
		g(127)
	end
	LoadBundle("no_such.bun")
	cr_log("ok", 1)
end
cr_test("sound_details", cr_t_sound_details)

cr_t_resource_locks = function()
	local names = { "LockCostume", "UnlockCostume" }
	local f = cr_fn("LockCostume")
	if f then
		cr_log("lock_costume", f("cr_box.cos"))
	end
	f = cr_fn("UnlockCostume")
	if f then
		cr_log("unlock_costume", f("cr_box.cos"))
	end
	f = cr_fn("UnLockFont")
	if f then
		cr_log("unlock_font", f(LockFont("cr_font.laf")))
	end
end
cr_test("resource_locks", cr_t_resource_locks)

cr_t_iris = function()
	IrisDown(320, 240, 100)
	local f = 0
	cr_frames(20)
	IrisUp(320, 240, 100)
	cr_frames(20)
	cr_log("ok", 1)
end
cr_test("iris", cr_t_iris)

cr_t_env = function()
	local f = cr_fn("getenv")
	if f then
		cr_log("missing_var", f("CR_SURELY_NOT_SET_12345"))
	end
	cr_log("date_type", type(date()))
end
cr_test("env", cr_t_env)

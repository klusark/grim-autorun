-- EMI's drawing (assets_emi_extra_rnd.py): actors with a costume drawn with an alpha (SetActorGlobalAlpha: a mode, 2
-- AlphaReplace, then the alpha, of the actor or of one mesh), in the overworld (the screen's own camera and lights), a
-- mesh whose texture is drawn additively and whose face is alpha-blended, a face without lighting, an additive sprite
-- without the alpha and depth tests, a talking actor with a costume (its line placed from the box of the actor on the
-- screen). ScummVM in the clean room draws few frames: cr_rnd_e_draw takes a snap (which draws the scene), not compared (the original's EMI has none). The original's EMI has no picture of the screen in the clean room: these log what Lua sees (positions, the
-- line going) and run ScummVM's drawing.

cr_rnd_e_actor = function(cos)
	local a = cr_ea_actor("cr_flat.set", TRUE)
	PlayActorChore(a, "wear_default", cos, 1)
	-- (in the overworld, 3 m in front of the screen's camera: ScummVM draws the actors of cr_flat with a costume only
	-- there in the clean room)
	if CR_RND_E_OVER then
		PutActorAt(a, 0, 0, 3)
		PutActorInOverworld(a)
	end
	cr_rnd_e_draw()
	return a
end

CR_RND_E_N = 0
cr_rnd_e_draw = function()
	cr_frames(2)
	CR_RND_E_N = CR_RND_E_N + 1
	cr_snap("draw" .. CR_RND_E_N)
	cr_unstable("draw" .. CR_RND_E_N)
	cr_frames(1)
end

cr_rnd_e_done = function(a)
	if CR_RND_E_OVER then
		RemoveActorFromOverworld(a)
	end
	StopActorChores(a)
	cr_frames(1)
	PutActorInSet(a, nil)
	cr_frames(1)
end

cr_t_rnd_e_alpha = function()
	local a = cr_rnd_e_actor("cr_ebox.cos")
	SetActorGlobalAlpha(a, 2)
	SetActorGlobalAlpha(a, 0.5)
	cr_rnd_e_draw()
	local x, y, z = GetActorPos(a)
	cr_log("half", x, y, z)
	SetActorGlobalAlpha(a, 0.25, "cr_ebox")
	cr_rnd_e_draw()
	SetActorLocalAlpha(a, 0, 0.5)
	cr_rnd_e_draw()
	local x, y, z = GetActorPos(a)
	cr_log("mesh", x, y, z)
	SetActorGlobalAlpha(a, 1)
	SetActorGlobalAlpha(a, 1, "cr_ebox")
	SetActorGlobalAlpha(a, -1)
	cr_rnd_e_draw()
	cr_rnd_e_done(a)
end
cr_test("rnd_e_alpha", function()
	CR_RND_E_OVER = 1
	cr_t_rnd_e_alpha()
	CR_RND_E_OVER = nil
end)

cr_t_rnd_e_overworld = function()
	ClearOverworld()
	local a = cr_rnd_e_actor("cr_ebox.cos")
	PutActorAt(a, 0, 0, 3)
	PutActorInOverworld(a)
	ToggleOverworld(TRUE)
	cr_rnd_e_draw()
	local x, y, z = GetActorPos(a)
	cr_log("pos", x, y, z)
	SetActorRot(a, 0, 45, 0)
	cr_rnd_e_draw()
	local x, y, z = GetActorRot(a)
	cr_log("rot", x, y, z)
	ToggleOverworld(FALSE)
	RemoveActorFromOverworld(a)
	ClearOverworld()
	cr_frames(1)
	cr_rnd_e_done(a)
end
cr_test("rnd_e_overworld", cr_t_rnd_e_overworld)

CR_RND_E_COS = { "rnd_add.cos", "rnd_nolit.cos", "rnd_spr.cos", "cr_esprite.cos" }
cr_t_rnd_e_costumes = function()
	local i = 1
	while CR_RND_E_COS[i] do
		local a = cr_rnd_e_actor(CR_RND_E_COS[i])
		SetActorRot(a, 0, 30, 0)
		cr_rnd_e_draw()
		local x, y, z = GetActorRot(a)
		cr_log(CR_RND_E_COS[i], x, y, z)
		cr_rnd_e_done(a)
		i = i + 1
	end
end
cr_test("rnd_e_costumes", function()
	CR_RND_E_OVER = 1
	cr_t_rnd_e_costumes()
	CR_RND_E_OVER = nil
end)

-- a talking actor with a costume in the overworld: at the middle, near the screen's edge, far
CR_RND_E_SAY = { { "middle", 0, 0, 3 }, { "edge", 1.4, 0, 3 }, { "far", 0, 0, 8 } }
cr_t_rnd_e_say = function()
	SetSayLineDefaults({ font = "cr_font.laf" })
	local i = 1
	while CR_RND_E_SAY[i] do
		local p = CR_RND_E_SAY[i]
		local a = cr_rnd_e_actor("cr_ebox.cos")
		PutActorAt(a, p[2], p[3], p[4])
		cr_rnd_e_draw()
		SayLine(a, "/crtv02/")
		cr_rnd_e_draw()
		cr_log(p[1], IsMessageGoing())
		ShutUpActor(a)
		cr_rnd_e_draw()
		cr_rnd_e_done(a)
		ExpireText()
		i = i + 1
	end
end
cr_test("rnd_e_say", function()
	CR_RND_E_OVER = 1
	cr_t_rnd_e_say()
	CR_RND_E_OVER = nil
end)

-- (a memory error in ScummVM under valgrind: on the skip list)
cr_scummvm_differs("rnd_e_alpha", "a memory error in ScummVM under valgrind (uninitialised value or invalid access): on the skip list")

-- (a memory error in ScummVM under valgrind: on the skip list)
cr_scummvm_differs("rnd_e_overworld", "a memory error in ScummVM under valgrind (uninitialised value or invalid access): on the skip list")

-- Lit models (assets.py): cr_lbox.cos, the white draw box with lighting mode 3 (lit), its vertices at light level 1
-- (cr_lbox_half: 0.5, cr_lbox_dark: 0), in cr_lit.set (cr_open with a black background, so that the box is all that is
-- not black) with three white lights: cr_omni (omni, 3 m above the origin), cr_dir (direct, straight down) and cr_spot
-- (spot, 3 m above, down, umbra 15 and penumbra 25 degrees). Each test turns the lights it wants on and the others off,
-- changes them, and snaps the box: cr_snap(key, "mean"), the box of the pixels that are not black, how many there are and
-- their mean brightness. (The model's normals all point up, +z: a turned box faces the lights another way.)
-- 2026-11-08: the original draws the box at the light level of its vertices (1: 248, 0.5: 121, 0: black), whatever the
-- lights: none of them reaches it (rdModel_DrawMesh lights the mesh in mode 3, rdLight_CalcVertexIntensities, but adds
-- nothing; why not is not known yet). ScummVM lights it with the set's lights and ignores the level of the vertices, and
-- its renderers differ from each other.

CR_LIT_LIGHTS = { "cr_omni", "cr_dir", "cr_spot" }

cr_lit_test = function(name, on, fn, cos)
	-- (dark_none, no light and a black box, comes out the same in the whole run, but with the shader renderer it is lit
	-- white (255) when it runs alone, --only: the mark stays)
	cr_scummvm_differs("lit_" .. name, "ScummVM lights the box with the set's lights, not at its vertices' level")
	cr_test("lit_" .. name, function()
		MakeCurrentSet("cr_lit.set")
		local on = %on
		local fn = %fn
		local i = 1
		while CR_LIT_LIGHTS[i] do
			local l = CR_LIT_LIGHTS[i]
			if on[l] then
				TurnLightOn(l, TRUE)
			else
				TurnLightOn(l, FALSE)
			end
			i = i + 1
		end
		-- (one actor for them all, its costume popped after: an actor a test, or the costumes kept, made the original
		-- crash in the save tests' load, ModelComponent_Destroy of a component without its model)
		if not CR_LIT_ACTOR then
			CR_LIT_ACTOR = LoadActor("cr_lit")
		end
		local a = CR_LIT_ACTOR
		PutActorInSet(a, "cr_lit.set")
		PutActorAt(a, 0, 0, 0)
		SetActorRot(a, 0, 0, 0)
		SetActorCostume(a, %cos or "cr_lbox.cos")
		if fn then
			fn(a)
		end
		LightMgrSetChange()
		cr_frames(2)
		cr_snap("snap", "mean")
		PopActorCostume(a)
		PutActorInSet(a, nil)
		-- (back as the set has them)
		SetLightIntensity("cr_omni", 1)
		SetLightIntensity("cr_dir", 1)
		SetLightIntensity("cr_spot", 1)
		SetLightPosition("cr_omni", 0, 0, 3)
		SetLightPosition("cr_spot", 0, 0, 3)
		SetAmbientLight(0)
		i = 1
		while CR_LIT_LIGHTS[i] do
			TurnLightOn(CR_LIT_LIGHTS[i], TRUE)
			i = i + 1
		end
	end)
end

cr_lit_test("none", { })
cr_lit_test("omni", { cr_omni = 1 })
cr_lit_test("dir", { cr_dir = 1 })
cr_lit_test("spot", { cr_spot = 1 })
cr_lit_test("all", { cr_omni = 1, cr_dir = 1, cr_spot = 1 })
cr_lit_test("omni_half", { cr_omni = 1 }, function() SetLightIntensity("cr_omni", 0.5) end)
cr_lit_test("omni_far", { cr_omni = 1 }, function() SetLightPosition("cr_omni", 0, 0, 20) end)
cr_lit_test("omni_side", { cr_omni = 1 }, function() SetLightPosition("cr_omni", 4, 0, 0.25) end)
cr_lit_test("spot_moved", { cr_spot = 1 }, function() SetLightPosition("cr_spot", 1.5, 0, 3) end)
cr_lit_test("spot_away", { cr_spot = 1 }, function() SetLightPosition("cr_spot", 6, 0, 3) end)
cr_lit_test("omni_pitch", { cr_omni = 1 }, function(a) SetActorRot(a, 60, 0, 0) end)
cr_lit_test("dir_roll", { cr_dir = 1 }, function(a) SetActorRot(a, 0, 0, 120) end)
cr_lit_test("ambient", { }, function() SetAmbientLight(1) end)
-- the light level of the vertices
cr_lit_test("half_none", { }, nil, "cr_lbox_half.cos")
cr_lit_test("half_all", { cr_omni = 1, cr_dir = 1, cr_spot = 1 }, nil, "cr_lbox_half.cos")
cr_lit_test("dark_none", { }, nil, "cr_lbox_dark.cos")
cr_lit_test("dark_omni", { cr_omni = 1 }, nil, "cr_lbox_dark.cos")
cr_lit_test("dark_dir", { cr_dir = 1 }, nil, "cr_lbox_dark.cos")
cr_lit_test("dark_omni_near", { cr_omni = 1 }, function() SetLightPosition("cr_omni", 0, 0, 0.8) end, "cr_lbox_dark.cos")

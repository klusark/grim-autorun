-- The software rasteriser's z-buffered face drawer (rdCache_DrawFaceZ 0x408af0) in its geometry, lighting and texture modes
-- (assets.RENDER_MODES): the white draw box with every face in geometry mode 1 (vertices), 2 (wireframe), 3 (solid) or 4
-- (textured); lighting 0 (none), 1 (flat), 2 (diffuse) or 3 (gouraud); texture mode 0 (affine) or 1 (perspective); face
-- type 0 or 2 (translucent); a plain texture, one flagged masked (flag 1) and a masked checker (colour 0 skipped). Drawn in
-- cr_rm.set (cr_lit.set with cr_rm_pal.cmp, whose light and 16-bit -> index tables the lit and translucent rasterisers read;
-- black background, the omni light on), turned so that perspective counts, and seen through cr_snap(key,
-- "mean"): the box of what is not black, how many pixels and their mean brightness.

cr_rm_test = function(name)
	cr_test("render_" .. strsub(name, 7), function()
		MakeCurrentSet("cr_rm.set")
		-- (the whole background again: only dirty parts are redrawn, and the vertices of the test before stay otherwise)
		ForceRefresh()
		cr_frames(1)
		TurnLightOn("cr_omni", TRUE)
		TurnLightOn("cr_dir", FALSE)
		TurnLightOn("cr_spot", FALSE)
		-- (one actor for them all, its costume popped after, as zz_lit.lua's)
		if not CR_RM_ACTOR then
			CR_RM_ACTOR = LoadActor("cr_rm")
		end
		local a = CR_RM_ACTOR
		PutActorInSet(a, "cr_rm.set")
		PutActorAt(a, 0.3, 0.2, 0)
		SetActorRot(a, 25, 35, 10)
		SetActorCostume(a, %name .. ".cos")
		LightMgrSetChange()
		cr_frames(2)
		cr_snap("snap", "mean")
		SetActorRot(a, 0, 0, 0)
		cr_frames(2)
		cr_snap("flat", "mean")
		PopActorCostume(a)
		PutActorInSet(a, nil)
		TurnLightOn("cr_dir", TRUE)
		TurnLightOn("cr_spot", TRUE)
	end)
end

-- (the models of assets.RENDER_MODES, in its order; not the translucent textured ones lit flat or diffuse: see there)
cr_rm_test("cr_rm_g1")
cr_rm_test("cr_rm_g2")
local l = 0
while l < 4 do
	cr_rm_test("cr_rm_g3_l" .. l .. "_y0")
	cr_rm_test("cr_rm_g3_l" .. l .. "_y2")
	l = l + 1
end
l = 0
while l < 4 do
	local t = 0
	while t < 2 do
		local y = 0
		while y <= 2 do
			if y == 0 or l == 0 or l == 3 then
				cr_rm_test("cr_rm_g4_l" .. l .. "_t" .. t .. "_y" .. y .. "_w")
				cr_rm_test("cr_rm_g4_l" .. l .. "_t" .. t .. "_y" .. y .. "_f")
			end
			cr_rm_test("cr_rm_g4_l" .. l .. "_t" .. t .. "_y" .. y .. "_k")
			y = y + 2
		end
		t = t + 1
	end
	l = l + 1
end

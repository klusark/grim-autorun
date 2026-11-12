-- The colormap of a costume stack whose costumes share one main model (bug #11818: Manny's suit turned orange after
-- mcc_snowblow.cos, with siberian.cmp, was pushed on mcc_thunder.cos, with m_chow.cmp, and popped). The costumes are the
-- white box of draw.lua with a colormap component under the model: cr_cm_white.cos (cr_pal.cmp, the box is white),
-- cr_cm_dim.cos (cr_dim.cmp, the box is grey 85) and cr_cm_none.cos (none, the actor's colormap). cr_snap(.., "seen")
-- gives the bright pixels: the box when it is white, "none" when it is grey. Each case logs the box alone, with the second
-- costume pushed and after the pop.

cr_dcm_actor = function(cos)
	local a = LoadActor("cr_cm_a")
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, cos)
	return a
end

cr_dcm_test = function(name, fn)
	cr_test("draw_" .. name, function()
		MakeCurrentSet("cr_open.set")
		cr_frames(2)
		%fn(%name)
	end)
end
local cases = {
	{ "white_dim", "cr_cm_white.cos", "cr_cm_dim.cos" },
	{ "dim_white", "cr_cm_dim.cos", "cr_cm_white.cos" },
	{ "none_dim", "cr_cm_none.cos", "cr_cm_dim.cos" },
	{ "dim_none", "cr_cm_dim.cos", "cr_cm_none.cos" },
	{ "white_none", "cr_cm_white.cos", "cr_cm_none.cos" },
	{ "none_white", "cr_cm_none.cos", "cr_cm_white.cos" },
}
local i = 1
while cases[i] do
	cr_dcm_test("cmap_" .. cases[i][1], function(k)
		local c = %cases[%i]
		local a = cr_dcm_actor(c[2])
		SetActorColormap(a, "cr_pal.cmp")
		cr_frames(2)
		cr_snap(k .. "_base", "seen")
		PushActorCostume(a, c[3])
		cr_frames(2)
		cr_log(k .. "_depth", GetActorCostumeDepth(a))
		cr_snap(k .. "_pushed", "seen")
		PopActorCostume(a)
		cr_frames(2)
		cr_log(k .. "_costume", GetActorCostume(a))
		cr_snap(k .. "_popped", "seen")
		PutActorInSet(a, nil)
	end)
	i = i + 1
end

-- three deep: dim on white on white, then popped one at a time
cr_dcm_test("cmap_three", function(k)
	local a = cr_dcm_actor("cr_cm_white.cos")
	PushActorCostume(a, "cr_cm_none.cos")
	PushActorCostume(a, "cr_cm_dim.cos")
	cr_frames(2)
	cr_snap(k .. "_three", "seen")
	PopActorCostume(a)
	cr_frames(2)
	cr_snap(k .. "_two", "seen")
	PopActorCostume(a)
	cr_frames(2)
	cr_snap(k .. "_one", "seen")
	PutActorInSet(a, nil)
end)

-- after the pop of a costume with a colormap over one without: the actor's colormap set again, then a new costume set over
-- the stack (a model of its own)
cr_dcm_test("cmap_none_dim_after", function(k)
	local a = cr_dcm_actor("cr_cm_none.cos")
	SetActorColormap(a, "cr_pal.cmp")
	PushActorCostume(a, "cr_cm_dim.cos")
	cr_frames(2)
	PopActorCostume(a)
	cr_frames(2)
	cr_snap(k .. "_popped", "seen")
	SetActorColormap(a, "cr_pal.cmp")
	cr_frames(2)
	cr_snap(k .. "_actor_cmap", "seen")
	SetActorCostume(a, "cr_cm_none.cos")
	cr_frames(2)
	cr_log(k .. "_depth", GetActorCostumeDepth(a))
	cr_snap(k .. "_set_again", "seen")
	SetActorCostume(a, nil)
	SetActorCostume(a, "cr_cm_none.cos")
	cr_frames(2)
	cr_snap(k .. "_new_costume", "seen")
	PutActorInSet(a, nil)
end)

-- The original writes a costume's colormap into the shared model when it draws and never clears it: with no colormap in
-- the costume below, the popped costume's stays (the box stays grey) until a new costume is set. ScummVM goes back to the
-- actor's colormap. No stack of the game shows it: wherever the costume below has no colormap, the pushed costume's is the
-- actor's (eva_sv, naranja, seabees, action).
cr_scummvm_differs("draw_cmap_none_dim", "the original keeps a popped costume's colormap when the one below has none")
cr_scummvm_differs("draw_cmap_none_dim_after", "the original keeps a popped costume's colormap when the one below has none")

-- The costume components in a save, and two kinds of component no other test has (assets_extra_cov.py).
-- Saves (as save.lua's cr_save_test, with only calls both engines take): cr_comp.cos (COMP_COMPONENTS: a material of two cels,
-- a mesh, a sprite) with its chores played and the costume's colormap set (MaterialComponent, MeshComponent,
-- SpriteComponent and Costume saveState / restoreState), and cr_kbox.cos with a looping slide (KeyframeComponent's).
-- cov_anim.cos: ANIM components (the demo's: the object state of a bitmap by its name, as an overlay and an underlay,
-- AnimComponent), cov_unknown.cos: a component of a tag no engine knows.

COV_CS_COMP = "cr_comp.cos"

-- (save.lua's cr_save_test and cr_t_save_case: a case of its own here, the lint reads each file alone. The test is one
-- function without upvalues: the original's Load crashed when the task that saved ran a closure with upvalues)
COV_CS_CASES = { }
cov_cs_save_test = function(name, setup, look, change, after)
	COV_CS_CASES["cov_save_" .. name] = { setup = setup, look = look, change = change, after = after }
	cr_test("cov_save_" .. name, cr_t_cov_cs_case)
end

cr_t_cov_cs_case = function()
	local c = COV_CS_CASES[CR_CUR]
	local file = "cr" .. CR_CUR .. ".gsv"
	cr_save_clean()
	c.setup()
	cr_frames(2)
	COV_CS_LOOK = c.look()
	WriteRegistryValue("CrSavePass", "saving")
	cr_save(file)
	if ReadRegistryValue("CrSavePass") == "saving" then
		WriteRegistryValue("CrSavePass", "loading")
		c.change()
		cr_frames(2)
		cr_log("changed", cr_save_diff(COV_CS_LOOK, c.look()))
		Load(file)
		cr_frames(10)
		cr_log("not_loaded", 1)
	else
		cr_log("pass", ReadRegistryValue("CrSavePass"))
		WriteRegistryValue("CrSavePass", "done")
		cr_frames(1)
		local now = c.look()
		local ks = cr_keys(COV_CS_LOOK)
		local j = 1
		while ks[j] do
			local k = ks[j]
			if now[k] == COV_CS_LOOK[k] then
				cr_log("kept_" .. k, 1)
			else
				cr_log("kept_" .. k, COV_CS_LOOK[k], now[k])
			end
			j = j + 1
		end
		if c.after then
			c.after()
		end
	end
end

cov_cs_actor = function(name, cos)
	MakeCurrentSet("cr_open.set")
	local a = LoadActor(name)
	PutActorInSet(a, "cr_open.set")
	PutActorAt(a, 0, 0, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, cos)
	return a
end

cov_cs_rect = function(a)
	local x0, y0, x1, y1 = GetActorRect(a)
	return tostring(x0) .. " " .. tostring(y0) .. " " .. tostring(x1) .. " " .. tostring(y1)
end

-- cel_grey (0), hide_right (2) and sprite_on (4) played to their end, the colormap cr_dim.cmp
cr_scummvm_differs("cov_save_comp_parts", "the chores and the colormap set after the save change the actor's rect on the original, not on ScummVM; the picture after the Load differs (mean brightness 69.7 against 69.1)")
cov_cs_save_test("comp_parts", function()
	CR_SA = cov_cs_actor("cov_cs_comp", COV_CS_COMP)
	SetActorColormap(CR_SA, "cr_dim.cmp")
	PlayActorChore(CR_SA, 0, COV_CS_COMP)
	PlayActorChore(CR_SA, 2, COV_CS_COMP)
	PlayActorChore(CR_SA, 4, COV_CS_COMP)
	cr_frames(10)
end, function()
	local l = { }
	l.rect = cov_cs_rect(CR_SA)
	l.costume = tostring(GetActorCostume(CR_SA))
	return l
end, function()
	PlayActorChore(CR_SA, 1, COV_CS_COMP)
	PlayActorChore(CR_SA, 3, COV_CS_COMP)
	PlayActorChore(CR_SA, 5, COV_CS_COMP)
	SetActorColormap(CR_SA, "cr_pal.cmp")
	cr_frames(10)
end, function()
	cr_snap("after", "mean")
	PlayActorChore(CR_SA, 1, COV_CS_COMP)
	cr_frames(10)
	cr_snap("after_white", "mean")
	PutActorInSet(CR_SA, nil)
end)

-- a slide that loops (cr_kbox.cos chore 1, slide_loop) when the game is saved
cov_cs_save_test("comp_keyframe", function()
	CR_SA = cov_cs_actor("cov_cs_key", "cr_kbox.cos")
	PlayActorChore(CR_SA, 1, "cr_kbox.cos")
	cr_frames(5)
end, function()
	local l = { }
	l.choring = tostring(IsActorChoring(CR_SA, 1, FALSE, "cr_kbox.cos"))
	return l
end, function()
	StopActorChore(CR_SA, 1, "cr_kbox.cos")
end, function()
	cr_frames(5)
	cr_log("still_choring", IsActorChoring(CR_SA, 1, FALSE, "cr_kbox.cos"))
	StopActorChore(CR_SA, 1, "cr_kbox.cos")
	PutActorInSet(CR_SA, nil)
end)

-- a stack of three costumes (Actor::saveState writes the ones under the top, restoreState loads them again), a chore
-- playing on the top one; looked at through the top costume only (GetActorCostume(a, n) quits ScummVM: asv_costume_stack).
-- comp_stack: cr_box.cos at the bottom, a model without a colormap of its own; comp_stack_cmap: the same with
-- cr_dbox.cos, which has one
cov_cs_stack_setup = function(bottom)
	CR_SA = cov_cs_actor("cov_cs_stack", bottom)
	PushActorCostume(CR_SA, "cr_kbox.cos")
	PushActorCostume(CR_SA, "cr_luav.cos")
	CR_LV = 0
	PlayActorChoreLooping(CR_SA, 0, "cr_luav.cos")
	cr_frames(3)
end

cov_cs_stack_look = function()
	local l = { }
	l.top = tostring(GetActorCostume(CR_SA))
	l.choring = tostring(IsActorChoring(CR_SA, 0, FALSE, "cr_luav.cos"))
	return l
end

cov_cs_stack_change = function()
	PopActorCostume(CR_SA)
	PopActorCostume(CR_SA)
	cr_frames(2)
end

cov_cs_stack_after = function()
	PopActorCostume(CR_SA)
	cr_log("popped1", GetActorCostume(CR_SA))
	PopActorCostume(CR_SA)
	cr_log("popped2", GetActorCostume(CR_SA))
	PopActorCostume(CR_SA)
	cr_log("popped3", GetActorCostume(CR_SA))
	PutActorInSet(CR_SA, nil)
end

cr_scummvm_differs("cov_save_comp_stack", "ScummVM quits through error() in the Load: \"Could not find colormap item.cmp!\" (Actor::restoreState loads the costumes under the top again, cr_box.cos's model without a colormap of its own falls back to the default, ModelComponent::init)")
cov_cs_save_test("comp_stack", function()
	cov_cs_stack_setup("cr_box.cos")
end, cov_cs_stack_look, cov_cs_stack_change, cov_cs_stack_after)

cov_cs_save_test("comp_stack_cmap", function()
	cov_cs_stack_setup("cr_dbox.cos")
end, cov_cs_stack_look, cov_cs_stack_change, cov_cs_stack_after)

-- the ANIM components: each chore sets the image of an object state that the component makes in the current set the
-- first time it is keyed (its bitmap by name: cov_art1.bm over the actors, cov_art2.bm under them)
cr_t_cov_anim = function()
	local a = cov_cs_actor("cov_cs_anim", "cov_anim.cos")
	cr_frames(2)
	cr_snap("start", "count")
	local i = 0
	local names = { "art1_on", "art1_off", "art2_on", "both_on", "art1_two" }
	while names[i + 1] do
		PlayActorChore(a, i, "cov_anim.cos")
		cr_frames(5)
		cr_log(names[i + 1] .. "_playing", IsActorChoring(a, i, FALSE, "cov_anim.cos"))
		cr_snap(names[i + 1], "count")
		i = i + 1
	end
	-- (the costume popped and put back: the components made again, the object states kept by the set)
	SetActorCostume(a, nil)
	cr_frames(2)
	cr_snap("no_costume", "count")
	SetActorCostume(a, "cov_anim.cos")
	PlayActorChore(a, 0, "cov_anim.cos")
	cr_frames(5)
	cr_snap("again", "count")
	PutActorInSet(a, nil)
	cr_frames(2)
	cr_snap("gone", "count")
end
cr_scummvm_differs("cov_anim", "the original does not load a costume with ANIM components (the demo's: no costume, nothing drawn); ScummVM loads it and draws the object states (anim_component.cpp)") cr_test("cov_anim", cr_t_cov_anim)

-- a costume with a component of an unknown tag: what loads, and its chore
cr_t_cov_unknown_tag = function()
	local a = cov_cs_actor("cov_cs_unknown", "cov_unknown.cos")
	cr_log("costume", GetActorCostume(a))
	CR_LV = 0
	PlayActorChore(a, 0, "cov_unknown.cos")
	cr_frames(5)
	cr_log("lv", CR_LV)
	cr_log("rect", cov_cs_rect(a))
	PutActorInSet(a, nil)
end
cr_scummvm_differs("cov_unknown_tag", "ScummVM crashes: Costume::loadComponent returns no component for an unknown tag, and Costume::load calls setCostume on it (costume.cpp:163-164)") cr_test("cov_unknown_tag", cr_t_cov_unknown_tag)

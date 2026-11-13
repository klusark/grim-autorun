-- The rest of actor.cpp's corners in EMI (prefix amc_): the alpha of one mesh and of single vertices
-- (SetActorGlobalAlpha(actor, alpha or mode, mesh), SetActorLocalAlpha(actor, vertex, alpha or mode); the modes are -1 off,
-- 2 replace, 3 modulate), the sort order of an attached actor, attaching again (to the same carrier, to another, to a joint
-- that is not there, to an actor without a skeleton), collisions while walking and when placed, a line said by an actor
-- without a costume (its text is placed on the actor), and a textured costume worn again after its material was freed.
-- No pictures of the screen on EMI's original: positions, sort orders and IsMessageGoing are what is compared.
--
-- (EMI's camera in the clean room looks along +z from (0, 6, -0.5): an actor at (0, 5.2, 3) is in front of it, so that
-- ScummVM draws its mesh)

amc_e_actor = function(name, set, x, y, z, follow)
	local a = LoadActor(name)
	PutActorInSet(a, set)
	PutActorAt(a, x, y, z)
	SetActorRot(a, 0, 0, 0)
	if follow then
		SetActorFollowBoxes(a, TRUE)
	end
	return a
end

amc_e_pos = function(key, a)
	local x, y, z = GetActorPos(a)
	cr_log(key, x, y, z)
end

amc_e_wpos = function(key, a)
	local x, y, z = GetActorWorldPos(a)
	cr_log(key, x, y, z)
end

-- the alpha of the mesh cr_ebox (the actor also wears cr_lv.cos, which has no mesh) and of its vertices, drawn in between
cr_test("amc_mesh_alpha", function()
	MakeCurrentSet("cr_flat.set")
	local c = amc_e_actor("amc_alpha", "cr_flat.set", 0, 5.2, 3)
	PlayActorChore(c, "endless", "cr_lv.cos")
	PlayActorChore(c, "wear_default", "cr_ebox.cos")
	cr_frames(2)
	SetActorGlobalAlpha(c, 0.5, "cr_ebox")
	cr_frames(2)
	SetActorGlobalAlpha(c, 0.5, "amc_no_mesh")
	SetActorGlobalAlpha(c, 2, "cr_ebox")
	SetActorGlobalAlpha(c, 2, "amc_no_mesh")
	cr_frames(2)
	SetActorLocalAlpha(c, 0, 2)
	SetActorLocalAlpha(c, 0, 0.25)
	SetActorLocalAlpha(c, 5, 2)
	SetActorLocalAlpha(c, 300, 3)
	cr_frames(2)
	SetActorGlobalAlpha(c, 3, "cr_ebox")
	SetActorGlobalAlpha(c, 2)
	cr_frames(2)
	SetActorGlobalAlpha(c, -1, "cr_ebox")
	SetActorGlobalAlpha(c, -1)
	SetActorLocalAlpha(c, 0, -1)
	SetActorLocalAlpha(c, 5, -1)
	SetActorLocalAlpha(c, 300, -1)
	cr_frames(2)
	amc_e_pos("pos", c)
	cr_log("sort", GetActorSortOrder(c))
	StopActorChores(c)
	cr_frames(1)
	PutActorInSet(c, nil)
end)

amc_e_pair = function()
	MakeCurrentSet("cr_flat.set")
	local c = amc_e_actor("amc_carrier", "cr_flat.set", 1, 0, 0, 1)
	PlayActorChore(c, "wear_default", "cr_ebox.cos")
	local r = amc_e_actor("amc_rider", "cr_flat.set", 0, 0, 0)
	cr_frames(2)
	return c, r
end

amc_e_unpair = function(c, r)
	StopActorChores(c)
	SetActorSortOrder(c, 0)
	SetActorSortOrder(r, 0)
	cr_frames(1)
	PutActorInSet(r, nil)
	PutActorInSet(c, nil)
end

-- the sort order of a rider: its carrier's while attached, until it is given one of its own; and after DetachActor
cr_test("amc_sort_attached", function()
	local c, r = amc_e_pair()
	SetActorSortOrder(c, 3)
	SetActorSortOrder(r, 1)
	cr_log("before", GetActorSortOrder(r), GetActorSortOrder(c))
	AttachActor(r, c, "body")
	cr_log("attached", GetActorSortOrder(r), GetActorSortOrder(c))
	SetActorSortOrder(c, 4)
	cr_log("carrier_set", GetActorSortOrder(r), GetActorSortOrder(c))
	SetActorSortOrder(r, 6)
	cr_log("rider_set", GetActorSortOrder(r), GetActorSortOrder(c))
	SetActorSortOrder(c, 8)
	cr_log("carrier_again", GetActorSortOrder(r), GetActorSortOrder(c))
	cr_frames(1)
	DetachActor(r)
	cr_log("detached", GetActorSortOrder(r), GetActorSortOrder(c))
	amc_e_unpair(c, r)
end)

-- attached twice to the same carrier, then to another one, then to a joint that is not there, then to an actor that has
-- no costume (no skeleton)
cr_scummvm_differs("amc_attach_again") cr_test("amc_attach_again", function()
	local c, r = amc_e_pair()
	local d = amc_e_actor("amc_carrier2", "cr_flat.set", -1, 0, 1, 1)
	PlayActorChore(d, "wear_default", "cr_ebox.cos")
	local n = amc_e_actor("amc_bare", "cr_flat.set", 0, 0, -1, 1)
	cr_frames(2)
	AttachActor(r, c, "body")
	cr_frames(1)
	amc_e_wpos("first", r)
	AttachActor(r, c, "body")
	cr_frames(1)
	amc_e_wpos("same_again", r)
	amc_e_pos("same_again_pos", r)
	AttachActor(r, d, "body")
	cr_frames(1)
	amc_e_wpos("other", r)
	amc_e_pos("other_pos", r)
	PutActorAt(d, -1, 0, 2)
	cr_frames(1)
	amc_e_wpos("other_moved", r)
	AttachActor(r, c, "amc_no_joint")
	cr_frames(1)
	amc_e_wpos("no_joint", r)
	amc_e_pos("no_joint_pos", r)
	PutActorAt(c, 1, 0, 1)
	cr_frames(1)
	amc_e_wpos("no_joint_moved", r)
	AttachActor(r, n, "body")
	cr_frames(1)
	amc_e_wpos("bare", r)
	amc_e_pos("bare_pos", r)
	PutActorAt(n, 0, 0, -1.5)
	cr_frames(1)
	amc_e_wpos("bare_moved", r)
	DetachActor(r)
	cr_frames(1)
	amc_e_wpos("detached", r)
	StopActorChores(d)
	PutActorInSet(d, nil)
	PutActorInSet(n, nil)
	amc_e_unpair(c, r)
end)

AMC_ELL = "cr_ell.set"

amc_e_moving = function()
	return not IsActorMoving(AMC_EW)
end

-- a walk round the corner of cr_ell (EMI: the floor in x-z) from (x0, z0) to (x1, z1) past another actor at (ox, oz):
-- the walker's and the other's collision modes, the other with cr_ebox.cos or without a costume
amc_e_walk = function(key, wmode, omode, ocos, ox, oz, x0, z0, x1, z1)
	MakeCurrentSet(AMC_ELL)
	local w = amc_e_actor("amc_ewalker", AMC_ELL, x0, 0, z0, 1)
	AMC_EW = w
	PlayActorChore(w, "wear_default", "cr_ebox.cos")
	SetActorWalkRate(w, 1)
	local o = amc_e_actor("amc_eother", AMC_ELL, ox, 0, oz, 1)
	if ocos then
		PlayActorChore(o, "wear_default", ocos)
	end
	cr_frames(2)
	SetActorCollisionMode(w, wmode)
	SetActorCollisionScale(w, 0.3)
	SetActorCollisionMode(o, omode)
	SetActorCollisionScale(o, 0.3)
	cr_frames(1)
	WalkActorTo(w, x1, 0, z1)
	local i = 0
	while i < 5 do
		cr_frames(20)
		amc_e_pos(key .. "_f" .. (i + 1) * 20, w)
		i = i + 1
	end
	local f = cr_until(amc_e_moving, 200)
	cr_log(key .. "_frames", f)
	amc_e_pos(key .. "_end", w)
	amc_e_pos(key .. "_other", o)
	SetActorCollisionMode(w, 0)
	SetActorCollisionMode(o, 0)
	SetActorCollisionScale(w, 1)
	SetActorCollisionScale(o, 1)
	StopActorChores(w)
	StopActorChores(o)
	cr_frames(1)
	PutActorInSet(w, nil)
	PutActorInSet(o, nil)
end

cr_scummvm_differs("amc_ewalk_sphere", "the walk does not go round the other actor (getTangentPos works in x-y, actor.cpp:2075)") cr_test("amc_ewalk_sphere", function()
	amc_e_walk("sphere", 2, 2, "cr_ebox.cos", -0.55, -0.35, -1, -1, 1, 1)
end)

cr_scummvm_differs("amc_ewalk_box", "the walk does not go round the other actor (getTangentPos works in x-y, actor.cpp:2075)") cr_test("amc_ewalk_box", function()
	amc_e_walk("box", 1, 2, "cr_ebox.cos", -0.55, -0.35, -1, -1, 1, 1)
	amc_e_walk("box_other", 2, 1, "cr_ebox.cos", -0.55, -0.35, -1, -1, 1, 1)
end)

cr_scummvm_differs("amc_ewalk_nocos", "the walk round the corner differs (as in emi_actors)") cr_test("amc_ewalk_nocos", function()
	amc_e_walk("nocos", 2, 2, nil, -0.55, -0.35, -1, -1, 1, 1)
end)

-- from ell_b to ell_c along z (x the same all the way), the other actor far away in ell_a
cr_scummvm_differs("amc_ewalk_along_z", "the walk is a little behind at frame 20, 0.1115 against 0.1152") cr_test("amc_ewalk_along_z", function()
	amc_e_walk("along_z", 2, 2, "cr_ebox.cos", -1.5, -1.5, 1, -1, 1, 1)
end)

-- placed next to an actor that collides: one without a costume, then one with
cr_scummvm_differs("amc_eput_collide", "setPos drops the collision's move (actor.cpp:521)") cr_test("amc_eput_collide", function()
	MakeCurrentSet("cr_flat.set")
	local o = amc_e_actor("amc_ewall", "cr_flat.set", 0, 0, 0, 1)
	PlayActorChore(o, "wear_default", "cr_ebox.cos")
	local p = amc_e_actor("amc_eput", "cr_flat.set", 1.5, 0, 0, 1)
	cr_frames(2)
	SetActorCollisionMode(o, 2)
	SetActorCollisionMode(p, 2)
	PutActorAt(p, 0.2, 0, 0)
	cr_frames(1)
	amc_e_pos("bare", p)
	PlayActorChore(p, "wear_default", "cr_ebox.cos")
	cr_frames(2)
	PutActorAt(p, 0.3, 0, 0.1)
	cr_frames(1)
	amc_e_pos("worn", p)
	SetActorCollisionMode(o, 1)
	PutActorAt(p, -0.2, 0, 0.1)
	cr_frames(1)
	amc_e_pos("box", p)
	SetActorCollisionMode(o, 0)
	SetActorCollisionMode(p, 0)
	StopActorChores(o)
	StopActorChores(p)
	cr_frames(1)
	PutActorInSet(o, nil)
	PutActorInSet(p, nil)
end)

-- a line with text said by an actor without a costume, in the set and in view: the text is placed on the actor
cr_test("amc_say_bare", function()
	MakeCurrentSet("cr_flat.set")
	local a = amc_e_actor("amc_sayer", "cr_flat.set", 0, 5.2, 3)
	SetSayLineDefaults({ font = "cr_font.laf" })
	cr_frames(1)
	SayLine(a, "/crtv02/Clean room")
	cr_log("at_once", IsMessageGoing())
	cr_frames(3)
	cr_log("going", IsMessageGoing())
	ShutUpActor(a)
	cr_frames(2)
	cr_log("shut_up", IsMessageGoing())
	PutActorInSet(a, nil)
	ExpireText()
	cr_frames(1)
end)

-- a textured costume (cr_esprite.cos: cr_etex.mesh and the sprite on cr_tex.tga) worn, taken off (its material freed)
-- and worn again
cr_test("amc_material_again", function()
	MakeCurrentSet("cr_flat.set")
	local a = amc_e_actor("amc_tex", "cr_flat.set", 0, 5.2, 3)
	local w = PlayActorChore(a, "wear_default", "cr_esprite.cos")
	cr_frames(3)
	cr_log("worn", CR_LV, IsChorePlaying(w))
	StopActorChores(a)
	cr_frames(3)
	CR_LV = 0
	w = PlayActorChore(a, "wear_default", "cr_esprite.cos")
	cr_frames(3)
	cr_log("worn_again", CR_LV, IsChorePlaying(w))
	StopActorChores(a)
	cr_frames(2)
	PutActorInSet(a, nil)
end)

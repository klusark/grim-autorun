-- The header of a binary model (radius, bounding box, centre) against its mesh (ScummVM commit dc7e5c2, "Fix collision
-- handling for box models"). The models of assets.py HEADER_MODELS have the body box of cr_box.3do with a header that is
-- not the one of the vertices:
--   cr_ctrx: the centre 0.5 m to +x, 0.2 m up       cr_ctrz: the centre 3 m up
--   cr_bbig: bounding box 2 x 2 m, radius 1 m        cr_bside: bounding box and centre 1 m to -x, radius 0.3 m
-- The original ignores the header: rdModel3_LoadPostProcess works the box out from the vertices through the node
-- transforms, the centre as its middle and the radius as half its diagonal. An engine that reads the header stops the
-- mover somewhere else with these. With the header the original works out (what a real model has):
--   cr_meshx: the box 0.5 m to +x by its vertices    cr_nodex: by its node    cr_float: 0.6 m high, from 1 m up

cr_hdr_actor = function(name, cos, x, y)
	local a = LoadActor(name)
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, x, y, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, cos)
	return a
end

-- (a, costume ca, walks forward from (0, -1) into b, costume cb, at (0.1, 0.5); mode 1 box, 2 sphere, for both)
cr_hdr_case = function(key, ca, cb, mode, scale)
	MakeCurrentSet("cr_flat.set")
	local a = cr_hdr_actor("cr_hdr_mover", ca, 0, -1)
	local b = cr_hdr_actor("cr_hdr_wall", cb, 0.1, 0.5)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 1)
	SetActorCollisionMode(a, mode)
	SetActorCollisionMode(b, mode)
	if scale then
		SetActorCollisionScale(a, scale)
		SetActorCollisionScale(b, scale)
	end
	cr_frames(1)
	local i = 0
	while i < 90 do
		WalkActorForward(a)
		if mod(i, 15) == 0 then
			cr_pos(key .. "_f" .. i, a)
		end
		break_here()
		i = i + 1
	end
	cr_pos(key .. "_end", a)
	cr_pos(key .. "_other", b)
	SetActorCollisionMode(a, 0)
	SetActorCollisionMode(b, 0)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end

cr_hdr_test = function(key, ca, cb, mode, scale)
	cr_test("hdr_" .. key, function()
		cr_hdr_case(%key, %ca, %cb, %mode, %scale)
	end)
end

-- the other actor's centre is not where its mesh is
cr_hdr_test("ctrx_wall_sphere", "cr_box.cos", "cr_ctrx.cos", 2)
cr_hdr_test("ctrx_wall_box", "cr_box.cos", "cr_ctrx.cos", 1)
cr_hdr_test("ctrz_wall_sphere", "cr_box.cos", "cr_ctrz.cos", 2)
cr_hdr_test("ctrz_wall_box", "cr_box.cos", "cr_ctrz.cos", 1)
-- the mover's centre is not where its mesh is
cr_hdr_test("ctrx_mover_sphere", "cr_ctrx.cos", "cr_box.cos", 2)
cr_hdr_test("ctrz_mover_sphere", "cr_ctrz.cos", "cr_box.cos", 2)
cr_hdr_test("ctrz_both_sphere", "cr_ctrz.cos", "cr_ctrz.cos", 2)
-- the header's bounding box and radius against the mesh's
cr_hdr_test("bbig_wall_box", "cr_box.cos", "cr_bbig.cos", 1)
cr_hdr_test("bbig_wall_sphere", "cr_box.cos", "cr_bbig.cos", 2)
cr_hdr_test("bbig_mover_sphere", "cr_bbig.cos", "cr_box.cos", 2)
cr_hdr_test("bbig_wall_box_half", "cr_box.cos", "cr_bbig.cos", 1, 0.5)
cr_hdr_test("bside_wall_box", "cr_box.cos", "cr_bside.cos", 1)
cr_hdr_test("bside_wall_sphere", "cr_box.cos", "cr_bside.cos", 2)
cr_hdr_test("bside_mover_sphere", "cr_bside.cos", "cr_box.cos", 2)
-- the centre where the mesh has it, off the actor's origin (dc7e5c2: the sphere of either actor at its model's centre)
cr_hdr_test("meshx_wall_sphere", "cr_box.cos", "cr_meshx.cos", 2)
cr_hdr_test("meshx_mover_sphere", "cr_meshx.cos", "cr_box.cos", 2)
cr_hdr_test("meshx_wall_box", "cr_box.cos", "cr_meshx.cos", 1)
cr_hdr_test("nodex_wall_sphere", "cr_box.cos", "cr_nodex.cos", 2)
cr_hdr_test("nodex_mover_sphere", "cr_nodex.cos", "cr_box.cos", 2)
cr_hdr_test("float_wall_sphere", "cr_box.cos", "cr_float.cos", 2)
cr_hdr_test("float_mover_sphere", "cr_float.cos", "cr_box.cos", 2)
cr_hdr_test("float_both_sphere", "cr_float.cos", "cr_float.cos", 2)
cr_hdr_test("float_wall_sphere_half", "cr_box.cos", "cr_float.cos", 2, 0.5)

-- what the header gives the Lua side: the rectangle and the node locations
cr_t_hdr_rects = function()
	MakeCurrentSet("cr_flat.set")
	local names = { "cr_box", "cr_ctrx", "cr_ctrz", "cr_bbig", "cr_bside", "cr_meshx", "cr_nodex", "cr_float" }
	local i = 1
	while names[i] do
		local a = cr_hdr_actor("cr_hdr_r" .. i, names[i] .. ".cos", 0.5, -0.5)
		cr_frames(1)
		cr_log(names[i] .. "_rect", GetActorRect(a))
		local x, y, z = GetActorNodeLocation(a, 2)
		cr_log(names[i] .. "_head", x, y, z)
		PutActorInSet(a, nil)
		i = i + 1
	end
end
cr_test("hdr_rects", cr_t_hdr_rects)

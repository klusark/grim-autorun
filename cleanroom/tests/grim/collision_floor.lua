-- An actor pushed by another's collision sphere stays on the floor: only its height (z) is logged, so that this test has
-- no mark of its own (model_header.lua's hdr_* cases are marked for their x and y). The spheres' centres can be at
-- different heights (cr_float's model is 0.6 m high from 1 m up, cr_ctrx's header puts its centre 0.2 m up): ScummVM
-- pushed along the 3D line between them, and only its per-frame snapping to the walkboxes (taken out in f6b233dca49)
-- put the actor back on the floor; the push itself is fixed in grim-collision-plane (ef081e28a5e). On the original the
-- height is 0 at the end of the walk.

-- (a, costume ca, walks forward from (0, -1) into b, costume cb, at (0.1, 0.5), both in sphere mode, as cr_hdr_case)
cr_cf_case = function(key, ca, cb, scale)
	MakeCurrentSet("cr_flat.set")
	local a = LoadActor("cr_cf_mover")
	PutActorInSet(a, "cr_flat.set")
	PutActorAt(a, 0, -1, 0)
	SetActorRot(a, 0, 0, 0)
	SetActorCostume(a, ca)
	local b = LoadActor("cr_cf_wall")
	PutActorInSet(b, "cr_flat.set")
	PutActorAt(b, 0.1, 0.5, 0)
	SetActorRot(b, 0, 0, 0)
	SetActorCostume(b, cb)
	SetActorFollowBoxes(a, TRUE)
	SetActorWalkRate(a, 1)
	SetActorCollisionMode(a, 2)
	SetActorCollisionMode(b, 2)
	if scale then
		SetActorCollisionScale(a, scale)
		SetActorCollisionScale(b, scale)
	end
	cr_frames(1)
	local i = 0
	while i < 90 do
		WalkActorForward(a)
		break_here()
		i = i + 1
	end
	local x, y, z = GetActorPos(a)
	cr_log(key .. "_z", z)
	cr_frames(10)
	x, y, z = GetActorPos(a)
	cr_log(key .. "_z_after", z)
	SetActorCollisionMode(a, 0)
	SetActorCollisionMode(b, 0)
	PutActorInSet(a, nil)
	PutActorInSet(b, nil)
end

cr_cf_test = function(key, ca, cb, scale)
	cr_test("floor_" .. key, function()
		cr_cf_case(%key, %ca, %cb, %scale)
	end)
end

cr_cf_test("float_wall", "cr_box.cos", "cr_float.cos")
cr_cf_test("float_mover", "cr_float.cos", "cr_box.cos")
cr_cf_test("float_wall_half", "cr_box.cos", "cr_float.cos", 0.5)
cr_cf_test("ctrx_wall", "cr_box.cos", "cr_ctrx.cos")
cr_cf_test("ctrx_mover", "cr_ctrx.cos", "cr_box.cos")

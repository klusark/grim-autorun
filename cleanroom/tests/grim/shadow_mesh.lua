-- Shadows that are drawn: cr_sbox.cos, the white draw box with a mesh whose "shadow" value is 1 (assets.py). Only such a mesh
-- casts a shadow (sputCostume_DrawMeshShadow 0x494940): the 16 corners of its box are projected from the shadow point through
-- the shadow plane, and the box's four faces, clipped to each sector of the plane (sputCostume_OutputShadowPoly 0x494bf0,
-- WalkPlane_ClipPoly), are drawn with shadow.mat through shadow.cmp. shadow.lua's boxes have no such mesh. Seen through
-- cr_snap(key, "dark"): the box of the pixels darker than the background.

cr_shm_test = function(name, fn)
	cr_test("shadow_mesh_" .. name, function()
		MakeCurrentSet("cr_open.set")
		local a = LoadActor("cr_shm_a")
		PutActorInSet(a, "cr_open.set")
		PutActorAt(a, 0, 0, 0)
		SetActorRot(a, 0, 0, 0)
		SetActorCostume(a, "cr_sbox.cos")
		cr_frames(2)
		%fn(%name, a)
		KillActorShadows(a)
		cr_frames(2)
		PutActorInSet(a, nil)
	end)
end

-- the shadow from a point, onto shadow1 (and the planes given)
cr_shm_on = function(a, x, y, z, planes)
	SetActiveShadow(a, 0)
	SetActorShadowPoint(a, x, y, z)
	SetActorShadowPlane(a, "shadow1")
	local i = 1
	planes = planes or { "shadow1" }
	while planes[i] do
		AddShadowPlane(a, planes[i])
		i = i + 1
	end
	ActivateActorShadow(a, TRUE, 0)
	cr_frames(3)
end

cr_shm_test("none", function(k, a)
	cr_snap(k .. "_dark", "dark")
	cr_snap(k .. "_box")
end)

local points = {
	{ "above", 0, 0, 10 },
	{ "left", -4, 0, 3 },
	{ "right", 4, 0, 3 },
	{ "front", 0, 4, 2 },
	{ "back", 0, -4, 2 },
	{ "low", 3, 3, 1 },
	{ "far", -1, 1, 30 },
}
local i = 1
while points[i] do
	cr_shm_test("point_" .. points[i][1], function(k, a)
		local p = %points[%i]
		cr_shm_on(a, p[2], p[3], p[4])
		cr_snap(k .. "_dark", "dark")
		cr_snap(k .. "_box")
	end)
	i = i + 1
end

-- below the top of the box: the corners above the point do not meet the plane (the whole shadow is left out)
cr_shm_test("point_below_top", function(k, a)
	cr_shm_on(a, -3, 0, 0.3)
	cr_snap(k .. "_dark", "dark")
end)

-- a long shadow that leaves shadow1 (6 x 6 m): clipped at its edge; onto the floor sector too (4 x 4 m)
cr_shm_test("clipped", function(k, a)
	cr_shm_on(a, -1.2, 0, 0.8)
	cr_snap(k .. "_dark", "dark")
end)

cr_shm_test("two_planes", function(k, a)
	cr_shm_on(a, -1.2, 0, 0.8, { "shadow1", "floor" })
	cr_snap(k .. "_dark", "dark")
end)

cr_shm_test("floor_only", function(k, a)
	cr_shm_on(a, -1.2, 0, 0.8, { "floor" })
	cr_snap(k .. "_dark", "dark")
end)

-- the actor moved and turned under the shadow point; the shadow colour; turned off again
cr_shm_test("moved", function(k, a)
	cr_shm_on(a, 0, 0, 4)
	PutActorAt(a, 1, -1, 0)
	SetActorRot(a, 0, 30, 0)
	cr_frames(3)
	cr_snap(k .. "_dark", "dark")
	cr_snap(k .. "_box")
end)

cr_shm_test("deactivated", function(k, a)
	cr_shm_on(a, -4, 0, 3)
	cr_snap(k .. "_on", "dark")
	ActivateActorShadow(a, FALSE, 0)
	cr_frames(3)
	cr_snap(k .. "_off", "dark")
end)

cr_shm_test("distance", function(k, a)
	cr_shm_on(a, 0, 0, 4)
	cr_log(k .. "_dist", ActorDistToShadowPlane(a, "shadow1"))
	PutActorAt(a, 0.5, 0.5, 0)
	cr_frames(2)
	cr_log(k .. "_dist_moved", ActorDistToShadowPlane(a, "shadow1"))
end)

-- (ScummVM differs: tools/mark_known.py)
cr_scummvm_differs("shadow_mesh_clipped")
cr_scummvm_differs("shadow_mesh_deactivated")
cr_scummvm_differs("shadow_mesh_distance")
cr_scummvm_differs("shadow_mesh_floor_only")
cr_scummvm_differs("shadow_mesh_moved")
cr_scummvm_differs("shadow_mesh_none")
cr_scummvm_differs("shadow_mesh_point_above")
cr_scummvm_differs("shadow_mesh_point_back")
cr_scummvm_differs("shadow_mesh_point_below_top")
cr_scummvm_differs("shadow_mesh_point_far")
cr_scummvm_differs("shadow_mesh_point_front")
cr_scummvm_differs("shadow_mesh_point_left")
cr_scummvm_differs("shadow_mesh_point_low")
cr_scummvm_differs("shadow_mesh_point_right")
cr_scummvm_differs("shadow_mesh_two_planes")

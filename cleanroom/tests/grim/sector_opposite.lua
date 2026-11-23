-- GetSectorOppositeEdge(actor, name): the original (sputLua_GetSectorOppositeEdge 0x49ed90) finds the sector by its exact
-- name (WalkPlane_PlaneNamed) and moves the actor itself (sputActor_LeaveSector -> WalkPlane_JumpOut 0x4a7390): for a sector
-- of four edges, the point 10 units behind the actor is clipped onto the edge the actor came through, and the actor is put
-- on the edge two further on, at the same place counted from its other end. The script gets no values
-- (Actor.teleport_out_of_hot_box in _actors.lua). cr_edge.set: e_left x -2..0, y -2..2; cr_funnel.set: fn_trap (slanted
-- edges), fn_tri (three edges).

cr_sopp_try = function(key, a, x, y, z, rot, name)
	PutActorAt(a, x, y, z)
	SetActorRot(a, 0, rot, 0)
	local r1, r2, r3 = GetSectorOppositeEdge(a, name)
	cr_log(key .. "_ret", r1, r2, r3)
	cr_pos(key, a)
end

-- the name: exact, a part of it, another case, none
cr_t_sopp_names = function()
	local a = cr_actor("cr_edge.set")
	cr_frames(1)
	cr_sopp_try("exact", a, -0.5, 0.5, 0, 0, "e_left")
	cr_sopp_try("part", a, -0.5, 0.5, 0, 0, "e_lef")
	cr_sopp_try("upper", a, -0.5, 0.5, 0, 0, "E_LEFT")
	cr_sopp_try("none", a, -0.5, 0.5, 0, 0, "no_such")
end
cr_scummvm_differs("sopp_names", "master: GetSectorOppositeEdge matches a part of the name and gives the point to the script instead of moving the actor") cr_test("sopp_names", cr_t_sopp_names)

-- the way the actor faces (the line goes behind it)
cr_t_sopp_facing = function()
	local a = cr_actor("cr_edge.set")
	cr_frames(1)
	cr_sopp_try("rot_0", a, -0.5, 0.5, 0, 0, "e_left")
	cr_sopp_try("rot_90", a, -0.5, 0.5, 0, 90, "e_left")
	cr_sopp_try("rot_180", a, -0.5, 0.5, 0, 180, "e_left")
	cr_sopp_try("rot_270", a, -0.5, 0.5, 0, 270, "e_left")
	cr_sopp_try("rot_30", a, -0.5, 0.5, 0, 30, "e_left")
	cr_sopp_try("rot_135", a, -0.5, 0.5, 0, 135, "e_left")
	cr_sopp_try("corner", a, -1.9, -1.9, 0, 225, "e_left")
end
cr_scummvm_differs("sopp_facing", "master: GetSectorOppositeEdge gives the point to the script instead of moving the actor") cr_test("sopp_facing", cr_t_sopp_facing)

-- a sector that is off, an actor outside of the sector, a sector that is not the actor's
cr_t_sopp_places = function()
	local a = cr_actor("cr_edge.set")
	cr_frames(1)
	MakeSectorActive("e_left", FALSE)
	cr_sopp_try("left_off", a, -0.5, 0.5, 0, 0, "e_left")
	MakeSectorActive("e_left", TRUE)
	cr_sopp_try("outside", a, 1, 0.5, 0, 0, "e_left")
	cr_sopp_try("outside_far", a, 1, 0.5, 0, 90, "e_left")
	cr_sopp_try("off_sector", a, -0.5, 0.5, 0, 0, "e_off")
end
cr_scummvm_differs("sopp_places", "master: GetSectorOppositeEdge gives the point to the script instead of moving the actor") cr_test("sopp_places", cr_t_sopp_places)

-- slanted edges (fn_trap) and a sector of three edges (fn_tri: nothing happens)
cr_t_sopp_shapes = function()
	local a = cr_actor("cr_funnel.set")
	cr_frames(1)
	cr_sopp_try("trap_rot_90", a, 2.5, -1, 0, 90, "fn_trap")
	cr_sopp_try("trap_rot_270", a, 2.5, -1, 0, 270, "fn_trap")
	cr_sopp_try("trap_rot_0", a, 2.5, -1, 0, 0, "fn_trap")
	cr_sopp_try("trap_rot_200", a, 3, -1.2, 0, 200, "fn_trap")
	cr_sopp_try("tri", a, -1.8, -2.2, 0, 0, "fn_tri")
	cr_sopp_try("tri_rot_90", a, -1.8, -2.2, 0, 90, "fn_tri")
end
cr_scummvm_differs("sopp_shapes", "master: GetSectorOppositeEdge gives the point to the script instead of moving the actor, also for three edges") cr_test("sopp_shapes", cr_t_sopp_shapes)

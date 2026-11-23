-- EMI's GetSectorOppositeEdge(actor, name) (Monkey4.exe Lua_GetSectorOppositeEdge 0x419600): the sector by its exact name
-- (SectorList_FindByExactName), then Actor_MoveToSectorOppositeEdge -> Sector_JumpOut (0x444780), Grim's WalkPlane_JumpOut
-- on the x-z floor; nothing is given to the script. And MakeSectorActive with a number (Lua_MakeSectorActive 0x4199d0: the
-- id of the sector; Grim's original looks a number up as a name). cr_edge.set: e_left x -2..0, z -2..2; cr_funnel.set:
-- fn_trap, fn_tri.

cr_eso_try = function(key, a, x, z, yaw, name)
	PutActorAt(a, x, 0, z)
	SetActorRot(a, 0, yaw, 0)
	local r1, r2, r3 = GetSectorOppositeEdge(a, name)
	cr_log(key .. "_ret", r1, r2, r3)
	cr_ea_pos(key, a)
end

cr_t_eopp_names = function()
	local a = cr_ea_actor("cr_edge.set")
	cr_frames(1)
	cr_eso_try("exact", a, -0.5, 0.5, 0, "e_left")
	cr_eso_try("part", a, -0.5, 0.5, 0, "e_lef")
	cr_eso_try("upper", a, -0.5, 0.5, 0, "E_LEFT")
	cr_eso_try("none", a, -0.5, 0.5, 0, "no_such")
	PutActorInSet(a, nil)
end
cr_scummvm_differs("eopp_names", "master: GetSectorOppositeEdge matches a part of the name, works on Grim's x-y floor and gives the script a point") cr_test("eopp_names", cr_t_eopp_names)

cr_t_eopp_facing = function()
	local a = cr_ea_actor("cr_edge.set")
	cr_frames(1)
	cr_eso_try("yaw_0", a, -0.5, 0.5, 0, "e_left")
	cr_eso_try("yaw_90", a, -0.5, 0.5, 90, "e_left")
	cr_eso_try("yaw_180", a, -0.5, 0.5, 180, "e_left")
	cr_eso_try("yaw_270", a, -0.5, 0.5, 270, "e_left")
	cr_eso_try("yaw_30", a, -0.5, 0.5, 30, "e_left")
	-- (from -0.5 0.5 at 135 degrees the line runs through the corner -2 2: which edge wins is down to the rounding of the
	-- sine and cosine, the original's differ from ScummVM's, so the actor starts a little lower)
	cr_eso_try("yaw_135", a, -0.5, 0.3, 135, "e_left")
	MakeSectorActive("e_left", FALSE)
	cr_eso_try("left_off", a, -0.5, 0.5, 0, "e_left")
	MakeSectorActive("e_left", TRUE)
	cr_eso_try("outside", a, 1, 0.5, 0, "e_left")
	PutActorInSet(a, nil)
end
cr_scummvm_differs("eopp_facing", "master: GetSectorOppositeEdge works on Grim's x-y floor and gives the script a point") cr_test("eopp_facing", cr_t_eopp_facing)

cr_t_eopp_shapes = function()
	local a = cr_ea_actor("cr_funnel.set")
	cr_frames(1)
	cr_eso_try("trap_yaw_90", a, 2.5, -1, 90, "fn_trap")
	cr_eso_try("trap_yaw_270", a, 2.5, -1, 270, "fn_trap")
	cr_eso_try("trap_yaw_200", a, 3, -1.2, 200, "fn_trap")
	cr_eso_try("tri", a, -1.8, -2.2, 0, "fn_tri")
	PutActorInSet(a, nil)
end
cr_scummvm_differs("eopp_shapes", "master: GetSectorOppositeEdge works on Grim's x-y floor and gives the script a point") cr_test("eopp_shapes", cr_t_eopp_shapes)

-- MakeSectorActive with the number of a sector (e_left is the first one, 0; e_off is 3)
cr_t_eopp_active_number = function()
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
	MakeSectorActive(0, FALSE)
	cr_log("left_off_by_number", IsPointInSector(-1, 0, 0, "e_left"))
	MakeSectorActive(0, TRUE)
	cr_log("left_on_by_number", IsPointInSector(-1, 0, 0, "e_left"))
	MakeSectorActive(3, TRUE)
	cr_log("off_on_by_number", IsPointInSector(0, 0, -3, "e_off"))
	MakeSectorActive(3, FALSE)
	cr_log("off_off_by_number", IsPointInSector(0, 0, -3, "e_off"))
	MakeSectorActive("0", FALSE)
	cr_log("left_by_string_number", IsPointInSector(-1, 0, 0, "e_left"))
	MakeSectorActive("0", TRUE)
end
cr_scummvm_differs("eopp_active_number", "master: a sector that is off contains points") cr_test("eopp_active_number", cr_t_eopp_active_number)

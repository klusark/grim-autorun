-- EMI's IsPointInSector and IsActorInSector: Monkey4.exe (0x416a40, 0x416790) finds the sector by its exact name
-- (SectorList_FindByExactName 0x4464e0: case-sensitive, the first sector with the name) and then tests the point with
-- Sector_ContainsPointExact(.., 1), for which a sector that is off contains nothing; IsActorInSector tests the actor's
-- world position. Grim matches a part of the name instead (tests/grim/sector_off.lua).
-- cr_edge.set (x-z floor): e_left (x -2..0), e_right (x 0..2), e_gap (z 2..4), e_off (z -4..-2, off), e_wedge.

cr_esl_point = function(key, x, y, z, name)
	local id, sname, typ = IsPointInSector(x, y, z, name)
	cr_log(key, id, sname, typ)
end

cr_esl_actor = function(key, a, name)
	local id, sname, typ = IsActorInSector(a, name)
	cr_log(key, id, sname, typ)
end

-- the name: exact, a part of it, another case
cr_t_esl_point_names = function()
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
	cr_esl_point("exact", -1, 0, 0, "e_left")
	cr_esl_point("part_end", -1, 0, 0, "left")
	cr_esl_point("part_start", -1, 0, 0, "e_lef")
	cr_esl_point("prefix", -1, 0, 0, "e_")
	cr_esl_point("upper", -1, 0, 0, "E_LEFT")
	cr_esl_point("longer", -1, 0, 0, "e_left2")
	cr_esl_point("other_sector", -1, 0, 0, "e_right")
	cr_esl_point("empty", -1, 0, 0, "")
	cr_esl_point("right_exact", 1, 0, 0, "e_right")
	cr_esl_point("right_part", 1, 0, 0, "right")
	cr_esl_point("shared_left", 0, 0, 0, "e_left")
	cr_esl_point("shared_right", 0, 0, 0, "e_right")
	cr_esl_point("shared_prefix", 0, 0, 0, "e_")
end
cr_scummvm_differs("esl_point_names", "master: IsPointInSector matches a part of the name (the Grim path), Monkey4.exe only the exact name") cr_test("esl_point_names", cr_t_esl_point_names)

-- sectors that are off
cr_t_esl_point_off = function()
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
	cr_esl_point("off_initial", 0, 0, -3, "e_off")
	cr_esl_point("off_initial_part", 0, 0, -3, "off")
	MakeSectorActive("e_off", TRUE)
	cr_esl_point("off_on", 0, 0, -3, "e_off")
	MakeSectorActive("e_off", FALSE)
	cr_esl_point("off_off", 0, 0, -3, "e_off")
	MakeSectorActive("e_left", FALSE)
	cr_esl_point("left_off", -1, 0, 0, "e_left")
	cr_esl_point("left_off_shared_right", 0, 0, 0, "e_right")
	cr_frames(1)
	cr_esl_point("left_off_frame", -1, 0, 0, "e_left")
	MakeSectorActive("e_left", TRUE)
	cr_esl_point("left_on", -1, 0, 0, "e_left")
end
cr_scummvm_differs("esl_point_off", "master: a sector that is off contains points (getSectorBySubstring ignores isVisible)") cr_test("esl_point_off", cr_t_esl_point_off)

-- an actor: the name, a sector that is off under it
cr_t_esl_actor = function()
	local a = cr_ea_actor("cr_edge.set", TRUE)
	cr_frames(1)
	PutActorAt(a, -1, 0, 0)
	cr_esl_actor("exact", a, "e_left")
	cr_esl_actor("part", a, "left")
	cr_esl_actor("prefix", a, "e_")
	cr_esl_actor("upper", a, "E_LEFT")
	MakeSectorActive("e_left", FALSE)
	cr_esl_actor("left_off", a, "e_left")
	cr_frames(2)
	cr_esl_actor("left_off_frames", a, "e_left")
	MakeSectorActive("e_left", TRUE)
	cr_esl_actor("left_on", a, "e_left")
	PutActorAt(a, 0, 0, -3)
	cr_esl_actor("in_off", a, "e_off")
	MakeSectorActive("e_off", TRUE)
	cr_esl_actor("in_off_on", a, "e_off")
	MakeSectorActive("e_off", FALSE)
	cr_esl_actor("in_off_off", a, "e_off")
	PutActorInSet(a, nil)
end
cr_scummvm_differs("esl_actor", "master: IsActorInSector finds a sector that is off (the EMI branch has no isVisible check)") cr_test("esl_actor", cr_t_esl_actor)

-- an actor attached to another one: its own position and its world position are in different sectors
cr_t_esl_actor_attached = function()
	local c = cr_ea_actor("cr_edge.set", TRUE)
	PutActorAt(c, 1, 0, 0)
	PlayActorChore(c, "wear_default", "cr_ebox.cos")
	local r = LoadActor("cr_rider")
	PutActorInSet(r, "cr_edge.set")
	PutActorAt(r, -1, 0, 0)
	SetActorRot(r, 0, 0, 0)
	cr_frames(2)
	cr_esl_actor("before_left", r, "e_left")
	cr_esl_actor("before_right", r, "e_right")
	AttachActor(r, c, nil)
	cr_frames(2)
	cr_ea_pos("attached_pos", r)
	cr_ea_wpos("attached_wpos", r)
	cr_esl_actor("attached_left", r, "e_left")
	cr_esl_actor("attached_right", r, "e_right")
	PutActorAt(c, 1, 0, 3)
	cr_frames(2)
	cr_ea_wpos("carrier_moved_wpos", r)
	cr_esl_actor("moved_right", r, "e_right")
	cr_esl_actor("moved_gap", r, "e_gap")
	-- (its own position, -2 0 0, is on the edge of e_left)
	cr_esl_actor("moved_left", r, "e_left")
	DetachActor(r)
	cr_frames(2)
	cr_ea_wpos("detached_wpos", r)
	cr_esl_actor("detached_left", r, "e_left")
	cr_esl_actor("detached_gap", r, "e_gap")
	StopActorChores(c)
	PutActorInSet(r, nil)
	PutActorInSet(c, nil)
end
cr_scummvm_differs("esl_actor_attached", "master: IsActorInSector tests the actor's own position, Monkey4.exe its world position") cr_test("esl_actor_attached", cr_t_esl_actor_attached)

-- a sector switched on (or off) stays so across a change of set (emi_sets.lua's es_point_in sees e_off on because es_active
-- left it so)
cr_esl_switch_and_return = function()
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
	MakeSectorActive("e_off", TRUE)
	MakeSectorActive("e_left", FALSE)
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
end

cr_esl_restore = function()
	MakeSectorActive("e_off", FALSE)
	MakeSectorActive("e_left", TRUE)
end

cr_t_esl_after_set_change = function()
	cr_esl_switch_and_return()
	cr_esl_point("off_point", 0, 0, -3, "e_off")
	cr_esl_point("left_point", -1, 0, 0, "e_left")
	-- the same set made current again
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
	cr_esl_point("off_point_same_set", 0, 0, -3, "e_off")
	cr_esl_restore()
end
cr_scummvm_differs("esl_after_set_change", "master: sectors that are off contain points, and switched sectors are back as the set file has them after a change of set") cr_test("esl_after_set_change", cr_t_esl_after_set_change)

-- the same seen through IsSectorActive (a builtin ScummVM's EMI does not have: a test of its own)
cr_t_esl_after_set_change_active = function()
	cr_esl_switch_and_return()
	cr_log("off_active", IsSectorActive("e_off"))
	cr_log("left_active", IsSectorActive("e_left"))
	cr_esl_restore()
end
cr_scummvm_differs("esl_after_set_change_active", "ScummVM's EMI has no IsSectorActive") cr_test("esl_after_set_change_active", cr_t_esl_after_set_change_active)

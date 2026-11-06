-- Sets: loading a hand-made set, its setup and its sectors

-- (the walk sector at a point: id, name and type, or nil)
cr_point = function(key, x, y, z)
	local id, name, typ = GetPointSector(x, y, z)
	cr_log(key, id, name, typ)
end

cr_t_set_flat = function()
	MakeCurrentSet("cr_flat.set")
	cr_frames(1)
	cr_log("setup", GetCurrentSetup("cr_flat.set"))
	cr_point("centre", 0, 0, 0)
	cr_point("corner_in", 1.99, 1.99, 0)
	cr_point("outside", 2.5, 0, 0)
	cr_point("on_edge", 2, 0, 0)
	cr_log("in_floor", IsPointInSector(0, 0, 0, "floor"), IsPointInSector(3, 0, 0, "floor"))
end
cr_test("set_flat", cr_t_set_flat)

cr_t_set_edge = function()
	MakeCurrentSet("cr_edge.set")
	cr_frames(1)
	cr_point("shared_edge", 0, 0, 0)
	cr_point("left", -1, 0, 0)
	cr_point("right", 1, 0, 0)
	cr_point("in_gap", 0, 2.00001, 0)
	cr_point("gap_floor", 0, 3, 0)
	cr_point("off_floor", 0, -3, 0)
	cr_point("wedge", 3, -1, 0)
	cr_point("wedge_slant", 3.9, 0.1, 0)
	MakeSectorActive("e_off", TRUE)
	cr_point("off_on", 0, -3, 0)
	MakeSectorActive("e_off", FALSE)
	cr_point("off_again", 0, -3, 0)
end
cr_scummvm_differs("set_edge") cr_test("set_edge", cr_t_set_edge)

cr_t_set_stair = function()
	MakeCurrentSet("cr_stair.set")
	cr_frames(1)
	cr_point("lo", 0, -1, 0)
	cr_point("ramp_mid", 0, 0.5, 0.25)
	cr_point("hi", 0, 2, 0.5)
	local id, name, typ = GetPointSector(1.5, -2.5, 0, 8192)
	cr_log("hot_type", id, name, typ)
end
cr_test("set_stair", cr_t_set_stair)
